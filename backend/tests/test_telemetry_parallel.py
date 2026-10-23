"""Durable telemetry ownership, exact capacity and actual PostgreSQL contention."""
# ruff: noqa: F811
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from uuid import uuid4

import pytest
from alembic import command
from sqlalchemy import create_engine, func, select, text
from test_auth_postgres import google_request, postgres_auth  # noqa: F401
from test_product_analytics import body, observed

from bmt_backend.db import make_engine, make_session_factory
from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.product_analytics import project_pending
from bmt_backend.telemetry import append_server_event
from bmt_backend.telemetry_models import (
    ProductEvent,
    ProductMetric,
    ProductProfile,
    ProductPublication,
    ProductState,
)
from bmt_backend.telemetry_processing import actor_once, publish, record_failure, shared_once
from bmt_backend.telemetry_queue import (
    activate,
    configure_capacity,
    finish,
    fold_one,
    lock_actor,
    partition,
    prepare,
    register,
)
from bmt_backend.telemetry_queue_models import (
    TelemetryActor,
    TelemetryCredit,
    TelemetryMetric,
    TelemetryWork,
)
from bmt_backend.track_models import Track, TrackVersion, now


@pytest.fixture(params=["sqlite", "postgres"])
def pipeline(request):
    if request.param == "postgres":
        return request.getfixturevalue("postgres_auth")[0]
    return request.getfixturevalue("auth_app")


def player(app, name=None):
    with app.state.session_factory() as db:
        row = Player(display_name=name or str(uuid4()), analytics_enabled=True)
        db.add(row)
        db.commit()
        return row.id


def seed(app, identity, count=1, *, kind="menu_ready", props=None, at=None):
    stamp = now() if at is None else at
    with app.state.session_factory() as db:
        activate(db)
        events = [ProductEvent(id=str(uuid4()), player_id=identity, is_test_driver=False,
            source="client", name=kind, occurred_at=stamp, received_at=stamp,
            session_id=str(uuid4()), payload_hash="fixture", properties=props or {}) for _ in range(count)]
        db.add_all(events)
        db.flush()
        register(db, events)
        ids = [e.id for e in events]
        db.commit()
        return ids


def credits(app):
    with app.state.session_factory() as db:
        return db.scalar(select(func.sum(TelemetryCredit.capacity - TelemetryCredit.free)))


def folds(app, stamp=None, limit=500):
    for _ in range(2048):
        if not fold_one(app.state.session_factory, stamp or now(), limit=limit):
            return
    raise AssertionError("Metric fold did not reach its persisted checkpoint")


def test_deferred_work_keeps_credit_until_its_atomic_completion(pipeline):
    identity = player(pipeline)
    ids = seed(pipeline, identity, kind="process_exit", props={"exit_reason": 4, "device_class": "desktop"})
    assert credits(pipeline) == 1
    assert actor_once(pipeline.state.session_factory) == 1
    assert credits(pipeline) == 1
    with pipeline.state.session_factory() as db:
        event = db.get(ProductEvent, ids[0])
        assert event.actor_at is not None and event.processed_at is None
        assert db.get(TelemetryWork, ids[0]) is not None
    assert shared_once(pipeline.state.session_factory) == 1
    assert credits(pipeline) == 0
    with pipeline.state.session_factory() as db:
        event = db.get(ProductEvent, ids[0])
        finish(db, [event], now())
        db.commit()
    assert credits(pipeline) == 0


