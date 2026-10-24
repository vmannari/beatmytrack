"""Shared work budgets, account contention, storage and anonymous network abuse."""
import asyncio
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from types import SimpleNamespace

import httpx
import pytest
from alembic import command
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import func, select, text, update
from test_attack_resistance import isolated_scope
from test_discovery_v3 import auth_app as auth_app_fixture
from test_discovery_v3 import browse
from test_discovery_v3 import indexed as indexed_fixture

from bmt_backend import discovery_guard as guard
from bmt_backend import discovery_retention as retention
from bmt_backend import discovery_v3
from bmt_backend.app import create_app
from bmt_backend.client_address import anonymous_network
from bmt_backend.discovery_erasure import erase_private
from bmt_backend.discovery_models import (
    DiscoveryCollection,
    DiscoveryGuard,
    DiscoveryMember,
    DiscoverySession,
    DiscoveryStorage,
    DiscoveryStorageBootstrap,
)
from bmt_backend.discovery_projection import cleanup
from bmt_backend.identity_models import Player
from bmt_backend.middleware import RequestBoundary
from bmt_backend.migrate import configuration

auth_app = auth_app_fixture
indexed = indexed_fixture
ENDPOINT = "/v1/discovery/v3/tracks"


def totals(d):
    with d.app.state.session_factory() as db:
        return (db.scalar(select(func.count()).select_from(DiscoveryMember)),
                db.scalar(select(func.coalesce(func.sum(DiscoveryStorage.member_rows), 0))),
                db.scalar(select(func.coalesce(func.sum(DiscoveryStorage.member_bytes), 0))))


def test_timeout_cooldown_is_shared_and_preserves_cheap_browsing(indexed, monkeypatch):
    d = indexed
    ordinary = browse(d, {"sort": "name"})
    searched = browse(d, {"search": "Circuit", "sort": "name"})
    original, entered = discovery_v3.page, []

    def fail(*args):
        if args[2].query["search"]:
            entered.append(True)
            raise HTTPException(503, "DISCOVERY_QUERY_BUDGET", headers={"Retry-After": "1"})
        return original(*args)

    monkeypatch.setattr(discovery_v3, "page", fail)
    response = d.client.post(ENDPOINT, json={"cursor": searched["page_cursor"]})
    assert response.status_code == 503 and response.headers["retry-after"] == "2"
    for body in ({"cursor": searched["page_cursor"]}, {"query": {"search": "rotated"}}):
        response = d.client.post(ENDPOINT, json=body)
        assert response.status_code == 503 and response.json()["detail"] == "DISCOVERY_RETRY_COOLDOWN"
    random = d.client.post("/v1/discovery/v3/random", json={"cursor": searched["page_cursor"], "exclude": "rotated"})
    assert random.status_code == 503 and random.json()["detail"] == "DISCOVERY_RETRY_COOLDOWN"
    replica = create_app(d.app.state.settings, engine=d.app.state.engine)
    with TestClient(replica) as client:
        response = client.post(ENDPOINT, json={"cursor": searched["page_cursor"]})
        assert response.status_code == 503 and response.json()["detail"] == "DISCOVERY_RETRY_COOLDOWN"
    assert len(entered) == 1
    assert d.client.post(ENDPOINT, json={"cursor": ordinary["next_cursor"]}).status_code == 200


def test_heavy_credit_exhaustion_does_not_spend_light_allowance(indexed):
    d = indexed
    ordinary = browse(d, {"sort": "name"})
    d.app.state.settings = replace(d.app.state.settings, discovery_expensive_units_per_minute=60)
    assert d.client.post(ENDPOINT, json={"query": {"minimum_rating": 5}}).status_code == 200
    response = d.client.post(ENDPOINT, json={"query": {"minimum_rating": 4}})
    assert response.status_code == 429 and response.json()["detail"] == "DISCOVERY_WORK_LIMIT"
    assert d.client.post(ENDPOINT, json={"cursor": ordinary["next_cursor"]}).status_code == 200


