"""Explicit early-stage mode: bounded facts on a separately authorized reader."""

import os
import time
from dataclasses import replace
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import sessionmaker

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade
from bmt_backend.studio_platform_models import AnalysisDay
from bmt_backend.studio_reporting import LIMITED_LOCK, StudioReporting, reporting_policy
from bmt_backend.studio_reporting_admin import provision_reader
from bmt_backend.track_models import now

OWNER = {"Authorization": "Bearer " + "o" * 40}
WINDOW = (0, 7 * 86400)


def limited_settings(**kwargs):
    return Settings(environment="test", workload_role="admin", studio_analysis_mode="shared_limited",
        studio_analysis_database_url="postgresql+psycopg://bmt_studio_report:fixture@localhost/bmt", **kwargs)


def test_shared_mode_requires_explicit_admin_and_dedicated_credential():
    assert Settings().studio_analysis_mode == "replica"
    safe = limited_settings()
    for changes in ({"workload_role": "api"}, {"workload_role": "worker"},
                    {"studio_analysis_database_url": ""},
                    {"studio_analysis_database_url": "postgresql+psycopg://bmt_admin@localhost/bmt"},
                    {"database_url": "postgresql+psycopg://bmt_studio_report@localhost/bmt"}):
        with pytest.raises(ValueError):
            replace(safe, **changes)
    assert reporting_policy(safe)["sql_budget_ms"] == 1500
    assert reporting_policy(safe)["max_days"] == 7


def test_operator_job_never_logs_dynamic_password_error_context(monkeypatch, capsys):
    import bmt_backend.studio_reporting_admin as module
    monkeypatch.setenv("BMT_DATABASE_URL", "postgresql+psycopg://fixture@localhost/bmt")
    monkeypatch.setenv("BMT_STAGING_OWNER", "a" * 32)
    monkeypatch.setenv("BMT_REPORTING_SECRET", "projects/fixture-project/secrets/bmt-stg-aaaaaaaa-analysis-db")
    monkeypatch.setattr("google.auth.default", lambda **kwargs: (object(), "fixture-project"))
    monkeypatch.setattr("google.auth.transport.requests.AuthorizedSession",
        lambda credentials: SimpleNamespace(close=lambda: None))
    monkeypatch.setattr(module, "create_engine", lambda *args, **kwargs: SimpleNamespace(dispose=lambda: None))
    def denied(*args, **kwargs):
        raise RuntimeError("DDL error containing fixture-password-must-not-be-logged")
    monkeypatch.setattr(module, "provision_reader", denied)
    with pytest.raises(SystemExit) as stopped:
        module.main([])
    assert stopped.value.code == 1
    captured = capsys.readouterr()
    assert "fixture-password" not in captured.out + captured.err
    assert '"error_class": "RuntimeError"' in captured.out


@pytest.mark.parametrize("window", [None, (0, 8 * 86400), (5, 5), (9, 8)])
def test_long_or_missing_window_fails_before_any_database_work(window):
    reporting = StudioReporting(limited_settings())
    try:
        with pytest.raises(HTTPException) as denied, reporting.snapshot(
                lambda: pytest.fail("Primary was touched for an invalid window"), window=window):
            pytest.fail("Invalid range reached a report")
        assert denied.value.status_code == 422
    finally:
        reporting.close()


@pytest.mark.parametrize("field,value", [("standby", True), ("read_only", False), ("reader", "bmt_admin"),
    ("privileged", True), ("inherited_role", True), ("can_write", True), ("can_create", True)])
def test_runtime_rejects_writable_or_wrong_readers(field, value):
    reporting = StudioReporting(limited_settings())
    fence = {"cluster_id": "cluster", "database": "bmt", "schema": "public"}
    row = dict(fence, standby=False, read_only=True, reader="bmt_studio_report", privileged=False,
        inherited_role=False, can_write=False, can_create=False)
    row[field] = value
    connection = SimpleNamespace(execute=lambda *_args: SimpleNamespace(
        mappings=lambda: SimpleNamespace(one=lambda: row)))
    with pytest.raises(HTTPException) as denied:
        reporting._shared_primary(connection, fence)
    assert denied.value.detail == "STUDIO_LIMITED_REPORTING_READER_NOT_READ_ONLY"
    reporting.close()


@pytest.fixture(scope="module")
def shared_database(tmp_path_factory):
    uri = os.environ.get("BMT_LIMITED_TEST_DATABASE_URL")
    if not uri:
        pytest.skip("Set BMT_LIMITED_TEST_DATABASE_URL to this task's isolated PostgreSQL fixture")
    engine = create_engine(uri, hide_parameters=True)
    upgrade(engine)
    with engine.begin() as connection:
        connection.execute(text("CREATE TABLE IF NOT EXISTS bmt_staging_guard(id integer primary key,owner text)"))
        connection.execute(text("INSERT INTO bmt_staging_guard VALUES(1,:owner) ON CONFLICT DO NOTHING"),
            {"owner": "a" * 32})
        connection.execute(text("DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='bmt_admin') "
            "THEN CREATE ROLE bmt_admin; END IF; END $$"))
    password = {}
    result = provision_reader(engine, "a" * 32, publish=lambda value, schema: password.update(value=value))
    assert result["role"] == "bmt_studio_report"
    if not password:
        # The isolated task fixture may be reused after a failing test run.
        with engine.begin() as connection:
            connection.execute(text("ALTER ROLE bmt_studio_report PASSWORD 'fixture-shared-reader'"))
        password["value"] = "fixture-shared-reader"
    reader_uri = make_url(uri).set(username="bmt_studio_report", password=password["value"])
    settings = limited_settings(database_url=uri, admin_owner_key="o" * 40, studio_legacy_keys_enabled=True,
        object_dir=str(tmp_path_factory.mktemp("limited-report-objects")))
    settings = replace(settings, studio_analysis_database_url=reader_uri.render_as_string(hide_password=False))
    yield engine, settings
    engine.dispose()


