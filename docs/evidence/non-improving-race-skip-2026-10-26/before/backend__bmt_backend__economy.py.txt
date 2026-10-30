"""Only verified runs mint account coins; prices and charges are server-owned."""
import json
from pathlib import Path

from fastapi import APIRouter, HTTPException, Request
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


def established_wallet(session, player_id):
    """One coherent read; missing financial provenance uses locked recovery."""
    from .studio_platform_models import StudioCoinEntry
    from .track_models import digest
    opening = digest({"player": player_id, "reference": "opening"})
    rows = session.execute(select(CoinWallet.balance, CoinWallet.revision, CosmeticUnlock.item_id, StudioCoinEntry.id)
        .select_from(CoinWallet).join(Player, Player.id == CoinWallet.player_id)
        .outerjoin(CosmeticUnlock, CosmeticUnlock.player_id == CoinWallet.player_id)
        .outerjoin(StudioCoinEntry, StudioCoinEntry.id == opening)
        .where(CoinWallet.player_id == player_id, Player.disabled.is_(False), Player.deleted_at.is_(None))
        .order_by(CosmeticUnlock.item_id)).all()
    if not rows or rows[0][3] is None:
        return None
    return {"schema": 1, "balance": rows[0][0], "revision": rows[0][1],
            "owned": [row[2] for row in rows if row[2] is not None], "prices": PRICES}


@router.get("/economy")
def balance(session: DB, player: Auth):
    value = established_wallet(session, player.id)
    if value is not None:
        return value
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
def reward(ticket_id: str, request: Request, session: DB, player: Auth):
    ticket = session.get(RunTicket, ticket_id)
    if ticket is None or ticket.player_id != player.id:
        raise HTTPException(404, "RACE_NOT_FOUND")
    run = session.scalar(select(Run).where(Run.ticket_id == ticket_id))
    receipt = session.get(CoinReward, run.id) if run else None
    if receipt is None and run is not None and run.reward_archive_hash:
        from .cost_archives import decrypt
        from .object_models import ArchiveKey
        key = session.get(ArchiveKey, player.id)
        if key is None:
            raise HTTPException(503, "REWARD_ARCHIVE_UNAVAILABLE")
        secret, run_id, archived = key.secret, run.id, run.reward_archive_hash
        session.commit()
        body = request.app.state.blobs.get_json(archived)
        stored = body.get("records", {}).get(run_id)
        if stored is None:
            raise OSError("Archived reward is missing")
        value = decrypt(secret, run_id, stored)
        return {"status": "credited", "amount": value["amount"], "rows": value["rows"]}
    status = "credited" if receipt else "unavailable" if run and run.status in ("verified", "rejected", "failed") else "pending"
    return {"status": status, "amount": receipt.amount if receipt else 0, "rows": receipt.rows if receipt else []}


def previous_bests(session, run):
    """Read before verified-run triggers replace the flying-lap minimum."""
    race = session.get(PersonalBest, (run.board_id, run.player_id))
    lap = session.get(LapPersonalBest, (run.board_id, run.player_id))
    return (race.time_ticks if race else 0, lap.time_ticks if lap else 0)


