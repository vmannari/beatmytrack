"""Bounded HTTP admission and exact queue enforcement without backlog counts."""
import asyncio
from dataclasses import replace

import httpx
import pytest
from sqlalchemy import event, select
from starlette.responses import JSONResponse
from test_domains import domain as domain_fixture
from test_domains import headers, public_course, ticket
from test_queue_capacity_slots import pending

from bmt_backend.config import Settings
from bmt_backend.middleware import RequestBoundary
from bmt_backend.queueing import admit, check_capacity
from bmt_backend.track_models import QueueCapacity, QueueReservation, Run, new_id

domain = domain_fixture


@pytest.mark.parametrize("pool,requested,allowed", [(4, 4, 3), (4, 2, 2), (1, 4, 1)])
def test_telemetry_concurrency_is_bounded_and_preserves_race_slots(monkeypatch,
                                                                pool, requested, allowed):
    monkeypatch.setattr("bmt_backend.middleware.check_budget", lambda *_a, **_k: True)

    async def exercise():
        release, ready, race_ready = asyncio.Event(), asyncio.Event(), asyncio.Event()
        live = {"telemetry": 0, "races": 0}

        async def handler(scope, receive, send):
            kind = "telemetry" if scope["path"] == "/v1/telemetry/batches" else "races"
            live[kind] += 1
            if live["telemetry"] == allowed:
                ready.set()
            if live["races"] == 2:
                race_ready.set()
            try:
                await release.wait()
                await JSONResponse({"ok": True})(scope, receive, send)
            finally:
                live[kind] -= 1

        settings = Settings(database_pool_size=pool,
                           telemetry_http_concurrency=requested, upload_concurrency=2)
        boundary = RequestBoundary(handler, settings, None)
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=boundary), base_url="http://test") as client:
            active = [asyncio.create_task(client.post("/v1/telemetry/batches", json={}))
                      for _ in range(allowed)]
            races = []
            try:
                await asyncio.wait_for(ready.wait(), 2)
                races = [asyncio.create_task(client.post("/v1/runs", json={})) for _ in range(2)]
                await asyncio.wait_for(race_ready.wait(), 2)
                busy = await client.post("/v1/telemetry/batches", json={})
                assert busy.status_code == 503
                assert busy.json()["detail"] == "REQUEST_VALIDATION_BUSY"
                assert live == {"telemetry": allowed, "races": 2}
            finally:
                release.set()
                completed = await asyncio.gather(*active, *races)
            assert all(response.status_code == 200 for response in completed)
            assert boundary.telemetry_parsers._value == allowed
            assert boundary.parsers._value == 2

    asyncio.run(exercise())


def test_queue_preflight_and_admission_do_not_count_the_backlog(domain):
    _version, board = public_course(domain)
    with domain.factory() as session:
        for _ in range(8):
            admit(session, domain.players["Alice"], 128)
            pending(session, domain, board)
        session.commit()
    statements = []

    def capture(_conn, _cursor, statement, _parameters, _context, _many):
        statements.append(statement.lower())

    event.listen(domain.app.state.engine, "before_cursor_execute", capture)
    try:
        with domain.factory() as session:
            check_capacity(session, domain.players["Bob"], 128)
            admit(session, domain.players["Bob"], 128)
            pending(session, domain, board, owner="Bob")
            session.commit()
    finally:
        event.remove(domain.app.state.engine, "before_cursor_execute", capture)
    assert not any("queue_capacity" in query for query in statements)
    assert not any("count(" in query and "queue_reservations" in query for query in statements)
    with domain.factory() as session:
        assert session.scalar(select(QueueCapacity.pending)) == 9


def test_committed_full_queue_returns_429_and_saved_retry_recovers(domain):
    version, board = public_course(domain)
    domain.app.state.settings = replace(domain.app.state.settings, max_queued_runs=1)
    issued = ticket(domain, version, "Bob")
    with domain.factory() as session:
        admit(session, domain.players["Alice"], 1)
        occupied = pending(session, domain, board)
        occupied_id = occupied.id
        session.commit()
    key = new_id()
    body = {"ticket_id": issued["ticket_id"],
            "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]] * 20}}
    response = domain.client.post("/v1/runs", json=body, headers=headers(domain, "Bob", key))
    assert response.status_code == 429, response.text
    with domain.factory() as session:
        assert session.scalar(select(QueueCapacity.pending)) == 1
        session.get(Run, occupied_id).status = "failed"
        session.commit()
    accepted = domain.client.post("/v1/runs", json=body, headers=headers(domain, "Bob", key))
    assert accepted.status_code == 202, accepted.text
    repeated = domain.client.post("/v1/runs", json=body, headers=headers(domain, "Bob", key))
    assert repeated.json() == accepted.json()


@pytest.mark.parametrize("occupied", [64, 128])
def test_bounded_queue_probe_suppresses_external_writes_and_retries_a_missed_vacancy(domain, monkeypatch,
                                                                                  occupied):
    version, _board = public_course(domain)
    issued = ticket(domain, version, "Bob")
    with domain.factory() as session:
        session.add_all([QueueReservation(kind="probe", job_id=new_id(), player_id=domain.players["Alice"],
                                         slot=index) for index in range(occupied)])
        session.commit()
    writes = []
    original = domain.app.state.blobs.put_json

    def record(value):
        writes.append(value)
        return original(value)

    monkeypatch.setattr(domain.app.state.blobs, "put_json", record)
    monkeypatch.setattr("bmt_backend.queueing.sample", lambda _domain, size: list(range(size)))
    key = new_id()
    body = {"ticket_id": issued["ticket_id"],
            "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]] * 20}}
    response = domain.client.post("/v1/runs", json=body, headers=headers(domain, "Bob", key))
    assert response.status_code == 503 and response.json()["detail"] == "VERIFICATION_CAPACITY_BUSY"
    assert response.headers["retry-after"] == "1" and writes == []
    with domain.factory() as session:
        assert session.scalar(select(QueueCapacity.pending)) == occupied  # Hint cannot reserve anything.
        if occupied == 128:
            session.delete(session.scalar(select(QueueReservation).where(QueueReservation.slot == 64)))
            session.commit()
    monkeypatch.setattr("bmt_backend.queueing.sample", lambda _domain, size: list(range(64, 64 + size)))
    accepted = domain.client.post("/v1/runs", json=body, headers=headers(domain, "Bob", key))
    assert accepted.status_code == 202, accepted.text
    assert len(writes) == 1
    repeated = domain.client.post("/v1/runs", json=body, headers=headers(domain, "Bob", key))
    assert repeated.json() == accepted.json() and len(writes) == 1


@pytest.mark.parametrize("value", [0, -1, 17, True])
def test_telemetry_http_setting_has_a_fixed_tree_limit(value):
    with pytest.raises(ValueError):
        Settings(telemetry_http_concurrency=value)


@pytest.mark.parametrize("settings", [
    {"studio_analysis_database_url": "sqlite://"},
    {"studio_analysis_statement_timeout_ms": 99},
    {"studio_analysis_statement_timeout_ms": 30001},
])
def test_studio_analysis_settings_require_bounded_replica_reads(settings):
    with pytest.raises(ValueError):
        Settings(**settings)
