"""Staging SQL ownership and grants against an explicitly disposable PostgreSQL DB."""
import os
import uuid
from pathlib import Path

import pytest
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import DBAPIError

from bmt_backend import cloud_setup, cloud_smoke
from bmt_backend.config import Settings
from bmt_backend.database_privileges import configure, verify_runtime
from bmt_backend.db import make_engine
from bmt_backend.migrate import SCHEMA_HEAD

pytestmark = pytest.mark.postgres


@pytest.fixture
def database():
    url = os.environ.get("BMT_GCP_SETUP_TEST_DATABASE_URL")
    if not url:
        pytest.skip("Explicit disposable database required for staging role/DDL tests")
    schema = "bmt_load_" + uuid.uuid4().hex
    roles = {kind: "bmt_" + kind + "_" + uuid.uuid4().hex[:16] for kind in ("api", "worker", "admin")}
    admin = create_engine(url, hide_parameters=True, connect_args={"connect_timeout": 3})
    with admin.begin() as connection:
        connection.exec_driver_sql(f'CREATE SCHEMA "{schema}"')
        for role in roles.values():
            connection.exec_driver_sql(f"CREATE ROLE \"{role}\" LOGIN CREATEDB CREATEROLE PASSWORD 'isolated-security-test-role'")
    engine = make_engine(url, Settings(database_url=url), schema=schema)
    try:
        yield engine, schema, roles, url
    finally:
        engine.dispose()
        with admin.begin() as connection:
            connection.exec_driver_sql(f'DROP SCHEMA "{schema}" CASCADE')
            for role in roles.values():
                connection.exec_driver_sql(f'DROP OWNED BY "{role}"')
                connection.exec_driver_sql(f'DROP ROLE "{role}"')
        admin.dispose()


def test_owned_setup_is_repeatable_and_application_role_has_no_ddl_or_guard_access(database):
    engine, schema, role, url = database
    owner = uuid.uuid4().hex
    cloud_setup.setup(engine, owner, role, schema)
    cloud_setup.setup(engine, owner, role, schema)
    application = create_engine(make_url(url).set(username=role["api"], password="isolated-security-test-role"), hide_parameters=True,
        connect_args={"connect_timeout": 3, "options": "-c search_path=" + schema})
    try:
        with application.connect() as connection:
            assert connection.execute(text("SELECT version_num FROM alembic_version")).scalar() == SCHEMA_HEAD
            assert not any(connection.execute(text("SELECT rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls FROM pg_roles WHERE rolname=current_user")).one())
            connection.execute(text("SELECT id FROM players LIMIT 1"))
        with pytest.raises(DBAPIError), application.begin() as connection:
            connection.execute(text("SELECT * FROM bmt_staging_guard"))
        with pytest.raises(DBAPIError), application.begin() as connection:
            connection.execute(text("CREATE TABLE forbidden (id integer)"))
    finally:
        application.dispose()


def test_different_owner_cannot_adopt_initialized_database(database):
    engine, schema, role, _ = database
    owner = uuid.uuid4().hex
    cloud_setup.setup(engine, owner, role, schema)
    before = set(inspect(engine).get_table_names(schema=schema))
    with pytest.raises(RuntimeError, match="ownership"):
        cloud_setup.setup(engine, uuid.uuid4().hex, role, schema)
    assert set(inspect(engine).get_table_names(schema=schema)) == before


def test_unowned_nonempty_schema_is_never_migrated(database):
    engine, schema, role, _ = database
    with engine.begin() as connection:
        connection.execute(text("CREATE TABLE existing_player_data (id integer)"))
    with pytest.raises(RuntimeError, match="unowned"):
        cloud_setup.setup(engine, uuid.uuid4().hex, role, schema)
    assert inspect(engine).get_table_names(schema=schema) == ["existing_player_data"]


def test_failed_first_migration_leaves_a_guard_for_safe_retry(database, monkeypatch):
    engine, schema, role, _ = database
    owner = uuid.uuid4().hex
    original = cloud_setup.upgrade
    def failed(engine):
        raise RuntimeError("Injected migration interruption")
    monkeypatch.setattr(cloud_setup, "upgrade", failed)
    with pytest.raises(RuntimeError, match="interruption"):
        cloud_setup.setup(engine, owner, role, schema)
    assert inspect(engine).get_table_names(schema=schema) == ["bmt_staging_guard"]
    monkeypatch.setattr(cloud_setup, "upgrade", original)
    cloud_setup.setup(engine, owner, role, schema)
    with engine.connect() as connection:
        assert connection.execute(text("SELECT version_num FROM alembic_version")).scalar() == SCHEMA_HEAD


