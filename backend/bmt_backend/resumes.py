"""Server clock, serialized wallet mutations, and race-bound resume authorization.

No client-facing grant endpoint: provider adapters must verify a reward/receipt
before calling grant_verified. Provider/product configuration is not yet selected.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select

from .identity_models import Player
from .resume_models import ResumeGrant, ResumeRace, ResumeReceipt, ResumeWallet
from .track_models import Run, RunTicket, commit_response, now, replay_response
from .tracks import DB, Auth, Key

router = APIRouter(tags=["resumes"])


def locked_wallet(session, player_id):
    session.scalar(select(Player).where(Player.id == player_id).with_for_update())
    wallet = session.get(ResumeWallet, player_id)
    if wallet is None:
        wallet = ResumeWallet(player_id=player_id, balance=0, free_day=-1)
        session.add(wallet)
        session.flush()
    return wallet


def wallet_payload(wallet):
    day = now() // 86400
    return {
        "free": int(wallet.free_day < day),
        "balance": wallet.balance,
        "reset_at": (day + 1) * 86400,
        "ads_available": False,
        "purchases_available": False,
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
def balance(session: DB, player: Auth):
    wallet = locked_wallet(session, player.id)
    session.commit()
    return wallet_payload(wallet)


class BeginRace(BaseModel):
    model_config = ConfigDict(extra="forbid")
    ticket_id: str | None = Field(default=None, min_length=36, max_length=36)


@router.post("/resume-races", status_code=201)
def begin(payload: BeginRace, session: DB, player: Auth, key: Key):
    body = payload.model_dump()
    locked_wallet(session, player.id)
    old = replay_response(session, player.id, "resume_race", key, body)
    if old is not None:
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


@router.post("/resume-races/{race_id}/resumes")
def consume(race_id: str, payload: Consume, session: DB, player: Auth, key: Key):
    body = {"race_id": race_id, **payload.model_dump()}
    wallet = locked_wallet(session, player.id)
    old = replay_response(session, player.id, "consume_resume", key, body)
    if old is not None:
        return old
    race = session.get(ResumeRace, race_id)
    if race is None or race.player_id != player.id:
        raise HTTPException(404, "Resume race not found")
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
    if wallet.free_day < day:
        source = "daily"
        wallet.free_day = day
    elif wallet.balance > 0:
        source = "balance"
        wallet.balance -= 1
    else:
        raise HTTPException(409, "No resumes available; daily free resume resets at 00:00 UTC")
    race.used += 1
    receipt = ResumeReceipt(race_id=race.id, source=source, **payload.model_dump())
    session.add(receipt)
    session.flush()
    return commit_response(
        session,
        player.id,
        "consume_resume",
        key,
        body,
        {"receipt_id": receipt.id, "used": race.used, "wallet": wallet_payload(wallet)},
    )


def validate_receipts(session, ticket_id: str, replay: dict):
    race = session.scalar(select(ResumeRace).where(ResumeRace.ticket_id == ticket_id))
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
