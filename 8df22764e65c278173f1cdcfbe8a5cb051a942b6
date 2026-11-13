"""Store-independent fulfillment and explicitly isolated development simulation.

There is deliberately no public endpoint accepting a client-claimed paid receipt.
A future store adapter must verify provider proof before using fulfill_verified.
"""
import calendar
import hashlib
from datetime import datetime, timezone
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, select, update

from .commerce_models import Entitlements, ProductControl, PublicationSlot, Purchase
from .identity_models import Identity, Player, now
from .middleware import ParsedJSONRoute
from .tracks import DB, Auth
from .usernames import username_key

router = APIRouter(route_class=ParsedJSONRoute, tags=["entitlements"])
CATALOG = {
    "creator_slot_1": {"title": "1 publishing slot", "slots": 1, "price_eur": "0.99", "kind": "consumable"},
    "creator_slots_5": {"title": "5 publishing slots", "slots": 5, "price_eur": "3.49", "kind": "consumable"},
    "creator_slots_10": {"title": "10 publishing slots", "slots": 10, "price_eur": "5.99", "kind": "consumable"},
    "ad_free_month": {"title": "One month ad-free", "slots": 0, "price_eur": "3.49", "kind": "consumable"},
    "ad_free_forever": {"title": "Forever ad-free", "slots": 0, "price_eur": "9.99", "kind": "non_consumable"},
}


def catalog_products(session):
    controls = {row.id: row for row in session.scalars(select(ProductControl).where(ProductControl.id.in_(CATALOG)))}
    return [{"id": sku, **spec, "enabled": controls[sku].enabled if sku in controls else False,
        "revision": controls[sku].revision if sku in controls else 0} for sku, spec in CATALOG.items()]


@router.get("/store/products")
def products(request: Request, session: DB):
    return {"products": catalog_products(session), "store_available": False,
        "simulation_configured": request.app.state.settings.purchase_simulation_enabled}


def simulator_allowed(session, settings, player_id):
    if not (settings is not None and settings.purchase_simulation_enabled
            and settings.environment == "development" and settings.dev_auth_enabled):
        return False
    if session.bind.dialect.name == "postgresql" and settings.workload_role == "worker":
        return session.scalar(select(func.bmt_has_development_identity(player_id)))
    return session.scalar(select(Identity.id).where(
        Identity.player_id == player_id, Identity.provider == "development")) is not None


def gift_recipient(session, buyer_id, recipient_id, product_id, *, settings=None, simulated=False):
    if recipient_id is None:
        return None
    if CATALOG.get(product_id, {}).get("slots", 0) == 0:
        raise HTTPException(422, "ONLY_TRACK_SLOTS_CAN_BE_GIFTED")
    if recipient_id == buyer_id:
        raise HTTPException(422, "CANNOT_GIFT_YOURSELF")
    recipient = session.get(Player, recipient_id)
    if (recipient is None or recipient.disabled or recipient.deleted_at is not None
            or recipient.needs_username or recipient.is_test_driver):
        raise HTTPException(404, "GIFT_RECIPIENT_UNAVAILABLE")
    if simulated and not simulator_allowed(session, settings, recipient_id):
        raise HTTPException(409, "GIFT_RECIPIENT_NOT_ELIGIBLE_FOR_SIMULATION")
    return recipient


def lock_purchase_accounts(session, buyer_id, recipient_id=None):
    # Opposite-direction gifts acquire Player locks in the same order.
    if recipient_id is not None:
        recipient = session.get(Player, recipient_id)
        if recipient is None:
            raise HTTPException(404, "GIFT_RECIPIENT_UNAVAILABLE")
    return {identity: lock_entitlements(session, identity, allow_inactive=identity != buyer_id)
        for identity in sorted({buyer_id, recipient_id} - {None})}


@router.get("/store/gift-recipient")
def find_gift_recipient(session: DB, player: Auth, username: str = Query(min_length=1, max_length=40)):
    recipient = session.scalar(select(Player).where(Player.username_key == username_key(username)))
    if recipient is None:
        raise HTTPException(404, "GIFT_RECIPIENT_UNAVAILABLE")
    gift_recipient(session, player.id, recipient.id, "creator_slot_1")
    return {"id": recipient.id, "display_name": recipient.display_name}


