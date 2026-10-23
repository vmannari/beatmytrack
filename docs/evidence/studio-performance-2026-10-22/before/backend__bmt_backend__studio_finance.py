"""Provider-derived money and a separate immutable noncash wallet ledger."""

from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError

from .admin import Access, Window
from .admin_ranges import calendar_range
from .commerce import CATALOG, entitlement_payload, fulfill_verified, lock_entitlements
from .commerce_models import Purchase
from .economy_models import CoinWallet
from .middleware import ParsedJSONRoute
from .studio_cases import begin
from .studio_platform_models import StudioCoinEntry, StudioFinanceEvent
from .studio_queries import read_snapshot
from .track_models import digest, now
from .tracks import DB, Auth

router = APIRouter(route_class=ParsedJSONRoute, tags=["Studio finance"])


def coin_entry(db, wallet, reference, kind, amount, detail):
    identity = digest({"player": wallet.player_id, "reference": reference})
    if db.get(StudioCoinEntry, identity) is None:
        db.add(
            StudioCoinEntry(
                id=identity,
                player_id=wallet.player_id,
                reference=reference,
                kind=kind,
                amount=amount,
                detail=detail,
            )
        )
        db.flush()


def play_account(player_id):
    from .provider_proofs import account_binding

    return account_binding(player_id)


@router.get("/v1/billing/account")
def account(player: Auth):
    return {"obfuscated_account_id": play_account(player.id)}


