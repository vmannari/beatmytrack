"""Explicit operator job: grant a dedicated limited reporting reader, never migrate."""

import argparse
import base64
import json
import os
import re
import secrets
import time
from types import SimpleNamespace

from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

from .database_privileges import identifier

ROLE = "bmt_studio_report"
MARKER = "bmt-studio-limited-reporting-v1"
TABLES = ("studio_analysis_state", "studio_analysis_people", "studio_analysis_days",
          "studio_analysis_sessions", "race_statistics_days", "product_state")


def provision_reader(engine, owner, *, publish=None):
    if not re.fullmatch(r"[0-9a-f]{32}", owner):
        raise ValueError("Explicit staging ownership is required")
    if engine.dialect.name != "postgresql":
        raise ValueError("Reporting-reader provisioning requires PostgreSQL")
    with engine.begin() as connection:
        connection.execute(text("SET LOCAL statement_timeout='5s'"))
        connection.execute(text("SET LOCAL lock_timeout='1s'"))
        schema, database = connection.execute(text("SELECT current_schema(),current_database()")).one()
        qschema, qdatabase = identifier(schema), identifier(database)
        actual_owner = connection.scalar(text(f"SELECT owner FROM {qschema}.bmt_staging_guard WHERE id=1"))
        if actual_owner != owner:
            raise RuntimeError("Reporting reader ownership mismatch")
        existing = connection.execute(text(
            "SELECT r.oid,shobj_description(r.oid,'pg_authid') AS marker FROM pg_roles r WHERE rolname=:role"
        ), {"role": ROLE}).mappings().one_or_none()
        if existing and existing["marker"] != MARKER:
            raise RuntimeError("Refusing to adopt an existing unowned reporting role")
        if existing and connection.scalar(text(
            "SELECT EXISTS(SELECT 1 FROM pg_auth_members WHERE member=:role)"
        ), {"role": existing["oid"]}):
            raise RuntimeError("Reporting role has unexpected memberships")
        password = None if existing else secrets.token_urlsafe(48)
        if password:
            connection.execute(text("SELECT set_config('bmt.reporting_password',:password,true)"),
                {"password": password})
            connection.execute(text("""DO $$ BEGIN
              EXECUTE format('CREATE ROLE bmt_studio_report LOGIN NOSUPERUSER NOCREATEDB '
                'NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS CONNECTION LIMIT 1 PASSWORD %L',
                current_setting('bmt.reporting_password'));
            END $$"""))
            connection.execute(text(f"COMMENT ON ROLE {ROLE} IS '{MARKER}'"))
        connection.execute(text(f"ALTER ROLE {ROLE} CONNECTION LIMIT 1"))
        options = {"default_transaction_read_only": "on", "statement_timeout": "1500ms",
            "lock_timeout": "200ms", "idle_in_transaction_session_timeout": "3000ms",
            "work_mem": "1MB", "max_parallel_workers_per_gather": "0", "jit": "off"}
        for key, value in options.items():
            connection.execute(text(f"ALTER ROLE {ROLE} SET {key}='{value}'"))
        connection.execute(text(f"ALTER ROLE {ROLE} SET search_path={qschema},pg_catalog"))
        connection.execute(text(f"REVOKE ALL ON ALL TABLES IN SCHEMA {qschema} FROM {ROLE}"))
        connection.execute(text(f"REVOKE ALL ON SCHEMA {qschema} FROM {ROLE}"))
        connection.execute(text(f"GRANT CONNECT ON DATABASE {qdatabase} TO {ROLE}"))
        connection.execute(text(f"GRANT USAGE ON SCHEMA {qschema} TO {ROLE}"))
        for table in TABLES:
            connection.execute(text(f"GRANT SELECT ON {qschema}.{identifier(table)} TO {ROLE}"))
        connection.execute(text(f"GRANT EXECUTE ON FUNCTION pg_catalog.pg_control_system() TO {ROLE},bmt_admin"))
        version = publish(password, schema) if password and publish else None
    # No password is returned from the operator job or written to logs.
    return {"role": ROLE, "schema": schema, "created": bool(password),
            "secret_version": version, "read_tables": list(TABLES), "connection_limit": 1}