def lock_entitlements(session, player_id, *, allow_inactive=False):
    # SQLite's FOR UPDATE is ignored. Reserve its writer before reading balances
    # so the same tests also exercise concurrent development-server purchases.
    if session.bind.dialect.name == "sqlite":
        session.execute(update(Player).where(Player.id == player_id).values(created_at=Player.created_at))
    player = session.scalar(select(Player).where(Player.id == player_id).with_for_update()
        .execution_options(populate_existing=True))
    if player is None or (not allow_inactive and (player.disabled or player.deleted_at is not None)):
        raise HTTPException(401, "INVALID_SESSION")
    row = session.get(Entitlements, player_id)
    if row is None:
        row = Entitlements(player_id=player_id)
        session.add(row)
        session.flush()
    return row


def entitlement_payload(session, settings, row):
    simulated = simulator_allowed(session, settings, row.player_id)
    until = max(row.ad_free_until, row.simulated_ad_free_until if simulated else 0)
    forever = row.forever or (simulated and row.simulated_forever)
    return {"publishing_slots": row.slots + (row.simulated_slots if simulated else 0),
        "ad_free": forever or until > now(), "ad_free_until": until, "ad_free_forever": bool(forever),
        "free_rewinds": forever or until > now(), "max_rewinds_per_race": 3,
        "purchase_simulation": bool(simulated), "store_available": False, "server_now": now()}


def add_month(timestamp):
    date = datetime.fromtimestamp(timestamp, timezone.utc)
    year, month = date.year + (date.month == 12), date.month % 12 + 1
    day = min(date.day, calendar.monthrange(year, month)[1])
    return int(date.replace(year=year, month=month, day=day).timestamp())


ACCESS_FIELDS = (
    "slots", "simulated_slots", "ad_free_until", "simulated_ad_free_until", "forever", "simulated_forever",
)


def access_values(row):
    """A read must not initialize a wallet or award a second initial allowance."""
    return ({name: getattr(row, name) for name in ACCESS_FIELDS} if row is not None else
        {"slots": 1, "simulated_slots": 0, "ad_free_until": 0, "simulated_ad_free_until": 0,
             "forever": False, "simulated_forever": False})


def grant_access(values, product_id, *, simulated, verified_at):
    result = dict(values)
    spec = CATALOG[product_id]
    if spec["slots"]:
        field = "simulated_slots" if simulated else "slots"
        result[field] += spec["slots"]
    elif product_id == "ad_free_month":
        field = "simulated_ad_free_until" if simulated else "ad_free_until"
        result[field] = add_month(max(result[field], verified_at))
    else:
        result["simulated_forever" if simulated else "forever"] = True
    return result


def adjust_simulated_access(values, action, *, at, slots_delta=0):
    result = dict(values)
    if action == "adjust_slots":
        if slots_delta == 0 or not 0 <= result["simulated_slots"] + slots_delta <= 1000000:
            raise HTTPException(422, "INVALID_REMAINING_SIMULATED_SLOTS")
        result["simulated_slots"] += slots_delta
    elif action in ("expire_month", "reset_ad_free"):
        result["simulated_ad_free_until"] = min(result["simulated_ad_free_until"], at)
        if action == "reset_ad_free":
            result["simulated_forever"] = False
    else:
        raise HTTPException(422, "INVALID_SIMULATION_ACTION")
    return result


def fulfill_verified(session, row, purchase, *, verified_at):
    """Caller verifies proof/account/product; transaction owns grant + permanent token ledger."""
    if purchase.product_id not in CATALOG or purchase.provider not in ("simulation", "google_play"):
        raise ValueError("Unknown verified product/provider")
    if (purchase.recipient_player_id or purchase.player_id) != row.player_id:
        raise HTTPException(409, "PURCHASE_ACCOUNT_MISMATCH")
    if purchase.recipient_player_id and not CATALOG[purchase.product_id]["slots"]:
        raise HTTPException(422, "ONLY_TRACK_SLOTS_CAN_BE_GIFTED")
    if purchase.fulfilled_at is not None:
        return
    if purchase.state != "approved":
        raise HTTPException(409, "PURCHASE_NOT_APPROVED")
    for field, value in grant_access(access_values(row), purchase.product_id,
            simulated=purchase.provider == "simulation", verified_at=verified_at).items():
        setattr(row, field, value)
    purchase.fulfilled_at = verified_at
    session.flush()


