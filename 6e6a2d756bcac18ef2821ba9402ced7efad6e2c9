"""Constant JSON paths shared by retention predicates and their indexes."""
from sqlalchemy import JSON, literal

FIELDS = ("run_id", "ticket_id", "race_id", "receipt_id")


def reference(response, field):
    if field not in FIELDS:
        raise ValueError("Unknown receipt reference")
    # Parameterized paths cannot match SQLite expression indexes. Only these
    # four fixed field names may become SQL literals.
    key = literal(field, type_=JSON.JSONStrIndexType(), literal_execute=True)
    return response[key].as_string()
