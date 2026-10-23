"""Only verified runs mint account coins; prices and charges are server-owned."""
import json
from pathlib import Path

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import or_, select, update

from .economy_models import CoinMilestone, CoinReward, CoinWallet, CosmeticUnlock
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .track_models import (
    Board,
    LapPersonalBest,
    PersonalBest,
    Run,
    RunTicket,
    TrackVersion,
    commit_response,
    replay_response,
)
from .tracks import DB, Auth, Key

router = APIRouter(route_class=ParsedJSONRoute, tags=["earned coins"])
CATALOG = json.loads(Path(__file__).with_name("vehicle_appearance_catalog.json").read_text(encoding="utf-8"))
PRICES = {**{"livery/" + item: 500 for item in CATALOG["patterns"] if item != "plain"},
          **{"kit/compact/" + category + "/" + item: 750
             for category, items in CATALOG["parts"].items() for item in items if item != "stock"}}
MAX_BALANCE = 2147483647
CHALLENGE_DAILY_LIMIT = 3


def challenge_rewards(session, challenge_id, player_id, timestamp):
    """Read the same durable milestones used by verification; browsing never grants."""
    complete = bool(player_id and session.get(CoinMilestone, (player_id, "challenge/attempt/" + challenge_id)))
    goal = bool(player_id and session.get(CoinMilestone, (player_id, "challenge/beaten/" + challenge_id)))
    day = session.get(CoinMilestone, (player_id, "challenge/day/" + str(timestamp // 86400))) if player_id else None
    remaining = max(0, CHALLENGE_DAILY_LIMIT - (day.value if day else 0))
    return {"finish": 50, "goal": 100, "finish_earned": complete, "goal_earned": goal,
            "eligible": complete or remaining > 0, "daily_limit": CHALLENGE_DAILY_LIMIT, "remaining_today": remaining}


def locked_wallet(session, player_id):
    if session.bind.dialect.name == "sqlite":
        session.execute(update(Player).where(Player.id == player_id).values(id=Player.id))
    owner = session.scalar(select(Player).where(Player.id == player_id).with_for_update()
                           .execution_options(populate_existing=True))
    if owner is None or owner.disabled or owner.deleted_at is not None:
        raise HTTPException(401, "INVALID_SESSION")
    wallet = session.get(CoinWallet, player_id)
    if wallet is None:
        wallet = CoinWallet(player_id=player_id, balance=0, revision=0)
        session.add(wallet)
        session.flush()
    from .studio_finance import coin_entry
    coin_entry(session,wallet,"opening","opening",wallet.balance,{"revision":wallet.revision})
    return wallet


def wallet_payload(session, wallet):
    return {"schema": 1, "balance": wallet.balance, "revision": wallet.revision,
            "owned": list(session.scalars(select(CosmeticUnlock.item_id)
                .where(CosmeticUnlock.player_id == wallet.player_id).order_by(CosmeticUnlock.item_id))),
            "prices": PRICES}


@router.get("/economy")
def balance(session: DB, player: Auth):
    value = wallet_payload(session, locked_wallet(session, player.id))
    session.commit()
    return value


class BuyCosmetic(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")
    item_id: str = Field(min_length=1, max_length=100)
    expected_price: int = Field(ge=1, le=1000000)


@router.post("/economy/purchases")
def purchase(body: BuyCosmetic, session: DB, player: Auth, key: Key):
    wallet = locked_wallet(session, player.id)
    payload = body.model_dump()
    old = replay_response(session, player.id, "coin_purchase", key, payload)
    if old is not None:
        return old
    price = PRICES.get(body.item_id)
    if price is None:
        raise HTTPException(422, "UNKNOWN_COSMETIC")
    owned = session.get(CosmeticUnlock, (player.id, body.item_id))
    charged = 0
    if owned is None:
        if body.expected_price != price:
            raise HTTPException(409, "COSMETIC_PRICE_CHANGED")
        if wallet.balance < price:
            raise HTTPException(409, "INSUFFICIENT_COINS")
        wallet.balance -= price
        wallet.revision += 1
        charged = price
        from .studio_finance import coin_entry
        coin_entry(session,wallet,"unlock/"+body.item_id,"spent",-price,{"item_id":body.item_id})
        session.add(CosmeticUnlock(player_id=player.id, item_id=body.item_id, price=price))
        session.flush()
    value = {"item_id": body.item_id, "charged": charged, "wallet": wallet_payload(session, wallet)}
    return commit_response(session, player.id, "coin_purchase", key, payload, value)


@router.get("/economy/rewards/{ticket_id}")
def reward(ticket_id: str, session: DB, player: Auth):
    ticket = session.get(RunTicket, ticket_id)
    if ticket is None or ticket.player_id != player.id:
        raise HTTPException(404, "RACE_NOT_FOUND")
    run = session.scalar(select(Run).where(Run.ticket_id == ticket_id))
    receipt = session.get(CoinReward, run.id) if run else None
    status = "credited" if receipt else "unavailable" if run and run.status in ("verified", "rejected", "failed") else "pending"
    return {"status": status, "amount": receipt.amount if receipt else 0, "rows": receipt.rows if receipt else []}


def previous_bests(session, run):
    """Read before verified-run triggers replace the flying-lap minimum."""
    race = session.get(PersonalBest, (run.board_id, run.player_id))
    lap = session.get(LapPersonalBest, (run.board_id, run.player_id))
    return (race.time_ticks if race else 0, lap.time_ticks if lap else 0)


def accept_verified(session, run, previous, *, incident_free=False):
    """Caller holds Player and commits the award in the verification transaction."""
    board = session.get(Board, run.board_id)
    player = session.get(Player, run.player_id)
    if (run.status != "verified" or board.manifest.get("purpose") == "creator_test"
            or player.is_test_driver or session.get(CoinReward, run.id) is not None):
        return
    wallet = locked_wallet(session, run.player_id)
    rows = []

    def add(title, amount, icon="flag"):
        rows.append({"title": title, "amount": amount, "icon": icon, "eligible": True, "status": "Credited"})

    def milestone(scope, value):
        old = session.get(CoinMilestone, (run.player_id, scope))
        if old is not None and old.value >= value:
            return False
        if old is None:
            session.add(CoinMilestone(player_id=run.player_id, scope=scope, value=value))
        else:
            old.value = value
        session.flush()
        return True

    add("Race completed", 50)
    version = session.get(TrackVersion, board.version_id)
    prior_track_run = session.scalar(select(Run.id).join(Board, Board.id == Run.board_id)
        .join(TrackVersion, TrackVersion.id == Board.version_id)
        .where(Run.player_id == run.player_id, Run.status == "verified", Run.id != run.id,
               TrackVersion.track_id == version.track_id,
               or_(Board.manifest["purpose"].as_string().is_(None),
                   Board.manifest["purpose"].as_string() != "creator_test")).limit(1))
    first_seen = milestone("track/" + version.track_id, 1)
    if prior_track_run is None and first_seen:
        add("First time on track", 50)
    flying = min(run.lap_ticks[1:])
    if previous[0] and run.time_ticks < previous[0]:
        add("New race PB", 100, "timer")
    if previous[1] and flying < previous[1]:
        add("New lap PB", 100, "timer")
    from .reward_ranks import percentile_amount
    for metric, ticks in (("race", run.time_ticks), ("lap", flying)):
        earned = session.get(CoinMilestone, (run.player_id, metric + "/" + board.id))
        if earned is not None and earned.value >= 500:
            continue
        amount = percentile_amount(session, board.id, metric, ticks)
        if amount and milestone(metric + "/" + board.id, amount):
            add("Race percentile tier" if metric == "race" else "Best-lap percentile tier", amount, "bars")
    from .challenge_models import ChallengeTicket
    binding = session.get(ChallengeTicket, run.ticket_id)
    if binding and binding.outcome and binding.outcome.get("counted"):
        state = challenge_rewards(session, binding.challenge_id, run.player_id, run.created_at)
        if state["eligible"]:
            if milestone("challenge/attempt/" + binding.challenge_id, 1):
                scope = "challenge/day/" + str(run.created_at // 86400)
                daily = session.get(CoinMilestone, (run.player_id, scope))
                if daily is None:
                    session.add(CoinMilestone(player_id=run.player_id, scope=scope, value=1))
                else:
                    daily.value += 1
                add("Challenge completed", 50)
            if binding.outcome.get("beaten") and milestone("challenge/beaten/" + binding.challenge_id, 1):
                add("Challenge goal", 100, "trophy")
    if incident_free is True:
        add("Clean race", 200, "trophy")
    from .achievements import capture_race
    capture_race(session, run, previous, incident_free=incident_free)
    amount = min(sum(row["amount"] for row in rows), MAX_BALANCE - wallet.balance)
    if amount != sum(row["amount"] for row in rows):
        rows = [{"title": "Wallet capacity", "amount": amount, "icon": "coin", "eligible": True, "status": "Credited"}]
    wallet.balance += amount
    wallet.revision += 1
    from .studio_finance import coin_entry
    coin_entry(session,wallet,"run/"+run.id,"earned",amount,{"rows":rows})
    session.add(CoinReward(run_id=run.id, player_id=run.player_id, amount=amount, rows=rows))