def consume_publication_slot(session, settings, row, version, *, official=False):
    if session.get(PublicationSlot, version.id):
        return
    if official and not simulator_allowed(session, settings, row.player_id):
        source = "official"
    elif row.slots:
        row.slots -= 1
        source = "initial_or_paid"
    elif simulator_allowed(session, settings, row.player_id) and row.simulated_slots:
        row.simulated_slots -= 1
        source = "simulation"
    else:
        raise HTTPException(409, "NO_PUBLISHING_SLOTS")
    session.add(PublicationSlot(version_id=version.id, player_id=row.player_id, source=source))
    session.flush()


def _require_simulator(session, request, player):
    if not simulator_allowed(session, request.app.state.settings, player.id):
        raise HTTPException(403, "PURCHASE_SIMULATION_DISABLED")


def _purchase_payload(purchase):
    return {"id": purchase.id, "product_id": purchase.product_id, "state": purchase.state,
        "recipient_player_id": purchase.recipient_player_id,
        "simulated": purchase.provider == "simulation", "created_at": purchase.created_at}


@router.get("/me/entitlements")
def entitlements(request: Request, session: DB, player: Auth):
    row = lock_entitlements(session, player.id)
    result = entitlement_payload(session, request.app.state.settings, row)
    session.commit()
    return result


@router.get("/development/purchases")
def simulation_catalog(request: Request, session: DB, player: Auth):
    _require_simulator(session, request, player)
    row = lock_entitlements(session, player.id)
    recent = list(session.scalars(select(Purchase).where(Purchase.player_id == player.id,
        Purchase.provider == "simulation", Purchase.state != "pending")
        .order_by(Purchase.created_at.desc(), Purchase.id.desc()).limit(20)))
    pending = list(session.scalars(select(Purchase).where(Purchase.player_id == player.id,
        Purchase.provider == "simulation", Purchase.state == "pending")
        .order_by(Purchase.created_at.desc(), Purchase.id.desc()).limit(20)))
    result = {"products": catalog_products(session),
        "purchases": [_purchase_payload(order) for order in pending + recent],
        "entitlements": entitlement_payload(session, request.app.state.settings, row)}
    session.commit()
    return result


