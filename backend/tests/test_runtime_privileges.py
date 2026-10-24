"""Actual effective-grant drift, not configuration-name assertions (SEC10)."""
import importlib.util
import os
import uuid
from pathlib import Path

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url
from test_cloud_setup import database as _database_fixture

from bmt_backend import cloud_setup
from bmt_backend.config import Settings
from bmt_backend.database_privileges import configure, verify_runtime

pytestmark = pytest.mark.postgres
database = _database_fixture


def runtime(database, kind):
    engine, schema, roles, url = database
    cloud_setup.setup(engine, uuid.uuid4().hex, roles, schema)
    peer = create_engine(make_url(url).set(username=roles[kind], password="isolated-security-test-role"),
                         hide_parameters=True, connect_args={"options": "-c search_path=" + schema})
    return peer


@pytest.mark.parametrize("kind,grant", [
    ("worker", "GRANT CREATE ON SCHEMA {schema} TO {role}"),
    ("api", "GRANT CREATE ON SCHEMA {schema} TO {role}"),
    ("admin", "GRANT CREATE ON SCHEMA {schema} TO {role}"),
    ("worker", "GRANT UPDATE(enabled) ON {schema}.studio_staff TO {role}"),
    ("worker", "GRANT UPDATE(enabled) ON {schema}.studio_staff TO PUBLIC"),
    ("worker", "GRANT INSERT ON {schema}.session_tokens TO {role}"),
    ("worker", "GRANT UPDATE(subject) ON {schema}.identities TO {role}"),
    ("worker", "GRANT UPDATE(emergency) ON {schema}.game_config_control TO {role}"),
    ("worker", "GRANT UPDATE(policy) ON {schema}.game_config_releases TO {role}"),
    ("api", "GRANT DELETE ON {schema}.game_config_releases TO {role}"),
    ("admin", "GRANT SELECT(subject) ON {schema}.identities TO {role}"),
    ("worker", "GRANT TRUNCATE ON {schema}.admin_audit TO {role}"),
    ("api", "GRANT TRUNCATE ON {schema}.admin_audit TO {role}"),
    ("admin", "GRANT TRUNCATE ON {schema}.admin_audit TO {role}"),
    ("worker", "GRANT TRIGGER ON {schema}.players TO {role}"),
    ("worker", "GRANT REFERENCES(id) ON {schema}.players TO {role}"),
    ("worker", "GRANT SELECT ON {schema}.players TO {role} WITH GRANT OPTION"),
    ("worker", "GRANT UPDATE(revision) ON {schema}.game_config_control TO {role} WITH GRANT OPTION"),
    ("worker", "GRANT USAGE ON SCHEMA {schema} TO {role} WITH GRANT OPTION"),
    ("worker", "GRANT UPDATE ON ALL SEQUENCES IN SCHEMA {schema} TO {role}"),
    ("api", "GRANT EXECUTE ON FUNCTION {schema}.bmt_redact_removed_audit(text) TO {role}"),
    ("worker", "GRANT EXECUTE ON FUNCTION {schema}.discovery_short_grams(text) TO {role} WITH GRANT OPTION"),
])
def test_startup_rejects_effective_privilege_drift(database, kind, grant):
    peer = runtime(database, kind)
    engine, schema, roles, _ = database
    try:
        verify_runtime(peer, Settings(workload_role=kind))
        with engine.begin() as db:
            db.execute(text(grant.format(schema='"' + schema + '"', role='"' + roles[kind] + '"')))
        with pytest.raises(RuntimeError):
            verify_runtime(peer, Settings(workload_role=kind))
    finally:
        peer.dispose()


@pytest.mark.parametrize("kind", ["api", "worker", "admin"])
def test_reviewed_policy_accepts_every_role_and_its_required_operations(database, kind):
    peer = runtime(database, kind)
    try:
        verify_runtime(peer, Settings(workload_role=kind))
        with peer.begin() as db:
            db.execute(text("SELECT id FROM players LIMIT 1"))
            if kind == "worker":
                db.execute(text("UPDATE game_config_control SET revision=revision"))
                db.execute(text("UPDATE game_config_releases SET state=state WHERE false"))
                db.execute(text("INSERT INTO admin_audit(id,command_id,request_hash,actor,action,entity_id,reason,before,after,request_id,created_at) "
                                "VALUES (:id,:id,'fixture','scheduler','test','fixture','fixture','{}','{}','fixture',1)"), {"id": str(uuid.uuid4())})
            if kind == "admin":
                db.execute(text("SELECT id,player_id,provider FROM identities LIMIT 1"))
                db.execute(text("UPDATE session_families SET revoked=true WHERE false"))
    finally:
        peer.dispose()


def test_database_create_permission_is_rejected_without_repairing_it(database):
    peer = runtime(database, "worker")
    engine, _, roles, _ = database
    try:
        with engine.begin() as db:
            name = db.scalar(text("SELECT current_database()"))
            db.execute(text('GRANT CREATE ON DATABASE "' + name.replace('"', '""') + '" TO "' + roles["worker"] + '"'))
        with pytest.raises(RuntimeError):
            verify_runtime(peer, Settings(workload_role="worker"))
        with peer.connect() as db:
            assert db.scalar(text("SELECT has_database_privilege(current_database(),'CREATE')"))
    finally:
        peer.dispose()


@pytest.mark.parametrize("object_sql", [
    "CREATE TABLE future_unreviewed(id integer)",
    "CREATE FUNCTION future_unreviewed() RETURNS integer LANGUAGE sql AS 'SELECT 1'",
    "CREATE FUNCTION future_unreviewed() RETURNS integer LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS 'SELECT 1'",
])
def test_future_objects_never_gain_automatic_authority(database, object_sql):
    peer = runtime(database, "worker")
    engine, schema, roles, _ = database
    try:
        with engine.begin() as db:
            db.execute(text(object_sql))
        with pytest.raises(RuntimeError):
            verify_runtime(peer, Settings(workload_role="worker"))
        with pytest.raises(RuntimeError, match="explicit workload privilege review"):
            configure(engine, schema=schema, roles=roles)
    finally:
        peer.dispose()


@pytest.mark.parametrize("grant", ["GRANT CREATE ON SCHEMA {schema} TO {role}",
                                  "GRANT UPDATE(enabled) ON {schema}.studio_staff TO {role}"])
def test_original_checker_control_accepts_the_reproduced_drift(database, grant):
    path = os.environ.get("BMT_ORIGINAL_PRIVILEGES_SOURCE")
    if not path:
        pytest.skip("Original-method control requires the task-start source snapshot")
    spec = importlib.util.spec_from_file_location("original_grant_checker", Path(path))
    original = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(original)
    peer = runtime(database, "worker")
    engine, schema, roles, _ = database
    try:
        with engine.begin() as db:
            db.execute(text(grant.format(schema='"' + schema + '"', role='"' + roles["worker"] + '"')))
        original.verify_runtime(peer, Settings(workload_role="worker"))
        with pytest.raises(RuntimeError):
            verify_runtime(peer, Settings(workload_role="worker"))
    finally:
        peer.dispose()
