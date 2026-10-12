"""Previewed, atomic, audited commands for development purchase/access testing."""

import hashlib
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError

from .admin import Access
from .admin_commerce import purchase_record
from .admin_models import AdminAudit
from .commerce import (
    CATALOG,
    access_values,
    adjust_simulated_access,
    fulfill_verified,
    grant_access,
    simulator_allowed,
)
from .commerce_models import Entitlements, ProductControl, Purchase
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .track_models import digest, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["administration"])
Action = Literal["simulate_purchase", "resolve_purchase", "adjust_slots", "expire_month", "reset_ad_free"]
Outcome = Literal["approved", "pending", "declined", "cancelled"]


class Draft(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    command_id: str = Field(min_length=36, max_length=36)
    action: Action
    product_id: str | None = Field(None, max_length=40)
    outcome: Outcome | None = None
    purchase_id: str | None = Field(None, max_length=96)
    slots_delta: int | None = Field(None, ge=-1000, le=1000)


class Execute(Draft):
    preview_at: int = Field(ge=0)
    expected_hash: str = Field(pattern=r"^[0-9a-f]{64}$")
    reason: str = Field(min_length=8, max_length=500)
    acknowledged: Literal[True]


def validate_draft(body):
    try:
        command_id = str(UUID(body.command_id))
    except ValueError:
        raise HTTPException(422, "INVALID_COMMAND_ID") from None
    populated = {name for name in ("product_id", "outcome", "purchase_id", "slots_delta")
                 if getattr(body, name) is not None}
    wanted = {"simulate_purchase": {"product_id", "outcome"},
              "resolve_purchase": {"purchase_id", "outcome"}, "adjust_slots": {"slots_delta"}}.get(body.action, set())
    if populated != wanted or (body.action == "resolve_purchase" and body.outcome == "pending"):
        raise HTTPException(422, "INVALID_COMMAND_FIELDS")
    return command_id


def require_control(settings, role):
    if role != "owner":
        raise HTTPException(403, "OWNER_REQUIRED")
    if (settings.environment != "development" or not settings.dev_auth_enabled
            or not settings.purchase_simulation_enabled):
        raise HTTPException(403, "PURCHASE_SIMULATION_DISABLED")


def player_for_control(session, settings, player_id, *, lock=False):
    if lock and session.bind.dialect.name == "sqlite":
        session.execute(update(Player).where(Player.id == player_id).values(created_at=Player.created_at))
    query = select(Player).where(Player.id == player_id)
    if lock:
        query = query.with_for_update().execution_options(populate_existing=True)
    player = session.scalar(query)
    if player is None:
        raise HTTPException(404, "PLAYER_NOT_FOUND")
    if player.disabled or not simulator_allowed(session, settings, player_id):
        raise HTTPException(403, "PLAYER_NOT_ELIGIBLE_FOR_SIMULATION")
    return player


def plan(session, player, body, at, *, lock_product=False):
    values = access_values(session.get(Entitlements, player.id))
    pending = session.scalar(select(func.count()).select_from(Purchase).where(
        Purchase.player_id == player.id, Purchase.state == "pending"))
    before = {"access": values, "pending_purchases": pending}
    after = {"access": dict(values)}
    purchase = None
    if body.action == "simulate_purchase":
        if body.product_id not in CATALOG:
            raise HTTPException(422, "UNKNOWN_PRODUCT")
        query = select(ProductControl).where(ProductControl.id == body.product_id)
        product = session.scalar(query.with_for_update() if lock_product else query)
        if product is None or not product.enabled:
            raise HTTPException(409, "PRODUCT_DISABLED")
        if body.product_id.startswith("ad_free") and (values["forever"] or values["simulated_forever"]):
            raise HTTPException(409, "ALREADY_AD_FREE_FOREVER")
        if body.outcome == "pending" and pending >= 20:
            raise HTTPException(409, "RESOLVE_PENDING_PURCHASES_FIRST")
        before["product"] = {"id": product.id, "enabled": product.enabled, "revision": product.revision}
        purchase_id = "simulation-admin:" + hashlib.sha256(str(UUID(body.command_id)).encode()).hexdigest()
        if session.get(Purchase, purchase_id) is not None:
            raise HTTPException(409, "PURCHASE_ALREADY_EXISTS")
        after["purchase"] = {"id": purchase_id, "product_id": body.product_id,
            "provider": "simulation", "state": body.outcome,
            "fulfilled_at": at if body.outcome == "approved" else None}
        if body.outcome == "approved":
            after["access"] = grant_access(values, body.product_id, simulated=True, verified_at=at)
    elif body.action == "resolve_purchase":
        purchase = session.get(Purchase, body.purchase_id)
        if purchase is None or purchase.player_id != player.id or purchase.provider != "simulation":
            raise HTTPException(404, "SIMULATED_PURCHASE_NOT_FOUND")
        if purchase.state != "pending" or purchase.fulfilled_at is not None:
            raise HTTPException(409, "PURCHASE_ALREADY_RESOLVED")
        if purchase.product_id not in CATALOG:
            raise HTTPException(409, "PURCHASE_NOT_SETTLEABLE")
        before["purchase"] = purchase_record(purchase)
        after["purchase"] = {**before["purchase"], "state": body.outcome,
            "fulfilled_at": at if body.outcome == "approved" else None}
        if body.outcome == "approved":
            after["access"] = grant_access(values, purchase.product_id, simulated=True, verified_at=at)
    else:
        after["access"] = adjust_simulated_access(values, body.action, at=at, slots_delta=body.slots_delta or 0)
    return before, after, purchase


def preview_digest(player_id, body, at, before, after):
    return digest({"player_id": player_id, "command": body.model_dump(include=set(Draft.model_fields)),
        "preview_at": at, "before": before, "after": after})


@router.post("/v1/admin/players/{player_id}/development/preview")
def preview(player_id: UUID, body: Draft, request: Request, role: Access):
    require_control(request.app.state.settings, role)
    validate_draft(body)
    with request.app.state.session_factory() as session:
        player = player_for_control(session, request.app.state.settings, str(player_id))
        at = now()
        before, after, _purchase = plan(session, player, body, at)
        return {"preview_at": at, "expected_hash": preview_digest(player.id, body, at, before, after),
            "before": before, "after": after}


@router.post("/v1/admin/players/{player_id}/development/commands")
def execute(player_id: UUID, body: Execute, request: Request, role: Access):
    settings = request.app.state.settings
    require_control(settings, role)
    command_id = validate_draft(body)
    if len(body.reason.strip()) < 8:
        raise HTTPException(422, "REASON_REQUIRED")
    player_id = str(player_id)
    hashed = digest({"player_id": player_id, **body.model_dump()})
    with request.app.state.session_factory() as session:
        player = player_for_control(session, settings, player_id, lock=True)
        prior = session.scalar(select(AdminAudit).where(AdminAudit.command_id == command_id))
        if prior:
            if prior.request_hash != hashed:
                raise HTTPException(409, "COMMAND_ID_REUSED")
            return {"audit_id": prior.id, "after": prior.after}
        if not 0 <= now() - body.preview_at <= 300:
            raise HTTPException(409, "PREVIEW_EXPIRED_REFRESH_REQUIRED")
        before, after, purchase = plan(session, player, body, body.preview_at, lock_product=True)
        if preview_digest(player_id, body, body.preview_at, before, after) != body.expected_hash:
            raise HTTPException(409, "STATE_CHANGED_REFRESH_REQUIRED")
        try:
            row = session.get(Entitlements, player_id)
            if row is None:
                row = Entitlements(player_id=player_id)
                session.add(row)
                session.flush()
            if body.action == "simulate_purchase":
                purchase = Purchase(id=after["purchase"]["id"], player_id=player_id,
                    product_id=body.product_id, provider="simulation", state=body.outcome,
                    created_at=now())
                session.add(purchase)
            elif body.action == "resolve_purchase":
                purchase.state = body.outcome
            if purchase is not None and body.outcome == "approved":
                fulfill_verified(session, row, purchase, verified_at=body.preview_at)
            elif body.action not in ("simulate_purchase", "resolve_purchase"):
                for field, value in after["access"].items():
                    setattr(row, field, value)
            session.flush()
            if access_values(row) != after["access"]:
                raise RuntimeError("Development command differs from its preview")
            audit = AdminAudit(command_id=command_id, actor=role, action=body.action,
                entity_id=player_id, reason=body.reason.strip(), before=before, after=after,
                request_hash=hashed, request_id=request.state.request_id)
            session.add(audit)
            session.commit()
        except IntegrityError:
            session.rollback()
            prior = session.scalar(select(AdminAudit).where(AdminAudit.command_id == command_id))
            if prior and prior.request_hash == hashed:
                return {"audit_id": prior.id, "after": prior.after}
            raise HTTPException(409, "COMMAND_CONFLICT") from None
        return {"audit_id": audit.id, "after": after}
