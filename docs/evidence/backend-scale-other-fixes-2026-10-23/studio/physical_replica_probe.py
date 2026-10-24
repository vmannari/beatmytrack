"""Disposable physical-replica report/freshness/privacy integration proof."""

import json
import os
from pathlib import Path
import time

from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, text
from sqlalchemy.exc import DBAPIError

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.db import make_session_factory
from bmt_backend.migrate import upgrade
from bmt_backend.studio_platform_models import AnalysisDay, AnalysisState
from bmt_backend.studio_erasure import erase_studio_private
from bmt_backend.studio_reporting import StudioReporting
from bmt_backend.track_models import now
import bmt_backend.studio_reporting as report_module


def main():
    report_errors = []

    def diagnose_report(_logger, error, _request_id, _dependency):
        diagnostic = {"report_exception": type(error).__name__,
                      "sqlstate": getattr(getattr(error, "orig", None), "sqlstate", None),
                      "synthetic_fixture_message": str(error).splitlines()[0][:300]}
        report_errors.append(diagnostic)
        print(json.dumps(diagnostic), flush=True)

    report_module.dependency_failure = diagnose_report
    primary_url = f"postgresql+psycopg://postgres@{os.environ['REPORT_PRIMARY']}/bmt_studio_reporting"
    replica_url = f"postgresql+psycopg://postgres@{os.environ['REPORT_REPLICA']}/bmt_studio_reporting"
    primary = create_engine(primary_url)
    standby_admin = create_engine(replica_url, isolation_level="AUTOCOMMIT")
    upgrade(primary)
    factory = make_session_factory(primary)
    stamp = now()
    with factory() as session:
        state = session.get(AnalysisState, 1)
        state.processed_through = state.latest_client_at = stamp
        session.add(AnalysisDay(
            day=stamp // 86400, player_id="synthetic-private-contribution", dimension="one",
            build_id="physical-replica", platform="android", mode="free_race",
            counters={"active": 1, "race_started": 17}, first_at=stamp, last_at=stamp,
        ))
        session.commit()
    with primary.begin() as connection:
        connection.execute(text("CREATE ROLE bmt_studio_metadata LOGIN"))
        connection.execute(text("CREATE ROLE bmt_studio_reader LOGIN"))
        connection.execute(text("REVOKE EXECUTE ON FUNCTION pg_catalog.pg_control_system() FROM PUBLIC"))
        connection.execute(text("GRANT USAGE ON SCHEMA public TO bmt_studio_metadata, bmt_studio_reader"))
        connection.execute(text("GRANT SELECT ON studio_analysis_state, studio_analysis_people, "
                                "studio_analysis_days, studio_analysis_sessions, product_state TO bmt_studio_reader"))
        connection.execute(text("GRANT SELECT ON players, session_families, session_tokens TO bmt_studio_metadata"))
        connection.execute(text("GRANT SELECT, INSERT, UPDATE ON rate_buckets TO bmt_studio_metadata"))
    metadata_url = primary_url.replace("//postgres@", "//bmt_studio_metadata@")
    reader_url = replica_url.replace("//postgres@", "//bmt_studio_reader@")
    metadata_engine = create_engine(metadata_url)
    metadata_factory = make_session_factory(metadata_engine)
    settings = Settings(database_url=metadata_url, studio_analysis_database_url=reader_url,
                        admin_owner_key="o" * 40, telemetry_enabled=True,
                        object_dir="/tmp/bmt-studio-report-objects",
                        studio_analysis_statement_timeout_ms=1500)
    reporting = StudioReporting(settings)
    def diagnose(context):
        error = context.original_exception
        print(json.dumps({"database_error": type(error).__name__,
                          "sqlstate": getattr(error, "sqlstate", None),
                          "synthetic_fixture_message": str(error).splitlines()[0][:200]}), flush=True)

    event.listen(reporting.engine, "handle_error", diagnose)
    event.listen(primary, "handle_error", diagnose)
    evidence = {"fixture": "isolated physical PostgreSQL 16 streaming replica, no published ports",
                "database_fixtures": "temporary task containers and tmpfs only", "checks": {}}

    def read_count():
        with reporting.snapshot(metadata_factory) as (session, metadata):
            count = session.scalar(text("SELECT COUNT(*) FROM studio_analysis_days"))
            return count, metadata

    for name, statement in (
        ("missing_primary_identity_privilege_denies_report",
         "GRANT EXECUTE ON FUNCTION pg_catalog.pg_control_system() TO bmt_studio_metadata"),
        ("missing_reader_identity_privilege_denies_report",
         "GRANT EXECUTE ON FUNCTION pg_catalog.pg_control_system() TO bmt_studio_reader"),
    ):
        try:
            read_count()
        except HTTPException as error:
            assert error.detail == "STUDIO_ANALYSIS_UNAVAILABLE", error.detail
            assert report_errors[-1]["sqlstate"] == "42501", report_errors[-1]
            evidence["checks"][name] = 503
        else:
            raise AssertionError("Unprivileged identity probe unexpectedly permitted a report")
        with primary.begin() as connection:
            connection.execute(text(statement))

    deadline = time.monotonic() + 10
    while True:
        try:
            count, metadata = read_count()
            break
        except HTTPException:
            if time.monotonic() >= deadline:
                raise
    assert count == 1 and metadata["source"] == "read_only_replica"
    evidence["checks"]["physical_standby_success"] = metadata
    time.sleep(2.1)
    count, quiet_metadata = read_count()
    assert count == 1 and quiet_metadata["last_replayed_transaction_age_seconds"] >= 2.0
    evidence["checks"]["quiet_caught_up_standby_remains_available"] = quiet_metadata

    with reporting.engine.connect() as connection:
        assert connection.scalar(text("SHOW transaction_read_only")) == "on"
        connection.rollback()
    try:
        with reporting.engine.begin() as connection:
            connection.execute(text("CREATE SCHEMA forbidden_reporting_write"))
    except DBAPIError as error:
        assert error.orig.sqlstate == "25006"
    else:
        raise AssertionError("Reporting connection permitted a write")
    evidence["checks"]["server_read_only"] = "SQLSTATE 25006"

    # A PostgreSQL sleep is actual database work, not a mocked clock: a later
    # query only gets the remaining report budget and is cancelled server-side.
    start = time.monotonic()
    try:
        with reporting.snapshot(metadata_factory) as (session, _metadata):
            session.execute(text("SELECT pg_sleep(0.9)"))
            session.execute(text("SELECT pg_sleep(0.9)"))
    except HTTPException as error:
        assert error.detail == "STUDIO_ANALYSIS_TIMEOUT", error.detail
    else:
        raise AssertionError("Two queries exceeded their shared total deadline")
    elapsed = time.monotonic() - start
    assert 1.2 <= elapsed < 3.0, elapsed
    evidence["checks"]["total_server_sql_deadline_seconds"] = elapsed
    assert read_count()[0] == 1

    # Pause replay after the first contribution is visible, then erase that
    # contribution on primary. A report must reject the stale replica even if
    # its most recently replayed transaction is only milliseconds old.
    with standby_admin.connect() as connection:
        connection.execute(text("SELECT pg_wal_replay_pause()"))
        deadline = time.monotonic() + 5
        while not connection.scalar(text("SELECT pg_is_wal_replay_paused()")):
            assert time.monotonic() < deadline
            time.sleep(.02)
    with factory() as session:
        session.execute(text("SET LOCAL synchronous_commit = off"))
        erase_studio_private(session, "synthetic-private-contribution")
        session.commit()
    with standby_admin.connect() as connection:
        assert connection.scalar(text("SELECT COUNT(*) FROM studio_analysis_days")) == 1
    start = time.monotonic()
    try:
        read_count()
    except HTTPException as error:
        assert error.detail == "STUDIO_ANALYSIS_REPLICA_CATCHING_UP", error.detail
    else:
        raise AssertionError("Report served a contribution erased before its WAL fence")
    evidence["checks"]["paused_replica_rejects_erased_contribution"] = {
        "status": 503, "duration_seconds": time.monotonic() - start,
        "erasure_commit_synchronous_commit": "off",
        "stale_contribution_still_present_on_paused_replica": True,
    }
    with standby_admin.connect() as connection:
        connection.execute(text("SELECT pg_wal_replay_resume()"))
    deadline = time.monotonic() + 10
    while True:
        try:
            count, _metadata = read_count()
            break
        except HTTPException:
            assert time.monotonic() < deadline
    assert count == 0
    evidence["checks"]["catch_up_observes_erasure"] = True
    try:
        with metadata_engine.connect() as connection:
            connection.execute(text("SELECT COUNT(*) FROM studio_analysis_days"))
    except DBAPIError as error:
        assert error.orig.sqlstate == "42501"
    else:
        raise AssertionError("Primary API fixture role unexpectedly has analytical table access")
    evidence["checks"]["restricted_primary_role_cannot_read_analysis_facts"] = "SQLSTATE 42501"

    # Exercise the real FastAPI endpoint and retain primary SQL shapes only.
    # Authentication and the constant WAL fence may use primary; report facts
    # (including product/analysis state) must all use the standby.
    app = create_app(settings, engine=metadata_engine)
    sql = []

    def capture(_connection, _cursor, statement, *_args):
        sql.append(statement)

    event.listen(metadata_engine, "before_cursor_execute", capture)
    with TestClient(app) as client:
        result = client.get("/v1/admin/analysis/behaviour?view=all",
                            headers={"Authorization": "Bearer " + "o" * 40})
        assert result.status_code == 200, result.text
        assert result.json()["active_players"] == 0
        assert result.json()["coverage"]["reporting_storage"]["request_start_fence_applied"]
    event.remove(metadata_engine, "before_cursor_execute", capture)
    assert not any("studio_analysis_" in statement or "product_state" in statement for statement in sql), sql
    evidence["checks"]["real_http_exact_report_primary_fact_queries"] = 0
    evidence["checks"]["real_http_primary_sql_shapes"] = sql
    reporting.close()
    metadata_engine.dispose()
    standby_admin.dispose()
    primary.dispose()
    Path("/evidence/physical_replica_result.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps({"physical_replica_checks": len(evidence["checks"]), "passed": True}))


if __name__ == "__main__":
    main()
