"""The four reproduced abuse paths must fail without breaking durable recovery."""
import asyncio
import os
from dataclasses import replace
from types import SimpleNamespace
from uuid import uuid4

import httpx
import pytest
from sqlalchemy import func, select, text, update
from test_domains import domain as domain_fixture
from test_domains import headers
from test_publication_intents import body
from test_publication_intents import publications as publications_fixture

from bmt_backend import discovery
from bmt_backend.discovery import DiscoveryBudget, DiscoverySnapshot
from bmt_backend.maintenance import retain
from bmt_backend.publication_models import PublicationIntent, PublicationUpload
from bmt_backend.publication_storage import reserve_upload
from bmt_backend.publications import process_one
from bmt_backend.track_models import Track, TrackVersion, digest, now

domain = domain_fixture
publications = publications_fixture


def isolated_scope(path, method="POST", credential=None):
    request_headers = [(b"content-type", b"application/json"), (b"content-length", b"2")]
    if credential is not None:
        request_headers.append((b"authorization", credential.encode()))
    return {"type": "http", "asgi": {"version": "3.0"}, "http_version": "1.1",
        "method": method, "scheme": "http", "path": path, "raw_path": path.encode(),
        "query_string": b"", "root_path": "", "headers": request_headers,
        "client": ("192.0.2.44", 4000), "server": ("test", 80)}


@pytest.mark.parametrize("credential", [None, "Bearer " + "x" * 43])
@pytest.mark.parametrize("path", ["/v1/runs", "/v1/publications", "/v1/telemetry/batches"])
def test_unauthenticated_upload_never_reads_body_or_takes_slot(auth_app, path, credential):
    async def exercise():
        messages = []

        async def forbidden():
            raise AssertionError("An unauthenticated upload must be rejected before receive")

        async def send(message):
            messages.append(message)

        await auth_app(isolated_scope(path, credential=credential), forbidden, send)
        assert next(item["status"] for item in messages if item["type"] == "http.response.start") == 401

    asyncio.run(exercise())


@pytest.mark.parametrize("method", ["GET", "HEAD", "DELETE", "OPTIONS"])
def test_unsupported_methods_never_read_or_parse_large_bodies(auth_app, monkeypatch, method):
    def forbidden_parse(_body):
        raise AssertionError("Unsupported methods cannot enter JSON parsing")

    monkeypatch.setattr("bmt_backend.middleware.parse_body", forbidden_parse)

    async def exercise():
        messages = []

        async def forbidden_receive():
            raise AssertionError("Unsupported methods cannot buffer a body")

        async def send(message):
            messages.append(message)

        await auth_app(isolated_scope("/v1/publications", method), forbidden_receive, send)
        assert next(item["status"] for item in messages if item["type"] == "http.response.start") == 405

    asyncio.run(exercise())


def test_anonymous_discovery_slow_body_does_not_block_race_upload(auth_app, sign_in):
    credentials = sign_in()

    async def exercise():
        reached, release = asyncio.Event(), asyncio.Event()

        async def receive():
            reached.set()
            await release.wait()
            return {"type": "http.request", "body": b"{}", "more_body": False}

        async def send(_message):
            pass

        pending = asyncio.create_task(auth_app(isolated_scope("/v1/discovery/tracks"), receive, send))
        try:
            await asyncio.wait_for(reached.wait(), 3)
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=auth_app), base_url="http://test") as client:
                response = await client.post("/v1/runs", headers={"Authorization": "Bearer " + credentials["access_token"],
                    "Idempotency-Key": str(uuid4())}, json={"ticket_id": str(uuid4()),
                    "replay": {"schema": "bmt-trajectory-v1", "input_count": 6, "race_proof": {}}})
                assert response.status_code == 404 and response.json()["detail"] == "Run ticket not found"
        finally:
            release.set()
            await asyncio.wait_for(pending, 3)

    asyncio.run(exercise())


def failed_content(domain, index=0):
    content = body(domain, id="invalid_"+str(index), padding="x"*2048)
    content["document"]["invalid"] = True
    return content


def post(domain, content, key=None):
    return domain.client.post("/v1/publications", json=content, headers=headers(domain, key=key))


