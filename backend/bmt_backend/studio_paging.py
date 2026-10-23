"""Count-free, scope-fenced Studio pages with indexed forward/backward cursors."""
import math
import re
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import and_, or_, tuple_

from .cursors import decode_cursor, encode_cursor


def identifier(value):
    """Canonical IDs use equality; never a leading-wildcard text search."""
    try:
        return str(UUID(value)) if len(value) == 36 else (value.lower() if re.fullmatch(r"[0-9a-fA-F]{32}|[0-9a-fA-F]{64}", value) else None)
    except ValueError:
        return None


def page(session, query, order, identity, *, scope, cursor, offset, limit,
         descending=True, identity_descending=None, numeric=False, nullable=False):
    """The selected entity is first; its SQL sort value is fetched once per row.

    Offset remains a bounded compatibility input. Cursor pages never use OFFSET
    or COUNT, including when navigating back. Mutable names/ranks can reorder
    records; these are current investigation pages, not immutable exports.
    """
    identity_descending = descending if identity_descending is None else identity_descending
    backwards = False
    if cursor:
        anchor = decode_cursor(cursor, max_length=2048)
        value, key = anchor.get("value"), anchor.get("id")
        valid_value = (type(value) in (int, float) and math.isfinite(value)) if numeric else (
            isinstance(value, str) and len(value) <= 200)
        valid_value = valid_value or nullable and value is None
        if (anchor.get("scope") != scope or not valid_value or not isinstance(key, str)
                or not 1 <= len(key) <= 128 or type(anchor.get("position")) is not int
                or not 0 <= anchor["position"] <= 10**12 or anchor.get("move") not in ("next", "previous")):
            raise HTTPException(422, "INVALID_CURSOR")
        offset, backwards = anchor["position"], anchor["move"] == "previous"
        sort_less = descending != backwards
        id_less = identity_descending != backwards
        id_condition = identity < key if id_less else identity > key
        if value is None:
            condition = and_(order.is_(None), id_condition)
            if backwards:
                condition = or_(order.is_not(None), condition)
        else:
            # A row comparison is an index range. An OR expansion may instead
            # become an index filter that revisits every earlier page in PG.
            if descending == identity_descending:
                condition = tuple_(order, identity) < (value, key) if sort_less else tuple_(order, identity) > (value, key)
            else:
                condition = or_(order < value if sort_less else order > value, and_(order == value, id_condition))
            if nullable and not backwards:
                condition = or_(condition, order.is_(None))
        query = query.where(condition)
    ordered = order.desc() if descending != backwards else order.asc()
    if nullable:
        ordered = ordered.nulls_first() if backwards else ordered.nulls_last()
    query = query.add_columns(order.label("studio_page_value")).order_by(ordered,
        identity.desc() if identity_descending != backwards else identity.asc())
    if not cursor and offset:
        query = query.offset(offset)
    rows = list(session.execute(query.limit(limit + 1)))
    more = len(rows) > limit
    rows = rows[:limit]
    if backwards:
        rows.reverse()
    has_previous = more if backwards else bool(cursor or offset)
    has_next = bool(rows) if backwards else more

    def token(row, move, position):
        return encode_cursor({"scope": scope, "value": row[-1], "id": row[0].id,
                              "move": move, "position": position})

    return [tuple(row[:-1]) for row in rows], {
        "offset": offset, "limit": limit, "has_more": has_next,
        "total": len(rows) if not cursor and not offset and not more else None,
        "next_cursor": token(rows[-1], "next", offset + len(rows)) if rows and has_next else None,
        "previous_cursor": token(rows[0], "previous", max(0, offset - limit)) if rows and has_previous else None,
    }
