"""Dedicated incident notification consumer; never occupies a race verifier."""

import argparse
import time

from .config import Settings
from .db import make_engine, make_session_factory
from .studio_incidents import deliver_one


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    settings = Settings.from_env()
    if not settings.studio_monitor_webhook_url:
        parser.error("Configure an explicit incident destination first")
    engine = make_engine(settings.database_url, settings)
    factory = make_session_factory(engine)
    try:
        while True:
            worked = deliver_one(factory, settings)
            if args.once:
                break
            if not worked:
                time.sleep(2)
    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