def test_byte_quota_precedes_storage_and_count_quota_is_owner_scoped(publications, monkeypatch):
    domain = publications
    domain.app.state.settings = replace(domain.app.state.settings, publication_evidence_bytes=1)
    def forbidden(_data):
        raise AssertionError("Quota rejection must precede object IO")
    original = domain.app.state.blobs.put_json
    monkeypatch.setattr(domain.app.state.blobs, "put_json", forbidden)
    denied = post(domain, failed_content(domain))
    assert denied.status_code == 429 and denied.json()["detail"] == "PUBLICATION_EVIDENCE_LIMIT"
    monkeypatch.setattr(domain.app.state.blobs, "put_json", original)
    domain.app.state.settings = replace(domain.app.state.settings, publication_evidence_bytes=64*1024*1024,
                                        publication_evidence_count=1)
    key, content = str(uuid4()), failed_content(domain)
    first = post(domain, content, key)
    assert first.status_code == 202 and process_one(domain.app)
    assert post(domain, failed_content(domain, 1)).status_code == 429
    replayed = post(domain, content, key)
    assert replayed.status_code == 202 and replayed.json()["publication_id"] == first.json()["publication_id"]
    assert domain.client.post("/v1/publications", json=failed_content(domain, 2),
                              headers=headers(domain, "Alice")).status_code == 202


def test_partial_storage_failure_remains_charged_and_same_key_recovers(publications, monkeypatch):
    domain = publications
    domain.app.state.settings = replace(domain.app.state.settings, publication_evidence_count=1)
    key, content = str(uuid4()), body(domain)
    original, calls = domain.app.state.blobs.put_json, []
    def fail_second(data):
        calls.append(1)
        if len(calls) == 2:
            raise OSError("Injected offline failure")
        return original(data)
    monkeypatch.setattr(domain.app.state.blobs, "put_json", fail_second)
    assert post(domain, content, key).status_code == 503
    with domain.factory() as session:
        reservation = session.get(PublicationUpload, (domain.players["Creator"], key))
        assert reservation.evidence_bytes > 0 and reservation.lease_until == 0
        reserved = reservation.evidence_bytes
    assert post(domain, failed_content(domain, 1)).status_code == 429
    monkeypatch.setattr(domain.app.state.blobs, "put_json", original)
    recovered = post(domain, content, key)
    assert recovered.status_code == 202
    with domain.factory() as session:
        assert session.get(PublicationUpload, (domain.players["Creator"], key)) is None
        assert session.get(PublicationIntent, recovered.json()["publication_id"]).evidence_bytes == reserved
    assert process_one(domain.app)
    assert post(domain, failed_content(domain, 2)).status_code == 202  # Published content releases the evidence allowance.


def test_rejected_evidence_expires_without_repeating_original_operation(publications):
    domain = publications
    key, content = str(uuid4()), failed_content(domain)
    accepted = post(domain, content, key)
    assert accepted.status_code == 202 and process_one(domain.app)
    with domain.factory() as session:
        row = session.get(PublicationIntent, accepted.json()["publication_id"])
        assert row.failure_code == "invalid_creator_proof"
        hashes = row.content_hash, row.replay_hash
        row.created_at = row.finished_at = now()-120*86400
        session.commit()
    for value in hashes:
        os.utime(domain.app.state.blobs._path(value), (now()-120*86400, now()-120*86400))
    result = retain(domain.factory, domain.app.state.blobs, apply=True, offline=True)
    assert result["retired_publications"] == 1 and result["orphaned_objects"] == 2
    with domain.factory() as session:
        row = session.get(PublicationIntent, accepted.json()["publication_id"])
        assert row.evidence_retired and row.evidence_bytes == 0 and row.contract == {}
    for value in hashes:
        assert not domain.app.state.blobs._path(value).exists()
    replayed = post(domain, content, key)
    assert replayed.status_code == 202 and replayed.json()["publication_id"] == accepted.json()["publication_id"]
    assert replayed.json()["state"] == "failed" and not process_one(domain.app)


def test_expired_incomplete_upload_is_a_permanent_tombstone(publications):
    domain = publications
    key, content = str(uuid4()), body(domain)
    with domain.factory() as session:
        document = {**content["document"], "creator": "Creator"}
        upload, _ = reserve_upload(session, domain.app.state.settings, domain.players["Creator"], key,
                                   digest(content), document, content["replay"])
        upload.created_at, upload.lease_until = now()-120*86400, 0
        session.commit()
    result = retain(domain.factory, domain.app.state.blobs, apply=True, offline=True)
    assert result["retired_publication_uploads"] == 1
    assert post(domain, content, key).status_code == 410
    assert post(domain, {**content, "name": "Changed"}, key).status_code == 409


