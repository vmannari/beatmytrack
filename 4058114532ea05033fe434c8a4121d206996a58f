"""Run product projection separately from competitive verification workers."""

import argparse
import logging
import signal
import threading
import time
from dataclasses import replace

from .config import Settings
from .db import make_engine, make_session_factory
from .observability import configure_logging, failure_site
from .product_analytics import project_pending
from .telemetry_processing import actor_once, maintenance, publish, record_failure, retry_stage, shared_once
from .telemetry_queue import PreparationSchedule, fold_one


def log_failure(event, error, stage):
    fields = {"exception_type": type(error).__name__, "failure_site": failure_site(error)}
    if stage in ("actor", "shared", "rollup", "maintenance", "metadata"):
        fields["telemetry_stage"] = stage
    identity = getattr(error, "telemetry_owner", None)
    if isinstance(identity, tuple) and len(identity) == 2 and identity[0] in ("actor", "shared"):
        owners = identity[1] if isinstance(identity[1], list) else [identity[1]]
        if len(owners) <= 256 and all(type(owner) is int and 0 <= owner < 256 for owner in owners):
            fields["telemetry_owners"] = owners
    logging.getLogger("bmt.product").error(event, extra=fields)


def main():
    configure_logging()
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
        preparation = PreparationSchedule()
        while not stop.is_set():
            role = roles[turn % len(roles)]
            turn += 1
            try:
                preparation.step(factory, settings.telemetry_processor_batch)
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
                log_failure("telemetry_stage_failed", error, role)
                try:
                    record_failure(factory, error)
                except Exception as recording_error:  # noqa: BLE001 - an unavailable DB must not kill recovery
                    log_failure("telemetry_failure_record_failed", recording_error, role)
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
                log_failure("telemetry_metadata_failed", error, "metadata")
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