def test_duplicate_heavy_work_on_another_replica_fails_fast(indexed, monkeypatch):
    d = indexed
    searched = browse(d, {"search": "Circuit", "sort": "name"})
    entered, release = threading.Event(), threading.Event()
    original = discovery_v3.page
    calls = []

    def held(*args):
        calls.append(True)
        entered.set()
        assert release.wait(5)
        return original(*args)

    monkeypatch.setattr(discovery_v3, "page", held)
    replica = create_app(d.app.state.settings, engine=d.app.state.engine)
    with TestClient(replica) as other, ThreadPoolExecutor(max_workers=1) as pool:
        future = pool.submit(d.client.post, ENDPOINT, json={"cursor": searched["page_cursor"]})
        try:
            assert entered.wait(3)
            response = other.post(ENDPOINT, json={"cursor": searched["page_cursor"]})
            assert response.status_code == 503 and response.json()["detail"] == "DISCOVERY_QUERY_BUSY"
            assert len(calls) == 1
        finally:
            release.set()
        assert future.result(5).status_code == 200


def test_non_text_filters_use_the_expensive_gate(indexed, monkeypatch):
    d = indexed
    searched = browse(d, {"search": "Circuit"})
    entered, release = threading.Event(), threading.Event()
    original = discovery_v3.page

    def held(*args):
        entered.set()
        assert release.wait(5)
        return original(*args)

    monkeypatch.setattr(discovery_v3, "page", held)
    with ThreadPoolExecutor(max_workers=1) as pool:
        pending = pool.submit(d.client.post, ENDPOINT, json={"cursor": searched["page_cursor"]})
        try:
            assert entered.wait(3)
            for query in ({"minimum_rating": 5}, {"race_history": "unraced"}, {"theme": "pine"}):
                response = d.client.post(ENDPOINT, json={"query": query})
                assert response.status_code == 503 and response.json()["detail"] == "DISCOVERY_SEARCH_BUSY"
        finally:
            release.set()
        assert pending.result(5).status_code == 200


def test_replaced_lease_cannot_commit_or_release_new_owner(indexed):
    d = indexed
    actor = discovery_v3.digest("lease-review")
    with d.app.state.session_factory() as first:
        old = guard.claim(first, actor, d.app.state.settings, "heavy")
        with d.app.state.session_factory() as db:
            db.execute(update(DiscoveryGuard).where(DiscoveryGuard.id == old.key).values(lease_until=0))
            db.commit()
        with d.app.state.session_factory() as second:
            new = guard.claim(second, actor, d.app.state.settings, "heavy")
            first.add(DiscoverySession(id=str(uuid.uuid4()), scope=actor, created_at=1, expires_at=2,
                secret="a"*64, query={}, epochs=[], slots=[]))
            with pytest.raises(HTTPException, match="DISCOVERY_LEASE_EXPIRED"):
                first.commit()
            first.rollback()
            first.info.pop("discovery_tickets")
            guard.finish(d.app.state.session_factory, [old])
            with d.app.state.session_factory() as db:
                assert db.get(DiscoveryGuard, new.key).lease_token == new.token
                assert db.scalar(select(DiscoverySession.id).where(DiscoverySession.scope == actor)) is None
            second.info.pop("discovery_tickets")
            second.rollback()
            guard.finish(d.app.state.session_factory, [new])


def test_a_slow_replica_cannot_reset_a_newer_credit_window(indexed, monkeypatch):
    d = indexed
    stamp = [100000.0]
    monkeypatch.setattr(guard, "time", SimpleNamespace(time=lambda: stamp[0], monotonic=time.monotonic))
    settings = replace(d.app.state.settings, discovery_expensive_units_per_minute=60)
    actor = discovery_v3.digest("regressing-clock-review")
    with d.app.state.session_factory() as db:
        ticket = guard.claim(db, actor, settings, "heavy")
        db.info.pop("discovery_tickets")
        db.rollback()
    guard.finish(d.app.state.session_factory, [ticket])
    stamp[0] -= 60
    with d.app.state.session_factory() as db, pytest.raises(HTTPException, match="DISCOVERY_WORK_LIMIT"):
        guard.claim(db, actor, settings, "heavy")


