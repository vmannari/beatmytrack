"""Published-only race admission preserves exact historical ticket outcomes."""
from dataclasses import replace

import pytest
from sqlalchemy import func, select
from test_domains import domain as domain_fixture
from test_domains import headers, race, submit, ticket, upload

from bmt_backend.track_models import (
    Board,
    IdempotencyRecord,
    QueueCapacity,
    Run,
    RunTicket,
    TrackValidation,
    TrackVersion,
    digest,
    now,
)
from bmt_backend.worker import process_one

domain = domain_fixture


def creator_ticket(domain, version):
    response = domain.client.post("/v1/run-tickets", json={"version_id": version["version_id"],
        "vehicle_id": "compact", "purpose": "creator_test"}, headers=headers(domain))
    assert response.status_code == 201, response.text
    return response.json()


def count(session, table):
    return session.scalar(select(func.count()).select_from(table))


def close_legacy(domain):
    domain.app.state.settings = replace(domain.app.state.settings, local_drafts_only=True)


def test_cached_private_ids_cannot_issue_creator_or_ordinary_tickets(domain):
    version = upload(domain)
    with domain.factory() as session:
        before = (count(session, Board), count(session, RunTicket), count(session, IdempotencyRecord))
    close_legacy(domain)
    for purpose in ("race", "creator_test"):
        response = domain.client.post("/v1/run-tickets", json={"version_id": version["version_id"],
            "vehicle_id": "compact", "purpose": purpose}, headers=headers(domain))
        assert response.status_code == 410 and "LOCAL_DRAFTS_ONLY" in response.text
    with domain.factory() as session:
        assert before == (count(session, Board), count(session, RunTicket), count(session, IdempotencyRecord))
        assert session.get(TrackVersion, version["version_id"]).state == "draft"


@pytest.mark.parametrize("purpose,published", [("creator_test", False), ("race", False), ("creator_test", True)])
def test_already_issued_private_or_creator_ticket_cannot_upload_new_evidence(domain, monkeypatch, purpose, published):
    version = upload(domain)
    issued = creator_ticket(domain, version) if purpose == "creator_test" else ticket(domain, version)
    if published:
        with domain.factory() as session:
            session.get(TrackVersion, version["version_id"]).state = "published"
            session.commit()
    close_legacy(domain)
    def forbidden(*args):
        raise AssertionError("New private creator evidence must not reach blob storage")
    monkeypatch.setattr(domain.app.state.blobs, "put_json", forbidden)
    response = domain.client.post("/v1/runs", json={"ticket_id": issued["ticket_id"],
        "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]]*20}}, headers=headers(domain))
    assert response.status_code == 410 and "LOCAL_DRAFTS_ONLY" in response.text
    with domain.factory() as session:
        assert count(session, Run) == 0 and session.get(QueueCapacity, 1).pending == 0
        assert count(session, RunTicket) == 1


def test_completed_historical_creator_submission_returns_exact_outcome_before_new_gate(domain, monkeypatch):
    version = upload(domain)
    issued = creator_ticket(domain, version)
    result = submit(domain, issued)
    assert process_one(domain.app)
    expected = domain.client.get("/v1/runs/"+result["run_id"], headers=headers(domain)).json()
    assert expected["status"] == "verified"
    with domain.factory() as session:
        session.get(RunTicket, issued["ticket_id"]).expires_at = now()-1
        session.commit()
    close_legacy(domain)
    def forbidden(*args):
        raise AssertionError("Recovery must not read/write blobs or verify again")
    monkeypatch.setattr(domain.app.state.blobs, "put_json", forbidden)
    monkeypatch.setattr(domain.app.state.verifier, "verify_run", forbidden)
    body = {"ticket_id": issued["ticket_id"], "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]]*20}}
    recovered = domain.client.post("/v1/runs", json=body, headers=headers(domain))
    assert recovered.status_code == 202
    assert recovered.json()["run_id"] == expected["run_id"] and recovered.json()["time_ticks"] == expected["time_ticks"]
    assert recovered.json()["status"] == "verified" and recovered.json()["lap_ticks"] == expected["lap_ticks"]
    modified = {**body, "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]]*21}}
    assert domain.client.post("/v1/runs", json=modified, headers=headers(domain)).status_code == 409
    assert domain.client.get("/v1/runs/"+expected["run_id"], headers=headers(domain)).json()["status"] == "verified"
    assert domain.client.post("/v1/runs/"+expected["run_id"]+"/retry", headers=headers(domain)).json()["status"] == "verified"
    with domain.factory() as session:
        assert count(session, Run) == 1 and session.get(QueueCapacity, 1).pending == 0


def test_failed_private_creator_run_cannot_reenter_verification_queue(domain):
    version = upload(domain)
    issued = creator_ticket(domain, version)
    replay = {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]]*20}
    with domain.factory() as session:
        saved = Run(ticket_id=issued["ticket_id"], player_id=domain.players["Creator"], board_id=issued["board_id"],
            replay_hash=digest(replay), status="failed", failure_code="verifier_unavailable", finished_at=now())
        session.add(saved)
        session.commit()
        identity = saved.id
    close_legacy(domain)
    response = domain.client.post("/v1/runs/"+identity+"/retry", headers=headers(domain))
    assert response.status_code == 410
    with domain.factory() as session:
        assert session.get(Run, identity).status == "failed" and session.get(QueueCapacity, 1).pending == 0


def test_published_ordinary_ticket_submission_and_repeat_keep_five_lap_acceptance(domain):
    version = upload(domain)
    with domain.factory() as session:
        session.get(TrackVersion, version["version_id"]).state = "published"
        session.commit()
    close_legacy(domain)
    result = race(domain, version, "Alice", frames=60)
    assert result["status"] == "verified" and result["lap_ticks"] == [60]*5 and result["time_ticks"] == 300
    with domain.factory() as session:
        run = session.get(Run, result["run_id"])
        board = session.get(Board, run.board_id)
        assert board.manifest["laps"] == 5 and "purpose" not in board.manifest
        session.get(RunTicket, run.ticket_id).expires_at = now()-1
        ticket_id = run.ticket_id
        session.commit()
    repeated = domain.client.post("/v1/runs", json={"ticket_id": ticket_id,
        "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]]*60}}, headers=headers(domain, "Alice"))
    assert repeated.status_code == 202 and repeated.json()["run_id"] == result["run_id"]
    assert repeated.json()["time_ticks"] == 300 and repeated.json()["lap_ticks"] == [60]*5
    with domain.factory() as session:
        assert count(session, Run) == 1 and session.get(QueueCapacity, 1).pending == 0


def test_failed_legacy_geometry_job_cannot_reoccupy_retired_queue_capacity(domain):
    version = upload(domain)
    with domain.factory() as session:
        job = TrackValidation(version_id=version["version_id"], status="failed", failure_code="validator_unavailable",
            detail="Historical validator failure", attempts=3)
        session.add(job)
        session.commit()
        idempotency_count = count(session, IdempotencyRecord)
    close_legacy(domain)
    response = domain.client.post(f"/v1/me/track-versions/{version['version_id']}/retry-validation", headers=headers(domain))
    assert response.status_code == 410 and "LOCAL_DRAFTS_ONLY" in response.text
    with domain.factory() as session:
        assert session.get(TrackValidation, version["version_id"]).status == "failed"
        assert session.get(QueueCapacity, 1).pending == 0
        assert count(session, IdempotencyRecord) == idempotency_count
