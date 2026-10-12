"""Pause only object GC for a consistent online DB/immutable-object backup."""
import argparse
import secrets

from sqlalchemy import select

from .config import Settings
from .db import make_engine, make_session_factory
from .track_models import OperationState, now


def begin(factory):
    with factory() as session:
        row = session.scalar(select(OperationState).where(OperationState.id=="object-maintenance").with_for_update())
        if row.updated_at > now():
            raise RuntimeError("A backup guard is already active; finish or recover it first")
        token = secrets.token_hex(24)
        # Crash leaves GC paused until explicit recovery, rather than silently
        # expiring while a large backup is still streaming. API/workers continue.
        row.updated_at,row.details = 2147483647,{"backup_token":token,"started_at":now()}
        session.commit()
        return token


def end(factory, token):
    with factory() as session:
        row = session.scalar(select(OperationState).where(OperationState.id=="object-maintenance").with_for_update())
        if not secrets.compare_digest(row.details.get("backup_token",""),token):
            raise RuntimeError("Backup recovery token does not match")
        row.updated_at,row.details = 0,{}
        session.commit()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation",choices=("begin","end"))
    parser.add_argument("--token",default="")
    args = parser.parse_args()
    settings = Settings.from_env()
    engine = make_engine(settings.database_url,settings)
    factory = make_session_factory(engine)
    try:
        if args.operation == "begin":
            print(begin(factory))
        else:
            end(factory,args.token)
    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
