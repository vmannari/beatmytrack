"""Availability, bounded maintenance and query-shape regressions from DF01-DF07."""
import asyncio
import threading
import time
from dataclasses import replace

import httpx
from sqlalchemy import event, func, select, text, update
from starlette.responses import JSONResponse
from test_attack_resistance import isolated_scope
from test_discovery_v3 import auth_app as auth_app_fixture
from test_discovery_v3 import browse
from test_discovery_v3 import indexed as indexed_fixture

from bmt_backend.config import Settings
from bmt_backend.discovery_models import (
    WINDOW,
    DiscoveryBoundary,
    DiscoveryDriver,
    DiscoveryHead,
    DiscoveryPartition,
)
from bmt_backend.discovery_projection import BATCH, health, step
from bmt_backend.middleware import RequestBoundary
from bmt_backend.track_models import TrackVersion

auth_app = auth_app_fixture
indexed = indexed_fixture


def test_small_and_bulk_queries_share_the_database_capacity(monkeypatch):
    monkeypatch.setattr("bmt_backend.middleware.check_budget",lambda *_args,**_kwargs:True)

    async def exercise():
        ready,release = asyncio.Event(),asyncio.Event()
        live = 0

        async def handler(scope,receive,send):
            nonlocal live
            live += 1
            if live == 2: ready.set()
            try:
                await release.wait()
                await JSONResponse({"ok":True})(scope,receive,send)
            finally:
                live -= 1

        boundary = RequestBoundary(handler,replace(Settings(),database_pool_size=3),None)
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=boundary),base_url="http://test") as client:
            tasks = [asyncio.create_task(client.post("/v1/discovery/v3/tracks",json=body))
                for body in ({"cursor":"fixture"},{"query":{},"padding":"x"*32769})]
            try:
                await asyncio.wait_for(ready.wait(),3)
                denied = await client.post("/v1/discovery/v3/tracks",json={"cursor":"fixture"})
                assert denied.status_code == 503 and denied.json()["detail"] == "DISCOVERY_QUERY_BUSY"
                assert live == 2
            finally:
                release.set()
                assert all(r.status_code==200 for r in await asyncio.gather(*tasks))
            assert (await client.post("/v1/discovery/v3/tracks",json={"cursor":"fixture"})).status_code==200

    asyncio.run(exercise())


def test_unfinished_small_and_bulk_bodies_do_not_own_discovery_query_capacity(indexed):
    d = indexed
    first = browse(d, {"sort": "name"})

    async def exercise():
        reached, release = asyncio.Event(), asyncio.Event()
        arrivals = 0

        async def receive():
            nonlocal arrivals
            arrivals += 1
            if arrivals == 2:
                reached.set()
            await release.wait()
            return {"type": "http.request", "body": b'{"query":{}}', "more_body": False}

        async def send(_message):
            pass

        scopes = [isolated_scope("/v1/discovery/v3/tracks") for _ in range(2)]
        scopes[0]["headers"][-1] = (b"content-length", b"12")
        scopes[1]["headers"][-1] = (b"content-length", b"32769")
        tasks = [asyncio.create_task(d.app(scope, receive, send)) for scope in scopes]
        try:
            await asyncio.wait_for(reached.wait(), 3)
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=d.app, client=("testclient", 50000)), base_url="http://test") as client:
                response = await client.post("/v1/discovery/v3/tracks", json={"cursor": first["page_cursor"]})
            assert response.status_code == 200, response.text
            assert len(response.json()["items"]) == 20
        finally:
            release.set()
            await asyncio.wait_for(asyncio.gather(*tasks), 5)

    asyncio.run(exercise())


