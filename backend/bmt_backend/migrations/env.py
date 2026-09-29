from alembic import context
from sqlalchemy import text

from bmt_backend import admin_models, identity_models, resume_models, track_models  # noqa: F401
from bmt_backend.db import Base

engine = context.config.attributes["engine"]
with engine.connect() as connection:
    if connection.dialect.name == "postgresql":
        connection.execute(text("SELECT pg_advisory_lock(67182001)"))
        connection.commit()
    try:
        context.configure(connection=connection, target_metadata=Base.metadata, compare_type=True)
        with context.begin_transaction():
            context.run_migrations()
    finally:
        if connection.dialect.name == "postgresql":
            connection.rollback()
            connection.execute(text("SELECT pg_advisory_unlock(67182001)"))
            connection.commit()
