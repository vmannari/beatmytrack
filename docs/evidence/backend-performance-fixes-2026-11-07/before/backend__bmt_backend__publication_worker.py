"""Keep explicit publications independent of competition and background work."""

import argparse
from dataclasses import replace

from .operations import heartbeat
from .publications import process_one
from .verifier import VerifierStopping
from .worker_lifecycle import run_worker, stopping


def process_job(app):
    if stopping(app):
        return False
    worker_id = app.state.worker_id
    # Warm the persistent engine before the first publication. Never advertise
    # a competition build: this process does not claim races or maintenance.
    try:
        app.state.verifier.manifest()
    except VerifierStopping:
        return False
    except RuntimeError:
        heartbeat(app, worker_id, role="publication", phase="unavailable", coalesce=True)
        return False
    heartbeat(app, worker_id, role="publication", phase="idle", coalesce=True)
    return process_one(app)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    from .config import Settings
    from .worker_app import create_worker_app

    # One additional bounded connection, within the existing service instance.
    settings = replace(Settings.from_env(), database_pool_size=1, database_pool_overflow=0)
    app = create_worker_app(settings)
    run_worker(app, process_job, once=args.once, idle_seconds=0.25)


if __name__ == "__main__":
    main()
