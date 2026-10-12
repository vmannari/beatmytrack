"""Regressions for the October full review; all writes use disposable databases."""
import os
from dataclasses import replace

import pytest
from sqlalchemy import update
from test_domains import domain as domain_fixture
from test_domains import headers, public_course, submit, ticket, upload

from bmt_backend.contracts import build_contract, current_manifest
from bmt_backend.identity_models import Player
from bmt_backend.maintenance import backfill_discovery, retain
from bmt_backend.operations import competition_health, heartbeat
from bmt_backend.track_models import PersonalBest, Run, Track, TrackValidation, TrackVersion, now
from bmt_backend.worker import process_one

domain = domain_fixture


def test_broad_json_tree_is_rejected_without_accepting_nonfinite_values():
    from bmt_backend.middleware import parse_body
    # Fits the body byte limit, but has excessive container overhead.
    with pytest.raises(ValueError, match="node limit"):
        parse_body(b"[" + b"[]," * 1200000 + b"[]]")


@pytest.mark.parametrize("physics", ["arcade-planar-0.39", "arcade-planar-0.48"])
@pytest.mark.parametrize("purpose", ["race", "creator_test"])
@pytest.mark.parametrize("rules", ["standing-5-road-gates-v12", "standing-5-road-gates-v13", "standing-5-road-gates-v14", "standing-5-road-gates-v15", "standing-5-road-gates-v16", "standing-5-road-gates-v18"])
def test_full_manifest_upgrade_verifies(domain, physics, purpose, rules):
    base = domain.app.state.verifier.manifest()
    domain.app.state.verifier.manifest = lambda: {**base, "physics_version": "arcade-planar-0.52", "rules_key": "standing-5-road-gates-v19"}
    version = upload(domain)
    with domain.factory() as session:
        row = session.get(TrackVersion, version["version_id"])
        row.manifest = {**row.manifest, "physics_version": physics, "rules_key": rules}
        original = dict(row.manifest)
        session.commit()
    metadata = domain.client.get("/v1/me/tracks", headers=headers(domain))
    assert metadata.status_code == 200
    visible = next(item for item in metadata.json()["items"] if item["version_id"] == version["version_id"])
    assert visible["manifest"]["rules_key"] == "standing-5-road-gates-v19"
    response = domain.client.post("/v1/run-tickets", json={"version_id": version["version_id"], "vehicle_id": "compact", "purpose": purpose}, headers=headers(domain))
    assert response.status_code == 201, response.text
    run = submit(domain, response.json())
    assert process_one(domain.app)
    with domain.factory() as session:
        assert session.get(Run, run["run_id"]).status == "verified"
        assert session.get(TrackVersion, version["version_id"]).manifest == original
    assert current_manifest(original)["physics_version"] == "arcade-planar-0.52"
    assert current_manifest(original)["rules_key"] == "standing-5-road-gates-v19"


def test_global_admission_and_fair_claims(domain):
    version, _ = public_course(domain)
    domain.app.state.settings = replace(domain.app.state.settings, max_queued_runs=3)
    first = submit(domain, ticket(domain, version, "Alice"), "Alice")
    second = submit(domain, ticket(domain, version, "Alice"), "Alice")
    third = submit(domain, ticket(domain, version, "Bob"), "Bob")
    full = domain.client.post("/v1/runs", json={"ticket_id": ticket(domain, version, "Carol")["ticket_id"], "replay": {"schema": "bmt-replay-v1", "frames": [[0,255,0]]}}, headers=headers(domain, "Carol"))
    assert full.status_code == 429 and full.headers["retry-after"]
    assert process_one(domain.app)
    assert process_one(domain.app)
    with domain.factory() as session:
        assert session.get(Run, third["run_id"]).status == "verified"
        assert sum(session.get(Run, job["run_id"]).status == "verified" for job in (first, second)) == 1
    health = competition_health(domain.app)
    assert health["active_workers"] == 1 and health["queue_depth"] == 1


def test_health_requests_never_parse_large_post(domain, monkeypatch):
    monkeypatch.setattr("bmt_backend.middleware.parse_body", lambda body: pytest.fail("health payload parsed"))
    response = domain.client.post("/healthz", content=b"x" * 3024048, headers={"content-type": "application/json"})
    assert response.status_code == 405
    assert domain.client.get("/healthz").status_code == 200


def test_competition_health_does_not_trust_an_incompatible_fresh_worker(domain):
    manifest = domain.app.state.verifier.manifest()
    build = build_contract(manifest)
    heartbeat(domain.app, "older-worker", build={**build, "rules_key":"older-rules"})
    assert competition_health(domain.app)["status"] == "worker_build_mismatch"
    heartbeat(domain.app, "compatible-worker", build=build)
    assert competition_health(domain.app)["status"] == "ready"