@pytest.mark.parametrize("kind,statement", [
    ("worker", "SELECT access_hash,refresh_hash FROM session_tokens"),
    ("worker", "SELECT * FROM identities"),
    ("worker", "SELECT * FROM studio_staff"),
    ("worker", "UPDATE admin_audit SET reason='tampered'"),
    ("worker", "DELETE FROM studio_staff"),
    ("api", "SELECT * FROM studio_staff"),
    ("api", "DELETE FROM product_controls"),
    ("api", "DELETE FROM admin_audit"),
    ("admin", "SELECT access_hash,refresh_hash FROM session_tokens"),
    ("admin", "SELECT subject FROM identities"),
    ("admin", "UPDATE admin_audit SET reason='tampered'"),
    ("admin", "DELETE FROM admin_audit"),
    ("worker", "ALTER TABLE players ADD COLUMN forbidden text"),
    ("worker", "SELECT bmt_redact_removed_audit('not-removed')"),
    ("worker", "UPDATE game_config_releases SET policy='{}'"),
    ("worker", "UPDATE game_config_control SET emergency='{}'"),
])
def test_workload_permission_denials(database, kind, statement):
    engine, schema, roles, url = database
    cloud_setup.setup(engine, uuid.uuid4().hex, roles, schema)
    runtime = create_engine(make_url(url).set(username=roles[kind], password="isolated-security-test-role"),
        hide_parameters=True, connect_args={"connect_timeout": 3, "options": "-c search_path=" + schema})
    try:
        with pytest.raises(DBAPIError) as denied, runtime.begin() as connection:
            connection.execute(text(statement))
        # The denial must be authority, never a misspelled object/column.
        assert denied.value.orig.sqlstate == "42501"
    finally:
        runtime.dispose()


def test_runtime_sessions_real_api_worker_and_admin(database, tmp_path):
    from fastapi.testclient import TestClient
    from sqlalchemy.orm import Session

    from bmt_backend.app import create_app
    engine, schema, roles, url = database
    cloud_setup.setup(engine, uuid.uuid4().hex, roles, schema)
    runtimes = {kind: make_engine(make_url(url).set(username=role, password="isolated-security-test-role").render_as_string(hide_password=False), schema=schema)
                for kind, role in roles.items()}
    try:
        with pytest.raises(RuntimeError,match="must not own objects"):
            verify_runtime(engine,Settings(workload_role="worker"))
        for kind,runtime in runtimes.items():verify_runtime(runtime,Settings(workload_role=kind))
        for kind,wrong in (("api","worker"),("worker","admin"),("admin","api")):
            with pytest.raises(RuntimeError):verify_runtime(runtimes[kind],Settings(workload_role=wrong))
        settings = Settings(environment="development", dev_auth_enabled=True, dev_auth_key="d"*40,
                            object_dir=str(tmp_path), workload_role="api")
        app = create_app(settings, engine=runtimes["api"])
        with TestClient(app) as client:
            signed = client.post("/v1/auth/development", headers={"X-Dev-Auth-Key":"d"*40},
                json={"subject":"permission-fixture", "display_name":"Permission fixture"})
            assert signed.status_code == 200, signed.text
            auth = {"Authorization":"Bearer " + signed.json()["access_token"]}
            assert client.get("/v1/economy", headers=auth).status_code == 200
            assert client.get("/v1/me/appearances", headers=auth).status_code == 200
            assert client.get("/v1/game-config?platform=android&build_id=permissions",headers=auth).status_code == 200
        from bmt_backend.admin_models import AdminAudit
        from bmt_backend.game_config import activate_schedules, publish_snapshot
        from bmt_backend.game_config_policy import DEFAULTS
        from bmt_backend.privacy import cleanup_one, remove_account
        from bmt_backend.privacy_models import AccountDeletion
        with Session(runtimes["admin"]) as session:
            publish_snapshot(session,"Scheduled fixture",DEFAULTS,[],scheduled_at=1)
            session.add(AdminAudit(command_id=str(uuid.uuid4()), actor="owner-fixture",action="suspend_player",
                entity_id=signed.json()["player"]["id"],reason="Private support detail",before={"private":"before"},
                after={"private":"after"},request_hash="a"*64,request_id=str(uuid.uuid4())))
            session.commit()
        factory=__import__("sqlalchemy.orm",fromlist=["sessionmaker"]).sessionmaker(runtimes["worker"])
        assert activate_schedules(factory,at=2)==1
        with Session(runtimes["api"]) as session:
            remove_account(session,signed.json()["player"]["id"],"a"*64,str(uuid.uuid4()))
            session.commit()
        worker=create_app(Settings(workload_role="worker",object_dir=str(tmp_path)),engine=runtimes["worker"])
        for _ in range(200):
            cleanup_one(worker)
            with Session(runtimes["worker"]) as session:
                if session.get(AccountDeletion,signed.json()["player"]["id"]).completed_at is not None: break
        else:pytest.fail("Bounded account cleanup did not finish with worker grants")
        with Session(runtimes["admin"]) as session:
            audit=session.scalar(__import__("sqlalchemy").select(AdminAudit).where(AdminAudit.actor=="owner-fixture"))
            assert audit.reason=="Removed account" and audit.before==audit.after=={}
            assert audit.action=="suspend_player" and audit.actor=="owner-fixture"
        # Named staff admission must work using only the private service's grants.
        settings = Settings(workload_role="admin", studio_staff_audiences=("staff",),
            studio_staff_subjects='{"known":{"name":"Owner","role":"owner"}}', object_dir=str(tmp_path))
        studio = create_app(settings, engine=runtimes["admin"])
        class Verifier:
            def verify(self, _): return {"sub":"known", "amr":["mfa"]}
        studio.state.staff_identity_verifier = Verifier()
        with TestClient(studio) as client:
            assert client.get("/v1/admin/overview", headers={"Authorization":"Bearer staff"}).status_code == 200
    finally:
        for runtime in runtimes.values(): runtime.dispose()