class Verify(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")
    product_id: str = Field(min_length=1, max_length=40)
    purchase_token: str = Field(min_length=16, max_length=4096)


@router.post("/v1/billing/google-play/verify")
def verify(body: Verify, request: Request, player: Auth, session: DB):
    if not request.app.state.settings.studio_play_package:
        raise HTTPException(503, "PLAY_NOT_CONFIGURED")
    if body.product_id not in CATALOG:
        raise HTTPException(422, "UNKNOWN_PRODUCT")
    player_id = player.id
    session.rollback()  # Provider IO never retains a SQL transaction or wallet lock.
    from .studio_providers import PlayProvider

    provider = getattr(request.app.state, "studio_play_provider", None) or PlayProvider(
        request.app.state.settings
    )
    proof = provider.verify(body.purchase_token)
    from .provider_proofs import InvalidProof, validate_play

    try:
        verified = validate_play(proof, body.product_id, player_id, at=now())
    except InvalidProof as error:
        raise HTTPException(409, str(error)) from None
    if verified["test_purchase"]:
        raise HTTPException(409, "PLAY_TEST_PURCHASE_NOT_LIVE")
    if verified["refundable_quantity"] != 1:
        raise HTTPException(409, "PURCHASE_REFUNDED")
    if verified["state"] != "PURCHASED":
        raise HTTPException(409, "PURCHASE_NOT_COMPLETED")
    identity = "google_play:" + digest({"token": body.purchase_token})
    try:
        begin(session, str(UUID(identity.split(":")[1][:32])))
        row = lock_entitlements(session, player_id)
        old = session.get(Purchase, identity)
        if old and (old.player_id != player_id or old.product_id != body.product_id):
            raise HTTPException(409, "PURCHASE_ALREADY_CLAIMED")
        if old is None:
            if verified["consumption"] != "CONSUMPTION_STATE_YET_TO_BE_CONSUMED":
                raise HTTPException(409, "PURCHASE_ALREADY_CONSUMED")
            old = Purchase(
                id=identity,
                player_id=player_id,
                provider="google_play",
                product_id=body.product_id,
                state="approved",
            )
            session.add(old)
        fulfill_verified(session, row, old, verified_at=now())
        result = {
            "purchase": {"id": old.id, "state": old.state, "fulfilled_at": old.fulfilled_at},
            "entitlements": entitlement_payload(session, request.app.state.settings, row),
        }
        session.commit()
        provider.complete(body.product_id, body.purchase_token, proof)
        return result
    except IntegrityError:
        session.rollback()
        raise HTTPException(409, "PURCHASE_ALREADY_CLAIMED") from None


@router.get("/v1/admin/finance")
def report(request: Request, role: Access, window: Window):
    first, until = window or calendar_range(7)
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        money = db.execute(
            select(
                StudioFinanceEvent.provider,
                StudioFinanceEvent.currency,
                StudioFinanceEvent.basis,
                StudioFinanceEvent.kind,
                func.sum(StudioFinanceEvent.amount_micros),
                func.count(),
                func.max(StudioFinanceEvent.received_at),
            )
            .where(StudioFinanceEvent.occurred_at >= first, StudioFinanceEvent.occurred_at < until)
            .group_by(
                StudioFinanceEvent.provider,
                StudioFinanceEvent.currency,
                StudioFinanceEvent.basis,
                StudioFinanceEvent.kind,
            )
        ).all()
        coins = db.execute(
            select(StudioCoinEntry.kind, func.sum(StudioCoinEntry.amount), func.count())
            .where(StudioCoinEntry.created_at >= first, StudioCoinEntry.created_at < until)
            .group_by(StudioCoinEntry.kind)
        ).all()
        purchases = dict(
            db.execute(
                select(Purchase.state, func.count())
                .where(
                    Purchase.provider == "google_play",
                    Purchase.created_at >= first,
                    Purchase.created_at < until,
                )
                .group_by(Purchase.state)
            ).all()
        )
        return {
            "role": role,
            "as_of": now(),
            "since": first,
            "until": until,
            "money": [
                dict(
                    zip(
                        (
                            "provider",
                            "currency",
                            "basis",
                            "kind",
                            "amount_micros",
                            "entries",
                            "last_import_at",
                        ),
                        r,
                    )
                )
                for r in money
            ],
            "coins": [dict(zip(("kind", "amount", "entries"), r)) for r in coins],
            "wallets": {
                "count": db.scalar(select(func.count()).select_from(CoinWallet)),
                "balance": db.scalar(select(func.coalesce(func.sum(CoinWallet.balance), 0))),
            },
            "purchases": purchases,
            "sources": {
                "play_configured": bool(request.app.state.settings.studio_play_package),
                "admob_configured": bool(request.app.state.settings.studio_admob_account),
                "latest_import_at": db.scalar(select(func.max(StudioFinanceEvent.received_at))),
            },
            "coverage": "Money is grouped by currency, provider and accounting basis. Verified purchases prove fulfilment, not monetary revenue. AdMob amounts are estimated network earnings in provider calendar dates (America/Los_Angeles); not player LTV. Opening Coin balances are not earnings.",
        }


def import_admob(db, account, items, received_at):
    """Append deltas of verified complete provider snapshots; preserve restatements."""
    if not items or "header" not in items[0] or "footer" not in items[-1]:
        raise ValueError("INCOMPLETE_ADMOB_REPORT")
    footer = items[-1]["footer"]
    rows = [i["row"] for i in items if "row" in i]
    if footer.get("warnings") or int(footer.get("matchingRowCount", -1)) != len(rows):
        raise ValueError("INCOMPLETE_ADMOB_REPORT")
    currency = items[0]["header"]["localizationSettings"]["currencyCode"]
    if len(currency) != 3 or not currency.isalpha() or not currency.isupper():
        raise ValueError("INVALID_CURRENCY")
    begin(db, str(UUID(digest({"admob": account})[:32])))
    added = 0
    for row in rows:
        dims = {k: v["value"] for k, v in row["dimensionValues"].items()}
        if set(dims) != {"DATE", "APP"}:
            raise ValueError("INVALID_ADMOB_DIMENSIONS")
        timestamp = int(datetime.strptime(dims["DATE"], "%Y%m%d").replace(tzinfo=timezone.utc).timestamp())
        total = int(row["metricValues"]["ESTIMATED_EARNINGS"]["microsValue"])
        key = digest({"account": account, "currency": currency, **dims})
        previous = db.scalar(
            select(StudioFinanceEvent)
            .where(
                StudioFinanceEvent.provider == "admob",
                StudioFinanceEvent.dimensions["snapshot_key"].as_string() == key,
            )
            .order_by(StudioFinanceEvent.received_at.desc(), StudioFinanceEvent.id.desc())
            .limit(1)
        )
        if previous and previous.received_at >= received_at:
            if previous.dimensions["total_micros"] == total:
                continue
            raise ValueError("STALE_ADMOB_SNAPSHOT")
        delta = total - (previous.dimensions["total_micros"] if previous else 0)
        if previous and delta == 0:
            continue
        reference = digest({"key": key, "prior": previous.reference if previous else "", "total": total})
        db.add(
            StudioFinanceEvent(
                provider="admob",
                reference=reference,
                kind="ad_earnings",
                basis="estimated",
                currency=currency,
                amount_micros=delta,
                occurred_at=timestamp,
                received_at=received_at,
                dimensions={
                    **dims,
                    "snapshot_key": key,
                    "total_micros": total,
                    "timezone": "America/Los_Angeles",
                },
                payload_hash=digest(row),
            )
        )
        added += 1
    db.commit()
    return added
