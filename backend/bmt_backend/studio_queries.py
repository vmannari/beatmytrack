"""A reporting response reads one consistent snapshot without changing authority."""
from sqlalchemy import text


def read_snapshot(session):
    if session.bind.dialect.name == "postgresql":
        session.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY"))
    elif session.bind.dialect.name == "sqlite":
        session.execute(text("BEGIN"))
