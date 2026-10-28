"""Reserved discovery projection process, independent of race queue emptiness."""
import argparse
import json
import logging
import signal
import threading
import time
from dataclasses import replace

from .config import Settings
from .db import make_engine, make_session_factory
from .discovery_daily import step as daily_step
from .discovery_projection import DiscoveryMaintenance, health, repair_track, step
from .track_of_day import step as track_of_day_step


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repair-track", default="", help="Explicit single-track derived-counter repair")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    settings = Settings.from_env()
    engine = make_engine(settings.database_url, replace(settings, database_pool_size=1, database_pool_overflow=0))
    stop = threading.Event()
    for signum in (signal.SIGTERM, signal.SIGINT):
        signal.signal(signum, lambda *_: stop.set())
    factory = make_session_factory(engine)
    idle = 0
    report_at = 0.0
    daily_at = 0.0
    maintenance = DiscoveryMaintenance()
    try:
        if args.repair_track:
            import uuid
            uuid.UUID(args.repair_track)
            if not repair_track(factory, args.repair_track):
                raise RuntimeError("Discovery track is not indexed")
            return
        while not stop.is_set():
            try:
                worked = step(factory, maintenance=maintenance)
                if time.monotonic() >= daily_at:
                    daily_work = daily_step(factory)
                    daily_work = track_of_day_step(factory) or daily_work
                    daily_at = time.monotonic() + (0.01 if daily_work else 30)
                    worked = daily_work or worked
                if time.monotonic() >= report_at:
                    logging.getLogger("bmt.discovery").info("discovery_projection_health %s",json.dumps(health(factory)))
                    report_at = time.monotonic()+60
                idle = 0 if worked else idle + 1
                stop.wait(0.01 if worked or idle < 16 else 1.0)
            except Exception:
                logging.getLogger("bmt.discovery").exception("discovery_projection_failed")
                stop.wait(1)
    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
