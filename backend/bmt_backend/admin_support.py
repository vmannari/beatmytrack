"""Player support projections and bounded, redacted cross-domain history."""

from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import JSONResponse
from sqlalchemy import String, cast, func, literal, or_, select, union_all

from .admin import Access, record
from .admin_commerce import purchase_record
from .admin_models import AdminAudit
from .admin_ranges import during, time_range
from .commerce import access_values, catalog_products, entitlement_payload, simulator_allowed
from .commerce_models import Entitlements, PublicationSlot, Purchase
from .cursors import decode_cursor, encode_cursor
from .identity_models import Identity, Player
from .middleware import ParsedJSONRoute
from .resume_models import ResumeGrant, ResumeRace, ResumeReceipt, ResumeWallet
from .track_models import Run, digest, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["administration"])
Window = Annotated[tuple[int, int] | None, Depends(time_range)]
HistoryKind = Literal["all", "purchase", "publication", "resume", "grant", "race", "audit"]
SOURCES = {
    "purchase": (Purchase, "id"), "publication": (PublicationSlot, "version_id"),
    "resume": (ResumeReceipt, "id"), "grant": (ResumeGrant, "id"),
    "race": (Run, "id"), "audit": (AdminAudit, "id"),
}


def get_player(session, player_id):
    player = session.get(Player, str(player_id))
    if player is None:
        raise HTTPException(404, "PLAYER_NOT_FOUND")
    return player


@router.get("/v1/admin/players/{player_id}/support")
def support(player_id: UUID, request: Request, role: Access):
    with request.app.state.session_factory() as session:
        player = get_player(session, player_id)
        row = session.get(Entitlements, player.id)
        wallet = session.get(ResumeWallet, player.id)
        values = access_values(row)
        effective_row = row or Entitlements(player_id=player.id, **values)
        settings = request.app.state.settings
        eligible = simulator_allowed(session, settings, player.id) and not player.disabled
        publications = session.scalar(select(func.count()).select_from(PublicationSlot).where(
            PublicationSlot.player_id == player.id))
        pending = session.scalar(select(func.count()).select_from(Purchase).where(
            Purchase.player_id == player.id, Purchase.state == "pending"))
        return {"player": {**record("players", player), "country_code": player.country_code,
                    "providers": sorted(set(session.scalars(select(Identity.provider).where(Identity.player_id == player.id))))},
            "access": values, "initialized": row is not None,
            "effective": entitlement_payload(session, settings, effective_row),
            "resumes": {"banked": wallet.balance if wallet else 0,
                "daily_free_available": not wallet or wallet.free_day < now() // 86400},
            "consumed_publication_slots": publications, "pending_purchases": pending,
            "products": catalog_products(session), "as_of": now(),
            "development_controls": {"editable": role == "owner" and eligible,
                "configured": settings.purchase_simulation_enabled and settings.environment == "development"
                    and settings.dev_auth_enabled,
                "eligible": bool(eligible), "role": role}}


def projection(kind, model, key):
    return select(literal(kind).label("kind"), cast(getattr(model, key), String).label("id"),
        model.created_at.label("time"), (literal(kind + ":") + cast(getattr(model, key), String)).label("key"))


def history_rows(session, player_id, kind, window, q, cursor, limit, state):
    scope = digest({"player": player_id, "kind": kind, "window": window, "q": q, "state": state})
    queries = []
    for source, (model, identity) in SOURCES.items():
        if kind != "all" and kind != source:
            continue
        query = projection(source, model, identity)
        if source == "resume":
            query = query.join(ResumeRace, ResumeRace.id == ResumeReceipt.race_id).where(ResumeRace.player_id == player_id)
        else:
            field = AdminAudit.entity_id if source == "audit" else model.player_id
            query = query.where(field == player_id)
        query = query.where(*during(model.created_at, window))
        if q:
            fields = [getattr(model, identity)]
            if source == "audit":
                fields += [AdminAudit.command_id, AdminAudit.request_id, AdminAudit.action]
            elif source == "race":
                fields += [Run.failure_code, Run.ticket_id]
            elif source == "purchase":
                fields += [Purchase.product_id]
            query = query.where(or_(*(field.icontains(q, autoescape=True) for field in fields)))
        if state:
            if source == "race":
                query = query.where(Run.status == state)
            elif source == "purchase":
                query = query.where(Purchase.state == state)
            else:
                continue
        queries.append(query)
    if not queries:
        return {"items": [], "next_cursor": None, "limit": limit, "range": window}
    combined = union_all(*queries).subquery()
    query = select(combined)
    if cursor:
        anchor = decode_cursor(cursor)
        if (anchor.get("scope") != scope or type(anchor.get("time")) is not int or anchor["time"] < 0
                or not isinstance(anchor.get("key"), str) or not 1 <= len(anchor["key"]) <= 200):
            raise HTTPException(422, "INVALID_CURSOR")
        query = query.where((combined.c.time < anchor["time"]) |
            ((combined.c.time == anchor["time"]) & (combined.c.key > anchor["key"])))
    anchors = session.execute(query.order_by(combined.c.time.desc(), combined.c.key).limit(limit + 1)).mappings().all()
    more = len(anchors) > limit
    anchors = anchors[:limit]
    evidence = {}
    for source, (model, identity) in SOURCES.items():
        ids = [a["id"] for a in anchors if a["kind"] == source]
        if ids:
            evidence[source] = {str(getattr(row, identity)): row for row in session.scalars(
                select(model).where(getattr(model, identity).in_(ids)))}
    items = []
    for anchor in anchors:
        source, identity = anchor["kind"], anchor["id"]
        row = evidence[source].get(identity)
        if row is None:
            # Retention can remove an old attempt between bounded read queries.
            continue
        if source == "purchase":
            data = purchase_record(row)
        elif source in ("race", "audit"):
            data = record("races" if source == "race" else "audit", row)
            if source == "audit":
                data["command_id"] = row.command_id
            else:
                data["ticket_id"] = row.ticket_id
        elif source == "publication":
            data = {"version_id": row.version_id, "source": row.source, "created_at": row.created_at}
        elif source == "grant":
            data = {"id": row.id, "source": row.source, "quantity": row.quantity, "created_at": row.created_at}
        else:
            data = {name: getattr(row, name) for name in ("id", "race_id", "ordinal", "source",
                "from_tick", "to_tick", "settled", "refunded", "created_at")}
        items.append({"kind": source, "id": identity, "created_at": anchor["time"], "record": data})
    return {"items": items, "limit": limit, "range": window,
        "next_cursor": encode_cursor({"scope": scope, "time": anchors[-1]["time"], "key": anchors[-1]["key"]}) if more else None}


@router.get("/v1/admin/players/{player_id}/history")
def history(player_id: UUID, request: Request, role: Access, window: Window,
    kind: HistoryKind = "all", q: str = Query("", max_length=100),
    state: str = Query("", max_length=32), cursor: str = Query("", max_length=400),
    limit: int = Query(25, ge=1, le=100), download: bool = False):
    with request.app.state.session_factory() as session:
        get_player(session, player_id)
        data = history_rows(session, str(player_id), kind, window, q, cursor, limit, state)
        data.update(player_id=str(player_id), as_of=now())
        if download:
            return JSONResponse(data, headers={"Content-Disposition": 'attachment; filename="player-history.json"'})
        return data
