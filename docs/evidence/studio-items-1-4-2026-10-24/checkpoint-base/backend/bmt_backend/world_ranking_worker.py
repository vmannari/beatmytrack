"""Low-priority SQL-only ranking worker; one connection, no canonical engine."""
import argparse
import logging
import signal
import threading
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
    try:
        while not stopped.is_set():
            try:
                worked = step(factory, blobs, settings)
            except Exception:
                log.exception("world_ranking_step_failed")
                worked = False
                if args.once:
                    raise
            if args.once:
                break
            stopped.wait(settings.world_ranking_pause_ms/1000 if worked else 10.0)
    finally:
        if hasattr(blobs, "close"):
            blobs.close()
        engine.dispose()


if __name__ == "__main__":
    main()
