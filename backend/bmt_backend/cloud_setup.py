"""Explicit staging-only database ownership, migrations and least-privilege grants."""
import os
import re

from sqlalchemy import inspect, text

from .config import Settings
from .db import make_engine
from .migrate import upgrade
from .database_privileges import DEFAULT_ROLES, configure, identifier


def setup(engine, owner, roles=None, schema="public"):
    if not re.fullmatch(r"[0-9a-f]{32}", owner):
        raise ValueError("Staging needs its explicit ownership identifier")
    roles = dict(DEFAULT_ROLES if roles is None else roles)
    if set(roles) != set(DEFAULT_ROLES) or len(set(roles.values())) != 3:
        raise ValueError("Three separate workload roles are required")
    for role in roles.values():
        identifier(role)
        if role in ("postgres", "cloudsqlsuperuser"):
            raise ValueError("Invalid application database role")
    if schema != "public" and not re.fullmatch(r"bmt_load_[0-9a-f]{32}", schema):
        raise ValueError("Invalid staging schema")
    if engine.dialect.name != "postgresql":
        raise ValueError("Cloud staging requires PostgreSQL")
    tables = inspect(engine).get_table_names(schema=schema)
    guard = f'"{schema}".bmt_staging_guard'
    with engine.begin() as connection:
        if tables and "bmt_staging_guard" not in tables:
            raise RuntimeError("Refusing to adopt a nonempty unowned database")
        connection.execute(text(f"CREATE TABLE IF NOT EXISTS {guard} (id integer PRIMARY KEY CHECK (id=1), owner varchar(32) NOT NULL)"))
        connection.execute(text(f"INSERT INTO {guard} (id,owner) VALUES (1,:owner) ON CONFLICT (id) DO NOTHING"), {"owner": owner})
        actual = connection.execute(text(f"SELECT owner FROM {guard} WHERE id=1 FOR UPDATE")).scalar()
        if actual != owner:
            raise RuntimeError("Staging database ownership mismatch")
    # Guard exists before upgrade, so an interrupted migration remains resumable.
    upgrade(engine)
    with engine.begin() as connection:
        for role in roles.values():
            flags = connection.execute(text("SELECT rolsuper,rolreplication,rolbypassrls FROM pg_roles WHERE rolname=:role"), {"role": role}).one_or_none()
            if flags is None or any(flags):
                raise RuntimeError("Refusing an inherently privileged application role")
            connection.execute(text(f'ALTER ROLE {identifier(role)} NOCREATEDB NOCREATEROLE'))
            if connection.execute(text("SELECT 1 FROM pg_roles WHERE rolname='cloudsqlsuperuser'")).scalar():
                connection.execute(text(f'REVOKE cloudsqlsuperuser FROM {identifier(role)}'))
    configure(engine, schema=schema, roles=roles)


def main():
    settings = Settings.from_env()
    if settings.workload_role != "migrator":
        raise ValueError("Staging setup requires the dedicated migrator workload")
    owner = os.environ.get("BMT_STAGING_OWNER", "")
    engine = make_engine(settings.database_url, settings)
    try:
        setup(engine, owner)
    finally:
        engine.dispose()
    print("Owned staging schema migrated; application role restricted")


if __name__ == "__main__":
    main()
