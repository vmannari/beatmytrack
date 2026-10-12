"""Operational cost controls without changing scoring or liveness contracts."""
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace

import pytest
from sqlalchemy import event, select
from test_domains import domain as domain_fixture
from test_domains import headers, public_course, race, upload

from bmt_backend import operations
from bmt_backend.histogram_snapshots import refresh_all_for_diagnostics
from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.runs import board_manifest
from bmt_backend.track_models import Board, HistogramSnapshot, OperationState, Run, TrackVersion, digest
from bmt_backend.worker_lifecycle import WorkerControl

domain = domain_fixture


def second_course(domain):
    version = upload(domain, "Bob", document={"shape":"second"})
    race(domain, version, "Bob", frames=60)
    response = domain.client.post(f"/v1/track-versions/{version['version_id']}/publish", headers=headers(domain,"Bob"))
    assert response.status_code == 200, response.text
    return version


def watch(engine):
    statements = []
    def record(_conn, _cursor, statement, *_):
        statements.append(statement)
    event.listen(engine, "before_cursor_execute", record)
    return statements, record


def test_routine_heartbeats_coalesce_but_keep_latest_diagnostics(auth_app, monkeypatch):
    clock = [0.0]
    monkeypatch.setattr(operations.time, "monotonic", lambda: clock[0])
    statements, callback = watch(auth_app.state.engine)
    try:
        operations.heartbeat(auth_app, "probe", phase="claiming", build={"version":1}, coalesce=True)
        initial = len(statements)
        for job in range(100):
            operations.heartbeat(auth_app, "probe", phase="verifying", last_queue_wait_seconds=job, coalesce=True)
            operations.heartbeat(auth_app, "probe", phase="idle", last_verification_seconds=0.002, coalesce=True)
        assert len(statements) == initial
        clock[0] = 1.1
        operations.heartbeat(auth_app, "probe", phase="claiming", build={"version":1}, coalesce=True)
        assert len(statements) == initial*2
        with auth_app.state.session_factory() as session:
            saved = session.get(OperationState, "worker:probe")
            assert saved.details["last_queue_wait_seconds"] == 99
            assert saved.details["last_verification_seconds"] == 0.002
        # A build change cannot wait for the normal heartbeat interval.
        operations.heartbeat(auth_app, "probe", build={"version":2}, coalesce=True)
        with auth_app.state.session_factory() as session:
            assert session.get(OperationState, "worker:probe").details["build"] == {"version":2}
    finally:
        event.remove(auth_app.state.engine, "before_cursor_execute", callback)


def test_stop_and_drain_flush_pending_data_immediately(auth_app, monkeypatch):
    monkeypatch.setattr(operations.time, "monotonic", lambda: 0.0)
    operations.heartbeat(auth_app, "probe", build={"version":1}, coalesce=True)
    operations.heartbeat(auth_app, "probe", last_queue_wait_seconds=10, coalesce=True)
    auth_app.state.worker_control = WorkerControl()
    auth_app.state.worker_control.request_stop()
    operations.heartbeat(auth_app, "probe", phase="idle", coalesce=True)
    with auth_app.state.session_factory() as session:
        row = session.get(OperationState, "worker:probe")
        assert row.details["lifecycle"] == "draining" and row.details["last_queue_wait_seconds"] == 10
    operations.heartbeat(auth_app, "probe", lifecycle="stopped")
    operations.heartbeat(auth_app, "probe", lifecycle="running", coalesce=True)
    with auth_app.state.session_factory() as session:
        assert session.get(OperationState, "worker:probe").details["lifecycle"] == "stopped"


def test_failed_heartbeat_flush_retains_pending_diagnostics(auth_app, monkeypatch):
    clock = [0.0]
    monkeypatch.setattr(operations.time, "monotonic", lambda: clock[0])
    operations.heartbeat(auth_app, "probe", build={"version":1}, coalesce=True)
    operations.heartbeat(auth_app, "probe", last_queue_wait_seconds=42, coalesce=True)
    original = operations._write_heartbeat
    def fail(*args, **kwargs):
        raise RuntimeError("injected database outage")
    monkeypatch.setattr(operations, "_write_heartbeat", fail)
    clock[0] = 2
    with pytest.raises(RuntimeError):
        operations.heartbeat(auth_app, "probe", phase="claiming", coalesce=True)
    monkeypatch.setattr(operations, "_write_heartbeat", original)
    operations.heartbeat(auth_app, "probe", phase="claiming", coalesce=True)
    with auth_app.state.session_factory() as session:
        assert session.get(OperationState, "worker:probe").details["last_queue_wait_seconds"] == 42


