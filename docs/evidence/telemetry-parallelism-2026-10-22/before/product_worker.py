"""Run product projection separately from competitive verification workers."""

import argparse
import signal
import threading
import time
from dataclasses import replace

from sqlalchemy import select

from .config import Settings
from .db import make_engine, make_session_factory
from .product_analytics import project_pending
from .telemetry_models import ProductEvent


def pending_exists(factory):
    with factory() as session:
        return session.scalar(select(ProductEvent.id).where(ProductEvent.processed_at.is_(None))
            .order_by(ProductEvent.received_at, ProductEvent.id).limit(1)) is not None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true")
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
        idle_wait, maintenance_at = 15, 0.0
        while not stop.is_set():
            if not args.once and not pending_exists(factory) and time.monotonic() < maintenance_at:
                stop.wait(idle_wait)
                idle_wait = min(60, idle_wait * 2)
                continue
            result = project_pending(factory, limit=settings.telemetry_processor_batch,
                raw_days=settings.telemetry_raw_days, fact_days=settings.telemetry_fact_days)
            print(result, flush=True)
            if args.once:
                break
            maintenance_at = time.monotonic() + 60
            idle_wait = 15 if result["processed"] else min(60, idle_wait * 2)
            stop.wait(0.2 if result["pending"] else idle_wait)
    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
