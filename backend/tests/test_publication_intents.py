"""Explicit Publish, immutable evidence and atomic slot/provenance effects."""
from dataclasses import replace

import pytest
from sqlalchemy import func, select
from test_domains import domain as domain_fixture
from test_domains import headers

from bmt_backend.commerce_models import Entitlements, PublicationSlot
from bmt_backend.config import Settings
from bmt_backend.publication_models import PublicationIntent
from bmt_backend.publications import process_one
from bmt_backend.track_models import Board, PersonalBest, QueueCapacity, Run, Track, TrackVersion
from bmt_backend.verifier import VerificationError

domain = domain_fixture


@pytest.fixture
def publications(domain, monkeypatch):
    domain.app.state.settings = replace(domain.app.state.settings, local_drafts_only=True)
    calls = []

    def verify(document, replay, vehicle_id, *, creator_test=False):
        calls.append((document, replay, vehicle_id, creator_test))
        assert creator_test and replay["schema"] == "bmt-trajectory-v1" and "frames" not in replay
        return {"time_ticks": replay["input_count"], "lap_ticks": [replay["input_count"]],
                "manifest": domain.app.state.verifier.validate_track(document)}

    monkeypatch.setattr(domain.app.state.verifier, "verify_run", verify)
    domain.proof_calls = calls
    return domain


def body(domain, **changes):
    document = {"schema": "creator-track-v5", "id": "local_creator", "name": "Local loop",
                "shape": "oval", "points": [[0, 0], [20, 0], [20, 20], [0, 20]]}
    document.update(changes)
    manifest = domain.app.state.verifier.validate_track(document)
    contract = {key: manifest[key] for key in ("engine_version", "verifier_version", "physics_version", "rules_key",
        "compiler_version", "track_schema", "replay_schema", "tick_rate", "track_content_hash")}
    contract["config_hash"] = manifest["vehicles"]["compact"]["config_hash"]
    return {"name": document["name"], "document": document, "vehicle_id": "compact", "contract": contract,
            "replay": {"schema": "bmt-trajectory-v1", "input_count": 120,
                       "race_proof": {"schema": "bmt-race-path-v1", "samples": [[0, 0, 0, 0], [120, 0, 0, 0]]}}}


def request(domain, content=None, auth=None):
    response = domain.client.post("/v1/publications", json=content or body(domain), headers=auth or headers(domain))
    assert response.status_code == 202, response.text
    return response.json()


def status(domain, identity, player="Creator"):
    response = domain.client.get(f"/v1/me/publications/{identity}", headers=headers(domain, player))
    assert response.status_code == 200, response.text
    return response.json()


def count(session, table):
    return session.scalar(select(func.count()).select_from(table))


def test_no_track_inventory_until_verified_publish_and_exact_provenance(publications):
    domain = publications
    intent = request(domain)
    assert intent["state"] == "queued" and intent["receipt"] is None
    with domain.factory() as session:
        assert count(session, Track) == count(session, TrackVersion) == count(session, Run) == 0
        assert session.get(QueueCapacity, 1).pending == 1
        assert session.get(Entitlements, domain.players["Creator"]).slots == 1
    assert domain.client.get("/v1/tracks").json()["items"] == []
    assert domain.client.get("/v1/me/tracks", headers=headers(domain)).json()["items"] == []
    assert process_one(domain.app)
    published = status(domain, intent["publication_id"])
    assert published["state"] == "published" and published["receipt"]["state"] == "published"
    assert len(domain.proof_calls) == 1
    version_id = published["receipt"]["version_id"]
    with domain.factory() as session:
        assert count(session, Track) == count(session, TrackVersion) == count(session, Run) == count(session, PublicationSlot) == 1
        assert count(session, PersonalBest) == 0  # Creator validity is never a score.
        version = session.get(TrackVersion, version_id)
        run = session.get(Run, version.creator_test_run_id)
        board = session.get(Board, run.board_id)
        assert run.status == "verified" and run.time_ticks == 120 and run.lap_ticks == [120]
        assert board.manifest["purpose"] == "creator_test" and board.manifest["laps"] == 1
        assert version.manifest["laps"] == 5
        assert domain.app.state.blobs.get_json(run.replay_hash) == body(domain)["replay"]
        assert domain.app.state.blobs.get_json(version.content_hash)["creator"] == "Creator"
        assert session.get(Entitlements, domain.players["Creator"]).slots == 0
        assert session.get(QueueCapacity, 1).pending == 0


