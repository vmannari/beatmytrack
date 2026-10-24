"""Broad exact reports cannot borrow gameplay database resources."""

from dataclasses import replace
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from sqlalchemy import event, text
from sqlalchemy.exc import DBAPIError
from test_domains import domain  # noqa: F401

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.migrate import upgrade
from bmt_backend.studio_platform_models import AnalysisDay
from bmt_backend.studio_reporting import StudioReporting
from bmt_backend.track_models import now

OWNER = {"Authorization": "Bearer " + "o" * 40}
URL = "/v1/admin/analysis/behaviour"
FENCE = {"lsn": "0/ABCD", "cluster_id": "fixture-cluster", "database": "fixture-db", "schema": "public"}


@pytest.fixture
def reports(auth_app, auth_client, tmp_path):
    settings = replace(auth_app.state.settings, environment="test", admin_owner_key="o" * 40)
    auth_app.state.settings = settings
    engine = make_engine(f"sqlite:///{(tmp_path / 'reporting.sqlite').as_posix()}")
    upgrade(engine)
    auth_app.state.studio_reporting.close()
    auth_app.state.studio_reporting = StudioReporting(settings, engine=engine)
    stamp = now()
    with engine.begin() as connection:
        connection.execute(AnalysisDay.__table__.insert(), [{
            "day": stamp // 86400, "player_id": "report-only-player", "dimension": "one",
            "build_id": "separate-reporting-storage", "platform": "android", "mode": "free_race",
            "counters": {"active": 1, "race_started": 3}, "first_at": stamp, "last_at": stamp,
        }])
    yield auth_app, auth_client, engine
    auth_app.state.studio_reporting.close()
    engine.dispose()


def test_unconfigured_report_is_actionable_without_fact_reads_or_primary_fallback(auth_app, auth_client):
    auth_app.state.settings = replace(auth_app.state.settings, admin_owner_key="o" * 40)
    queries = []

    def capture(_conn, _cursor, statement, *_args):
        queries.append(statement)

    event.listen(auth_app.state.engine, "before_cursor_execute", capture)
    try:
        response = auth_client.get(URL, headers=OWNER)
    finally:
        event.remove(auth_app.state.engine, "before_cursor_execute", capture)
    assert response.status_code == 503
    assert "BMT_STUDIO_ANALYSIS_DATABASE_URL" in response.json()["detail"]
    assert response.headers["retry-after"] == "5"
    assert not any("studio_analysis" in statement for statement in queries)
    assert auth_client.get("/v1/admin/overview", headers=OWNER).status_code == 200


def test_engine_injection_requires_explicit_test_environment(auth_app):
    with pytest.raises(ValueError, match="test environment"):
        create_app(replace(auth_app.state.settings, environment="development"), engine=auth_app.state.engine,
                   analysis_engine=auth_app.state.engine)


def test_exact_report_reads_only_separate_storage(reports):
    app, client, _engine = reports
    queries = []

    def capture(_conn, _cursor, statement, *_args):
        queries.append(statement)

    event.listen(app.state.engine, "before_cursor_execute", capture)
    try:
        response = client.get(URL, headers=OWNER)
    finally:
        event.remove(app.state.engine, "before_cursor_execute", capture)
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["active_players"] == 1 and data["counters"]["race_started"] == 3
    assert data["options"][0]["build_id"] == "separate-reporting-storage"
    assert data["coverage"]["reporting_storage"]["source"] == "explicit_test_engine"
    assert not any("studio_analysis" in statement or "product_state" in statement for statement in queries)


def test_saturated_reports_fail_promptly_and_release_their_slot(reports):
    app, client, _engine = reports
    with app.state.studio_reporting.snapshot(app.state.session_factory):
        response = client.get(URL, headers=OWNER)
        assert response.status_code == 503 and response.json()["detail"] == "STUDIO_ANALYSIS_BUSY"
    assert client.get(URL, headers=OWNER).status_code == 200


def test_total_deadline_does_not_restart_with_each_query_and_recovers(reports, monkeypatch):
    import bmt_backend.studio_reporting as module

    app, _client, _engine = reports
    clock = [0.0]
    monkeypatch.setattr(module, "time", SimpleNamespace(monotonic=lambda: clock[0]))
    with (pytest.raises(HTTPException) as caught,
          app.state.studio_reporting.snapshot(app.state.session_factory) as (session, _meta)):
        assert session.scalar(text("SELECT 1")) == 1
        clock[0] = 4.0
        assert session.scalar(text("SELECT 1")) == 1
        clock[0] = 6.0
        session.scalar(text("SELECT 1"))
    assert caught.value.status_code == 503 and caught.value.detail == "STUDIO_ANALYSIS_TIMEOUT"
    with app.state.studio_reporting.snapshot(app.state.session_factory) as (session, _meta):
        assert session.scalar(text("SELECT 1")) == 1