def test_one_anonymous_peer_cannot_fill_all_small_body_receivers(indexed, monkeypatch):
    from bmt_backend import middleware
    monkeypatch.setattr(middleware, "DISCOVERY_BODY_STALL_SECONDS", .1)
    d = indexed

    async def exercise():
        reached = asyncio.Event()
        messages = []

        async def receive():
            reached.set()
            await asyncio.Event().wait()

        async def send(message):
            messages.append(message)

        scope = isolated_scope("/v1/discovery/v3/tracks")
        task = asyncio.create_task(d.app(scope, receive, send))
        try:
            await asyncio.wait_for(reached.wait(), 3)
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=d.app,client=("192.0.2.44", 50000)),base_url="http://test") as client:
                denied = await client.post("/v1/discovery/v3/tracks",json={"query":{}})
                assert denied.status_code == 503 and denied.json()["detail"] == "DISCOVERY_UPLOAD_BUSY"
            await asyncio.wait_for(task, 3)
            assert next(m["status"] for m in messages if m["type"] == "http.response.start") == 408
            # Timeout must release both the actor ownership and receiver permit.
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=d.app,client=("192.0.2.44", 50000)),base_url="http://test") as client:
                assert (await client.post("/v1/discovery/v3/tracks",json={"query":{}})).status_code == 200
        finally:
            task.cancel()
            await asyncio.gather(task,return_exceptions=True)

    asyncio.run(exercise())


def test_valid_players_behind_same_nat_have_independent_body_ownership(indexed, sign_in):
    d = indexed
    other = sign_in("Another NAT user")

    async def exercise():
        reached, release = asyncio.Event(), asyncio.Event()

        async def receive():
            reached.set()
            await release.wait()
            return {"type":"http.request", "body":b'{"query":{}}', "more_body":False}

        async def send(_message):
            pass

        scope = isolated_scope("/v1/discovery/v3/tracks",credential="Bearer "+d.token)
        task = asyncio.create_task(d.app(scope,receive,send))
        try:
            await asyncio.wait_for(reached.wait(),3)
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=d.app,client=("192.0.2.44",50000)),base_url="http://test") as client:
                response = await client.post("/v1/discovery/v3/tracks",headers={"Authorization":"Bearer "+other["access_token"]},json={"query":{}})
                assert response.status_code == 200, response.text
        finally:
            release.set()
            await asyncio.wait_for(task,5)

    asyncio.run(exercise())


def test_expensive_initial_and_saved_searches_cannot_exclude_ordinary_pages(indexed, monkeypatch):
    from bmt_backend import discovery_v3
    d = indexed
    ordinary = browse(d, {"sort": "name"})
    searched = browse(d, {"sort": "name", "search": "Circuit"})
    reached, release = threading.Event(), threading.Event()
    original = discovery_v3.page

    def held(*args):
        if args[1].headers.get("x-review-hold") == "1":
            reached.set()
            assert release.wait(5)
        return original(*args)

    monkeypatch.setattr(discovery_v3, "page", held)

    async def exercise():
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=d.app, client=("testclient", 50000)), base_url="http://test") as client:
            task = asyncio.create_task(client.post("/v1/discovery/v3/tracks", headers={"X-Review-Hold": "1"},
                json={"cursor": searched["page_cursor"]}))
            try:
                assert await asyncio.to_thread(reached.wait, 3)
                for body in ({"query": {"search": "Circuit"}}, {"cursor": searched["next_cursor"]}):
                    denied = await client.post("/v1/discovery/v3/tracks", json=body)
                    assert denied.status_code == 503 and denied.json()["detail"] == "DISCOVERY_SEARCH_BUSY"
                normal = await client.post("/v1/discovery/v3/tracks", json={"cursor": ordinary["next_cursor"]})
                assert normal.status_code == 200, normal.text
            finally:
                release.set()
                assert (await task).status_code == 200
            # Every exit releases the gate, including the rejected cursor.
            assert (await client.post("/v1/discovery/v3/tracks", json={"cursor": searched["next_cursor"]})).status_code == 200

    asyncio.run(exercise())


def test_freshness_checks_share_one_statement_and_candidates_use_only_projection(indexed):
    statements = []

    def capture(_connection, _cursor, sql, *_args):
        statements.append(sql)

    event.listen(indexed.app.state.engine, "before_cursor_execute", capture)
    try:
        first = browse(indexed, {"sort": "name"})
        assert sum("discovery_changes.created_at" in sql for sql in statements) == 1
        statements.clear()
        browse(indexed, cursor=first["next_cursor"])
        candidates = [sql for sql in statements if "discovery_entries" in sql and sql.startswith("SELECT")]
        assert len(candidates) == 1
        assert "JOIN tracks" not in candidates[0] and "JOIN players" not in candidates[0]
        assert "discovery_entries.name," not in candidates[0]  # narrow key/revision projection
    finally:
        event.remove(indexed.app.state.engine, "before_cursor_execute", capture)