def test_permanent_retries_dedupe_content_and_slot(publications):
    domain = publications
    auth, content = headers(domain), body(domain)
    first = request(domain, content, auth)
    assert request(domain, content, auth)["publication_id"] == first["publication_id"]
    changed = {**content, "name": "Different name"}
    assert domain.client.post("/v1/publications", json=changed, headers=auth).status_code == 409
    assert process_one(domain.app)
    assert request(domain, content, auth)["state"] == "published"
    # A new operation key for identical immutable content also cannot double grant/consume.
    repeated = request(domain, content)
    assert process_one(domain.app)
    assert status(domain, repeated["publication_id"])["receipt"]["version_id"] == status(domain, first["publication_id"])["receipt"]["version_id"]
    with domain.factory() as session:
        assert count(session, TrackVersion) == count(session, Run) == count(session, PublicationSlot) == 1
        assert session.get(Entitlements, domain.players["Creator"]).slots == 0


def test_invalid_lap_and_build_mismatch_leave_only_failed_publication(publications, monkeypatch):
    domain = publications
    content = body(domain)
    content["contract"]["compiler_version"] = "different-compiler"
    first = request(domain, content)
    assert process_one(domain.app)
    assert status(domain, first["publication_id"])["failure_code"] == "build_mismatch"
    assert domain.proof_calls == []
    monkeypatch.setattr(domain.app.state.verifier, "verify_run", lambda *args, **kwargs: (_ for _ in ()).throw(VerificationError("Ordered road gates incomplete")))
    second = request(domain)
    assert process_one(domain.app)
    invalid = status(domain, second["publication_id"])
    assert invalid["failure_code"] == "invalid_creator_proof" and not invalid["retryable"]
    with domain.factory() as session:
        assert count(session, Track) == count(session, TrackVersion) == count(session, Run) == count(session, PublicationSlot) == 0
        assert session.get(Entitlements, domain.players["Creator"]).slots == 1
        assert session.get(QueueCapacity, 1).pending == 0


def test_no_capacity_rolls_back_every_catalogue_and_proof_write(publications):
    domain = publications
    first = request(domain)
    assert process_one(domain.app)
    second = request(domain, body(domain, name="Edited publication", shape="updated"))
    assert process_one(domain.app)
    failed = status(domain, second["publication_id"])
    assert failed["state"] == "failed" and failed["failure_code"] == "NO_PUBLISHING_SLOTS" and failed["retryable"]
    with domain.factory() as session:
        assert count(session, TrackVersion) == count(session, Run) == count(session, PublicationSlot) == 1
        session.get(Entitlements, domain.players["Creator"]).slots += 1
        session.commit()
    retry = domain.client.post(f"/v1/me/publications/{second['publication_id']}/retry", headers=headers(domain))
    assert retry.status_code == 200 and retry.json()["state"] == "queued"
    assert process_one(domain.app)
    published = status(domain, second["publication_id"])
    assert published["state"] == "published" and published["receipt"]["version"] == 2
    assert published["receipt"]["track_id"] == status(domain, first["publication_id"])["receipt"]["track_id"]
    with domain.factory() as session:
        assert count(session, Track) == 1 and count(session, TrackVersion) == count(session, Run) == count(session, PublicationSlot) == 2
        assert session.get(QueueCapacity, 1).pending == 0


def test_legacy_draft_requests_rejected_before_storage_and_owner_status_is_private(publications, monkeypatch):
    domain = publications
    def forbidden(*args, **kwargs):
        raise AssertionError("Legacy draft request must not store/read objects")
    monkeypatch.setattr(domain.app.state.blobs, "put_json", forbidden)
    for route, method, content in (("/v1/tracks", "post", {"name": "Loop", "document": {"schema": "creator-track-v5", "id": "legacy"}}),
        ("/v1/tracks/unknown/versions", "post", {"name": "Loop", "document": {}}),
        ("/v1/me/drafts/legacy/archive", "post", None), ("/v1/me/drafts/legacy/head", "get", None)):
        response = getattr(domain.client, method)(route, **({"json": content} if content else {}), headers=headers(domain))
        assert response.status_code == 410, response.text
    with domain.factory() as session:
        assert count(session, Track) == count(session, TrackVersion) == count(session, PublicationIntent) == 0