def test_database_failure_does_not_poison_report_slot(reports):
    app, client, _engine = reports
    with (pytest.raises(HTTPException) as caught,
          app.state.studio_reporting.snapshot(app.state.session_factory) as (session, _meta)):
        session.execute(text("SELECT * FROM missing_report_table"))
    assert caught.value.detail == "STUDIO_ANALYSIS_UNAVAILABLE"
    assert client.get(URL, headers=OWNER).status_code == 200


@pytest.mark.parametrize("values,code", [
    ({"standby": False}, "STUDIO_ANALYSIS_REQUIRES_READ_ONLY_REPLICA"),
    ({"read_only": False}, "STUDIO_ANALYSIS_REQUIRES_READ_ONLY_REPLICA"),
    ({"fenced": False}, "STUDIO_ANALYSIS_REPLICA_CATCHING_UP"),
    ({"cluster_id": "another-cluster"}, "STUDIO_ANALYSIS_REPLICA_IDENTITY_MISMATCH"),
    ({"database": "another-database"}, "STUDIO_ANALYSIS_REPLICA_IDENTITY_MISMATCH"),
    ({"schema": "another-schema"}, "STUDIO_ANALYSIS_REPLICA_IDENTITY_MISMATCH"),
])
def test_replica_rejects_unsafe_or_unverifiable_snapshots(values, code):
    reporting = StudioReporting(Settings())
    row = {**FENCE, "standby": True, "read_only": True, "fenced": True,
           "replayed_at": 990, "observed_at": 1000, **values}
    seen = []

    class Connection:
        def execute(self, statement, parameters):
            seen.append((str(statement), parameters))
            return SimpleNamespace(mappings=lambda: SimpleNamespace(one=lambda: row))

    with pytest.raises(HTTPException) as caught:
        reporting._replica(Connection(), FENCE)
    assert caught.value.detail == code
    assert seen[0][1] == {"fence": "0/ABCD"}
    assert "pg_last_wal_replay_lsn()" in seen[0][0]


@pytest.mark.parametrize("replayed_at,age", [(990, 10.0), (100, 900.0), (None, None)])
def test_fenced_replica_exposes_transaction_age_without_rejecting_quiet_replicas(replayed_at, age):
    reporting = StudioReporting(Settings())
    row = {**FENCE, "standby": True, "read_only": True, "fenced": True,
           "replayed_at": replayed_at, "observed_at": 1000}
    connection = SimpleNamespace(execute=lambda *_args: SimpleNamespace(
        mappings=lambda: SimpleNamespace(one=lambda: row)))
    assert reporting._replica(connection, FENCE) == {
        "source": "read_only_replica", "last_replayed_transaction_at": replayed_at,
        "last_replayed_transaction_age_seconds": age,
        "request_start_fence_applied": True,
    }


def test_postgres_budget_uses_remaining_total_time(monkeypatch):
    import bmt_backend.studio_reporting as module

    monkeypatch.setattr(module, "time", SimpleNamespace(monotonic=lambda: 2.0))
    calls = []
    connection = SimpleNamespace(info={"bmt_studio_report_deadline": 5.0},
                                 dialect=SimpleNamespace(name="postgresql"))
    StudioReporting._budget(connection, SimpleNamespace(execute=calls.append), "SELECT 1", None, None, False)
    assert calls == ["SET LOCAL statement_timeout = 3000"]


def test_real_postgres_primary_is_rejected_and_reader_is_server_read_only(domain):  # noqa: F811
    if domain.app.state.engine.dialect.name != "postgresql":
        pytest.skip("Requires disposable PostgreSQL")
    reporting = StudioReporting(replace(
        domain.app.state.settings,
        studio_analysis_database_url=domain.app.state.settings.database_url,
    ))
    try:
        with pytest.raises(HTTPException) as caught, reporting.snapshot(domain.factory):
            pytest.fail("A primary must not execute analytical facts")
        assert caught.value.detail == "STUDIO_ANALYSIS_REQUIRES_READ_ONLY_REPLICA"
        with pytest.raises(DBAPIError) as denied, reporting.engine.begin() as connection:
            connection.execute(text("CREATE SCHEMA bmt_studio_report_forbidden"))
        assert denied.value.orig.sqlstate == "25006"
    finally:
        reporting.close()
