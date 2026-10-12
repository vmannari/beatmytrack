"""Cheap liveness and fail-closed dependency checks without probe amplification."""
import asyncio
import threading
import time
from dataclasses import replace

import httpx
import pytest
from sqlalchemy import event, text
from sqlalchemy.exc import OperationalError

from bmt_backend.config import Settings
from bmt_backend.migrate import SCHEMA_HEAD
from bmt_backend.readiness import DependencyFailure, ReadinessProbe


def test_coalesced_checks_reuse_ready_and_storage_success(auth_app, monkeypatch):
    clock = [100.0]
    probe = auth_app.state.readiness = ReadinessProbe(auth_app, clock=lambda: clock[0])
    counts = {"schema": 0, "put": 0, "get": 0}
    def sql(_conn, _cursor, statement, _params, _context, _many):
        if statement == "SELECT version_num FROM alembic_version":
            counts["schema"] += 1
    event.listen(auth_app.state.engine, "before_cursor_execute", sql)
    for name in ("put", "get"):
        original = getattr(auth_app.state.blobs, name + "_json")
        def wrapped(*args, _name=name, _original=original):
            counts[_name] += 1
            return _original(*args)
        monkeypatch.setattr(auth_app.state.blobs, name + "_json", wrapped)
    async def exercise():
        replies = await asyncio.gather(*(probe.check() for _ in range(80)))
        assert all(reply == {"status": "ready", "schema": SCHEMA_HEAD} for reply in replies)
        replies[0]["schema"] = "caller-mutated"
        assert (await probe.check())["schema"] == SCHEMA_HEAD
        assert counts == {"schema": 1, "put": 1, "get": 1}
        clock[0] += 3
        await probe.check()
        assert counts == {"schema": 2, "put": 1, "get": 1}
        clock[0] += 31
        await probe.check()
        assert counts == {"schema": 3, "put": 2, "get": 2}
    try:
        asyncio.run(exercise())
    finally:
        event.remove(auth_app.state.engine, "before_cursor_execute", sql)


def test_liveness_does_not_touch_dependencies(auth_app, monkeypatch):
    def forbidden(*args, **kwargs):
        pytest.fail("Liveness accessed a dependency")
    monkeypatch.setattr(auth_app.state.engine, "connect", forbidden)
    monkeypatch.setattr(auth_app.state.blobs, "put_json", forbidden)
    async def exercise():
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=auth_app), base_url="http://test") as client:
            result = await client.get("/healthz")
            assert result.status_code == 200 and result.json() == {"status": "ok"}
    asyncio.run(exercise())


def test_ready_cache_cannot_extend_expired_storage_success(auth_app, monkeypatch):
    clock = [100.0]
    probe = auth_app.state.readiness = ReadinessProbe(auth_app, clock=lambda: clock[0])
    async def exercise():
        await probe.check()
        clock[0] = 129.5
        await probe.check()  # Schema-only refresh just before the storage interval expires.
        def unavailable(value):
            raise OSError("Storage is now unavailable")
        monkeypatch.setattr(auth_app.state.blobs, "put_json", unavailable)
        clock[0] = 130.1
        with pytest.raises(DependencyFailure) as error:
            await probe.check()
        assert error.value.code == "DEPENDENCY_UNAVAILABLE"
    asyncio.run(exercise())


def test_probe_stall_has_bounded_wait_and_one_thread(auth_app, monkeypatch):
    auth_app.state.settings = replace(auth_app.state.settings, readiness_timeout_seconds=1)
    probe = auth_app.state.readiness
    entered, release, exited = threading.Event(), threading.Event(), threading.Event()
    calls = []
    def stuck(storage_needed):
        calls.append(storage_needed)
        entered.set()
        try:
            assert release.wait(5)
            return {"status": "ready", "schema": SCHEMA_HEAD}
        finally:
            exited.set()
    monkeypatch.setattr(probe, "_dependencies", stuck)
    async def exercise():
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=auth_app), base_url="http://test") as client:
            started = time.monotonic()
            tasks = [asyncio.create_task(client.get("/readyz")) for _ in range(40)]
            while not entered.is_set():
                await asyncio.sleep(0.01)
            health = await client.get("/healthz")
            assert health.status_code == 200 and time.monotonic() - started < 0.5
            responses = await asyncio.gather(*tasks)
            assert all(r.status_code == 503 and r.json()["detail"] == "DEPENDENCY_TIMEOUT" for r in responses)
            assert 0.9 <= time.monotonic() - started < 2
            responses = await asyncio.gather(*(client.get("/readyz") for _ in range(40)))
            assert all(r.status_code == 503 for r in responses) and len(calls) == 1
            release.set()
            while probe.pending is not None:
                await asyncio.sleep(0.01)
            # A late result remains unavailable rather than publishing stale success.
            assert (await client.get("/readyz")).status_code == 503
            probe.invalidate(storage=True)
            monkeypatch.setattr(probe, "_dependencies", lambda needed: {"status": "ready", "schema": SCHEMA_HEAD})
            assert (await client.get("/readyz")).status_code == 200
    try:
        asyncio.run(exercise())
    finally:
        release.set()
        assert exited.wait(3)


