"""Explicit staging-only database ownership, migrations and least-privilege grants."""
import os
import re

from sqlalchemy import inspect, text

from .config import Settings
from .db import make_engine
from .migrate import upgrade


def setup(engine, owner, app_role="bmt", schema="public"):
    if not re.fullmatch(r"[0-9a-f]{32}", owner):
        raise ValueError("Staging needs its explicit ownership identifier")
    if not re.fullmatch(r"[a-z][a-z0-9_]{2,62}", app_role) or app_role in ("postgres", "cloudsqlsuperuser"):
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
        flags = connection.execute(text("SELECT rolsuper,rolreplication,rolbypassrls FROM pg_roles WHERE rolname=:role"), {"role": app_role}).one_or_none()
        if flags is None or any(flags):
            raise RuntimeError("Refusing an inherently privileged application role")
        # Cloud SQL's managed administrator is not a PostgreSQL superuser; do not
        # attempt superuser-only attribute changes even when setting them false.
        connection.execute(text(f'ALTER ROLE "{app_role}" NOCREATEDB NOCREATEROLE'))
        if connection.execute(text("SELECT 1 FROM pg_roles WHERE rolname='cloudsqlsuperuser'")).scalar():
            connection.execute(text(f'REVOKE cloudsqlsuperuser FROM "{app_role}"'))
        connection.execute(text(f'GRANT USAGE ON SCHEMA "{schema}" TO "{app_role}"'))
        connection.execute(text(f'GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA "{schema}" TO "{app_role}"'))
        connection.execute(text(f'GRANT USAGE,SELECT,UPDATE ON ALL SEQUENCES IN SCHEMA "{schema}" TO "{app_role}"'))
        connection.execute(text(f'ALTER DEFAULT PRIVILEGES IN SCHEMA "{schema}" GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO "{app_role}"'))
        connection.execute(text(f'ALTER DEFAULT PRIVILEGES IN SCHEMA "{schema}" GRANT USAGE,SELECT,UPDATE ON SEQUENCES TO "{app_role}"'))
        connection.execute(text(f'REVOKE ALL ON {guard} FROM "{app_role}"'))


def main():
    settings = Settings.from_env()
    owner = os.environ.get("BMT_STAGING_OWNER", "")
    engine = make_engine(settings.database_url, settings)
    try:
        setup(engine, owner)
    finally:
        engine.dispose()
    print("Owned staging schema migrated; application role restricted")


if __name__ == "__main__":
    main()
