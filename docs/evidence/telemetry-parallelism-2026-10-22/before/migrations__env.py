from alembic import context
from sqlalchemy import text

from bmt_backend import (  # noqa: F401
    achievement_models,
    admin_models,
    challenge_models,
    commerce_models,
    community_models,
    discovery,
    discovery_models,
    economy_models,
    identity_models,
    network_models,
    news_models,
    object_models,
    privacy_models,
    publication_models,
    quality_models,
    race_statistics_models,
    resume_models,
    rivalry_models,
    studio_case_models,
    studio_platform_models,
    telemetry_models,
    test_driver_models,
    track_models,
)
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
