"""Low-priority SQL-only ranking worker; one connection, no canonical engine."""
import argparse
import logging
import signal
import threading
import time
from dataclasses import replace

from .config import Settings
from .db import make_engine, make_session_factory
from .storage import make_blob_store
from .world_ranking_build import step

log = logging.getLogger("bmt.world_ranking")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    settings = replace(Settings.from_env(), database_pool_size=1, database_pool_overflow=0)
    engine = make_engine(settings.database_url, settings)
    factory = make_session_factory(engine)
    blobs = make_blob_store(settings, factory)
    stopped = threading.Event()
    for signum in (signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, lambda *_: stopped.set())
    logging.basicConfig(level=logging.INFO)
    next_heartbeat = 0.0
    try:
        while not stopped.is_set():
            error_kind = ''
            try:
                worked = step(factory, blobs, settings)
            except Exception as error:
                error_kind = type(error).__name__
                log.exception("world_ranking_step_failed")
                worked = False
                if args.once:
                    raise
            if time.monotonic() >= next_heartbeat:
                from .studio_ranking import record_worker_heartbeat
                try:
                    record_worker_heartbeat(factory, worked=worked, error_kind=error_kind)
                except Exception:
                    log.exception('world_ranking_heartbeat_failed')
                next_heartbeat = time.monotonic() + 15.0
            if args.once:
                break
            stopped.wait(settings.world_ranking_pause_ms/1000 if worked else 10.0)
    finally:
        if hasattr(blobs, "close"):
            blobs.close()
        engine.dispose()


if __name__ == "__main__":
    main()