def test_status_reads_do_not_verify_or_read_blobs_and_cannot_cross_accounts(publications, monkeypatch):
    domain = publications
    intent = request(domain)
    def forbidden(*args, **kwargs):
        raise AssertionError("Status is prepared metadata")
    monkeypatch.setattr(domain.app.state.blobs, "get_json", forbidden)
    monkeypatch.setattr(domain.app.state.verifier, "verify_run", forbidden)
    assert status(domain, intent["publication_id"])["state"] == "queued"
    assert domain.client.get(f"/v1/me/publications/{intent['publication_id']}", headers=headers(domain, "Alice")).status_code == 404


def test_old_drafts_remain_stored_but_owned_catalogue_has_only_published(publications):
    domain = publications
    with domain.factory() as session:
        track = Track(owner_id=domain.players["Creator"], authoring_id="historical_draft")
        session.add(track)
        session.flush()
        old = TrackVersion(track_id=track.id, number=1, name="Published", content_hash="a"*64, manifest={}, state="published")
        draft = TrackVersion(track_id=track.id, number=2, name="Historical draft", content_hash="b"*64, manifest={}, state="draft")
        session.add_all((old, draft))
        session.commit()
        old_id = old.id
    mine = domain.client.get("/v1/me/tracks?heads=true", headers=headers(domain)).json()["items"]
    assert [row["version_id"] for row in mine] == [old_id]
    with domain.factory() as session:
        assert count(session, TrackVersion) == 2


def test_production_and_development_cannot_enable_legacy_remote_drafts():
    assert Settings().local_drafts_only
    for environment in ("production", "development"):
        with pytest.raises(ValueError, match="compatibility test"):
            Settings(environment=environment, local_drafts_only=False)
    assert not Settings(environment="test", local_drafts_only=False).local_drafts_only


def test_infrastructure_retry_and_stale_worker_fence_cannot_publish(publications, monkeypatch):
    domain = publications
    original = domain.app.state.verifier.verify_run
    domain.app.state.settings = replace(domain.app.state.settings, max_job_attempts=1)
    monkeypatch.setattr(domain.app.state.verifier, "verify_run", lambda *args, **kwargs: (_ for _ in ()).throw(RuntimeError("unavailable")))
    first = request(domain)
    assert process_one(domain.app)
    assert status(domain, first["publication_id"])["failure_code"] == "validator_unavailable"
    with domain.factory() as session:
        assert count(session, TrackVersion) == 0 and session.get(QueueCapacity, 1).pending == 0
    monkeypatch.setattr(domain.app.state.verifier, "verify_run", original)
    assert domain.client.post(f"/v1/me/publications/{first['publication_id']}/retry", headers=headers(domain)).status_code == 200

    def stale(document, replay, vehicle, *, creator_test=False):
        result = original(document, replay, vehicle, creator_test=creator_test)
        with domain.factory() as session:
            row = session.get(PublicationIntent, first["publication_id"])
            row.lease_token = "00000000-0000-4000-8000-000000000002"
            session.commit()
        return result

    monkeypatch.setattr(domain.app.state.verifier, "verify_run", stale)
    assert process_one(domain.app)
    with domain.factory() as session:
        assert count(session, TrackVersion) == count(session, PublicationSlot) == 0
        assert session.get(QueueCapacity, 1).pending == 1
        assert session.get(Entitlements, domain.players["Creator"]).slots == 1


def test_retention_protects_pending_publication_document_and_saved_proof(publications, monkeypatch):
    from bmt_backend.maintenance import retain
    from bmt_backend.track_models import now
    domain = publications
    created = request(domain)
    with domain.factory() as session:
        row = session.get(PublicationIntent, created["publication_id"])
        hashes = (row.content_hash, row.replay_hash)
    objects = [{"digest": identity, "modified": now()-2*86400, "bytes": 100} for identity in hashes]
    monkeypatch.setattr(domain.app.state.blobs, "list_objects", lambda *args: (objects, None))
    def forbidden(*args):
        raise AssertionError("Pending immutable publication evidence must be retained")
    monkeypatch.setattr(domain.app.state.blobs, "delete", forbidden)
    result = retain(domain.factory, domain.app.state.blobs, apply=True, offline=True)
    assert result["orphaned_objects"] == 0
    for identity in hashes:
        assert domain.app.state.blobs.get_json(identity)