def test_actor_failure_rolls_back_profiles_partial_totals_and_completion(pipeline, monkeypatch):
    identity = player(pipeline)
    ids = seed(pipeline, identity)
    from bmt_backend import studio_analysis
    original = studio_analysis.project

    def fail(*_args, **_kwargs):
        raise RuntimeError("injected after partial metrics")

    monkeypatch.setattr(studio_analysis, "project", fail)
    with pytest.raises(RuntimeError, match="injected"):
        actor_once(pipeline.state.session_factory)
    assert credits(pipeline) == 1
    with pipeline.state.session_factory() as db:
        assert db.get(ProductEvent, ids[0]).actor_at is None
        assert db.get(ProductProfile, identity) is None
        assert db.scalar(select(func.count()).select_from(TelemetryMetric)) == 0
    monkeypatch.setattr(studio_analysis, "project", original)
    project_pending(pipeline.state.session_factory)
    assert credits(pipeline) == 0
    with pipeline.state.session_factory() as db:
        assert db.get(ProductMetric, (now() // 86400, "event_menu_ready", "")).value == 1


def test_rollup_is_bounded_idempotent_and_preserves_historical_baseline(pipeline):
    stamp = now()
    with pipeline.state.session_factory() as db:
        db.add(ProductMetric(day=stamp // 86400, key="event_menu_ready", dimension="", value=77))
        db.commit()
    seed(pipeline, player(pipeline), count=3, at=stamp)
    assert actor_once(pipeline.state.session_factory, at=stamp) == 3
    folds(pipeline, stamp, limit=1)
    folds(pipeline, stamp, limit=1)
    with pipeline.state.session_factory() as db:
        assert db.get(ProductMetric, (stamp // 86400, "event_menu_ready", "")).value == 80
    assert credits(pipeline) == 0


def test_reporting_barrier_completes_without_waiting_for_future_receipts(pipeline):
    stamp, identity = now(), player(pipeline)
    seed(pipeline, identity, at=stamp)
    publish(pipeline.state.session_factory, stamp)
    seed(pipeline, identity, at=stamp + 1)
    assert actor_once(pipeline.state.session_factory, 1, stamp) == 1
    folds(pipeline, stamp)
    publish(pipeline.state.session_factory, stamp)
    with pipeline.state.session_factory() as db:
        assert db.get(ProductState, 1).processed_through == stamp
        assert db.get(ProductState, 1).pending_events == 1
    assert credits(pipeline) == 1


def test_later_player_batch_waits_for_earlier_metric_contributions(pipeline):
    identity = player(pipeline)
    seed(pipeline, identity, count=2)
    assert actor_once(pipeline.state.session_factory, limit=1) == 1
    assert actor_once(pipeline.state.session_factory, limit=1) == 0
    assert credits(pipeline) == 1
    folds(pipeline)
    assert actor_once(pipeline.state.session_factory, limit=1) == 1
    folds(pipeline)
    with pipeline.state.session_factory() as db:
        assert db.get(ProductMetric, (now() // 86400, "event_menu_ready", "")).value == 2
    assert credits(pipeline) == 0


def test_erasure_cancels_pending_work_and_returns_capacity_once(pipeline):
    identity = player(pipeline)
    ids = seed(pipeline, identity, kind="process_exit", props={"exit_reason": 4, "device_class": "desktop"})
    actor_once(pipeline.state.session_factory)
    from bmt_backend.telemetry_erasure import cancel_events
    with pipeline.state.session_factory() as db:
        lock_actor(db, identity)
        db.get(Player, identity).deleted_at = now()
        rows = [db.get(ProductEvent, ids[0])]
        cancel_events(db, rows)
        db.delete(rows[0])
        db.commit()
    assert credits(pipeline) == 0
    assert shared_once(pipeline.state.session_factory) == 0
    with pipeline.state.session_factory() as db:
        assert db.get(TelemetryWork, ids[0]) is None


def test_pending_publication_cannot_recreate_erased_creator_fact(pipeline):
    creator, driver = player(pipeline), player(pipeline)
    stamp = now()
    with pipeline.state.session_factory() as db:
        track = Track(owner_id=creator)
        db.add(track)
        db.flush()
        version = TrackVersion(track_id=track.id, number=1, name="Fixture", content_hash="a" * 64,
            manifest={}, state="published", published_at=stamp)
        db.add(version)
        db.flush()
        version_id = version.id
        append_server_event(db, "race_accepted", str(uuid4()), driver,
            {"track_version": version_id, "owner_id": creator, "published_at": stamp})
        db.commit()
    actor_once(pipeline.state.session_factory)
    from bmt_backend.telemetry_erasure import erase_publications
    with pipeline.state.session_factory() as db:
        db.get(Player, creator).deleted_at = stamp
        lock_actor(db, creator)
        assert erase_publications(db, creator)
        db.commit()
    shared_once(pipeline.state.session_factory)
    with pipeline.state.session_factory() as db:
        assert db.get(ProductPublication, version_id) is None
        assert db.scalar(select(TelemetryWork.event_id).where(TelemetryWork.owner_id == creator)) is None


def test_expansion_preserves_retired_history_and_routes_pending_receipts():
    engine = make_engine("sqlite://")
    try:
        command.upgrade(configuration(engine), "0050_discovery_indexed")
        stamp, identity, receipt = now(), str(uuid4()), str(uuid4())
        with engine.begin() as db:
            db.execute(text("UPDATE product_state SET processed_events=123 WHERE id=1"))
            db.execute(ProductMetric.__table__.insert().values(day=stamp // 86400,
                key="event_menu_ready", dimension="", value=77))
            db.execute(Player.__table__.insert().values(id=identity, display_name=identity, needs_username=True))
            db.execute(ProductEvent.__table__.insert().values(id=receipt, player_id=identity,
                source="client", name="menu_ready", occurred_at=stamp, received_at=stamp, properties={}, payload_hash="original"))
        upgrade(engine)
        factory = make_session_factory(engine)
        assert prepare(factory) == 1
        project_pending(factory, at=stamp)
        with factory() as db:
            assert db.get(ProductMetric, (stamp // 86400, "event_menu_ready", "")).value == 78
            assert db.get(ProductState, 1).processed_events == 124
            assert db.get(ProductEvent, receipt).payload_hash == "original"
    finally:
        engine.dispose()


def test_failed_reservation_rolls_back_receipts_and_capacity(pipeline):
    identity = player(pipeline)
    with pipeline.state.session_factory() as db:
        configure_capacity(db, 3)
        db.commit()
    seed(pipeline, identity)
    from fastapi import HTTPException
    with pytest.raises(HTTPException, match="TELEMETRY_BACKLOG_FULL"):
        seed(pipeline, identity, count=3)
    assert credits(pipeline) == 1
    with pipeline.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(ProductEvent)) == 1
        assert db.scalar(select(func.sum(TelemetryCredit.capacity))) == 3
        assert db.scalar(select(func.sum(TelemetryCredit.free))) == 2
    project_pending(pipeline.state.session_factory)
    assert credits(pipeline) == 0


def test_failed_owner_backs_off_without_losing_events_or_stalling_other_owners(pipeline, monkeypatch):
    identity = player(pipeline)
    seed(pipeline, identity)
    from bmt_backend import studio_analysis
    original = studio_analysis.project

    def fail(*_args, **_kwargs):
        raise RuntimeError("injected owner failure")

    monkeypatch.setattr(studio_analysis, "project", fail)
    with pytest.raises(RuntimeError) as failure:
        actor_once(pipeline.state.session_factory)
    record_failure(pipeline.state.session_factory, failure.value)
    monkeypatch.setattr(studio_analysis, "project", original)
    other = player(pipeline)
    while partition(other) == partition(identity):
        other = player(pipeline)
    seed(pipeline, other)
    assert actor_once(pipeline.state.session_factory) == 1
    with pipeline.state.session_factory() as db:
        assert db.get(ProductProfile, other) is not None
        assert db.get(ProductProfile, identity) is None
        owner = db.get(TelemetryActor, partition(identity))
        assert owner.failures == 1 and owner.retry_after > now()
        owner.retry_after = 0
        db.commit()
    project_pending(pipeline.state.session_factory)
    assert credits(pipeline) == 0


def test_keyed_race_map_matches_serial_order_at_the_cell_limit(pipeline):
    from copy import deepcopy

    from test_race_statistics import package

    from bmt_backend import race_statistics
    from bmt_backend.race_statistics_models import RaceStatisticsDay

    for index in range(12):
        props = package("a" * 36, cells=[[index * 128 + cell, 0, 2, 1] for cell in range(128)],
                        segments=[[0, 256, 128]], position_samples=256)
        seed(pipeline, player(pipeline), kind="race_statistics", props=props)
    assert actor_once(pipeline.state.session_factory, owner_limit=256) == 12
    fields = ("races", "elapsed_ms", "frame_buckets", "position_samples", "dropped_samples",
              "aggregate_dropped_samples", "cells", "segments")
    with pipeline.state.session_factory() as db:
        ordered = db.scalars(select(ProductEvent).join(TelemetryWork, TelemetryWork.event_id == ProductEvent.id)
            .order_by(TelemetryWork.position)).all()
        race_statistics.project(db, ordered)
        db.flush()
        reference = db.scalar(select(RaceStatisticsDay))
        expected = {field: deepcopy(getattr(reference, field)) for field in fields}
        db.rollback()
    if pipeline.state.engine.dialect.name == "postgresql":
        with ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda _index: shared_once(pipeline.state.session_factory, limit=3), range(4)))
    while shared_once(pipeline.state.session_factory, limit=3):
        pass
    with pipeline.state.session_factory() as db:
        actual = db.scalar(select(RaceStatisticsDay))
        assert {field: getattr(actual, field) for field in fields} == expected
        assert len(actual.cells) == race_statistics.AGGREGATE_CELLS
        assert actual.aggregate_dropped_samples == 1024
    assert credits(pipeline) == 0


@pytest.mark.postgres
def test_postgres_killed_worker_releases_ownership_and_rolls_back_effects(postgres_auth):
    import os
    import subprocess
    import sys

    app, _client = postgres_auth
    seed(app, player(app), count=8)
    source = app.state.engine
    with source.connect() as db:
        schema = db.scalar(text("SELECT current_schema()"))
    code = """
import os, sys
from sqlalchemy import create_engine
from bmt_backend.db import make_session_factory
from bmt_backend.telemetry_processing import actor_once
from bmt_backend import studio_analysis
engine=create_engine(os.environ['TELEMETRY_TEST_URL'],
    connect_args={'options':os.environ['TELEMETRY_TEST_OPTIONS']},hide_parameters=True)
original=studio_analysis.project
def pause(*args, **kwargs):
    original(*args, **kwargs)
    args[0].flush()
    print('UNCOMMITTED', flush=True)
    sys.stdin.read(1)
studio_analysis.project=pause
actor_once(make_session_factory(engine))
"""
    env = {**os.environ, "TELEMETRY_TEST_URL": source.url.render_as_string(hide_password=False),
           "TELEMETRY_TEST_OPTIONS": f"-c search_path={schema} -c statement_timeout=10000"}
    child = subprocess.Popen([sys.executable, "-c", code], env=env, stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    pool = ThreadPoolExecutor(max_workers=1)
    try:
        assert pool.submit(child.stdout.readline).result(timeout=20).strip() == "UNCOMMITTED"
        child.kill()
        child.communicate(timeout=10)
    finally:
        if child.poll() is None:
            child.kill()
            child.communicate(timeout=10)
        pool.shutdown()
    assert credits(app) == 8
    project_pending(app.state.session_factory)
    assert credits(app) == 0
    with app.state.session_factory() as db:
        assert db.get(ProductMetric, (now() // 86400, "event_menu_ready", "")).value == 8


@pytest.mark.postgres
def test_postgres_ingress_ignores_global_and_analytical_owner_locks(postgres_auth):
    app, client = postgres_auth
    app.state.settings = replace(app.state.settings, telemetry_enabled=True)
    signed = client.post("/v1/auth/google", json=google_request(app, client, "independent-ingress")).json()
    identity = signed["player"]["id"]
    headers = {"Authorization": "Bearer " + signed["access_token"]}
    assert client.post("/v1/privacy/preferences", headers=headers, json={"analytics_enabled": True}).status_code == 200
    assert client.post("/v1/telemetry/batches", headers=headers, json=body([observed("menu_ready")])).status_code == 200
    other = player(app)
    while partition(other) == partition(identity):
        other = player(app)
    seed(app, other)
    with ThreadPoolExecutor(max_workers=1) as pool, app.state.session_factory() as locked:
        locked.scalar(select(ProductState).where(ProductState.id == 1).with_for_update())
        locked.scalar(select(TelemetryActor).where(TelemetryActor.id == partition(identity)).with_for_update())
        future = pool.submit(client.post, "/v1/telemetry/batches", headers=headers, json=body([observed("menu_ready")]))
        try:
            response = future.result(timeout=2)
            assert response.status_code == 200, response.text
            assert actor_once(app.state.session_factory) == 1
            with app.state.session_factory() as check:
                assert check.get(ProductProfile, other) is not None
                assert check.get(ProductProfile, identity) is None
        finally:
            locked.rollback()


@pytest.mark.postgres
def test_postgres_parallel_workers_and_retry_have_exact_effects(postgres_auth):
    app, _client = postgres_auth
    identities = [player(app) for _ in range(16)]
    for identity in identities:
        seed(app, identity, 4)
    with ThreadPoolExecutor(max_workers=4) as pool:
        for _ in range(8):
            list(pool.map(lambda _i: actor_once(app.state.session_factory, 8), range(4)))
    project_pending(app.state.session_factory)
    assert credits(app) == 0
    with app.state.session_factory() as db:
        assert db.get(ProductMetric, (now() // 86400, "event_menu_ready", "")).value == 64
        assert db.scalar(select(func.count()).select_from(ProductProfile)) == 16
        assert db.scalar(select(func.count()).select_from(ProductEvent).where(ProductEvent.processed_at.is_(None))) == 0


@pytest.mark.postgres
def test_postgres_waiting_migrator_does_not_deadlock_concurrent_indexes(postgres_auth):
    source = postgres_auth[0].state.engine
    schemas = ["telemetry_migration_" + uuid4().hex for _ in range(2)]
    engines = []
    children = []
    try:
        for schema in schemas:
            with source.begin() as db:
                db.execute(text(f"CREATE SCHEMA {schema}"))
            engine = create_engine(source.url, hide_parameters=True,
                connect_args={"options": f"-c search_path={schema} -c statement_timeout=20000"})
            engines.append(engine)
            command.upgrade(configuration(engine), "0050_discovery_indexed")
        # Alembic's Python environment proxy is process-global. Separate
        # interpreters exercise two real migration processes, as in deployment.
        import subprocess
        import sys
        code = ("from sqlalchemy import create_engine; from bmt_backend.migrate import upgrade; "
                "import os; upgrade(create_engine(os.environ['TELEMETRY_TEST_URL'], "
                "connect_args={'options':os.environ['TELEMETRY_TEST_OPTIONS']},hide_parameters=True))")
        import os
        for schema in schemas:
            env = {**os.environ, "TELEMETRY_TEST_URL": source.url.render_as_string(hide_password=False),
                "TELEMETRY_TEST_OPTIONS": f"-c search_path={schema} -c statement_timeout=20000"}
            children.append(subprocess.Popen([sys.executable, "-c", code], env=env,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True))
        for child in children:
            _out, errors = child.communicate(timeout=60)
            assert child.returncode == 0, errors[-2000:]
    finally:
        for child in children:
            if child.poll() is None:
                child.kill()
                child.communicate(timeout=10)
        for engine in engines:
            engine.dispose()
        with source.begin() as db:
            for schema in schemas:
                db.execute(text(f"DROP SCHEMA {schema} CASCADE"))


@pytest.mark.postgres
def test_postgres_expansion_resumes_after_interrupted_concurrent_index(postgres_auth, monkeypatch):
    from alembic import op
    from sqlalchemy import inspect

    source = postgres_auth[0].state.engine
    schema = "telemetry_resume_" + uuid4().hex
    with source.begin() as db:
        db.execute(text(f"CREATE SCHEMA {schema}"))
    engine = create_engine(source.url, hide_parameters=True,
        connect_args={"options": f"-c search_path={schema} -c statement_timeout=20000"})
    try:
        command.upgrade(configuration(engine), "0050_discovery_indexed")
        original = op.create_index

        def interrupted(*args, **kwargs):
            original(*args, **kwargs)
            if kwargs.get("postgresql_concurrently"):
                raise RuntimeError("injected index interruption")

        monkeypatch.setattr(op, "create_index", interrupted)
        with pytest.raises(RuntimeError, match="injected index interruption"):
            command.upgrade(configuration(engine), "0051_telemetry_parallel")
        monkeypatch.setattr(op, "create_index", original)
        command.upgrade(configuration(engine), "0051_telemetry_parallel")
        with engine.connect() as db:
            assert db.scalar(text("SELECT COUNT(*) FROM telemetry_intake")) == 256
            assert db.scalar(text("SELECT SUM(free) FROM telemetry_credits")) == 50000
            assert db.scalar(text("SELECT version_num FROM alembic_version")) == "0051_telemetry_parallel"
            indexes = {row["name"] for row in inspect(db).get_indexes("product_events")}
            assert {"ix_telemetry_actor_pending", "ix_telemetry_full_pending", "ix_telemetry_legacy_pending"} <= indexes
    finally:
        engine.dispose()
        with source.begin() as db:
            db.execute(text(f"DROP SCHEMA {schema} CASCADE"))