def test_anonymous_unknown_ids_do_not_create_retained_members(indexed):
    d = indexed
    before = totals(d)
    unknown = [str(uuid.uuid5(uuid.NAMESPACE_URL, f"resource-unknown-{i}")) for i in range(2000)]
    result = browse(d, {"section": "favorites", "ids": unknown, "raced_ids": unknown})
    assert result["items"] == [] and totals(d) == before
    with d.app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(DiscoveryCollection)) == 0


def test_retention_keeps_only_captured_typed_ids_and_ignores_unused_history(indexed):
    d = indexed
    first, second = [row["id"] for row in d.tracks[:2]]
    result = browse(d, {"section": "favorites", "ids": [first, second, "unknown"],
        "race_history": "raced", "raced_ids": [second, "unknown"]})
    assert [row["track_id"] for row in result["items"]] == [second]
    assert totals(d) == (3, 3, retention.weight("favorite", first)+retention.weight("favorite", second)+retention.weight("raced", second))
    browse(d, {"raced_ids": [row["id"] for row in d.tracks]})
    assert totals(d)[0] == 3


def test_outstanding_actor_rows_include_expired_rows_until_removed(indexed):
    d = indexed
    d.app.state.settings = replace(d.app.state.settings, discovery_actor_member_rows=3)
    ids = [row["id"] for row in d.tracks[:5]]
    browse(d, {"section": "favorites", "ids": ids[:3]})
    with d.app.state.session_factory() as db:
        db.execute(update(DiscoveryCollection).values(expires_at=1))
        db.commit()
    denied = d.client.post(ENDPOINT, json={"query": {"section": "favorites", "ids": ids[3:]}})
    assert denied.status_code == 429 and denied.json()["detail"] == "DISCOVERY_STORAGE_LIMIT"
    assert totals(d)[0:2] == (3, 3)
    with d.app.state.session_factory() as db:
        cleanup(db, int(time.time()))
        db.commit()
        cleanup(db, int(time.time()))
        db.commit()
    assert totals(d) == (0, 0, 0)
    browse(d, {"section": "favorites", "ids": ids[3:]})
    assert totals(d)[0:2] == (2, 2)


def test_storage_bytes_and_service_stripe_limits_are_independent(indexed):
    d = indexed
    first, second = [row["id"] for row in d.tracks[:2]]
    d.app.state.settings = replace(d.app.state.settings, discovery_actor_member_bytes=retention.weight("favorite", first))
    browse(d, {"section": "favorites", "ids": [first]})
    denied = d.client.post(ENDPOINT, json={"query": {"section": "favorites", "ids": [second]}})
    assert denied.status_code == 429 and denied.json()["detail"] == "DISCOVERY_STORAGE_LIMIT"
    assert totals(d)[0:2] == (1, 1)


def test_failed_collection_transaction_refunds_service_capacity(indexed, monkeypatch):
    d = indexed

    def fail(*_args):
        raise HTTPException(422, "resource rollback fixture")

    monkeypatch.setattr(discovery_v3, "page", fail)
    response = d.client.post(ENDPOINT, json={"query": {"section": "favorites", "ids": [d.tracks[0]["id"]]}})
    assert response.status_code == 422 and totals(d) == (0, 0, 0)
    with d.app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(DiscoveryCollection)) == 0


def test_legacy_accounting_resumes_after_rollback_and_partial_expiry(indexed):
    d = indexed
    actor = discovery_v3.digest("legacy-resource-review")
    identity = "f"*64
    with d.app.state.session_factory() as db:
        db.add(DiscoveryCollection(id=identity, scope=actor, expires_at=1, accounted=False))
        db.execute(update(DiscoveryStorageBootstrap).values(ready=False))
        db.flush()
        db.execute(DiscoveryMember.__table__.insert(), [{"collection_id": identity, "kind": "favorite",
            "track_id": f"legacy-{i:04}"} for i in range(600)])
        db.commit()
        assert retention.backfill(db, 128) == 128
        db.rollback()
    assert totals(d) == (600, 0, 0)
    with d.app.state.session_factory() as db:
        assert retention.backfill(db, 128) == 128
        db.commit()
        assert cleanup(db, int(time.time())) >= 512
        db.commit()
        for _ in range(5):
            retention.backfill(db, 128)
            cleanup(db, int(time.time()))
            db.commit()
        assert db.get(DiscoveryStorageBootstrap, 1).ready
    assert totals(d) == (0, 0, 0)