def test_track_validations_share_admission_with_races(domain):
    version, _ = public_course(domain)
    domain.app.state.settings = replace(domain.app.state.settings, max_queued_runs=2)
    submit(domain, ticket(domain, version, "Alice"), "Alice")
    body = {"name":"Private", "document":{"schema":"creator-track-v5", "id":"private", "points":[]},
            "authoring_id":"private", "defer_validation":True}
    first = domain.client.post("/v1/tracks", json=body, headers=headers(domain))
    assert first.status_code == 201, first.text
    # A retry of the same immutable snapshot consumes no second queue slot.
    duplicate = domain.client.post("/v1/tracks", json=body, headers=headers(domain))
    assert duplicate.status_code == 201 and duplicate.json()["version_id"] == first.json()["version_id"]
    changed = {**body, "document":{**body["document"], "points":[[1,1]]}}
    full = domain.client.post("/v1/tracks", json=changed, headers=headers(domain))
    assert full.status_code == 429 and full.headers["retry-after"]
    race = domain.client.post("/v1/runs", json={"ticket_id":ticket(domain, version, "Bob")["ticket_id"],
        "replay":{"schema":"bmt-replay-v1", "frames":[[0,255,0]]}}, headers=headers(domain, "Bob"))
    assert race.status_code == 429
    health = competition_health(domain.app)
    assert health["queue_depth"] == 2 and health["pending_track_validations"] == 1


def test_private_validation_claims_are_fair_between_owners(domain):
    from bmt_backend.track_validation import process_one as validate_one
    versions = []
    for owner, source in [("Alice","first"), ("Alice","second"), ("Bob","third")]:
        body = {"name":source, "document":{"schema":"creator-track-v5", "id":source, "points":[]},
                "authoring_id":source, "defer_validation":True}
        response = domain.client.post("/v1/tracks", json=body, headers=headers(domain, owner))
        assert response.status_code == 201, response.text
        versions.append(response.json()["version_id"])
    assert validate_one(domain.app) and validate_one(domain.app)
    with domain.factory() as session:
        assert session.get(TrackValidation, versions[2]).status == "validated"
        assert sum(session.get(TrackValidation, version).status == "validated" for version in versions[:2]) == 1


def test_discovery_backfill_handles_json_null_and_is_resumable(domain):
    version = upload(domain, document={"shape":"oval", "points":[[0,0],[20,0],[20,20],[0,20]]})
    with domain.factory() as session:
        session.get(TrackVersion, version["version_id"]).discovery = None
        session.commit()
    assert backfill_discovery(domain.factory, domain.app.state.blobs, limit=1)["backfilled"] == 1
    assert backfill_discovery(domain.factory, domain.app.state.blobs, limit=1)["backfilled"] == 0
    with domain.factory() as session:
        assert session.get(TrackVersion, version["version_id"]).discovery["points"]


def test_catalog_cursor_crosses_legacy_cap_without_blob_reads(domain, monkeypatch):
    with domain.factory() as session:
        session.add_all([Track(id=f"track-{n}", owner_id=domain.players["Creator"]) for n in range(10102)])
        session.flush()
        session.add_all([TrackVersion(id=f"{n:036d}", track_id=f"track-{n}", number=1, name=f"Course {n}", content_hash="a"*64, manifest={}, discovery={"theme":"pine","points":[]}, state="published", published_at=now(), created_at=now()) for n in range(10102)])
        session.commit()
    monkeypatch.setattr(domain.app.state.blobs, "get_json", lambda key: pytest.fail("discovery read immutable blob"))
    cursor, seen = "", set()
    for _ in range(102):
        response = domain.client.get("/v1/tracks", params={"limit":100, "cursor":cursor})
        assert response.status_code == 200, response.text
        page = response.json()
        for item in page["items"]:
            assert item["version_id"] not in seen and "manifest" not in item
            seen.add(item["version_id"])
        cursor = page["next_cursor"]
        if cursor is None: break
    assert len(seen) == 10102 and cursor is None
    assert domain.client.get("/v1/tracks", params={"cursor":"broken"}).status_code == 422


