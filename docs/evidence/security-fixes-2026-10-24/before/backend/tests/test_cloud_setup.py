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
from bmt_backend.db import make_engine
from bmt_backend.migrate import SCHEMA_HEAD

pytestmark = pytest.mark.postgres


@pytest.fixture
def database():
    url = os.environ.get("BMT_GCP_SETUP_TEST_DATABASE_URL")
    if not url:
        pytest.skip("Explicit disposable database required for staging role/DDL tests")
    schema, role = "bmt_load_" + uuid.uuid4().hex, "bmt_role_" + uuid.uuid4().hex[:16]
    admin = create_engine(url, hide_parameters=True, connect_args={"connect_timeout": 3})
    with admin.begin() as connection:
        connection.exec_driver_sql(f'CREATE SCHEMA "{schema}"')
        connection.exec_driver_sql(f'CREATE ROLE "{role}" LOGIN CREATEDB CREATEROLE')
    engine = make_engine(url, Settings(database_url=url), schema=schema)
    try:
        yield engine, schema, role, url
    finally:
        engine.dispose()
        with admin.begin() as connection:
            connection.exec_driver_sql(f'DROP SCHEMA "{schema}" CASCADE')
            connection.exec_driver_sql(f'DROP OWNED BY "{role}"')
            connection.exec_driver_sql(f'DROP ROLE "{role}"')
        admin.dispose()


def test_owned_setup_is_repeatable_and_application_role_has_no_ddl_or_guard_access(database):
    engine, schema, role, url = database
    owner = uuid.uuid4().hex
    cloud_setup.setup(engine, owner, role, schema)
    cloud_setup.setup(engine, owner, role, schema)
    application = create_engine(make_url(url).set(username=role), hide_parameters=True,
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


@pytest.mark.godot
def test_staging_smoke_uses_native_proof_and_no_player_writes(database, monkeypatch):
    from test_gcs_storage import Credentials, Peer

    from bmt_backend.gcs_storage import GCSBlobStore
    engine, schema, role, url = database
    owner = uuid.uuid4().hex
    cloud_setup.setup(engine, owner, role, schema)
    application = create_engine(make_url(url).set(username=role), hide_parameters=True,
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