def accept_verified(session, run, previous, *, incident_free=False, acceptance=None):
    """Caller holds Player and commits the award in the verification transaction."""
    board = acceptance.board if acceptance else session.get(Board, run.board_id)
    player = session.get(Player, run.player_id)
    if (run.status != "verified" or run.reward_archive_hash or board.manifest.get("purpose") == "creator_test"
            or player.is_test_driver or (acceptance.reward if acceptance else session.get(CoinReward, run.id)) is not None):
        return
    if acceptance:
        # The worker already owns Player's write lock before loading Acceptance.
        # Keep that lock through commit; do not issue a second locking SELECT.
        if player.disabled or player.deleted_at is not None:
            raise HTTPException(401, "INVALID_SESSION")
        wallet = acceptance.wallet
        if wallet is None:
            wallet = CoinWallet(player_id=run.player_id, balance=0, revision=0)
            session.add(wallet)
            acceptance.wallet = wallet
    else:
        wallet = locked_wallet(session, run.player_id)
    opening_balance, opening_revision = wallet.balance, wallet.revision
    rows = []
    version = acceptance.version if acceptance else session.get(TrackVersion, board.version_id)
    from .challenge_models import ChallengeTicket
    binding = acceptance.challenge if acceptance else session.get(ChallengeTicket, run.ticket_id)
    scopes = ["track/" + version.track_id, "race/" + board.id, "lap/" + board.id]
    if binding and binding.outcome and binding.outcome.get("counted"):
        scopes.extend(("challenge/attempt/" + binding.challenge_id, "challenge/beaten/" + binding.challenge_id,
                       "challenge/day/" + str(run.created_at // 86400)))
    milestones = {row.scope: row for row in session.scalars(select(CoinMilestone).where(
        CoinMilestone.player_id == run.player_id, CoinMilestone.scope.in_(scopes)))}

    def add(title, amount, icon="flag"):
        rows.append({"title": title, "amount": amount, "icon": icon, "eligible": True, "status": "Credited"})

    def milestone(scope, value):
        old = milestones.get(scope)
        if old is not None and old.value >= value:
            return False
        if old is None:
            old = CoinMilestone(player_id=run.player_id, scope=scope, value=value)
            session.add(old)
            milestones[scope] = old
        else:
            old.value = value
        return True

    add("Race completed", 50)
    track_scope = "track/" + version.track_id
    if track_scope not in milestones or milestones[track_scope].value < 1:
        # Old accepted history may predate CoinMilestone. Inspect it only once;
        # the permanent marker survives ordinary race-history retention.
        prior_track_run = session.scalar(select(Run.id).join(Board, Board.id == Run.board_id)
            .join(TrackVersion, TrackVersion.id == Board.version_id)
            .where(Run.player_id == run.player_id, Run.status == "verified", Run.id != run.id,
                   TrackVersion.track_id == version.track_id,
                   or_(Board.manifest["purpose"].as_string().is_(None),
                       Board.manifest["purpose"].as_string() != "creator_test")).limit(1))
        milestone(track_scope, 1)
        if prior_track_run is None:
            add("First time on track", 50)
    flying = min(run.lap_ticks[1:])
    if previous[0] and run.time_ticks < previous[0]:
        add("New race PB", 100, "timer")
    if previous[1] and flying < previous[1]:
        add("New lap PB", 100, "timer")
    from .reward_ranks import percentile_amount
    for metric, ticks in (("race", run.time_ticks), ("lap", flying)):
        earned = milestones.get(metric + "/" + board.id)
        if earned is not None and earned.value >= 500:
            continue
        amount = percentile_amount(session, board.id, metric, ticks)
        if amount and milestone(metric + "/" + board.id, amount):
            add("Race percentile tier" if metric == "race" else "Best-lap percentile tier", amount, "bars")
    if binding and binding.outcome and binding.outcome.get("counted"):
        completed = milestones.get("challenge/attempt/" + binding.challenge_id)
        daily_scope = "challenge/day/" + str(run.created_at // 86400)
        daily = milestones.get(daily_scope)
        if completed or daily is None or daily.value < CHALLENGE_DAILY_LIMIT:
            if milestone("challenge/attempt/" + binding.challenge_id, 1):
                if daily is None:
                    daily = CoinMilestone(player_id=run.player_id, scope=daily_scope, value=1)
                    session.add(daily)
                    milestones[daily_scope] = daily
                else:
                    daily.value += 1
                add("Challenge completed", 50)
            if binding.outcome.get("beaten") and milestone("challenge/beaten/" + binding.challenge_id, 1):
                add("Challenge goal", 100, "trophy")
    if incident_free is True:
        add("Clean race", 200, "trophy")
    from .achievements import capture_race
    capture_race(session, run, previous, incident_free=incident_free, acceptance=acceptance)
    amount = min(sum(row["amount"] for row in rows), MAX_BALANCE - wallet.balance)
    if amount != sum(row["amount"] for row in rows):
        rows = [{"title": "Wallet capacity", "amount": amount, "icon": "coin", "eligible": True, "status": "Credited"}]
    wallet.balance += amount
    wallet.revision += 1
    if acceptance:
        from .studio_finance import race_coin_entries
        race_coin_entries(session, wallet, run.id, amount, rows, opening_balance, opening_revision)
    else:
        from .studio_finance import coin_entry
        coin_entry(session,wallet,"run/"+run.id,"earned",amount,{"rows":rows})
    receipt = CoinReward(run_id=run.id, player_id=run.player_id, amount=amount, rows=rows)
    session.add(receipt)
    if acceptance:
        acceptance.reward = receipt
