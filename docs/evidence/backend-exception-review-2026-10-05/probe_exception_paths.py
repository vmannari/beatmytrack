"""Isolated review probes assert observed behavior, including recovery gaps.

These passing observations do not mean the discovered gaps are repaired.
"""
import json
import logging
import sys
from dataclasses import replace
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend" / "tests"))

from bmt_backend.app import create_app
from bmt_backend.observability import JsonFormatter
from bmt_backend.resume_models import ResumeReceipt
from bmt_backend.track_models import IdempotencyRecord, PersonalBest, Run, now
from bmt_backend.worker import process_one
from conftest import auth_app as auth_app_fixture
from conftest import auth_client as auth_client_fixture
from fastapi.testclient import TestClient
from sqlalchemy import delete, event, select
from sqlalchemy.exc import OperationalError
from test_domains import FakeVerifier, headers, public_course, submit, ticket
from test_domains import domain as domain_fixture

domain = domain_fixture
auth_app = auth_app_fixture
auth_client = auth_client_fixture


def test_lost_submission_response_same_key_recovers_across_api_restart(domain):
    course = public_course(domain)[0]
    issued = ticket(domain, course, "Alice")
    body = {"ticket_id": issued["ticket_id"],
            "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]] * 20}}
    h = headers(domain, "Alice", "lost-response-key")
    accepted = domain.client.post("/v1/runs", json=body, headers=h)
    assert accepted.status_code == 202
    # Deliberately ignore the response, then recreate an API against the same DB/store.
    fresh = create_app(domain.app.state.settings, engine=domain.app.state.engine,
                       verifier=FakeVerifier())
    fresh.dependency_overrides = domain.app.dependency_overrides.copy()
    with TestClient(fresh) as client:
        retried = client.post("/v1/runs", json=body, headers=h)
    assert retried.status_code == 202
    assert retried.json()["run_id"] == accepted.json()["run_id"]
    with domain.factory() as session:
        assert len(list(session.scalars(select(Run).where(Run.ticket_id == issued["ticket_id"])))) == 1


def test_lost_resume_response_is_idempotent_but_credit_already_spent(domain):
    course = public_course(domain)[0]
    issued = ticket(domain, course, "Alice")
    h = headers(domain, "Alice", "begin-resume-key")
    race = domain.client.post("/v1/resume-races", json={"ticket_id": issued["ticket_id"]}, headers=h).json()
    body = {"ordinal": 1, "input_offset": 10, "from_tick": 10, "to_tick": 0}
    url = f"/v1/resume-races/{race['race_id']}/resumes"
    h = headers(domain, "Alice", "lost-resume-key")
    first = domain.client.post(url, json=body, headers=h)
    assert first.status_code == 200
    assert first.json()["wallet"]["free"] == 0
    second = domain.client.post(url, json=body, headers=h)
    assert second.json() == first.json()
    with domain.factory() as session:
        assert len(list(session.scalars(select(ResumeReceipt).where(ResumeReceipt.race_id == race["race_id"])))) == 1
    # A client must resolve the pending operation; omitting its authorized event fails closed.
    rejected = domain.client.post("/v1/runs", headers=headers(domain, "Alice"),
        json={"ticket_id": issued["ticket_id"],
              "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]] * 20}})
    assert rejected.status_code == 422


def test_incompatible_worker_claims_and_exhausts_valid_job(domain):
    course = public_course(domain)[0]
    issued = ticket(domain, course, "Alice")
    accepted = submit(domain, issued, "Alice")

    class OldWorker(FakeVerifier):
        calls = 0

        def manifest(self):
            return {**super().manifest(), "physics_version": "old-worker"}

        def verify_run(self, *args, **kwargs):
            self.calls += 1
            return super().verify_run(*args, **kwargs)

    old = OldWorker()
    domain.app.state.verifier = old
    for _ in range(domain.app.state.settings.max_job_attempts):
        with domain.factory() as session:
            session.get(Run, accepted["run_id"]).lease_until = 0
            session.commit()
        assert process_one(domain.app)
    assert old.calls == 3
    result = domain.client.get("/v1/runs/" + accepted["run_id"], headers=headers(domain, "Alice")).json()
    assert result["status"] == "failed"
    assert result["failure_code"] == "verifier_unavailable"
    assert result["retryable"]
    with domain.factory() as session:
        assert session.scalar(select(PersonalBest).where(PersonalBest.run_id == accepted["run_id"])) is None


def test_invalid_server_digest_is_classified_as_invalid_client_replay(domain):
    issued = ticket(domain, public_course(domain)[0], "Alice")
    accepted = submit(domain, issued, "Alice")
    with domain.factory() as session:
        session.get(Run, accepted["run_id"]).replay_hash = "z" * 64
        session.commit()
    assert process_one(domain.app)
    result = domain.client.get("/v1/runs/" + accepted["run_id"], headers=headers(domain, "Alice")).json()
    assert result["status"] == "rejected"
    assert result["failure_code"] == "invalid_replay"
    assert not result["retryable"]


def test_missing_pending_run_after_restore_can_be_resubmitted(domain):
    issued = ticket(domain, public_course(domain)[0], "Alice")
    accepted = submit(domain, issued, "Alice", key="restore-pending-key")
    # Model a consistent restore point after ticket issue but before submission.
    with domain.factory() as session:
        session.execute(delete(IdempotencyRecord).where(IdempotencyRecord.player_id == domain.players["Alice"],
                                                       IdempotencyRecord.scope == "submit_run"))
        session.delete(session.get(Run, accepted["run_id"]))
        session.commit()
    status = domain.client.get("/v1/runs/" + accepted["run_id"], headers=headers(domain, "Alice"))
    assert status.status_code == 404
    recovered = submit(domain, issued, "Alice", key="restore-pending-key")
    assert recovered["run_id"] != accepted["run_id"]


def test_database_outage_is_503_and_no_secret_parameters(auth_app, auth_client):
    def broken(*args):
        raise OperationalError("synthetic-statement", {}, Exception("synthetic unavailable"), hide_parameters=True)

    event.listen(auth_app.state.engine, "before_cursor_execute", broken)
    try:
        result = auth_client.get("/v1/bootstrap")
        assert result.status_code == 503
        assert result.json()["detail"] == "DATABASE_UNAVAILABLE"
        assert set(result.json()) == {"detail", "request_id"}
    finally:
        event.remove(auth_app.state.engine, "before_cursor_execute", broken)
    assert auth_client.get("/v1/bootstrap").status_code == 200


def test_old_and_future_phone_clocks_block_new_mutations(domain):
    course = public_course(domain)[0]
    for timestamp, expected in ((now() + 2 * 86400, 422), (now() - 91 * 86400, 410)):
        key = f"v2.{timestamp:010d}." + "a" * 48
        response = domain.client.post("/v1/run-tickets", json={"version_id": course["version_id"],
            "vehicle_id": "compact"}, headers=headers(domain, "Alice", key))
        assert response.status_code == expected


def test_fake_authorization_header_increases_public_read_allowance(auth_app):
    settings = replace(auth_app.state.settings, rate_limit_per_minute=2, edge_limit_per_minute=100)
    app = create_app(settings, engine=auth_app.state.engine, identity_verifier=auth_app.state.identity_verifier)
    with TestClient(app) as client:
        assert [client.get("/v1/bootstrap").status_code for _ in range(3)] == [200, 200, 429]
        assert [client.get("/v1/bootstrap", headers={"Authorization": "unvalidated-garbage"}).status_code
                for _ in range(3)] == [200, 200, 200]
        assert client.get("/v1/me", headers={"Authorization": "unvalidated-garbage"}).status_code == 401


def test_worker_service_duration_is_dropped_from_structured_logs():
    record = logging.LogRecord("bmt.worker", logging.INFO, "worker.py", 195, "verification_complete", (), None)
    record.verification_seconds = 1.234
    record.run_id = "synthetic-run"
    encoded = json.loads(JsonFormatter().format(record))
    assert encoded["run_id"] == "synthetic-run"
    assert "verification_seconds" not in encoded
