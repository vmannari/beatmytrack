"""Explicit one-shot migrations; web and worker processes never mutate the schema."""

from pathlib import Path

from alembic import command
from alembic.config import Config

from .config import Settings
from .db import make_engine


def configuration(engine) -> Config:
    config = Config()
    config.set_main_option("script_location", str(Path(__file__).with_name("migrations")))
    config.attributes["engine"] = engine
    return config


def upgrade(engine):
    command.upgrade(configuration(engine), "head")


def main():
    engine = make_engine(Settings.from_env().database_url)
    upgrade(engine)
    engine.dispose()
    print("Database migrated to current revision")


if __name__ == "__main__":
    main()