def test_real_reader_cannot_write_even_after_disabling_read_only_or_read_identity_tables(shared_database):
    _primary, settings = shared_database
    reporting = StudioReporting(settings)
    try:
        for sql in ("UPDATE product_state SET id=id WHERE false", "SELECT * FROM identities LIMIT 1",
                    "CREATE TABLE studio_reader_forbidden(id integer)"):
            with pytest.raises(DBAPIError) as denied, reporting.engine.begin() as connection:
                connection.execute(text("SET TRANSACTION READ WRITE"))
                connection.execute(text(sql))
            assert denied.value.orig.sqlstate == "42501"
        with reporting.snapshot(sessionmaker(_primary), window=WINDOW) as (db, metadata):
            assert db.scalar(text("SELECT current_setting('transaction_read_only')")) == "on"
            assert metadata["source"] == "limited_shared_primary"
    finally:
        reporting.close()


def test_real_database_lock_bounds_reports_across_processes_and_recovers(shared_database):
    primary, settings = shared_database
    reporting = StudioReporting(settings)
    try:
        with primary.connect() as other_process:
            other_process.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": LIMITED_LOCK})
            with pytest.raises(HTTPException) as denied, reporting.snapshot(sessionmaker(primary), window=WINDOW):
                pytest.fail("A second process entered a report")
            assert denied.value.detail == "STUDIO_ANALYSIS_BUSY"
        with reporting.snapshot(sessionmaker(primary), window=WINDOW) as (db, _metadata):
            assert db.scalar(text("SELECT 1")) == 1
    finally:
        reporting.close()


def test_real_total_sql_deadline_cancels_and_releases_snapshot(shared_database):
    primary, settings = shared_database
    reporting = StudioReporting(settings)
    start = time.monotonic()
    try:
        with pytest.raises(HTTPException) as denied, reporting.snapshot(sessionmaker(primary), window=WINDOW) as (db, _meta):
            db.execute(text("SELECT pg_sleep(0.9)"))
            db.execute(text("SELECT pg_sleep(0.9)"))
        assert denied.value.detail == "STUDIO_ANALYSIS_TIMEOUT"
        assert time.monotonic() - start < 2.5
        with reporting.snapshot(sessionmaker(primary), window=WINDOW) as (db, _meta):
            assert db.scalar(text("SELECT 1")) == 1
    finally:
        reporting.close()


def test_real_report_and_csv_are_exact_and_erasure_is_visible_next_request(shared_database):
    primary, settings = shared_database
    app = create_app(settings, engine=primary)
    stamp = now()
    with primary.begin() as connection:
        connection.execute(AnalysisDay.__table__.insert(), {"day": stamp // 86400,
            "player_id": "shared-fixture-player", "dimension": "one", "build_id": "shared-fixture-build",
            "platform": "android", "mode": "free_race", "counters": {"active": 1, "race_started": 3},
            "first_at": stamp, "last_at": stamp, "artificial": False})
    with TestClient(app) as client:
        report = client.get("/v1/admin/analysis/behaviour", headers=OWNER)
        assert report.status_code == 200, report.text
        assert report.json()["active_players"] == 1
        assert report.json()["coverage"]["reporting_storage"]["source"] == "limited_shared_primary"
        first, until = (stamp // 86400 - 8) * 86400, stamp
        rejected = client.get(f"/v1/admin/analysis/behaviour?since={first}&until={until}", headers=OWNER)
        assert rejected.status_code == 422 and "7 UTC" in rejected.json()["detail"]
        for view in ("retention", "journey", "engagement"):
            response = client.get("/v1/admin/analysis/behaviour?view=" + view, headers=OWNER)
            assert response.status_code == 200, response.text
        release = client.get("/v1/admin/analysis/releases", headers=OWNER)
        assert release.status_code == 200, release.text
        export = client.get("/v1/admin/exports/activity.csv", headers=OWNER)
        assert export.status_code == 200, export.text
        with primary.begin() as connection:
            connection.execute(text("DELETE FROM studio_analysis_days WHERE player_id='shared-fixture-player'"))
        erased = client.get("/v1/admin/analysis/behaviour", headers=OWNER)
        assert erased.status_code == 200 and erased.json()["active_players"] == 0
    app.state.studio_reporting.close()


def test_existing_unowned_role_and_wrong_owner_are_not_adopted(shared_database):
    primary, _settings = shared_database
    with pytest.raises(RuntimeError, match="ownership mismatch"):
        provision_reader(primary, "b" * 32)
    with primary.begin() as connection:
        connection.execute(text("COMMENT ON ROLE bmt_studio_report IS 'not-this-task'"))
    try:
        with pytest.raises(RuntimeError, match="unowned"):
            provision_reader(primary, "a" * 32)
    finally:
        with primary.begin() as connection:
            connection.execute(text("COMMENT ON ROLE bmt_studio_report IS 'bmt-studio-limited-reporting-v1'"))
