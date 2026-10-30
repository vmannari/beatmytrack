"""Bounded purchase inspection and owner-only, audited product availability."""
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import or_, select, update
from sqlalchemy.exc import IntegrityError

from .admin import Access, Window
from .admin_models import AdminAudit
from .admin_ranges import during
from .commerce import CATALOG, catalog_products
from .commerce_models import ProductControl, Purchase
from .cursors import decode_cursor, encode_cursor
from .middleware import ParsedJSONRoute
from .track_models import digest, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["administration"])


def purchase_record(row):
    return {"id": row.id, "player_id": row.player_id, "product_id": row.product_id,
        "provider": row.provider, "state": row.state, "created_at": row.created_at,
        "fulfilled_at": row.fulfilled_at, "simulated": row.provider == "simulation",
        "test_adjustment": row.id.startswith("simulation-adjustment:")}


@router.get("/v1/admin/purchases")
def purchases(request: Request, role: Access, window: Window, player_id: UUID | None = None,
              state: Literal["", "pending", "approved", "declined", "cancelled"] = "",
              provider: Literal["", "simulation", "google_play"] = "",
              cursor: str = Query("", max_length=400), limit: int = Query(25, ge=1, le=100),
              q: str = Query("", max_length=100)):
    scope = digest({"player_id": str(player_id) if player_id else "", "state": state,
        "provider": provider, "window": window, "q": q})
    conditions = during(Purchase.created_at, window)
    if q:
        conditions.append(or_(Purchase.id.icontains(q, autoescape=True),
            Purchase.product_id.icontains(q, autoescape=True)))
    if player_id:
        conditions.append(Purchase.player_id == str(player_id))
    if state:
        conditions.append(Purchase.state == state)
    if provider:
        conditions.append(Purchase.provider == provider)
    if cursor:
        anchor = decode_cursor(cursor)
        if (anchor.get("scope") != scope or type(anchor.get("time")) is not int
                or anchor["time"] < 0 or not isinstance(anchor.get("id"), str)
                or not 1 <= len(anchor["id"]) <= 96):
            raise HTTPException(422, "INVALID_CURSOR")
        conditions.append((Purchase.created_at < anchor["time"]) |
            ((Purchase.created_at == anchor["time"]) & (Purchase.id > anchor["id"])))
    with request.app.state.session_factory() as session:
        rows = list(session.scalars(select(Purchase).where(*conditions)
            .order_by(Purchase.created_at.desc(), Purchase.id).limit(limit+1)))
        more = len(rows) > limit
        rows = rows[:limit]
        return {"items": [purchase_record(row) for row in rows], "limit": limit,
            "next_cursor": encode_cursor({"scope":scope,"time":rows[-1].created_at,"id":rows[-1].id}) if more else None}


@router.get("/v1/admin/products")
def products(request: Request, role: Access):
    with request.app.state.session_factory() as session:
        return {"items": catalog_products(session),
            "editable": role == "owner" and request.app.state.settings.environment in ("development", "test")}


class ProductCommand(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    command_id: str = Field(min_length=36, max_length=36)
    expected_revision: int = Field(ge=0)
    enabled: bool
    reason: str = Field(min_length=8, max_length=500)
    acknowledged: Literal[True]


@router.post("/v1/admin/products/{product_id}")
def configure_product(product_id: str, body: ProductCommand, request: Request, role: Access):
    if role != "owner":
        raise HTTPException(403, "OWNER_REQUIRED")
    if request.app.state.settings.environment not in ("development", "test"):
        raise HTTPException(403, "TEST_CONFIGURATION_ONLY")
    if product_id not in CATALOG:
        raise HTTPException(404, "PRODUCT_NOT_FOUND")
    if len(body.reason.strip()) < 8:
        raise HTTPException(422, "REASON_REQUIRED")
    try:
        command_id = str(UUID(body.command_id))
    except ValueError:
        raise HTTPException(422, "INVALID_COMMAND_ID") from None
    hashed = digest({"product_id":product_id, **body.model_dump()})
    with request.app.state.session_factory() as session:
        prior = session.scalar(select(AdminAudit).where(AdminAudit.command_id == command_id))
        if prior:
            if prior.request_hash != hashed:
                raise HTTPException(409, "COMMAND_ID_REUSED")
            return {"audit_id":prior.id,"after":prior.after}
        row = session.get(ProductControl, product_id)
        if row is None:
            raise HTTPException(404, "PRODUCT_NOT_FOUND")
        before = {"enabled":row.enabled,"revision":row.revision}
        changed = session.execute(update(ProductControl).where(ProductControl.id == product_id,
            ProductControl.revision == body.expected_revision).values(enabled=body.enabled,
                revision=ProductControl.revision+1, updated_at=now()))
        if changed.rowcount != 1:
            prior = session.scalar(select(AdminAudit).where(AdminAudit.command_id == command_id))
            if prior and prior.request_hash == hashed:
                return {"audit_id":prior.id,"after":prior.after}
            raise HTTPException(409, "STATE_CHANGED_REFRESH_REQUIRED")
        after = {"enabled":body.enabled,"revision":body.expected_revision+1}
        audit = AdminAudit(command_id=command_id, actor=role, action="product_availability",
            entity_id=product_id, reason=body.reason.strip(), before=before, after=after,
            request_hash=hashed, request_id=request.state.request_id)
        session.add(audit)
        try:
            session.commit()
        except IntegrityError:
            session.rollback()
            prior = session.scalar(select(AdminAudit).where(AdminAudit.command_id == command_id))
            if prior and prior.request_hash == hashed:
                return {"audit_id":prior.id,"after":prior.after}
            raise HTTPException(409, "COMMAND_CONFLICT") from None
        return {"audit_id":audit.id,"after":after}