def test_replaced_upload_lease_fences_old_writer_and_preserves_new_charge(publications, monkeypatch):
    domain = publications
    key, content = str(uuid4()), body(domain)
    original, tokens = domain.app.state.blobs.put_json, []
    def replace_lease(data):
        if not tokens:
            with domain.factory() as session:
                upload = session.get(PublicationUpload, (domain.players["Creator"], key))
                upload.lease_until = 0
                session.commit()
                replacement, _ = reserve_upload(session, domain.app.state.settings, domain.players["Creator"], key,
                    digest(content), {**content["document"], "creator": "Creator"}, content["replay"])
                tokens.append(replacement.lease_token)
        return original(data)
    monkeypatch.setattr(domain.app.state.blobs, "put_json", replace_lease)
    assert post(domain, content, key).status_code == 503
    with domain.factory() as session:
        upload = session.get(PublicationUpload, (domain.players["Creator"], key))
        assert upload.lease_token == tokens[0] and upload.lease_until > now() and upload.evidence_bytes > 0
        assert session.scalar(select(func.count()).select_from(PublicationIntent)) == 0
    monkeypatch.setattr(domain.app.state.blobs, "put_json", original)
    assert post(domain, content, key).status_code == 202


def test_resource_migration_preserves_and_charges_legacy_rows(domain):
    from alembic import command

    from bmt_backend.migrate import configuration, upgrade
    engine = domain.app.state.engine
    command.downgrade(configuration(engine), "0032_network_health")
    identity = str(uuid4())
    with engine.begin() as connection:
        connection.execute(text("INSERT INTO publication_intents "
            "(id,player_id,operation_key,request_hash,authoring_id,name,content_hash,replay_hash,vehicle_id,contract,"
            "status,attempts,lease_until,created_at,finished_at,failure_code) VALUES "
            "(:id,:player,:key,:hash,'legacy','Legacy',:hash,:hash,'compact','{}','failed',0,0,1,1,'invalid_creator_proof')"),
            {"id": identity, "player": domain.players["Creator"], "key": str(uuid4()), "hash": "a"*64})
        connection.execute(text("INSERT INTO discovery_snapshots (id,query_hash,expires_at,version_ids) "
            "VALUES (:id,:hash,:expires,:ids)"), {"id": str(uuid4()), "hash": "b"*64,
            "expires": now()+1800, "ids": '["one","two"]'})
    upgrade(engine)
    with domain.factory() as session:
        row = session.get(PublicationIntent, identity)
        assert row.operation_key and row.status == "failed" and row.contract == {}
        assert row.evidence_bytes == 2621440 and not row.evidence_retired
        budget = session.get(DiscoveryBudget, 1)
        assert budget.entries == 2 and budget.snapshots == 1


@pytest.mark.parametrize("failure", ["validator_unavailable", "build_mismatch", "NO_PUBLISHING_SLOTS"])
def test_infrastructure_and_entitlement_evidence_remains_recoverable(publications, failure):
    domain = publications
    accepted = post(domain, body(domain))
    with domain.factory() as session:
        row = session.get(PublicationIntent, accepted.json()["publication_id"])
        row.status, row.failure_code, row.finished_at = "failed", failure, now()-120*86400
        session.commit()
    assert retain(domain.factory, domain.app.state.blobs, apply=True, offline=True)["retired_publications"] == 0
    with domain.factory() as session:
        assert not session.get(PublicationIntent, accepted.json()["publication_id"]).evidence_retired


@pytest.fixture
def catalogue(domain):
    with domain.factory() as session:
        for index in range(12):
            track = Track(owner_id=domain.players["Creator"])
            session.add(track)
            session.flush()
            session.add(TrackVersion(track_id=track.id, number=1, name="Route " + str(index), content_hash="f"*64,
                manifest={"laps": 5}, state="published", published_at=now()-1, discovery={"theme": "pine"}))
        session.commit()
    return domain


def query(domain, **values):
    return domain.client.post("/v1/discovery/tracks", json=values)


def test_fresh_queries_coalesce_across_cache_restart(catalogue):
    domain = catalogue
    snapshots = []
    for _ in range(3):
        response = query(domain, fresh=True)
        assert response.status_code == 200 and response.json()["total"] == 12
        snapshots.append(response.json()["snapshot"])
        domain.app.state.discovery_memory.clear()
    assert len(set(snapshots)) == 1
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(DiscoverySnapshot)) == 1
        budget = session.get(DiscoveryBudget, 1)
        assert budget.entries == 12 and budget.snapshots == 1


def test_unchanged_fresh_order_is_not_duplicated_each_refresh_window(catalogue, monkeypatch):
    domain = catalogue
    epoch = now()
    epoch -= epoch % 1800
    epoch += 300
    with domain.factory() as session:
        session.execute(update(TrackVersion).values(published_at=epoch-1))
        session.commit()
    snapshots = []
    for offset in (0, 21, 42):
        monkeypatch.setattr(discovery, "time", SimpleNamespace(time=lambda offset=offset: epoch+offset))
        response = query(domain, fresh=True)
        assert response.status_code == 200
        snapshots.append(response.json()["snapshot"])
    assert len(set(snapshots)) == 1
    with domain.factory() as session:
        assert session.get(DiscoveryBudget, 1).snapshots == 1


