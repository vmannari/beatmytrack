"""Run product projection separately from competitive verification workers."""

import argparse
import logging
import signal
import threading
import time
from dataclasses import replace

from sqlalchemy import select

from .config import Settings
from .db import make_engine, make_session_factory
from .product_analytics import project_pending
from .telemetry_models import ProductEvent
from .telemetry_processing import actor_once, maintenance, publish, record_failure, retry_stage, shared_once
from .telemetry_queue import fold_one, prepare


def pending_exists(factory):
    with factory() as session:
        return session.scalar(select(ProductEvent.id).where(ProductEvent.processed_at.is_(None))
            .order_by(ProductEvent.received_at, ProductEvent.id).limit(1)) is not None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--stage", choices=("all", "actor", "shared", "rollup", "maintenance"), default="all")
    args = parser.parse_args()
    settings = Settings.from_env()
    if not settings.telemetry_enabled:
        print("Product telemetry is disabled")
        return
    stop = threading.Event()
    for signum in (signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, lambda *_args: stop.set())
    engine = make_engine(settings.database_url, replace(settings, database_pool_size=1, database_pool_overflow=0))
    try:
        factory = make_session_factory(engine)
        if args.once and args.stage == "all":
            print(project_pending(factory, limit=settings.telemetry_processor_batch,
                raw_days=settings.telemetry_raw_days, fact_days=settings.telemetry_fact_days), flush=True)
            return
        roles = ("actor", "shared", "rollup") if args.stage == "all" else (args.stage,)
        turn, idle_wait, summary_at, maintenance_at = 0, .05, 0.0, 0.0
        while not stop.is_set():
            role = roles[turn % len(roles)]
            turn += 1
            try:
                prepare(factory, settings.telemetry_processor_batch)
                if role == "actor":
                    worked = retry_stage(actor_once, factory, settings.telemetry_processor_batch,
                        fact_days=settings.telemetry_fact_days)
                elif role == "shared":
                    worked = retry_stage(shared_once, factory, settings.telemetry_processor_batch,
                        fact_days=settings.telemetry_fact_days)
                elif role == "rollup":
                    worked = retry_stage(fold_one, factory, time.time(), settings.telemetry_fact_days,
                        settings.telemetry_processor_batch)
                else:
                    worked = False
            except Exception as error:  # noqa: BLE001 - retain evidence and service unrelated owners
                record_failure(factory, error)
                logging.getLogger("bmt.product").error("telemetry_stage_failed stage=%s error=%s", role, type(error).__name__)
                worked = False
            tick = time.monotonic()
            try:
                if args.stage in ("all", "rollup", "maintenance") and tick >= summary_at:
                    retry_stage(publish, factory, fact_days=settings.telemetry_fact_days)
                    summary_at = tick + 5
                if args.stage in ("all", "maintenance") and tick >= maintenance_at:
                    cleanup = retry_stage(maintenance, factory, raw_days=settings.telemetry_raw_days,
                        fact_days=settings.telemetry_fact_days, limit=settings.telemetry_processor_batch)
                    maintenance_at = tick + (0 if cleanup.get("more") else 60)
                    worked = worked or cleanup.get("more", False)
            except Exception as error:  # noqa: BLE001 - retry background metadata without killing healthy owners
                logging.getLogger("bmt.product").error("telemetry_metadata_failed error=%s", type(error).__name__)
                summary_at, maintenance_at = tick + 5, tick + 5
            if args.once:
                break
            # Busy stages never have a fixed sleep; rotate fairly between roles.
            if worked:
                idle_wait = .05
            elif turn % len(roles) == 0:
                stop.wait(idle_wait)
                idle_wait = min(2.0, idle_wait * 2)
    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