def validate_reports():
    """Operator-only read check; does not mint an HTTP credential or weaken MFA."""
    from fastapi import HTTPException
    from sqlalchemy.orm import sessionmaker

    from .config import Settings
    from .studio_analysis import behaviour
    from .studio_exports import behaviour_export
    from .studio_governance import csv_cell
    from .studio_release_reports import release_report
    from .studio_reporting import StudioReporting

    settings = Settings.from_env()
    if settings.studio_analysis_mode != "shared_limited":
        raise ValueError("Read validation requires explicit limited shared mode")
    engine = create_engine(settings.database_url, hide_parameters=True, connect_args={"connect_timeout": 3})
    reporting = StudioReporting(settings)
    request = SimpleNamespace(app=SimpleNamespace(state=SimpleNamespace(settings=settings,
        session_factory=sessionmaker(engine), studio_reporting=reporting)),
        state=SimpleNamespace(request_id="studio-limited-read-validation"))
    filters = {"build_id": "", "platform": "", "mode": "", "population": "all"}
    checks = []
    try:
        for view in ("activity", "retention", "journey", "engagement"):
            started = time.monotonic()
            result = behaviour(request, "owner", None, **filters, view=view)
            if result["coverage"]["reporting_storage"]["source"] != "limited_shared_primary":
                raise RuntimeError("Read validation used the wrong reporting mode")
            checks.append({"report": view, "status": "passed", "elapsed_ms": round((time.monotonic()-started)*1000, 2)})
        release = release_report(request, "owner", None, "", "", "", "", "", "", "")
        builds = release["builds"]
        if builds:
            release_report(request, "owner", None, builds[0], builds[1] if len(builds) > 1 else "",
                "", "", "", "", "")
        checks.append({"report": "release_comparison", "status": "passed", "selected_build_checked": bool(builds)})
        for view in ("activity", "retention", "journey", "engagement", "dimensions"):
            exported = behaviour_export(request, "owner", None, filters, view, csv_cell)
            if exported.status_code != 200:
                raise RuntimeError("Read validation CSV export failed")
            checks.append({"report": view + "_csv", "status": "passed", "bytes": len(exported.body)})
        try:
            behaviour(request, "owner", (0, 8*86400), **filters, view="activity")
        except HTTPException as denied:
            if denied.status_code != 422:
                raise
        else:
            raise RuntimeError("Limited reporting accepted an oversized window")
        checks.append({"report": "oversized_window_rejected", "status": "passed"})
        return {"mode": "shared_limited", "role": ROLE, "checks": checks,
                "http_authentication_modified": False, "http_endpoints_tested": False,
                "note": "Authorized operator job checks the same read functions; owner HTTP/MFA remains unchanged."}
    finally:
        reporting.close()
        engine.dispose()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--validate", action="store_true")
    args = parser.parse_args(argv)
    if args.validate:
        try:
            print(json.dumps(validate_reports()))
        except Exception as error:  # noqa: BLE001 - operator boundary redacts SQL/provider secrets
            from fastapi import HTTPException
            print(json.dumps({"status": "failed", "error_class": type(error).__name__,
                "code": error.detail if isinstance(error, HTTPException) else None,
                "sqlstate": getattr(getattr(error, "orig", error), "sqlstate", None)}))
            raise SystemExit(1) from None
        return
    import google.auth
    from google.auth.transport.requests import AuthorizedSession

    uri = os.environ["BMT_DATABASE_URL"]
    owner = os.environ["BMT_STAGING_OWNER"]
    secret = os.environ["BMT_REPORTING_SECRET"]
    if not re.fullmatch(r"projects/[a-z0-9-]+/secrets/bmt-stg-[0-9a-f]{8}-analysis-db", secret):
        raise ValueError("Unexpected reporting secret resource")
    credentials, _project = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    http = AuthorizedSession(credentials)
    def publish(password, schema):
        original = make_url(uri)
        query = dict(original.query)
        query["options"] = "-c search_path=" + schema
        reader = original.set(username=ROLE, password=password, query=query).render_as_string(hide_password=False)
        response = http.post("https://secretmanager.googleapis.com/v1/" + secret + ":addVersion",
            json={"payload": {"data": base64.b64encode(reader.encode()).decode()}}, timeout=20)
        if not response.ok:
            raise RuntimeError(f"Reporting credential publish failed: HTTP{response.status_code}")
        return response.json()["name"]
    engine = create_engine(uri, hide_parameters=True, connect_args={"connect_timeout": 3})
    try:
        result = provision_reader(engine, owner, publish=publish)
    except Exception as error:  # noqa: BLE001 - dynamic DDL errors can contain the generated password
        # PostgreSQL's dynamic-DDL error context can contain a generated password.
        # Do not print the exception text, SQL or a chained traceback in this job.
        print(json.dumps({"status": "failed", "error_class": type(error).__name__,
            "sqlstate": getattr(getattr(error, "orig", error), "sqlstate", None)}))
        raise SystemExit(1) from None
    finally:
        engine.dispose()
        http.close()
    print(json.dumps(result))


if __name__ == "__main__":
    main()