def test_retention_preserves_pb_proof_and_all_course_content(domain):
    version, _ = public_course(domain)
    extra = submit(domain, ticket(domain, version), frames=100)
    assert process_one(domain.app)
    old = now() - 100 * 86400
    with domain.factory() as session:
        session.execute(update(Run).values(finished_at=old))
        session.commit()
    blobs = domain.app.state.blobs
    orphan = blobs.put_json({"uncommitted": True})
    os.utime(blobs._path(orphan), (old, old))
    unmanaged = blobs.root / "aa" / ("z"*64 + ".json")
    unmanaged.parent.mkdir(exist_ok=True)
    unmanaged.write_text("{}")
    os.utime(unmanaged, (old, old))
    plan = retain(domain.factory, blobs)
    assert plan["runs"] == 1 and plan["orphaned_objects"] >= 1
    with pytest.raises(ValueError): retain(domain.factory, blobs, apply=True)
    result = retain(domain.factory, blobs, apply=True, offline=True)
    assert result["applied"] and not blobs._path(orphan).exists()
    assert unmanaged.exists() # GC is restricted to valid content-addressed keys.
    with domain.factory() as session:
        assert session.get(Run, extra["run_id"]) is None
        course = session.get(TrackVersion, version["version_id"])
        assert session.get(Run, course.creator_test_run_id) is not None
        assert blobs.get_json(course.content_hash)


def test_poll_budget_does_not_exhaust_sign_in_budget(domain):
    from fastapi.testclient import TestClient

    from bmt_backend.app import create_app
    app = create_app(replace(domain.app.state.settings, auth_limit_per_minute=30, google_client_ids=("test",)), engine=domain.app.state.engine)
    with TestClient(app) as client:
        for _ in range(40):
            response = client.post("/v1/auth/google/browser/poll", json={"token":"a"*48})
            assert response.status_code != 429
        assert client.post("/v1/auth/google/challenge").status_code == 201


def test_document_etag_rechecks_disabled_owner(domain):
    version, _ = public_course(domain)
    path = f"/v1/track-versions/{version['version_id']}/document"
    first = domain.client.get(path)
    assert first.status_code == 200 and "must-revalidate" in first.headers["cache-control"]
    assert domain.client.get(path, headers={"If-None-Match":first.headers["etag"]}).status_code == 304
    with domain.factory() as session:
        session.get(Player, domain.players["Creator"]).disabled = True
        session.commit()
    assert domain.client.get(path, headers={"If-None-Match":first.headers["etag"]}).status_code == 404


def test_board_cache_tracks_pbs_and_restrictions_across_sessions(domain):
    version, _ = public_course(domain)
    first = submit(domain, ticket(domain, version, "Alice"), "Alice", frames=30)
    assert process_one(domain.app)
    board = first["board_id"]
    path = f"/v1/boards/{board}"
    # Populate both caches, then change their inputs through separate DB sessions.
    assert domain.client.get(path).json()["population"] == 2
    assert domain.client.get(path+"/histogram").json()["maximum_ticks"] == 300
    second = submit(domain, ticket(domain, version, "Bob"), "Bob", frames=80)
    assert process_one(domain.app)
    assert domain.client.get(path).json()["population"] == 3
    assert domain.client.get(path+"/histogram").json()["maximum_ticks"] == 400
    with domain.factory() as session:
        session.get(Player, domain.players["Bob"]).disabled = True
        session.commit()
    assert domain.client.get(path).json()["population"] == 2
    assert domain.client.get(path+"/histogram").json()["maximum_ticks"] == 300
    with domain.factory() as session:
        session.execute(update(PersonalBest).where(PersonalBest.board_id == board, PersonalBest.player_id == domain.players["Creator"]).values(time_ticks=90))
        session.commit()
    assert domain.client.get(path+"/histogram").json()["maximum_ticks"] == 150
    assert second["run_id"] != first["run_id"]


def test_board_cursor_preserves_competition_ties(domain):
    version, _ = public_course(domain)
    for name in ("Alice", "Bob", "Carol"):
        result = submit(domain, ticket(domain, version, name), name, frames=60)
        assert process_one(domain.app)
    path = f"/v1/boards/{result['board_id']}"
    first = domain.client.get(path, params={"limit":2}).json()
    second = domain.client.get(path, params={"limit":2, "cursor":first["next_cursor"]}).json()
    rows = first["items"] + second["items"]
    assert len({row["player_id"] for row in rows}) == 4
    assert [row["position"] for row in rows] == [1,2,3,4]
    assert [row["rank"] for row in rows] == [1,1,1,1]
    assert second["next_cursor"] is None


def test_historical_contract_waits_for_compatible_worker_and_never_rescored(domain, monkeypatch):
    version, _ = public_course(domain)
    issued = ticket(domain, version)
    submitted = submit(domain, issued)
    from bmt_backend.track_models import Board
    with domain.factory() as session:
        board = session.get(Board, issued["board_id"])
        original = {**board.manifest, "rules_key":"historical-build"}
        board.manifest = original
        session.commit()
    monkeypatch.setattr(domain.app.state.verifier, "verify_run", lambda *args, **kwargs: pytest.fail("historical replay was rescored"))
    assert not process_one(domain.app)
    with domain.factory() as session:
        job = session.get(Run, submitted["run_id"])
        assert job.status == "queued" and job.attempts == 0
        assert session.get(Board, issued["board_id"]).manifest == original