def test_schema_mismatch_does_not_probe_storage(auth_app, monkeypatch):
    with auth_app.state.engine.begin() as connection:
        connection.execute(text("UPDATE alembic_version SET version_num = 'outdated'"))
    monkeypatch.setattr(auth_app.state.blobs, "put_json", lambda value: pytest.fail("Outdated schema wrote a blob"))
    with pytest.raises(DependencyFailure) as error:
        asyncio.run(auth_app.state.readiness.check())
    assert error.value.code == "SCHEMA_NOT_READY"


@pytest.mark.parametrize("failure", [OSError("private-provider-detail"), ValueError("private-corruption-detail"),
    OperationalError("private-query", {}, Exception("private-credentials"))])
def test_dependency_failures_are_unavailable_and_do_not_leak(auth_app, monkeypatch, failure):
    def fail(value):
        raise failure
    monkeypatch.setattr(auth_app.state.blobs, "put_json", fail)
    async def exercise():
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=auth_app), base_url="http://test") as client:
            result = await client.get("/readyz")
            assert result.status_code == 503 and result.json()["detail"] == "DEPENDENCY_UNAVAILABLE"
            assert "private" not in result.text
    asyncio.run(exercise())


def test_api_storage_failure_invalidates_a_successful_probe(auth_app, monkeypatch):
    failed = [False]
    original = auth_app.state.blobs.put_json
    def store(value):
        if failed[0]:
            raise OSError("private provider failure")
        return original(value)
    monkeypatch.setattr(auth_app.state.blobs, "put_json", store)
    @auth_app.get("/__test/storage-failure")
    def failure():
        return auth_app.state.blobs.put_json({"data": "synthetic"})
    async def exercise():
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=auth_app), base_url="http://test") as client:
            assert (await client.get("/readyz")).status_code == 200
            failed[0] = True
            assert (await client.get("/__test/storage-failure")).status_code == 503
            assert (await client.get("/readyz")).status_code == 503
            failed[0] = False
            auth_app.state.readiness.invalidate(storage=True)
            assert (await client.get("/readyz")).status_code == 200
    asyncio.run(exercise())


def test_invalidation_during_probe_cannot_restore_stale_success(auth_app, monkeypatch):
    probe = auth_app.state.readiness
    entered, release = threading.Event(), threading.Event()
    calls = []
    def dependencies(needed):
        calls.append(needed)
        if len(calls) == 1:
            entered.set()
            assert release.wait(3)
            return {"status": "ready", "schema": SCHEMA_HEAD}
        raise OSError("Current dependency is unavailable")
    monkeypatch.setattr(probe, "_dependencies", dependencies)
    async def exercise():
        request = asyncio.create_task(probe.check())
        while not entered.is_set():
            await asyncio.sleep(0.01)
        probe.invalidate(storage=True)
        release.set()
        with pytest.raises(DependencyFailure) as error:
            await request
        assert error.value.code == "DEPENDENCY_UNAVAILABLE" and calls == [True, True]
    try:
        asyncio.run(exercise())
    finally:
        release.set()


def test_shutdown_invalidates_probe_and_reopen_refreshes_dependencies(auth_app):
    probe = auth_app.state.readiness
    async def exercise():
        await probe.check()
        await probe.close()
        with pytest.raises(DependencyFailure):
            await probe.check()
        probe.open()
        assert (await probe.check())["schema"] == SCHEMA_HEAD
    asyncio.run(exercise())


def test_repeated_invalidation_does_not_extend_request_deadline(auth_app, monkeypatch):
    auth_app.state.settings = replace(auth_app.state.settings, readiness_timeout_seconds=1)
    probe = auth_app.state.readiness
    calls = []
    def invalidated(needed):
        calls.append(needed)
        time.sleep(0.04)
        probe.invalidate(storage=True)
        return {"status": "ready", "schema": SCHEMA_HEAD}
    monkeypatch.setattr(probe, "_dependencies", invalidated)
    async def exercise():
        started = time.monotonic()
        with pytest.raises(DependencyFailure) as error:
            await probe.check()
        assert error.value.code == "DEPENDENCY_TIMEOUT"
        assert 0.9 <= time.monotonic() - started < 2 and len(calls) > 1
        await probe.close()
    asyncio.run(exercise())


@pytest.mark.parametrize("field,value", [("readiness_timeout_seconds", 0), ("readiness_timeout_seconds", 6),
    ("readiness_cache_seconds", 6), ("readiness_storage_cache_seconds", 61)])
def test_readiness_configuration_is_bounded(field, value):
    with pytest.raises(ValueError):
        Settings(**{field: value})
