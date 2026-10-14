"""Disposable process harness for real POSIX termination and lease recovery."""
import json
import sys
import threading
from pathlib import Path
from types import SimpleNamespace

from fastapi import Request
from fastapi.testclient import TestClient
from sqlalchemy import select
from test_domains import FakeVerifier, public_course, submit, ticket

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.operations import competition_health, heartbeat
from bmt_backend.security import current_player
from bmt_backend.track_models import OperationState, PersonalBest, QueueCapacity, Run, now
from bmt_backend.verifier import VerifierStopping
from bmt_backend.worker import process_one
from bmt_backend.worker_lifecycle import run_worker


def probe(folder, mode):
    folder = Path(folder)
    folder.mkdir(parents=True, exist_ok=True)

    class ProbeVerifier(FakeVerifier):
        armed = False
        def __init__(self):
            self.abort = threading.Event()
            self.closed = False

        def request_stop(self):
            self.abort.set()

        def close(self):
            self.closed = True

        def verify_run(self, *args, **kwargs):
            if self.armed:
                (folder / "entered").touch()
                while not (folder / "release").exists():
                    if self.abort.wait(0.02):
                        raise VerifierStopping("probe shutdown")
                    with app.state.session_factory() as session:
                        state = session.get(OperationState, "worker:" + app.state.worker_id)
                        if state and state.details.get("lifecycle") == "draining":
                            (folder / "draining").touch()
            return super().verify_run(*args, **kwargs)

    verifier = ProbeVerifier()
    app = create_app(Settings(environment="test", allow_sync_track_validation=True, local_drafts_only=False,
        database_url=f"sqlite:///{(folder / 'db.sqlite').as_posix()}", object_dir=str(folder / "objects"),
        worker_shutdown_grace_seconds=1, rate_limit_per_minute=10000, write_limit_per_minute=10000),
        verifier=verifier)
    upgrade(app.state.engine)
    if mode == "recover":
        with app.state.session_factory() as session:
            for row in session.scalars(select(Run).where(Run.status == "verifying")):
                row.lease_until = 0  # Explicitly simulate expiry in this disposable database.
            session.commit()
        assert process_one(app)
        assert process_one(app)  # The second originally queued race can now proceed too.
        assert not process_one(app)
    else:
        players = {}
        with app.state.session_factory() as session:
            for name in ("Creator", "Alice", "Bob", "Carol"):
                player = Player(display_name=name)
                session.add(player)
                session.flush()
                players[name] = player.id
            session.commit()
        def player(request: Request):
            with app.state.session_factory() as session:
                value = session.get(Player, request.headers["x-test-player"])
                session.expunge(value)
                return value
        app.dependency_overrides[current_player] = player
        with TestClient(app) as client:
            domain = SimpleNamespace(app=app, client=client, factory=app.state.session_factory, players=players)
            version, _ = public_course(domain)
            first = submit(domain, ticket(domain, version, "Alice"), "Alice")
            second = submit(domain, ticket(domain, version, "Bob"), "Bob")
        with app.state.session_factory() as session:
            session.get(Run, first["run_id"]).created_at = now() - 2
            session.get(Run, second["run_id"]).created_at = now() - 1
            session.commit()
        (folder / "setup.json").write_text(json.dumps({"first": first["run_id"], "second": second["run_id"]}))
        heartbeat(app, app.state.worker_id, lifecycle="stopped")  # Retire the inline creator-proof setup worker.
        verifier.armed = True
        run_worker(app, process_one)
    with app.state.session_factory() as session:
        rows = session.scalars(select(Run).order_by(Run.created_at, Run.id)).all()
        report = {"runs": {r.id: {"status": r.status, "attempts": r.attempts, "lease_token": r.lease_token} for r in rows},
            "pb_count": len(session.scalars(select(PersonalBest)).all()),
            "pending": session.get(QueueCapacity, 1).pending, "verifier_closed": verifier.closed,
            "health": competition_health(app)}
    (folder / "report.json").write_text(json.dumps(report))


if __name__ == "__main__":
    probe(*sys.argv[1:])
