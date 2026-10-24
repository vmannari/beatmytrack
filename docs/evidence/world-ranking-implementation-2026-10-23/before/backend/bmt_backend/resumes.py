"""Server clock, serialized wallet mutations, and race-bound resume authorization.

No client-facing grant endpoint: provider adapters must verify a reward/receipt
before calling grant_verified. Provider/product configuration is not yet selected.
"""

from typing import Literal

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select

from .identity_models import Player
from .middleware import ParsedJSONRoute
from .resume_models import ResumeGrant, ResumeRace, ResumeReceipt, ResumeWallet
from .track_models import IdempotencyRecord, Run, RunTicket, commit_response, digest, now, replay_response
from .tracks import DB, Auth, Key

router = APIRouter(route_class=ParsedJSONRoute, tags=["resumes"])
# Owner-authorized bridge until a real rewarded-ad adapter is integrated.
# These receipts are explicitly not evidence of a watched ad or a banked grant.
TEMPORARY_AD_RESUMES = True


def locked_wallet(session, player_id, *, allow_disabled=False):
    owner = session.scalar(select(Player).where(Player.id == player_id).with_for_update().execution_options(populate_existing=True))
    if owner is None or (owner.disabled and not allow_disabled):
        raise HTTPException(401, "INVALID_SESSION")
    wallet = session.get(ResumeWallet, player_id)
    if wallet is None:
        wallet = ResumeWallet(player_id=player_id, balance=0, free_day=-1)
        session.add(wallet)
        session.flush()
    return wallet


def wallet_payload(wallet, session=None, settings=None):
    day = now() // 86400
    ad_free = False
    if session is not None:
        from .commerce import entitlement_payload, lock_entitlements
        ad_free = entitlement_payload(session, settings, lock_entitlements(session, wallet.player_id))["ad_free"]
    return {
        "free": int(wallet.free_day < day),
        "balance": wallet.balance,
        "reset_at": (day + 1) * 86400,
        "ads_available": False,
        "ad_preview_available": TEMPORARY_AD_RESUMES,
        "purchases_available": False,
        "ad_free": ad_free,
        "free_rewinds": ad_free,
    }


def grant_verified(session, player_id: str, source: str, transaction_id: str, quantity: int = 1):
    """Internal fulfillment boundary; caller owns provider proof verification and commit."""
    if (
        source not in {"ad", "purchase", "award"}
        or not 1 <= quantity <= 10000
        or (source == "ad" and quantity != 1)
    ):
        raise ValueError("Invalid resume grant")
    if not transaction_id or len(transaction_id) > 140:
        raise ValueError("Invalid transaction identity")
    wallet = locked_wallet(session, player_id)
    identity = source + ":" + transaction_id
    old = session.get(ResumeGrant, identity)
    if old:
        if old.player_id != player_id or old.quantity != quantity:
            raise HTTPException(409, "Reward transaction already claimed")
        return wallet_payload(wallet)
    session.add(ResumeGrant(id=identity, player_id=player_id, source=source, quantity=quantity))
    wallet.balance += quantity
    session.flush()
    return wallet_payload(wallet)


@router.get("/resumes")
def balance(request: Request, session: DB, player: Auth):
    wallet = locked_wallet(session, player.id)
    result = wallet_payload(wallet, session, request.app.state.settings)
    session.commit()
    return result


class BeginRace(BaseModel):
    model_config = ConfigDict(extra="forbid")
    ticket_id: str | None = Field(default=None, min_length=36, max_length=36)


@router.post("/resume-races", status_code=201)
def begin(payload: BeginRace, session: DB, player: Auth, key: Key):
    body = payload.model_dump()
    locked_wallet(session, player.id)
    old = replay_response(session, player.id, "resume_race", key, body)
    if old is not None:
        existing_race = session.get(ResumeRace, old["race_id"])
        if existing_race and existing_race.abandoned:
            raise HTTPException(409, "RACE_ABANDONED")
        return old
    expires = now() + 7200
    if payload.ticket_id:
        ticket = session.get(RunTicket, payload.ticket_id)
        if ticket is None or ticket.player_id != player.id:
            raise HTTPException(404, "Race ticket not found")
        if ticket.expires_at <= now() or session.scalar(select(Run.id).where(Run.ticket_id == ticket.id)):
            raise HTTPException(409, "Race ticket is closed")
        expires = ticket.expires_at
        race = session.scalar(select(ResumeRace).where(ResumeRace.ticket_id == ticket.id))
    else:
        race = None
    if race is None:
        race = ResumeRace(player_id=player.id, ticket_id=payload.ticket_id, expires_at=expires)
        session.add(race)
        session.flush()
    if race.abandoned:
        raise HTTPException(409, "RACE_ABANDONED")
    return commit_response(
        session,
        player.id,
        "resume_race",
        key,
        body,
        {"race_id": race.id, "used": race.used, "expires_at": race.expires_at},
    )