def test_creation_budget_does_not_charge_cached_pages(catalogue):
    domain = catalogue
    domain.app.state.settings = replace(domain.app.state.settings, discovery_create_per_minute=1)
    first = query(domain, fresh=True)
    assert first.status_code == 200
    assert query(domain, fresh=True).status_code == 200
    limited = query(domain, fresh=True, sort="name")
    assert limited.status_code == 429 and limited.json()["detail"] == "DISCOVERY_CREATION_LIMIT"


@pytest.mark.parametrize("setting,value,code", [("discovery_catalogue_limit", 6, "DISCOVERY_CATALOGUE_LIMIT"),
    ("discovery_snapshot_ids", 6, "DISCOVERY_SNAPSHOT_LIMIT")])
def test_discovery_bounds_do_not_silently_truncate_catalogue(catalogue, setting, value, code):
    domain = catalogue
    domain.app.state.settings = replace(domain.app.state.settings, **{setting: value})
    response = query(domain, fresh=True)
    assert response.status_code == 503 and response.json()["detail"] == code
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(DiscoverySnapshot)) == 0
        assert session.get(DiscoveryBudget, 1).entries == 0


def test_snapshot_count_recovers_after_expiry_and_cached_pages_keep_working(catalogue, monkeypatch):
    domain = catalogue
    domain.app.state.settings = replace(domain.app.state.settings, discovery_snapshot_count=1)
    first = query(domain, fresh=True)
    assert first.status_code == 200
    assert query(domain, fresh=True, sort="name").status_code == 503
    assert query(domain, fresh=True, cursor=first.json()["page_cursor"]).status_code == 200
    epoch = now()+1801
    monkeypatch.setattr(discovery, "time", SimpleNamespace(time=lambda: epoch))
    assert query(domain, fresh=True, sort="name").status_code == 200
    assert query(domain, fresh=True, cursor=first.json()["page_cursor"]).status_code == 410
    with domain.factory() as session:
        budget = session.get(DiscoveryBudget, 1)
        assert budget.entries == 12 and budget.snapshots == 1


def test_postgres_concurrent_new_publication_keys_cannot_exceed_quota(publications):
    from concurrent.futures import ThreadPoolExecutor
    if not publications.postgres:
        pytest.skip("Quota races require independent PostgreSQL transactions")
    publications.app.state.settings = replace(publications.app.state.settings, publication_evidence_count=1)
    with ThreadPoolExecutor(max_workers=2) as executor:
        responses = list(executor.map(lambda index: post(publications, failed_content(publications, index)), range(2)))
    assert sorted(response.status_code for response in responses) == [202, 429]
    with publications.factory() as session:
        assert session.scalar(select(func.count()).select_from(PublicationIntent)) == 1
        assert session.scalar(select(func.count()).select_from(PublicationUpload)) == 0


@pytest.mark.parametrize("same_query", [False, True])
def test_postgres_discovery_budget_is_shared_across_replicas(catalogue, monkeypatch, same_query):
    from concurrent.futures import ThreadPoolExecutor

    from fastapi.testclient import TestClient

    from bmt_backend.app import create_app
    domain = catalogue
    if not domain.postgres:
        pytest.skip("Snapshot races require independent PostgreSQL transactions")
    domain.app.state.settings = replace(domain.app.state.settings, discovery_snapshot_count=1)
    epoch = now()
    monkeypatch.setattr(discovery, "time", SimpleNamespace(time=lambda: epoch))
    peer = create_app(domain.app.state.settings, engine=domain.app.state.engine, verifier=domain.app.state.verifier)
    peer.dependency_overrides.update(domain.app.dependency_overrides)
    with TestClient(peer) as peer_client:
        clients = domain.client, peer_client
        with ThreadPoolExecutor(max_workers=2) as executor:
            responses = list(executor.map(lambda index: clients[index].post("/v1/discovery/tracks",
                json={"fresh": True, "sort": "name" if index == 1 and not same_query else "recommended"}), range(2)))
    assert sorted(response.status_code for response in responses) == ([200, 200] if same_query else [200, 503])
    if same_query:
        assert responses[0].json()["snapshot"] == responses[1].json()["snapshot"]
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(DiscoverySnapshot)) == 1
        budget = session.get(DiscoveryBudget, 1)
        assert budget.entries == 12 and budget.snapshots == 1
