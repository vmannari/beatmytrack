"""Delete expired ephemeral authentication/rate-limit records; retain race/content history."""

import argparse
import json

from sqlalchemy import delete

from .config import Settings
from .db import make_engine, make_session_factory
from .identity_models import LoginChallenge, RateBucket, SessionFamily, now


def cleanup(factory) -> dict:
    current = now()
    with factory() as session:
        result = {}
        for name, model in (
            ("rate_buckets", RateBucket),
            ("login_challenges", LoginChallenge),
            ("session_families", SessionFamily),
        ):
            result[name] = session.execute(delete(model).where(model.expires_at < current)).rowcount
        session.commit()
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    engine = make_engine(Settings.from_env().database_url)
    print(json.dumps(cleanup(make_session_factory(engine))))
    engine.dispose()


if __name__ == "__main__":
    main()