class SimulatePurchase(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    request_id: str = Field(min_length=36, max_length=36)
    product_id: Literal["creator_slot_1", "creator_slots_5", "creator_slots_10", "ad_free_month", "ad_free_forever"]
    outcome: Literal["approved", "pending", "declined", "cancelled"] = "approved"
    recipient_player_id: str | None = Field(None, min_length=36, max_length=36)


@router.post("/development/purchases")
def simulate(payload: SimulatePurchase, request: Request, session: DB, player: Auth):
    _require_simulator(session, request, player)
    try:
        identity = str(UUID(payload.request_id))
    except ValueError:
        raise HTTPException(422, "INVALID_PURCHASE_ID") from None
    purchase_id = "simulation:" + hashlib.sha256(identity.encode()).hexdigest()
    if payload.recipient_player_id is not None:
        try:
            payload.recipient_player_id = str(UUID(payload.recipient_player_id))
        except ValueError:
            raise HTTPException(422, "INVALID_GIFT_RECIPIENT") from None
    rows = lock_purchase_accounts(session, player.id, payload.recipient_player_id)
    row = rows[player.id]
    purchase = session.get(Purchase, purchase_id)
    if purchase:
        if (purchase.player_id != player.id or purchase.product_id != payload.product_id
                or purchase.recipient_player_id != payload.recipient_player_id):
            raise HTTPException(409, "PURCHASE_ALREADY_CLAIMED")
        # Permanent purchase identity survives short-lived API idempotency records.
        # A resolved pending order is returned on retry of the original request.
    else:
        gift_recipient(session, player.id, payload.recipient_player_id, payload.product_id,
            settings=request.app.state.settings, simulated=True)
        product = session.scalar(select(ProductControl).where(ProductControl.id == payload.product_id).with_for_update())
        if product is None or not product.enabled:
            raise HTTPException(409, "PRODUCT_DISABLED")
        if (payload.product_id.startswith("ad_free")
                and entitlement_payload(session, request.app.state.settings, row)["ad_free_forever"]):
            raise HTTPException(409, "ALREADY_AD_FREE_FOREVER")
        if payload.outcome == "pending" and session.scalar(select(func.count()).select_from(Purchase)
                .where(Purchase.player_id == player.id, Purchase.state == "pending")) >= 20:
            raise HTTPException(409, "RESOLVE_PENDING_PURCHASES_FIRST")
        purchase = Purchase(id=purchase_id, player_id=player.id, provider="simulation",
            product_id=payload.product_id, state=payload.outcome, recipient_player_id=payload.recipient_player_id)
        session.add(purchase)
        if payload.outcome == "approved":
            fulfill_verified(session, rows[purchase.recipient_player_id or player.id], purchase, verified_at=now())
    session.flush()
    result = {"purchase": _purchase_payload(purchase),
        "entitlements": entitlement_payload(session, request.app.state.settings, row)}
    session.commit()
    return result


class AdjustSimulation(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    request_id: str = Field(min_length=36, max_length=36)
    action: Literal["expire_month", "reset_ad_free"]


@router.post("/development/entitlements/adjust")
def adjust_simulation(payload: AdjustSimulation, request: Request, session: DB, player: Auth):
    """Test controls only, with audit evidence. These are not a store refund policy."""
    _require_simulator(session, request, player)
    try:
        identity = str(UUID(payload.request_id))
    except ValueError:
        raise HTTPException(422, "INVALID_PURCHASE_ID") from None
    row = lock_entitlements(session, player.id)
    adjustment_id = "simulation-adjustment:" + hashlib.sha256(identity.encode()).hexdigest()
    old = session.get(Purchase, adjustment_id)
    if old and (old.player_id != player.id or old.product_id != payload.action):
        raise HTTPException(409, "PURCHASE_ALREADY_CLAIMED")
    if old is None:
        for field, value in adjust_simulated_access(access_values(row), payload.action, at=now()).items():
            setattr(row, field, value)
        session.add(Purchase(id=adjustment_id, player_id=player.id, provider="simulation",
            product_id=payload.action, state="approved", fulfilled_at=now()))
        session.flush()
    result = {"entitlements": entitlement_payload(session, request.app.state.settings, row)}
    session.commit()
    return result


class ResolvePurchase(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    outcome: Literal["approved", "declined", "cancelled"]


@router.post("/development/purchases/{purchase_id}/resolve")
def resolve(purchase_id: str, payload: ResolvePurchase, request: Request, session: DB, player: Auth):
    _require_simulator(session, request, player)
    purchase = session.get(Purchase, purchase_id)
    if purchase is None or purchase.player_id != player.id or purchase.provider != "simulation":
        raise HTTPException(404, "PURCHASE_NOT_FOUND")
    rows = lock_purchase_accounts(session, player.id, purchase.recipient_player_id)
    row = rows[player.id]
    session.refresh(purchase)
    if purchase.state != "pending" and purchase.state != payload.outcome:
        raise HTTPException(409, "PURCHASE_ALREADY_RESOLVED")
    purchase.state = payload.outcome
    if purchase.state == "approved" and purchase.fulfilled_at is None:
        gift_recipient(session, player.id, purchase.recipient_player_id, purchase.product_id,
            settings=request.app.state.settings, simulated=True)
        fulfill_verified(session, rows[purchase.recipient_player_id or player.id], purchase, verified_at=now())
    result = {"purchase": _purchase_payload(purchase),
        "entitlements": entitlement_payload(session, request.app.state.settings, row)}
    session.commit()
    return result
