"""Authoring identity and durable lifecycle failures, on disposable databases."""

from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace

import pytest
from sqlalchemy import func, select
from test_domains import domain as domain_fixture
from test_domains import headers, submit

from bmt_backend.track_models import Run, Track, TrackValidation, TrackVersion
from bmt_backend.verifier import VerificationError
from bmt_backend.worker import process_one

domain = domain_fixture


def save(domain, source="track_lifecycle", **changes):
    document = {"schema": "creator-track-v5", "id": source, "name": "Lifecycle loop",
                "shape": "oval", "points": [[0, 0], [20, 0], [20, 20], [0, 20]]}
    body = {"name": document["name"], "document": document, "authoring_id": source, "defer_validation": True}
    body.update(changes)
    import time
    auth = headers(domain)
    for retry in range(10):
        response = domain.client.post("/v1/tracks", json=body, headers=auth)
        if response.status_code != 503 or response.json().get("detail") != "REQUEST_VALIDATION_BUSY": break
        time.sleep(.1)
    assert response.status_code == 201, response.text
    return response.json(), body


def status(domain, version):
    response = domain.client.get(f"/v1/me/track-versions/{version['version_id']}", headers=headers(domain))
    assert response.status_code == 200, response.text
    return response.json()


def test_new_keys_and_edits_keep_one_logical_track(domain):
    first, body = save(domain)
    repeated, _ = save(domain)
    assert first["track_id"] == repeated["track_id"] and first["version_id"] == repeated["version_id"]
    changed_document = {**body["document"], "shape": "changed"}
    changed, _ = save(domain, document=changed_document)
    assert changed["track_id"] == first["track_id"] and changed["version_id"] != first["version_id"]
    assert changed["version"] == 2
    again, _ = save(domain, document=changed_document)
    assert again["version_id"] == changed["version_id"]
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(Track)) == 1
        assert session.scalar(select(func.count()).select_from(TrackVersion)) == 2
    # Another owner gets their own mapping, not ownership of the creator's track.
    response = domain.client.post("/v1/tracks", json=body, headers=headers(domain, "Alice"))
    assert response.json()["track_id"] != first["track_id"]


def test_private_acceptance_survives_validator_outage_and_retry(domain, monkeypatch):
    original = domain.app.state.verifier.validate_track
    monkeypatch.setattr(domain.app.state.verifier, "validate_track", lambda doc: (_ for _ in ()).throw(RuntimeError()))
    version, _ = save(domain)
    assert status(domain, version)["state"] == "validating"
    assert domain.client.get(f"/v1/track-versions/{version['version_id']}").status_code == 404
    domain.app.state.settings = replace(domain.app.state.settings, max_job_attempts=1)
    assert process_one(domain.app)
    failed = status(domain, version)
    assert failed["validation"]["status"] == "failed" and failed["validation"]["retryable"]
    assert domain.client.get(f"/v1/me/track-versions/{version['version_id']}/document", headers=headers(domain)).json()["id"] == "track_lifecycle"
    retry = domain.client.post(f"/v1/me/track-versions/{version['version_id']}/retry-validation", headers=headers(domain))
    assert retry.status_code == 200
    monkeypatch.setattr(domain.app.state.verifier, "validate_track", original)
    assert process_one(domain.app)
    assert status(domain, version)["state"] == "draft"


def test_exact_creator_proof_unlocks_publication_and_owner_status(domain):
    version, _ = save(domain)
    pending = domain.client.post("/v1/run-tickets", json={"version_id": version["version_id"], "vehicle_id": "compact", "purpose": "creator_test"}, headers=headers(domain))
    assert pending.status_code == 409
    assert process_one(domain.app)
    issued = domain.client.post("/v1/run-tickets", json={"version_id": version["version_id"], "vehicle_id": "compact", "purpose": "creator_test"}, headers=headers(domain)).json()
    run = submit(domain, issued)
    new_ticket = domain.client.post("/v1/run-tickets", json={"version_id": version["version_id"], "vehicle_id":"compact", "purpose":"creator_test"}, headers=headers(domain)).json()
    assert submit(domain, new_ticket)["run_id"] == run["run_id"]
    assert process_one(domain.app)
    assert status(domain, version)["proof"]["status"] == "verified"
    response = domain.client.post(f"/v1/track-versions/{version['version_id']}/publish", headers=headers(domain))
    assert response.status_code == 200
    assert response.json()["authoring_id"] == "track_lifecycle"
    assert domain.client.get(f"/v1/me/track-versions/{version['version_id']}", headers=headers(domain, "Alice")).status_code == 404
    assert domain.client.get(f"/v1/track-versions/{version['version_id']}/leaderboard").json()["population"] == 0
    with domain.factory() as session:
        assert session.get(Run, run["run_id"]).status == "verified"


