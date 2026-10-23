"""Owner support grants, separate from billing and development simulation."""

from typing import Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError

from .admin import Access
from .admin_models import AdminAudit
from .commerce import CATALOG, access_values, grant_access
from .commerce_models import Entitlements
from .economy import MAX_BALANCE, PRICES, locked_wallet
from .economy_models import CoinWallet, CosmeticUnlock
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .resume_models import ResumeWallet
from .resumes import grant_verified
from .track_models import digest, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["administration"])


def grant_catalogue():
    return [
        {"id": "publishing_slots", "title": "Track publishing slots", "group": "Track slots", "max_quantity": 1000},
        *[{"id": key, "title": item["title"], "group": "Store products", "max_quantity": 1}
          for key, item in CATALOG.items()],
        {"id": "resumes", "title": "Banked resumes", "group": "Resumes", "max_quantity": 1000},
        *[{"id": key, "title": " / ".join(part.replace("_", " ").title() for part in key.split("/")[1:]),
           "group": "Customisation kits" if key.startswith("kit/") else "Liveries", "max_quantity": 1}
          for key in sorted(PRICES)],
    ]


def grant_context(session, player, role):
    wallet = session.get(CoinWallet, player.id)
    return {"editable": role == "owner" and not player.disabled and player.deleted_at is None,
        "products": grant_catalogue(), "coin_balance": wallet.balance if wallet else 0,
        "owned": list(session.scalars(select(CosmeticUnlock.item_id)
            .where(CosmeticUnlock.player_id == player.id).order_by(CosmeticUnlock.item_id)))}