def test_foreground_races_precede_publication_and_publication_precedes_artificial(publications):
    from test_domains import submit, ticket, upload

    from bmt_backend.identity_models import Player
    from bmt_backend.worker import process_one as worker_one
    domain = publications
    # Explicit compatibility fixture is used only to seed an existing published
    # race course; the behavior under test retains the new local-draft policy.
    domain.app.state.settings = replace(domain.app.state.settings, local_drafts_only=False)
    version = upload(domain)
    with domain.factory() as session:
        session.get(TrackVersion, version["version_id"]).state = "published"
        session.commit()
    issued = ticket(domain, version, "Alice")
    raced = submit(domain, issued, "Alice")
    domain.app.state.settings = replace(domain.app.state.settings, local_drafts_only=True)
    intent = request(domain)
    original = domain.app.state.verifier.verify_run
    def both(document, replay, vehicle, *, creator_test=False):
        if creator_test:
            return original(document, replay, vehicle, creator_test=True)
        return {"time_ticks": 100, "lap_ticks": [20]*5, "manifest": domain.app.state.verifier.validate_track(document)}
    domain.app.state.verifier.verify_run = both
    assert worker_one(domain.app)
    with domain.factory() as session:
        assert session.get(Run, raced["run_id"]).status == "verified"
        assert session.get(PublicationIntent, intent["publication_id"]).status == "queued"
    second_ticket = ticket(domain, version, "Bob")
    artificial = submit(domain, second_ticket, "Bob")
    with domain.factory() as session:
        session.get(Player, domain.players["Bob"]).is_test_driver = True
        session.commit()
    assert worker_one(domain.app)
    assert status(domain, intent["publication_id"])["state"] == "published"
    with domain.factory() as session:
        assert session.get(Run, artificial["run_id"]).status == "queued"


def test_publication_admin_metadata_is_bounded_authenticated_and_has_no_raw_documents(publications, monkeypatch):
    domain = publications
    domain.app.state.settings = replace(domain.app.state.settings, admin_owner_key="o"*40, admin_analyst_key="a"*40)
    first = request(domain)
    assert domain.client.get("/v1/admin/publications").status_code == 401
    def forbidden(*args):
        raise AssertionError("Operator metadata must never load private documents/trajectories")
    monkeypatch.setattr(domain.app.state.blobs, "get_json", forbidden)
    listing = domain.client.get("/v1/admin/publications?limit=1", headers={"Authorization": "Bearer "+"a"*40})
    assert listing.status_code == 200, listing.text
    data = listing.json()
    assert data["role"] == "analyst" and data["counts"] == {"pending": 1, "failed": 0} and not data["failed_count_capped"]
    assert len(data["items"]) == 1 and "document" not in data["items"][0] and "replay" not in data["items"][0]
    assert "operation_key" not in data["items"][0] and "lease_token" not in data["items"][0]
    detail = domain.client.get(f"/v1/admin/publications/{first['publication_id']}", headers={"Authorization": "Bearer "+"o"*40})
    assert detail.status_code == 200 and detail.json()["publication"]["creator_run_id"] is None
    assert domain.client.get("/v1/admin/publications?limit=101", headers={"Authorization": "Bearer "+"a"*40}).status_code == 422


def test_upgrade_parks_old_draft_jobs_preserves_source_metadata_and_releases_counters(domain, tmp_path):
    import uuid

    from alembic import command
    from sqlalchemy import create_engine, text
    from sqlalchemy.orm import Session

    from bmt_backend.identity_models import Player
    from bmt_backend.migrate import configuration
    from bmt_backend.track_models import QueuePlayer, TrackValidation, now

    schema = "test_retired_drafts_"+uuid.uuid4().hex
    if domain.postgres:
        with domain.app.state.engine.begin() as connection:
            connection.exec_driver_sql("CREATE SCHEMA "+schema)
        engine = create_engine(domain.app.state.settings.database_url,
            connect_args={"options": "-c search_path="+schema, "connect_timeout": 5})
    else:
        engine = create_engine("sqlite:///"+(tmp_path/"legacy.sqlite").as_posix())
    try:
        command.upgrade(configuration(engine), "0027_client_quality")
        with Session(engine) as session:
            owner = Player(display_name="Legacy Owner")
            session.add(owner)
            session.flush()
            track = Track(owner_id=owner.id, authoring_id="kept_draft")
            session.add(track)
            session.flush()
            source = TrackVersion(track_id=track.id, number=1, name="Legacy draft", content_hash="a"*64,
                manifest={}, state="validating")
            published = TrackVersion(track_id=track.id, number=2, name="Published retained", content_hash="b"*64,
                manifest={}, state="published", published_at=now())
            session.add_all((source, published))
            session.flush()
            version_id, published_id, owner_id = source.id, published.id, owner.id
            original_detail = "x"*500
            lease_token = str(uuid.uuid4())
            session.execute(text("""INSERT INTO track_validations(version_id,status,attempts,lease_until,lease_token,failure_code,detail,created_at)
                VALUES(:version,'validating',2,1234567890,:token,'validator_unavailable',:detail,1)"""),
                {"version": version_id, "token": lease_token, "detail": original_detail})
            session.commit()
            assert session.get(QueueCapacity, 1).pending == session.get(QueuePlayer, owner_id).pending == 1
        command.upgrade(configuration(engine), "0028_publication_intents")
        with Session(engine) as session:
            kept = session.get(TrackValidation, version_id)
            assert kept.status == "legacy_saved" and kept.lease_token is None and kept.lease_until == 0
            assert kept.legacy_workflow_snapshot == {"status": "validating", "failure_code": "validator_unavailable",
                "detail": original_detail, "attempts": 2, "lease_until": 1234567890, "lease_token": lease_token}
            assert count(session, Track) == 1 and count(session, TrackVersion) == 2
            assert session.get(TrackVersion, version_id).content_hash == "a"*64
            assert session.get(TrackVersion, published_id).state == "published"
            assert session.get(QueueCapacity, 1).pending == session.get(QueuePlayer, owner_id).pending == 0
    finally:
        engine.dispose()
        if domain.postgres:
            with domain.app.state.engine.begin() as connection:
                connection.exec_driver_sql("DROP SCHEMA "+schema+" CASCADE")