def test_erasure_releases_capacity_and_private_guard_rows(indexed):
    d = indexed
    headers = {"Authorization": "Bearer " + d.token}
    response = d.client.post(ENDPOINT, json={"query": {"section": "favorites", "ids": [d.tracks[0]["id"]]}}, headers=headers)
    assert response.status_code == 200 and totals(d)[0] == 1
    actor = discovery_v3.digest("player:" + d.owner)
    with d.app.state.session_factory() as db:
        db.execute(update(Player).where(Player.id == d.owner).values(disabled=True, deleted_at=int(time.time())))
        db.commit()
        for _ in range(30):
            done = erase_private(db, d.owner, limit=20)
            db.commit()
            if done:
                break
        assert done
        assert db.scalar(select(DiscoveryGuard.id).where(DiscoveryGuard.scope == actor)) is None
    assert totals(d) == (0, 0, 0)


def test_ipv6_network_create_budget_preserves_account_and_cursor_scope(indexed):
    d = indexed
    d.app.state.settings = replace(d.app.state.settings, discovery_network_creates_per_minute=1)

    async def exercise():
        clients = [httpx.AsyncClient(transport=httpx.ASGITransport(app=d.app, client=(ip, 4000)), base_url="http://test")
            for ip in ("2001:db8:1234:5678::1", "2001:db8:1234:5678::2")]
        async with clients[0] as first, clients[1] as second:
            result = await first.post(ENDPOINT, json={"query": {"sort": "name"}})
            assert result.status_code == 200
            denied = await second.post(ENDPOINT, json={"query": {"sort": "name"}})
            assert denied.status_code == 429 and denied.json()["detail"] == "DISCOVERY_NETWORK_LIMIT"
            cursor = await second.post(ENDPOINT, json={"cursor": result.json()["page_cursor"]})
            assert cursor.status_code == 422 and cursor.json()["detail"] == "INVALID_CURSOR"
            signed = await second.post(ENDPOINT, json={"query": {"sort": "name"}}, headers={"Authorization": "Bearer " + d.token})
            assert signed.status_code == 200, signed.text

    asyncio.run(exercise())
    assert anonymous_network("::ffff:192.0.2.1") == "192.0.2.1/32"


def test_anonymous_network_burst_does_not_trust_headers_or_invalid_credentials(indexed, monkeypatch):
    from bmt_backend import middleware
    stamp = time.time()
    monkeypatch.setattr(middleware, "time", SimpleNamespace(time=lambda: stamp, monotonic=time.monotonic))
    d = indexed
    app = create_app(replace(d.app.state.settings, discovery_network_burst=1), engine=d.app.state.engine)

    async def exercise():
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app, client=("2001:db8:abcd::1", 4000)), base_url="http://test") as client:
            first = await client.post(ENDPOINT, json={"query": {}})
            assert first.status_code == 200
            denied = await client.post(ENDPOINT, json={"query": {}}, headers={"X-Forwarded-For": "192.0.2.99", "Authorization": "Bearer " + "x"*64})
            assert denied.status_code == 429 and denied.json()["detail"] == "DISCOVERY_NETWORK_LIMIT"
            signed = await client.post(ENDPOINT, json={"query": {}}, headers={"Authorization": "Bearer " + d.token})
            assert signed.status_code == 200

    asyncio.run(exercise())