def test_cleanup_keeps_worker_active_until_expired_boundary_backlog_drains(indexed):
    factory = indexed.app.state.session_factory
    stamp = int(time.time())
    with factory() as db:
        db.execute(update(DiscoveryPartition).values(audit_at=stamp+3600))
        db.execute(DiscoveryBoundary.__table__.insert(), [{"id":f"{index:064x}", "session_id":"retired",
            "expires_at":stamp-60, "positions":{}, "phase":0} for index in range(3*BATCH+5)])
        db.commit()
    assert health(factory)["cleanup_oldest_age_seconds"]["boundaries"] >= 60
    for _ in range(4):
        assert step(factory, clock=stamp), "Maintenance must not be reported as idle work"
    with factory() as db:
        assert db.scalar(select(func.count()).select_from(DiscoveryBoundary)) == 0
    assert not step(factory, clock=stamp)
    assert health(factory)["cleanup_oldest_age_seconds"]["boundaries"] == 0


def test_compact_expiry_index_drains_equal_timestamps_in_bounded_exact_batches(indexed):
    import uuid

    from bmt_backend.identity_models import Player
    d = indexed
    count, stamp = 3*BATCH+7, int(time.time())
    track_id = d.tracks[0]["id"]
    with d.app.state.session_factory() as db:
        db.execute(update(DiscoveryPartition).values(audit_at=stamp+3600))
        shard = db.get(DiscoveryHead,track_id)
        shard.popularity = count
        for index in range(count):
            player_id = str(uuid.uuid4())
            db.add(Player(id=player_id,username_key=f"expiry actor {index}",display_name=f"Expiry actor {index}"))
            db.add(DiscoveryDriver(track_id=track_id,player_id=player_id,partition=shard.partition,
                last_at=stamp-WINDOW-1,expires_at=stamp-1,counted=True))
        db.commit()
    assert max(row["expired_pair_age_seconds"] for row in health(d.app.state.session_factory)["partitions"]) >= 1
    previous = count
    for _ in range(4):
        assert step(d.app.state.session_factory,clock=stamp)
        with d.app.state.session_factory() as db:
            remaining = db.scalar(select(func.count()).select_from(DiscoveryDriver))
            assert 0 < previous-remaining <= BATCH
            assert db.get(DiscoveryHead,track_id).popularity == remaining
            previous = remaining
    assert previous == 0


def test_short_and_punctuation_searches_keep_exact_substring_semantics(indexed):
    from bmt_backend.discovery_projection import settle_for_diagnostics
    d = indexed
    special = "A_B% Straße İ猫😺"
    with d.app.state.session_factory() as db:
        db.execute(update(TrackVersion).where(TrackVersion.id == d.versions[0]["id"]).values(name=special))
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory)
    for term in ("Ci", "i", "_B", "%", "猫", "😺", "İ", "a_b", "e İ", "zz", "___"):
        with d.app.state.session_factory() as db:
            expected = set(db.scalars(select(TrackVersion.id).where(TrackVersion.name.icontains(term, autoescape=True))))
        result = browse(d, {"sort": "name", "search_kind": 1, "search": term})
        actual = {row["version_id"] for row in result["items"]}
        assert actual <= expected and len(actual) == min(20, len(expected)), (term, actual, expected)
    if d.app.state.engine.dialect.name == "postgresql":
        with d.app.state.engine.connect() as db:
            db.execute(text("SET LOCAL enable_seqscan=off"))
            plan = db.execute(text("EXPLAIN SELECT track_id FROM discovery_entries "
                "WHERE discovery_short_grams(name) @> discovery_short_grams('zz')")).all()
            assert "ix_discovery_entry_name_short" in str(plan)