def test_concurrent_publication_delivery_has_one_intent_and_one_effect(publications):
    from concurrent.futures import ThreadPoolExecutor
    domain = publications
    if not domain.postgres:
        pytest.skip("Concurrent request/owner row-lock behavior is exercised on PostgreSQL")
    auth, content = headers(domain), body(domain)
    with ThreadPoolExecutor(max_workers=2) as executor:
        returned = list(executor.map(lambda _: request(domain, content, auth), range(2)))
    assert returned[0]["publication_id"] == returned[1]["publication_id"]
    assert process_one(domain.app)
    with domain.factory() as session:
        assert count(session, PublicationIntent) == count(session, TrackVersion) == count(session, PublicationSlot) == count(session, Run) == 1
        assert session.get(Entitlements, domain.players["Creator"]).slots == 0
        assert session.get(QueueCapacity, 1).pending == 0


def test_concurrent_publications_cannot_spend_one_slot_twice(publications):
    from concurrent.futures import ThreadPoolExecutor
    domain = publications
    if not domain.postgres:
        pytest.skip("Concurrent finalization/entitlement row-lock behavior is exercised on PostgreSQL")
    first = request(domain)
    second = request(domain, body(domain, id="another_local_track", name="Second local loop"))
    with ThreadPoolExecutor(max_workers=2) as executor:
        assert all(executor.map(lambda _: process_one(domain.app), range(2)))
    states = [status(domain, item["publication_id"])["state"] for item in (first, second)]
    assert sorted(states) == ["failed", "published"]
    with domain.factory() as session:
        assert count(session, Track) == count(session, TrackVersion) == count(session, PublicationSlot) == count(session, Run) == 1
        assert session.get(Entitlements, domain.players["Creator"]).slots == 0
        assert session.get(QueueCapacity, 1).pending == 0


def test_permanent_publication_identity_survives_key_age_without_new_effect(publications, monkeypatch):
    from bmt_backend.track_models import now
    domain = publications
    issued = now()
    key = "v2."+str(issued)+"."+"a"*48
    content = body(domain)
    first = request(domain, content, headers(domain, key=key))
    assert process_one(domain.app)
    monkeypatch.setattr("bmt_backend.track_models.now", lambda: issued+91*86400)
    repeated = request(domain, content, headers(domain, key=key))
    assert repeated["state"] == "published" and repeated["publication_id"] == first["publication_id"]
    # Expired unknown identities cannot create a new publication, and a known
    # identity with altered content cannot change its original effect.
    unknown = key[:-1]+"b"
    assert domain.client.post("/v1/publications", json=content, headers=headers(domain, key=unknown)).status_code == 410
    changed = {**content, "name": "Changed request"}
    assert domain.client.post("/v1/publications", json=changed, headers=headers(domain, key=key)).status_code == 409
    with domain.factory() as session:
        assert count(session, PublicationIntent) == count(session, TrackVersion) == count(session, PublicationSlot) == 1