@pytest.mark.parametrize("shared_prefix", [True, False])
def test_anonymous_receiver_caps_leave_capacity_for_signed_in_players(indexed, shared_prefix):
    d = indexed

    async def exercise():
        release = asyncio.Event()
        entered = []
        tasks = []
        limit = 2 if shared_prefix else 4
        peers = ([f"2001:db8:1234:5678::{i+1}" for i in range(limit+1)] if shared_prefix
                 else [f"2001:db8:{i+1}::1" for i in range(limit+1)])

        async def receive():
            entered.append(True)
            await release.wait()
            return {"type": "http.request", "body": b'{"query":{}}', "more_body": False}

        async def send(_message):
            pass

        try:
            for peer in peers[:limit]:
                scope = isolated_scope(ENDPOINT)
                scope["client"] = (peer, 4000)
                scope["headers"] = [(b"content-type", b"application/json"), (b"content-length", b"12")]
                tasks.append(asyncio.create_task(d.app(scope, receive, send)))
                deadline = time.monotonic()+2
                while len(entered) < len(tasks) and time.monotonic() < deadline:
                    await asyncio.sleep(.005)
                assert len(entered) == len(tasks)
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=d.app, client=(peers[-1], 4000)), base_url="http://test") as client:
                denied = await client.post(ENDPOINT, json={"query": {}})
                assert denied.status_code == 503 and denied.json()["detail"] == "DISCOVERY_UPLOAD_BUSY"
                signed = await client.post(ENDPOINT, json={"query": {}}, headers={"Authorization": "Bearer " + d.token})
                assert signed.status_code == 200, signed.text
        finally:
            release.set()
            await asyncio.gather(*tasks, return_exceptions=True)
        boundary = d.app.middleware_stack
        while not isinstance(boundary, RequestBoundary):
            boundary = boundary.app
        assert boundary.discovery_anonymous_receiving == 0 and boundary.discovery_network_receivers == {}

    asyncio.run(exercise())


def test_service_stripes_reject_overflow_without_global_counter_contention(indexed):
    d = indexed
    d.app.state.settings = replace(d.app.state.settings, discovery_storage_member_rows=16)
    own_part = int(discovery_v3.digest("peer:testclient")[:2], 16) % 16
    same, different = None, None
    for i in range(1, 255):
        peer = "192.0.2." + str(i)
        part = int(discovery_v3.digest("peer:"+peer)[:2], 16) % 16
        if part == own_part:
            same = peer
        else:
            different = peer
        if same and different:
            break
    body = {"query": {"section": "favorites", "ids": [d.tracks[0]["id"]]}}
    assert d.client.post(ENDPOINT, json=body).status_code == 200

    async def exercise():
        responses = []
        for peer in (same, different):
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=d.app, client=(peer, 4000)), base_url="http://test") as client:
                responses.append(await client.post(ENDPOINT, json=body))
        assert responses[0].status_code == 429 and responses[0].json()["detail"] == "DISCOVERY_STORAGE_LIMIT"
        assert responses[1].status_code == 200

    asyncio.run(exercise())
    assert totals(d)[0:2] == (2, 2)


def test_new_personal_writes_wait_for_legacy_accounting(indexed):
    d = indexed
    with d.app.state.session_factory() as db:
        db.execute(update(DiscoveryStorageBootstrap).values(ready=False))
        db.commit()
    body = {"query": {"section": "favorites", "ids": [d.tracks[0]["id"]]}}
    response = d.client.post(ENDPOINT, json=body)
    assert response.status_code == 503 and response.json()["detail"] == "DISCOVERY_STORAGE_PREPARING"
    assert totals(d) == (0, 0, 0)
    with d.app.state.session_factory() as db:
        assert retention.backfill(db) == 1
        db.commit()
    assert d.client.post(ENDPOINT, json=body).status_code == 200
    assert totals(d)[0:2] == (1, 1)


def test_migration_preserves_legacy_members_and_accounts_them_incrementally(indexed):
    d = indexed
    engine = d.app.state.engine
    command.downgrade(configuration(engine), "0056_bounded_retention")
    legacy_id = "e"*64
    actor = discovery_v3.digest("legacy-migration-review")
    members = [("favorite", "legacy-Ä"), ("favorite", "legacy-雪"), ("raced", "old-local-id")]
    with engine.begin() as db:
        db.execute(text("INSERT INTO discovery_collections(id,scope,expires_at) VALUES(:id,:scope,:expiry)"),
            {"id": legacy_id, "scope": actor, "expiry": int(time.time())+3600})
        db.execute(text("INSERT INTO discovery_members(collection_id,kind,track_id) VALUES(:id,:kind,:track)"),
            [{"id": legacy_id, "kind": kind, "track": value} for kind, value in members])
    command.upgrade(configuration(engine), "head")
    with d.app.state.session_factory() as db:
        collection = db.get(DiscoveryCollection, legacy_id)
        assert collection.scope == actor and not collection.accounted and collection.member_rows == 0
        assert not db.get(DiscoveryStorageBootstrap, 1).ready
        for _ in range(5):
            retention.backfill(db, 1)
            db.commit()
        assert db.get(DiscoveryStorageBootstrap, 1).ready
        assert db.get(DiscoveryCollection, legacy_id).accounted
        retained = set(db.execute(select(DiscoveryMember.kind, DiscoveryMember.track_id)
            .where(DiscoveryMember.collection_id == legacy_id)))
        assert retained == set(members)
    assert totals(d) == (3, 3, sum(retention.weight(*row) for row in members))