class Consume(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    ordinal: int = Field(ge=1, le=3)
    input_offset: int = Field(ge=1, le=216000)
    from_tick: int = Field(ge=1, le=216000)
    to_tick: int = Field(ge=0, le=215999)
    recovery: Literal["v1"] | None = None


@router.post("/resume-races/{race_id}/resumes")
def consume(race_id: str, payload: Consume, request: Request, session: DB, player: Auth, key: Key):
    body = {"race_id": race_id, **payload.model_dump(exclude_none=True)}
    wallet = locked_wallet(session, player.id)
    race = session.get(ResumeRace, race_id)
    if race is None or race.player_id != player.id:
        raise HTTPException(404, "Resume race not found")
    if race.abandoned:
        raise HTTPException(409, "RACE_ABANDONED")
    old = replay_response(session, player.id, "consume_resume", key, body)
    if old is not None:
        return old
    if race.expires_at <= now():
        raise HTTPException(410, "Resume race expired")
    if race.ticket_id:
        # Same lock order as submission: player, then ticket.
        session.scalar(select(RunTicket).where(RunTicket.id == race.ticket_id).with_for_update())
        if session.scalar(select(Run.id).where(Run.ticket_id == race.ticket_id)):
            raise HTTPException(409, "Race already submitted")
    if race.used >= 3 or payload.ordinal != race.used + 1:
        raise HTTPException(409, "Maximum three resumes per race; refresh race state")
    if not 1 <= payload.from_tick - payload.to_tick <= 1200:
        raise HTTPException(422, "Choose a point within the last 10 seconds")
    previous = session.scalar(
        select(ResumeReceipt).where(ResumeReceipt.race_id == race.id, ResumeReceipt.ordinal == race.used)
    )
    offset = previous.input_offset if previous else 0
    tick = previous.to_tick if previous else 0
    if payload.input_offset <= offset or payload.from_tick != tick + payload.input_offset - offset:
        raise HTTPException(422, "Resume does not follow the race input timeline")
    day = now() // 86400
    current_wallet = wallet_payload(wallet, session, request.app.state.settings)
    if current_wallet["free_rewinds"]:
        source = "ad_free"
    elif wallet.balance > 0:
        source = "balance"
        wallet.balance -= 1
    elif wallet.free_day < day:
        source = "daily"
        wallet.free_day = day
    elif TEMPORARY_AD_RESUMES:
        source = "ad_preview"
    else:
        raise HTTPException(409, "No resumes available; daily free resume resets at 00:00 UTC")
    race.used += 1
    receipt = ResumeReceipt(race_id=race.id, source=source,
                            settled=payload.recovery != "v1", **payload.model_dump(exclude={"recovery"}))
    session.add(receipt)
    session.flush()
    return commit_response(
        session,
        player.id,
        "consume_resume",
        key,
        body,
        {"receipt_id": receipt.id, "used": race.used, "wallet": wallet_payload(wallet, session, request.app.state.settings)},
    )


def validate_receipts(session, ticket_id: str, replay: dict, *, settle=False):
    race = session.scalar(select(ResumeRace).where(ResumeRace.ticket_id == ticket_id))
    if race and race.abandoned:
        raise HTTPException(409, "RACE_ABANDONED")
    receipts = (
        list(
            session.scalars(
                select(ResumeReceipt).where(ResumeReceipt.race_id == race.id).order_by(ResumeReceipt.ordinal)
            )
        )
        if race
        else []
    )
    events = replay.get("rewinds", [])
    if len(receipts) != len(events):
        raise HTTPException(422, "Replay must include every authorized resume")
    for receipt, event in zip(receipts, events):
        if event != {
            "receipt_id": receipt.id,
            "input_offset": receipt.input_offset,
            "from_tick": receipt.from_tick,
            "to_tick": receipt.to_tick,
        }:
            raise HTTPException(422, "Resume receipt does not match this race and rewind")
        if receipt.refunded:
            raise HTTPException(409, "RACE_ABANDONED")
        if settle:
            receipt.settled = True


class ResumeRecovery(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    begin_key: str = Field(min_length=8, max_length=128)
    consume_key: str = Field(min_length=8, max_length=128)
    race_id: str | None = Field(default=None, min_length=36, max_length=36)
    ticket_id: str | None = Field(default=None, min_length=36, max_length=36)
    selection: Consume
    action: Literal["inspect", "confirm", "abandon"] = "inspect"


@router.post("/resume-recovery")
def recover_resume(payload: ResumeRecovery, request: Request, session: DB, player: Auth):
    """Never replay a charge. Close an unsubmitted race before returning uncertain resources."""
    wallet = locked_wallet(session, player.id)
    beginning = session.get(IdempotencyRecord, (player.id, "resume_race", payload.begin_key))
    bound_id = beginning.response.get("race_id") if beginning else None
    if bound_id and payload.race_id and bound_id != payload.race_id:
        raise HTTPException(409, "RECOVERY_OPERATION_MISMATCH")
    race_id = payload.race_id or bound_id
    race = session.get(ResumeRace, race_id) if race_id else None
    if race is None:
        session.commit()
        return {"state": "absent", "wallet": wallet_payload(wallet, session, request.app.state.settings)}
    if race.player_id != player.id or race.ticket_id != payload.ticket_id:
        raise HTTPException(404, "Resume race not found")
    if race.ticket_id:
        session.scalar(select(RunTicket).where(RunTicket.id == race.ticket_id).with_for_update())
    race = session.scalar(select(ResumeRace).where(ResumeRace.id == race.id).with_for_update())
    receipt = session.scalar(select(ResumeReceipt).where(
        ResumeReceipt.race_id == race.id, ResumeReceipt.ordinal == payload.selection.ordinal))
    if receipt:
        if any(getattr(receipt, name) != value for name, value in payload.selection.model_dump(exclude={"recovery"}).items()):
            raise HTTPException(409, "RECOVERY_OPERATION_MISMATCH")
        operation = session.get(IdempotencyRecord, (player.id, "consume_resume", payload.consume_key))
        if operation and operation.request_hash != digest({"race_id": race.id, **payload.selection.model_dump(exclude_none=True)}):
            raise HTTPException(409, "RECOVERY_OPERATION_MISMATCH")
    if payload.action == "abandon":
        if race.ticket_id and session.scalar(select(Run.id).where(Run.ticket_id == race.ticket_id)):
            raise HTTPException(409, "RACE_ALREADY_SUBMITTED")
        # A delayed original consume cannot charge after this transaction commits.
        race.abandoned = True
        uncertain_receipts = [receipt] if receipt and not receipt.settled and not receipt.refunded else []
        for uncertain in uncertain_receipts:
            if uncertain.source == "balance":
                wallet.balance += 1
            elif (uncertain.source == "daily" and uncertain.created_at // 86400 == now() // 86400
                  and wallet.free_day == now() // 86400):
                wallet.free_day -= 1
            # Temporary ad_preview never mints a banked credit; expired daily never rolls over.
            uncertain.refunded = True
            uncertain.settled = True
    elif payload.action == "confirm" and receipt and not receipt.refunded:
        receipt.settled = True
    state = "abandoned" if race.abandoned else "consumed" if receipt else "absent"
    result = {"state": state, "race_id": race.id, "wallet": wallet_payload(wallet, session, request.app.state.settings)}
    if receipt and not race.abandoned:
        result.update(receipt_id=receipt.id, used=receipt.ordinal)
    session.commit()
    return result


def expire_unsettled(factory, cutoff, *, apply=False):
    """Bound lost-device recovery evidence without permanently consuming its credit."""
    with factory() as session:
        rows = session.execute(select(ResumeReceipt.id, ResumeRace.id, ResumeRace.player_id)
            .join(ResumeRace, ResumeRace.id == ResumeReceipt.race_id)
            .where(ResumeReceipt.settled.is_(False), ResumeRace.expires_at < cutoff,
                   ~select(Run.id).where(Run.ticket_id == ResumeRace.ticket_id).exists())
            .order_by(ResumeRace.expires_at, ResumeReceipt.id).limit(1000)).all()
    if not apply:
        return len(rows)
    recovered = 0
    for receipt_id, race_id, owner_id in rows:
        with factory() as session:
            wallet = locked_wallet(session, owner_id, allow_disabled=True)
            original = session.get(ResumeRace, race_id)
            if original is None:
                continue
            if original.ticket_id:
                session.scalar(select(RunTicket).where(RunTicket.id == original.ticket_id).with_for_update())
            race = session.scalar(select(ResumeRace).where(ResumeRace.id == race_id).with_for_update())
            receipt = session.get(ResumeReceipt, receipt_id)
            if (receipt is None or receipt.settled or race.expires_at >= cutoff
                    or (race.ticket_id and session.scalar(select(Run.id).where(Run.ticket_id == race.ticket_id)))):
                continue
            race.abandoned = True
            if not receipt.refunded:
                if receipt.source == "balance":
                    wallet.balance += 1
                elif (receipt.source == "daily" and receipt.created_at // 86400 == now() // 86400
                      and wallet.free_day == now() // 86400):
                    wallet.free_day -= 1
            receipt.refunded, receipt.settled = True, True
            session.commit()
            recovered += 1
    return recovered