def test_postgres_shutdown_heartbeat_does_not_wait_for_application_write_lock(domain, monkeypatch):
    if not domain.postgres:
        pytest.skip("Independent PostgreSQL connections required")
    clock = [0.0]
    monkeypatch.setattr(operations.time, "monotonic", lambda: clock[0])
    operations.heartbeat(domain.app, "probe", build={"version":1}, coalesce=True)
    clock[0] = 2
    blocked, release = threading.Event(), threading.Event()
    original = operations._write_heartbeat
    def delayed(app, worker, details):
        if details.get("phase") == "idle" and "lifecycle" not in details:
            blocked.set()
            assert release.wait(timeout=5)
        return original(app, worker, details)
    monkeypatch.setattr(operations, "_write_heartbeat", delayed)
    with ThreadPoolExecutor(max_workers=2) as pool:
        routine = pool.submit(operations.heartbeat, domain.app, "probe", phase="idle", coalesce=True)
        try:
            assert blocked.wait(timeout=2)
            stopped = pool.submit(operations.heartbeat, domain.app, "probe", lifecycle="stopped")
            stopped.result(timeout=2)
            with domain.factory() as session:
                assert session.get(OperationState, "worker:probe").details["lifecycle"] == "stopped"
        finally:
            release.set()
            routine.result(timeout=5)
    with domain.factory() as session:
        assert session.get(OperationState, "worker:probe").details["lifecycle"] == "stopped"


def test_record_and_visibility_invalidations_do_not_touch_other_tracks(domain):
    first, _ = public_course(domain)
    second = second_course(domain)
    race(domain, first, "Alice", frames=20)
    slower = race(domain, first, "Alice", frames=25)
    refresh_all_for_diagnostics(domain.app)
    with domain.factory() as session:
        other = session.get(HistogramSnapshot, (second["version_id"],"compact",False))
        generation = other.generation
        session.get(Run, slower["run_id"]).status = "failed"
        session.commit()
        assert not session.get(HistogramSnapshot, (first["version_id"],"compact",False)).invalidated
        assert not session.get(HistogramSnapshot, (second["version_id"],"compact",False)).invalidated
        assert other.generation == generation
    refresh_all_for_diagnostics(domain.app)
    with domain.factory() as session:
        session.get(Player, domain.players["Alice"]).disabled = True
        session.commit()
        assert session.get(HistogramSnapshot, (first["version_id"],"compact",False)).invalidated
        assert not session.get(HistogramSnapshot, (second["version_id"],"compact",False)).invalidated


def test_artificial_reset_only_affects_named_tracks_car_and_population(domain):
    domain.app.state.settings = replace(domain.app.state.settings, environment="development", dev_auth_enabled=True,
        dev_auth_key="isolated-scalability-test-key"*2, test_drivers_enabled=True)
    first, _ = public_course(domain)
    second = second_course(domain)
    with domain.factory() as session:
        version = session.get(TrackVersion, first["version_id"])
        manifest = {**board_manifest(version,"compact"),"test_population":True}
        bid = digest({"version_id":version.id,**manifest})
        session.add(Board(id=bid, version_id=version.id, vehicle_id="compact",manifest=manifest))
        session.commit()
    refresh_all_for_diagnostics(domain.app)
    with domain.factory() as session:
        before = session.get(Board,bid).lap_revision
        session.add(OperationState(id="test-pop-batch:scoped-reset", details={"vehicle_id":"compact",
            "request":{"clear_test_records":True},"created_at":100,"tracks":[{"version_id":first["version_id"]}]}))
        session.commit()
        assert session.get(Board,bid).lap_revision == before  # No lap PB was retired.
        from bmt_backend.track_models import LapBestState
        assert session.get(LapBestState,bid).epoch == 1
        assert session.get(LapBestState,bid).cutoff == 100
        for vid in (first["version_id"],second["version_id"]):
            assert not session.get(HistogramSnapshot,(vid,"compact",False)).invalidated
        assert session.get(HistogramSnapshot,(first["version_id"],"compact",True)).invalidated
        assert not session.get(HistogramSnapshot,(second["version_id"],"compact",True)).invalidated


def test_index_and_scope_migration_round_trip_preserves_records(domain):
    from alembic import command
    first, _ = public_course(domain)
    with domain.factory() as session:
        records = session.execute(select(Run.id,Run.status,Run.time_ticks)).all()
    command.downgrade(configuration(domain.app.state.engine), "0022_histogram_cache")
    upgrade(domain.app.state.engine)
    with domain.factory() as session:
        assert session.execute(select(Run.id,Run.status,Run.time_ticks)).all() == records
        assert session.get(HistogramSnapshot,(first["version_id"],"compact",False)) is not None