def test_sqlite_deadline_survives_budget_commits_and_does_not_leak(indexed, monkeypatch):
    d = indexed
    if d.app.state.engine.dialect.name != "sqlite":
        pytest.skip("SQLite progress-handler lifecycle")
    monkeypatch.setattr(discovery_v3, "QUERY_SECONDS", .01)
    with d.app.state.session_factory() as db, pytest.raises(HTTPException, match="DISCOVERY_QUERY_BUDGET"), discovery_v3.query_budget(db):
        db.commit()
        db.execute(text("WITH RECURSIVE n(x) AS (SELECT 0 UNION ALL SELECT x+1 FROM n WHERE x<10000000) SELECT sum(x) FROM n"))
    with d.app.state.session_factory() as db:
        assert db.scalar(text("SELECT 1")) == 1


def test_sqlite_short_lock_timeout_is_restored_before_pool_reuse(indexed):
    d = indexed
    if d.app.state.engine.dialect.name != "sqlite":
        pytest.skip("SQLite connection-local busy timeout")
    with d.app.state.session_factory() as db:
        previous = db.scalar(text("PRAGMA busy_timeout"))
        with guard.short_locks(db):
            assert db.scalar(text("PRAGMA busy_timeout")) == 50
            db.commit()
            with d.app.state.engine.connect() as connection:
                assert connection.scalar(text("PRAGMA busy_timeout")) == previous
        assert db.scalar(text("PRAGMA busy_timeout")) == previous


def test_discovery_owner_lock_cannot_fill_the_other_players_pool(indexed, sign_in):
    d = indexed
    if d.app.state.engine.dialect.name != "postgresql":
        pytest.skip("PostgreSQL NOWAIT and row-lock contention")
    other = sign_in("Independent driver")
    own = {"Authorization": "Bearer " + d.token}
    theirs = {"Authorization": "Bearer " + other["access_token"]}
    assert d.client.get("/v1/me", headers=own).status_code == 200
    assert d.client.get("/v1/me", headers=theirs).status_code == 200
    with d.app.state.session_factory() as holder, ThreadPoolExecutor(max_workers=3) as pool:
        holder.scalar(select(Player.id).where(Player.id == d.owner).with_for_update())
        started = time.monotonic()
        requests = [pool.submit(d.client.post, ENDPOINT, json={"query": {}}, headers=own) for _ in range(3)]
        replies = [future.result(1.25) for future in requests]
        assert all(r.status_code == 503 and r.json()["detail"] == "DISCOVERY_ACCOUNT_BUSY" for r in replies)
        assert d.client.get("/v1/me", headers=theirs).status_code == 200
        assert time.monotonic()-started < 1.25


def test_removed_account_still_wins_over_a_released_guard(indexed, monkeypatch):
    d = indexed
    marker = str(uuid.uuid4())

    def remove(db, *_args):
        db.rollback()
        with d.app.state.session_factory() as other:
            other.execute(update(Player).where(Player.id == d.owner).values(disabled=True, deleted_at=int(time.time())))
            other.commit()
        db.add(DiscoverySession(id=marker, scope="resurrection", created_at=1, expires_at=2,
            secret="a"*64, query={}, epochs=[], slots=[]))
        db.commit()
        raise AssertionError("Removed actor committed private state")

    monkeypatch.setattr(discovery_v3, "page", remove)
    response = d.client.post(ENDPOINT, json={"query": {}}, headers={"Authorization": "Bearer " + d.token})
    assert response.status_code == 401
    with d.app.state.session_factory() as db:
        assert db.get(DiscoverySession, marker) is None