def test_revision_conflict_keeps_original_master(domain):
    version, body = save(domain)
    response = domain.client.post("/v1/tracks", json={**body, "document": {**body["document"], "shape": "new"},
        "expected_head_revision_id": "00000000-0000-0000-0000-000000000000"}, headers=headers(domain))
    assert response.status_code == 409
    assert status(domain, version)["version"] == 1
    mismatch = domain.client.post("/v1/tracks", json={**body, "authoring_id":"another_identity"}, headers=headers(domain))
    assert mismatch.status_code == 422
    conflict = domain.client.post("/v1/tracks", json={**body, "document":{**body["document"], "shape":"offline edit"}, "expected_head_revision_id":"new"}, headers=headers(domain))
    assert conflict.status_code == 409


def test_owner_heads_exclude_older_revisions_and_other_accounts(domain):
    first, body = save(domain)
    second, _ = save(domain, document={**body["document"], "shape": "changed"})
    heads = domain.client.get("/v1/me/tracks?heads=true", headers=headers(domain)).json()["items"]
    assert [item["version_id"] for item in heads] == [second["version_id"]]
    assert first["version_id"] != second["version_id"]
    assert domain.client.get("/v1/me/tracks?heads=true", headers=headers(domain, "Alice")).json()["items"] == []


def test_invalid_document_stays_private_and_cannot_publish(domain, monkeypatch):
    version, _ = save(domain, document={"schema": "creator-track-v5", "id": "track_lifecycle", "points": "invalid"})
    def invalid(document):
        raise VerificationError("Disconnected roads")
    monkeypatch.setattr(domain.app.state.verifier, "validate_track", invalid)
    assert process_one(domain.app)
    assert status(domain, version)["state"] == "invalid"
    assert domain.client.post(f"/v1/track-versions/{version['version_id']}/publish", headers=headers(domain)).status_code == 409
    assert domain.client.get("/v1/tracks").json()["items"] == []


def test_infrastructure_run_retry_retains_original_replay(domain, monkeypatch):
    version, _ = save(domain)
    assert process_one(domain.app)
    ticket = domain.client.post("/v1/run-tickets", json={"version_id": version["version_id"], "vehicle_id": "compact", "purpose": "creator_test"}, headers=headers(domain)).json()
    run = submit(domain, ticket)
    domain.app.state.settings = replace(domain.app.state.settings, max_job_attempts=1)
    original = domain.app.state.verifier.verify_run
    def unavailable(*args, **kwargs):
        raise RuntimeError("Verifier temporarily unavailable")
    monkeypatch.setattr(domain.app.state.verifier, "verify_run", unavailable)
    assert process_one(domain.app)
    failed = domain.client.get(f"/v1/runs/{run['run_id']}", headers=headers(domain)).json()
    assert failed["status"] == "failed" and failed["retryable"]
    with domain.factory() as session:
        saved_hash = session.get(Run, run["run_id"]).replay_hash
    assert domain.app.state.blobs.get_json(saved_hash)["frames"]
    monkeypatch.setattr(domain.app.state.verifier, "verify_run", original)
    response = domain.client.post(f"/v1/runs/{run['run_id']}/retry", headers=headers(domain))
    assert response.status_code == 200 and response.json()["status"] == "queued"
    assert process_one(domain.app)
    assert status(domain, version)["state"] == "tested"


def test_legacy_owned_document_identity_recovers_existing_track(domain):
    from test_domains import upload
    old = upload(domain, document={"id": "track_legacy", "shape": "oval"})
    recovered, _ = save(domain, source="track_legacy")
    assert recovered["track_id"] == old["track_id"]
    assert recovered["version"] == 2


def test_validation_lease_fences_old_worker(domain, monkeypatch):
    version, _ = save(domain)
    original = domain.app.state.verifier.validate_track
    def steal(document):
        with domain.factory() as session:
            job = session.get(TrackValidation, version["version_id"])
            job.lease_token = "replacement-worker"
            session.commit()
        return original(document)
    monkeypatch.setattr(domain.app.state.verifier, "validate_track", steal)
    assert process_one(domain.app)
    assert status(domain, version)["state"] == "validating"


def test_concurrent_new_keys_have_one_authoring_identity(domain):
    if not domain.postgres:
        pytest.skip("Cross-connection locking acceptance requires PostgreSQL")
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(lambda _: save(domain)[0], range(4)))
    assert len({item["track_id"] for item in results}) == 1
    assert len({item["version_id"] for item in results}) == 1