class Draft(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    command_id: str = Field(min_length=36, max_length=36)
    product_id: str = Field(min_length=1, max_length=100)
    quantity: int = Field(default=1, ge=1, le=1000)


class Execute(Draft):
    preview_at: int = Field(ge=0)
    expected_hash: str = Field(pattern=r"^[0-9a-f]{64}$")
    reason: str = Field(min_length=8, max_length=500)
    acknowledged: Literal[True]


def validate(body, role):
    if role != "owner":
        raise HTTPException(403, "OWNER_REQUIRED")
    try:
        command_id = str(UUID(body.command_id))
    except ValueError:
        raise HTTPException(422, "INVALID_COMMAND_ID") from None
    products = {product["id"]: product for product in grant_catalogue()}
    product = products.get(body.product_id)
    if product is None:
        raise HTTPException(422, "UNKNOWN_GRANT_PRODUCT")
    if body.quantity > product["max_quantity"]:
        raise HTTPException(422, "INVALID_GRANT_QUANTITY")
    return command_id, product


def target(session, player_id, *, lock=False):
    if lock and session.bind.dialect.name == "sqlite":
        session.execute(update(Player).where(Player.id == player_id).values(id=Player.id))
    query = select(Player).where(Player.id == player_id)
    if lock:
        query = query.with_for_update().execution_options(populate_existing=True)
    player = session.scalar(query)
    if player is None:
        raise HTTPException(404, "PLAYER_NOT_FOUND")
    if player.disabled or player.deleted_at is not None:
        raise HTTPException(409, "PLAYER_NOT_ELIGIBLE_FOR_GRANT")
    return player


def plan(session, player_id, body, at):
    product = body.product_id
    if product == "resumes":
        wallet = session.get(ResumeWallet, player_id)
        before = {"banked_resumes": wallet.balance if wallet else 0}
        after = {"banked_resumes": before["banked_resumes"] + body.quantity}
        if after["banked_resumes"] > MAX_BALANCE:
            raise HTTPException(409, "GRANT_CAPACITY_EXCEEDED")
    elif product in PRICES:
        if session.get(CosmeticUnlock, (player_id, product)) is not None:
            raise HTTPException(409, "COSMETIC_ALREADY_OWNED")
        wallet = session.get(CoinWallet, player_id)
        before = {"owned": False, "coin_balance": wallet.balance if wallet else 0,
                  "wallet_revision": wallet.revision if wallet else 0}
        after = {**before, "owned": True, "wallet_revision": before["wallet_revision"] + 1}
    else:
        before = access_values(session.get(Entitlements, player_id))
        if product == "publishing_slots":
            after = {**before, "slots": before["slots"] + body.quantity}
        else:
            if product.startswith("ad_free") and before["forever"]:
                raise HTTPException(409, "ALREADY_AD_FREE_FOREVER")
            after = grant_access(before, product, simulated=False, verified_at=at)
        if after["slots"] > MAX_BALANCE:
            raise HTTPException(409, "GRANT_CAPACITY_EXCEEDED")
    return before, after


def preview_digest(player_id, body, at, before, after):
    return digest({"player_id": player_id, "command": body.model_dump(include=set(Draft.model_fields)),
        "preview_at": at, "before": before, "after": after})


@router.post("/v1/admin/players/{player_id}/grants/preview")
def preview(player_id: UUID, body: Draft, request: Request, role: Access):
    _command_id, product = validate(body, role)
    with request.app.state.session_factory() as session:
        player = target(session, str(player_id))
        at = now()
        before, after = plan(session, player.id, body, at)
        return {"player": {"id": player.id, "display_name": player.display_name}, "product": product,
            "quantity": body.quantity, "preview_at": at, "before": before, "after": after,
            "expected_hash": preview_digest(player.id, body, at, before, after)}


@router.post("/v1/admin/players/{player_id}/grants/commands")
def execute(player_id: UUID, body: Execute, request: Request, role: Access):
    command_id, product = validate(body, role)
    if len(body.reason.strip()) < 8:
        raise HTTPException(422, "REASON_REQUIRED")
    player_id = str(player_id)
    hashed = digest({"player_id": player_id, **body.model_dump()})
    with request.app.state.session_factory() as session:
        target(session, player_id, lock=True)
        prior = session.scalar(select(AdminAudit).where(AdminAudit.command_id == command_id))
        if prior:
            if prior.request_hash != hashed:
                raise HTTPException(409, "COMMAND_ID_REUSED")
            return {"audit_id": prior.id, "after": prior.after}
        if not 0 <= now() - body.preview_at <= 300:
            raise HTTPException(409, "PREVIEW_EXPIRED_REFRESH_REQUIRED")
        before, after = plan(session, player_id, body, body.preview_at)
        if preview_digest(player_id, body, body.preview_at, before, after) != body.expected_hash:
            raise HTTPException(409, "STATE_CHANGED_REFRESH_REQUIRED")
        try:
            if body.product_id == "resumes":
                grant_verified(session, player_id, "award", "admin/" + command_id, body.quantity)
            elif body.product_id in PRICES:
                wallet = locked_wallet(session, player_id)
                wallet.revision += 1
                session.add(CosmeticUnlock(player_id=player_id, item_id=body.product_id, price=0))
            else:
                row = session.get(Entitlements, player_id)
                if row is None:
                    row = Entitlements(player_id=player_id)
                    session.add(row)
                for field, value in after.items():
                    setattr(row, field, value)
            recorded = {"product_id": body.product_id, "title": product["title"],
                "quantity": body.quantity, "source": "support_grant", "state": after}
            audit = AdminAudit(command_id=command_id, actor=role, action="player_grant",
                entity_id=player_id, reason=body.reason.strip(), before=before, after=recorded,
                request_hash=hashed, request_id=request.state.request_id)
            session.add(audit)
            session.commit()
        except IntegrityError:
            session.rollback()
            prior = session.scalar(select(AdminAudit).where(AdminAudit.command_id == command_id))
            if prior and prior.request_hash == hashed:
                return {"audit_id": prior.id, "after": prior.after}
            raise HTTPException(409, "COMMAND_CONFLICT") from None
        return {"audit_id": audit.id, "after": recorded}
