from collections.abc import Generator

from fastapi import Request
from sqlalchemy import create_engine, event
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker
from sqlalchemy.pool import StaticPool


class Base(DeclarativeBase):
    pass


def make_engine(url: str, settings=None, *, schema=""):
    if url.startswith("sqlite"):
        options = {"connect_args": {"check_same_thread": False}}
        if url.endswith(":memory:") or url == "sqlite://":
            options["poolclass"] = StaticPool
        engine = create_engine(url, hide_parameters=True, **options)

        @event.listens_for(engine, "connect")
        def configure_sqlite(connection, _):
            connection.execute("PRAGMA foreign_keys=ON")

        return engine
    import re
    if schema and not re.fullmatch(r"bmt_load_[0-9a-f]{32}",schema):
        raise ValueError("Load tests require a generated isolated schema")
    timeout = getattr(settings, "database_statement_timeout_ms", 10000)
    options = f"-c statement_timeout={timeout} -c lock_timeout=2000 -c idle_in_transaction_session_timeout=15000"
    if schema:
        options += f" -c search_path={schema}"
    return create_engine(
        url,
        hide_parameters=True,
        pool_pre_ping=True,
        pool_size=getattr(settings, "database_pool_size", 4),
        max_overflow=getattr(settings, "database_pool_overflow", 0),
        pool_timeout=getattr(settings, "database_pool_timeout_seconds", 3),
        connect_args={"connect_timeout": 3, "options":options},
    )


def make_session_factory(engine):
    return sessionmaker(engine, expire_on_commit=False)


def get_session(request: Request) -> Generator[Session, None, None]:
    with request.app.state.session_factory() as session:
        yield session