def test_reconfiguration_removes_stale_column_grants_and_denies_future_tables(database):
    engine,schema,roles,_url=database
    cloud_setup.setup(engine,uuid.uuid4().hex,roles,schema)
    with engine.begin() as db:
        db.execute(text(f'GRANT SELECT(access_hash) ON "{schema}".session_tokens TO PUBLIC'))
        db.execute(text(f'GRANT UPDATE(reason) ON "{schema}".admin_audit TO "{roles["worker"]}"'))
    configure(engine,schema=schema,roles=roles)
    with engine.connect() as db:
        assert not db.scalar(text("SELECT has_column_privilege(:role,:table,'access_hash','SELECT')"),
            {"role":roles["worker"],"table":schema+".session_tokens"})
        assert not db.scalar(text("SELECT has_column_privilege(:role,:table,'reason','UPDATE')"),
            {"role":roles["worker"],"table":schema+".admin_audit"})
    with engine.begin() as db:
        db.execute(text("CREATE TABLE future_unreviewed (id integer)"))
        assert not db.scalar(text("SELECT has_table_privilege(:role,:table,'SELECT')"),
            {"role":roles["worker"],"table":schema+".future_unreviewed"})
    with pytest.raises(RuntimeError,match="explicit workload privilege review"):
        configure(engine,schema=schema,roles=roles)


def test_schema_owner_without_superuser_can_migrate_and_apply_grants(database):
    from bmt_backend.migrate import upgrade
    engine,schema,roles,url=database
    migrator="bmt_migrator_"+uuid.uuid4().hex[:16]
    with engine.begin() as db:
        db.execute(text(f"CREATE ROLE {migrator} LOGIN PASSWORD 'isolated-owner-test-role'"))
        db.execute(text(f'ALTER SCHEMA "{schema}" OWNER TO {migrator}'))
        for role in roles.values():db.execute(text(f'ALTER ROLE "{role}" NOCREATEDB NOCREATEROLE'))
    owner=make_engine(make_url(url).set(username=migrator,password="isolated-owner-test-role").render_as_string(hide_password=False),schema=schema)
    try:
        upgrade(owner)
        configure(owner,schema=schema,roles=roles)
        with owner.connect() as db:
            assert not any(db.execute(text("SELECT rolsuper,rolcreatedb,rolcreaterole FROM pg_roles WHERE rolname=current_user")).one())
    finally:
        owner.dispose()
        with engine.begin() as db:
            db.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
            db.execute(text(f'CREATE SCHEMA "{schema}"'))
            db.execute(text(f'DROP OWNED BY {migrator}'))
            db.execute(text(f'DROP ROLE {migrator}'))


@pytest.mark.godot
def test_staging_smoke_uses_native_proof_and_no_player_writes(database, monkeypatch):
    from test_gcs_storage import Credentials, Peer

    from bmt_backend.gcs_storage import GCSBlobStore
    engine, schema, role, url = database
    owner = uuid.uuid4().hex
    cloud_setup.setup(engine, owner, role, schema)
    application = create_engine(make_url(url).set(username=role["api"], password="isolated-security-test-role"), hide_parameters=True,
        connect_args={"connect_timeout": 3, "options": "-c search_path=" + schema})
    binary = Path(os.environ.get("BMT_GODOT_BIN", r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe"))
    if not binary.is_file():
        application.dispose()
        pytest.skip("This native probe requires the exact pinned engine")
    project = os.environ.get("BMT_GAME_PROJECT") or str(Path(__file__).parents[2] / "game")
    settings = Settings(database_url=url, object_backend="gcs", gcs_bucket="bmt-fixture",
        godot_bin=str(binary), game_project=project)
    peer = Peer()
    monkeypatch.setattr(cloud_smoke, "make_engine", lambda *args: application)
    monkeypatch.setattr(cloud_smoke, "GCSBlobStore", lambda config: GCSBlobStore(config, credentials=Credentials(), transport=peer))
    result = cloud_smoke.check(settings, owner, Path(__file__).parent / "fixtures/verified_oval.json")
    assert result["status"] == "passed" and result["canonical_ticks"] == 12757 and result["player_writes"] == 0
    assert peer.objects == {}
    with engine.connect() as connection:
        assert connection.execute(text("SELECT count(*) FROM players")).scalar() == 0
        assert connection.execute(text("SELECT count(*) FROM runs")).scalar() == 0
