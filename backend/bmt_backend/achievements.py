"""Event-driven lifetime milestones. Reads never award, scan history or queue jobs."""
import json
import time
from pathlib import Path

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import delete, func, literal, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from .achievement_models import (
    AchievementCohort,
    AchievementCompetition,
    AchievementCount,
    AchievementFact,
    AchievementRecord,
    AchievementState,
)
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .track_models import Board, PersonalBest, Run, Track, TrackVersion, now
from .tracks import DB, Auth

router = APIRouter(route_class=ParsedJSONRoute, tags=["achievements"])
CATALOG = json.loads(Path(__file__).with_name("achievement_catalog.json").read_text(encoding="utf-8"))
FAMILIES = CATALOG["families"]
IDS = {f["id"] for f in FAMILIES if f["scope"] != "local"}
BIOMES = ("pine", "desert", "winter", "storm", "night_city")
CARS = ("compact", "pickup", "classic", "formula", "kart")
MAX_VALUE = 2**53 - 1


def insert(session, model):
    return (pg_insert if session.bind.dialect.name == "postgresql" else sqlite_insert)(model)


def eligible(player):
    return player is not None and not (player.disabled or player.deleted_at is not None or player.is_test_driver)


def count(session, player_id, key, delta=1):
    # Sixteen fixed shards avoid a global unlock/denominator lock. No per-race writes.
    shard = sum(player_id.encode()) % 16
    statement = insert(session, AchievementCount).values(key=key, shard=shard, value=delta)
    session.execute(statement.on_conflict_do_update(index_elements=["key", "shard"],
        set_={"value": AchievementCount.value + delta}))


def enroll(session, player_id):
    inserted = session.scalar(insert(session, AchievementCohort).values(player_id=player_id)
        .on_conflict_do_nothing().returning(AchievementCohort.player_id))
    if inserted:
        count(session, player_id, "__eligible")


def state(session, player_id, scope, *, skip_locked=False, accepted_creator=False):
    # Conditional insert fences concurrent account erasure without a second Player lock.
    table = AchievementState.__table__.c
    values = {"player_id": player_id, "scope": scope, "metrics": {}, "unlocked": {}, "featured": [], "revision": 0,
              "rarity_pending": False, "rarity_counted": []}
    allowed = select(Player.id).where(Player.id == player_id, Player.deleted_at.is_(None))
    if not (accepted_creator and scope == "creator"):
        allowed = allowed.where(Player.disabled.is_(False), Player.is_test_driver.is_(False))
    source = select(*(literal(value, type_=table[key].type) for key, value in values.items())).where(allowed.exists())
    session.execute(insert(session, AchievementState).from_select(list(values), source).on_conflict_do_nothing())
    return session.scalar(select(AchievementState).where(AchievementState.player_id == player_id,
        AchievementState.scope == scope).with_for_update(skip_locked=skip_locked).execution_options(populate_existing=True))


def save(session, row, metrics, stamp, *, flush=True):
    if row is None:
        return
    unlocked = dict(row.unlocked)
    newly = []
    for family in FAMILIES:
        if family["scope"] != row.scope:
            continue
        for index, threshold in enumerate(family["tiers"]):
            key = family["id"] + "/" + str(index + 1)
            if metrics.get(family["metric"], 0) >= threshold and key not in unlocked:
                unlocked[key] = stamp
                newly.append(key)
    if newly or row.revision == 0:
        row.rarity_pending = True
    row.metrics, row.unlocked = metrics, unlocked
    row.revision += 1
    if flush:
        session.flush()


def bump(metrics, key, amount=1):
    metrics[key] = min(MAX_VALUE, metrics.get(key, 0) + amount)


def fact(session, player_id, kind, identity):
    return bool(session.scalar(insert(session, AchievementFact).values(
        player_id=player_id, kind=kind, identity=identity).on_conflict_do_nothing()
        .returning(AchievementFact.identity)))


def consistent(laps, percent):
    return len(laps) == 5 and all(type(t) is int and t > 0 for t in laps) and all(
        abs(t * len(laps) - sum(laps)) * 100 <= sum(laps) * percent for t in laps)


def schedule(session, kind, identity, due_at, facts=None):
    session.execute(insert(session, AchievementCompetition).values(kind=kind, id=identity,
        due_at=due_at, done=False, facts=facts or {}).on_conflict_do_nothing())
    return session.scalar(select(AchievementCompetition).where(AchievementCompetition.kind == kind,
        AchievementCompetition.id == identity).with_for_update())


def capture_race(session, run, previous, *, incident_free=False, acceptance=None):
    """Called once under the existing CoinReward receipt and Player transaction fence."""
    board = acceptance.board if acceptance else session.get(Board, run.board_id)
    player = session.get(Player, run.player_id)
    if run.status != "verified" or not eligible(player) or board.manifest.get("purpose") or board.manifest.get("test_population"):
        return
    version = acceptance.version if acceptance else session.get(TrackVersion, board.version_id)
    track = acceptance.track if acceptance else session.get(Track, version.track_id)
    if version.state != "published" or track.hidden or track.archived:
        return
    from .challenge_models import Challenge, ChallengeTicket
    from .rivalry_models import RivalryGroup, RivalryTicket
    binding = acceptance.rivalry if acceptance else session.get(RivalryTicket, run.ticket_id)
    if binding and binding.outcome:
        group = session.get(RivalryGroup, binding.group_id)
        if not group.test_population:
            job = schedule(session, "rivalry", group.id, group.ends_at)
            outcome = binding.outcome
            before = outcome.get("overall_before", {})
            # A first run in an empty week is not a comeback. A strict sole last
            # place must have already scored against at least four real drivers.
            if before.get("completed", 0) > 0:
                from .rivalry import standings_data
                _, standings = standings_data(session, group)
                scoring = [r for r in standings if r["completed"] and not r["is_test_driver"]]
                if (len(scoring) >= 5 and all(before.get("points", 0) < r["points"]
                        for r in scoring if r["id"] != run.player_id)):
                    job.facts = {**job.facts, run.player_id: True}
    challenge_ticket = acceptance.challenge if acceptance else session.get(ChallengeTicket, run.ticket_id)
    challenge = session.get(Challenge, challenge_ticket.challenge_id) if challenge_ticket else None
    if challenge and challenge_ticket.outcome and challenge_ticket.outcome.get("counted"):
        schedule(session, "challenge", challenge.id, challenge.ends_at)
    row = state(session, run.player_id, "race")
    if row is None:
        return
    metrics = dict(row.metrics)
    bump(metrics, "races")
    length = version.manifest.get("route_length", 0)
    if type(length) in (int, float) and 0 < length <= 100000:
        bump(metrics, "distance_m", round(length * len(run.lap_ticks)))
    theme = (version.discovery or {}).get("theme", "")
    if theme in BIOMES:
        bump(metrics, "race_" + theme)
    metrics["cars_" + board.vehicle_id] = 1
    metrics["cars"] = sum(metrics.get("cars_" + car, 0) > 0 for car in CARS)
    metrics["biomes"] = sum(metrics.get("race_" + biome, 0) > 0 for biome in BIOMES)
    if metrics.get("tracks", 0) < 1000 and fact(session, run.player_id, "track", track.id):
        bump(metrics, "tracks")
    race_pb = bool(previous[0] and run.time_ticks < previous[0])
    lap_pb = bool(previous[1] and min(run.lap_ticks[1:]) < previous[1])
    if race_pb:
        bump(metrics, "race_pb")
    if lap_pb:
        bump(metrics, "lap_pb")
    metrics["pb_streak"] = metrics.get("pb_streak", 0) + 1 if race_pb else 0
    metrics["pb_streak_best"] = max(metrics.get("pb_streak_best", 0), metrics["pb_streak"])
    clean = incident_free is True
    metrics["clean_streak"] = metrics.get("clean_streak", 0) + 1 if clean else 0
    metrics["clean_streak_best"] = max(metrics.get("clean_streak_best", 0), metrics["clean_streak"])
    if clean:
        bump(metrics, "clean")
        if theme in BIOMES:
            bump(metrics, "clean_" + theme)
        metrics["clean_car_" + board.vehicle_id] = 1
    metrics["clean_biomes"] = sum(metrics.get("clean_" + biome, 0) > 0 for biome in BIOMES)
    metrics["clean_cars"] = sum(metrics.get("clean_car_" + car, 0) > 0 for car in CARS)
    if consistent(run.lap_ticks, 2):
        bump(metrics, "precision")
    if clean and consistent(run.lap_ticks, 1):
        metrics["perfectionist"] = 1
    if race_pb and metrics.get("friends", 0) < 100:
        from .news import friend_roster
        friends = [pid for pid, _ in friend_roster(session, run.player_id)]
        defeated = session.scalars(select(PersonalBest.player_id).where(PersonalBest.board_id == board.id,
            PersonalBest.player_id.in_(friends), PersonalBest.time_ticks < previous[0],
            PersonalBest.time_ticks > run.time_ticks).order_by(PersonalBest.player_id).limit(100)).all()
        for pid in defeated:
            if metrics.get("friends", 0) < 100 and fact(session, run.player_id, "friend", pid):
                bump(metrics, "friends")
    if (challenge and challenge.mode == "beat" and challenge_ticket.outcome.get("beaten")
            and challenge.creator_id != run.player_id and eligible(session.get(Player, challenge.creator_id))
            and challenge.target_ticks and previous[0] * 10 >= challenge.target_ticks * 11):
        metrics["odds"] = 1
    save(session, row, metrics, run.finished_at)
    if previous[0] == 0 or run.time_ticks < previous[0]:
        observe_record(session, board.id, run.finished_at)
    if track.owner_id != run.player_id:
        from .creator_achievements import enqueue
        enqueue(session, run, track.owner_id)


def capture_publication(session, track, player, stamp):
    row = state(session, player.id, "creator")
    if row and row.metrics.get("publications", 0) < 25 and fact(session, player.id, "published", track.id):
        metrics = dict(row.metrics)
        bump(metrics, "publications")
        save(session, row, metrics, stamp)


def capture_reach(session, track, reach, run_id):
    from .news_models import TrackRacer
    owner = session.get(TrackRacer, (track.id, track.owner_id))
    value = max(0, reach.racers - int(owner is not None))
    from .creator_achievements import capture_reach as enqueue_reach
    enqueue_reach(session, run_id, track.owner_id, value)


def leaders(session, board_id):
    return session.execute(select(PersonalBest.player_id, PersonalBest.time_ticks).join(Player)
        .where(PersonalBest.board_id == board_id, Player.disabled.is_(False), Player.deleted_at.is_(None),
            Player.is_test_driver.is_(False)).order_by(PersonalBest.time_ticks, PersonalBest.player_id).limit(11)).all()


def observe_record(session, board_id, stamp):
    rows = leaders(session, board_id)
    old = session.get(AchievementRecord, board_id)
    if len(rows) < 10 or rows[0].time_ticks == rows[1].time_ticks:
        if old:
            session.delete(old)
        return
    first = rows[0]
    if old and old.player_id == first.player_id:
        old.ticks = first.time_ticks
    else:
        values = {"board_id": board_id, "player_id": first.player_id, "ticks": first.time_ticks,
            "since": stamp, "due_at": stamp + 30 * 86400}
        session.execute(insert(session, AchievementRecord).values(**values).on_conflict_do_update(
            index_elements=["board_id"], set_=values))


def process_due(app, *, clock=None):
    """Fair bounded turns: competitions, rarity, held records and creator effects."""
    stamp = now() if clock is None else clock
    from .creator_achievements import process_one as project_creator
    roles = (process_competition, process_rarity, process_record, None)
    cursor = getattr(app.state, "achievement_role", 0)
    for offset in range(len(roles)):
        index = (cursor + offset) % len(roles)
        # Advance before execution, including failures, so a broken role cannot
        # permanently exclude later classes on the next service iteration.
        app.state.achievement_role = (index + 1) % len(roles)
        if (roles[index](app, stamp) if roles[index] else project_creator(app)):
            return True
    return False


def process_competition(app, stamp):
    with app.state.session_factory() as session:
        job = session.scalar(select(AchievementCompetition).where(AchievementCompetition.done.is_(False),
            AchievementCompetition.due_at <= stamp).order_by(AchievementCompetition.due_at,
            AchievementCompetition.kind, AchievementCompetition.id).limit(1).with_for_update(skip_locked=True))
        if job:
            finalize_competition(session, job, stamp)
            session.commit()
            return True
    return False


def process_rarity(app, stamp):
    with app.state.session_factory() as session:
        # Rarity is a coalesced projection in the existing idle worker. Racing
        # never waits on a global counter, even when playing each other's tracks.
        row = session.scalar(select(AchievementState).where(AchievementState.rarity_pending.is_(True))
            .order_by(AchievementState.player_id, AchievementState.scope).limit(1)
            .with_for_update(skip_locked=True))
        if row:
            if eligible(session.get(Player, row.player_id)):
                enroll(session, row.player_id)
                for key in sorted(set(row.unlocked) - set(row.rarity_counted)):
                    count(session, row.player_id, key)
                row.rarity_counted = sorted(row.unlocked)
            row.rarity_pending = False
            session.commit()
            return True
    return False


def process_record(app, stamp):
    with app.state.session_factory() as session:
        record = session.scalar(select(AchievementRecord).where(AchievementRecord.due_at <= stamp)
            .order_by(AchievementRecord.due_at, AchievementRecord.board_id).limit(1).with_for_update(skip_locked=True))
        if record:
            rows = leaders(session, record.board_id)
            if (len(rows) >= 10 and rows[0].player_id == record.player_id
                    and rows[0].time_ticks < rows[1].time_ticks):
                row = state(session, record.player_id, "race")
                if row:
                    save(session, row, {**row.metrics, "unbeaten": 1}, stamp)
            session.delete(record)
            session.commit()
            return True
    return False


def drive_idle(app, *, force=False):
    """No timers/services: share the existing worker with bounded idle SQL cost."""
    current = time.monotonic()
    if not force and current < getattr(app.state, "achievement_check_after", 0):
        return False
    worked = process_due(app)
    app.state.achievement_check_after = current + (0.25 if worked else 60.0)
    return worked


def finalize_competition(session, job, stamp):
    from .challenge_models import Challenge, ChallengeTicket
    from .challenges import standings
    from .rivalry import standings_data
    from .rivalry_models import RivalryGroup, RivalryTicket
    rivalry = job.kind == "rivalry"
    binding = RivalryTicket if rivalry else ChallengeTicket
    competition_id = binding.group_id if rivalry else binding.challenge_id
    pending = session.scalar(select(Run.id).join(binding, binding.ticket_id == Run.ticket_id)
        .where(competition_id == job.id, Run.status.in_(("queued", "verifying"))).limit(1))
    if pending:
        job.due_at = stamp + 60
        return
    entity = session.get(RivalryGroup if rivalry else Challenge, job.id)
    if entity is None:
        job.done = True
        return
    if stamp < entity.ends_at:
        job.due_at = entity.ends_at
        return
    if rivalry:
        if entity.test_population:
            job.done = True
            return
        _, rows = standings_data(session, entity)
        rows = [r for r in rows if r["completed"] and not r["is_test_driver"]
                and eligible(session.get(Player, r["id"]))]
        minimum = 5
        leaders_count = sum(r["rank"] == 1 for r in rows)
    else:
        if entity.cancelled:
            job.done = True
            return
        rows = [r for r in standings(session, entity) if r["ticks"] is not None
                and eligible(session.get(Player, r["id"]))]
        minimum = 2
        leaders_count = sum(r["rank"] == 1 for r in rows)
    if len(rows) >= minimum:
        # Stable Player order also makes concurrent finalizers deterministic.
        for result in sorted(rows, key=lambda r: r["id"]):
            row = state(session, result["id"], "race")
            if row is None:
                continue
            metrics = dict(row.metrics)
            if rivalry:
                if result["rank"] <= 3:
                    bump(metrics, "rivalry_podiums")
                if result["completed"] == 5:
                    bump(metrics, "rivalry_weeks")
                if result["rank"] == 1 and leaders_count == 1:
                    bump(metrics, "rivalry_wins")
                    if job.facts.get(result["id"]):
                        metrics["comeback"] = 1
            elif entity.mode == "beat":
                if result["id"] != entity.creator_id and result["ticks"] < entity.target_ticks:
                    bump(metrics, "challenge_wins")
            elif result["rank"] == 1 and leaders_count == 1:
                bump(metrics, "challenge_wins")
            save(session, row, metrics, stamp)
    job.done = True
    job.facts = {}  # Retain only the compact deduplication identity.


@router.get("/achievements")
def collection(session: DB, player: Auth):
    if player.is_test_driver:
        raise HTTPException(403, "ACHIEVEMENTS_REAL_PLAYERS_ONLY")
    rows = session.scalars(select(AchievementState).where(AchievementState.player_id == player.id)).all()
    counts = dict(session.execute(select(AchievementCount.key, func.sum(AchievementCount.value))
        .group_by(AchievementCount.key)).all())
    denominator = max(0, counts.pop("__eligible", 0))
    return {"schema": 1, "states": {row.scope: {"metrics": row.metrics, "unlocked": row.unlocked,
        "featured": row.featured, "revision": row.revision} for row in rows},
        "rarity": {"eligible": denominator, "minimum": CATALOG["rarity_minimum"],
            "definition": "Real registered players with a recorded race or creator milestone since achievements launched",
            "unlocks": counts if denominator >= CATALOG["rarity_minimum"] else {}},
        "tracking": "since_launch"}


class Featured(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")
    families: list[str] = Field(max_length=5)


@router.put("/achievements/featured")
def feature(body: Featured, session: DB, player: Auth):
    if not eligible(player):
        raise HTTPException(403, "ACHIEVEMENTS_REAL_PLAYERS_ONLY")
    if len(set(body.families)) != len(body.families) or any(f not in IDS for f in body.families):
        raise HTTPException(422, "INVALID_FEATURED_ACHIEVEMENT")
    # Serialize the two scopes in the same order as race -> creator capture.
    race = state(session, player.id, "race")
    creator = session.get(AchievementState, (player.id, "creator"))
    unlocked = {**race.unlocked, **(creator.unlocked if creator else {})}
    if any(f + "/1" not in unlocked for f in body.families):
        raise HTTPException(409, "ACHIEVEMENT_LOCKED")
    if race.featured != body.families:
        race.featured = body.families
        race.revision += 1
    session.commit()
    return {"featured": race.featured}


def erase_private(session, player_id):
    """Called after the account is fenced; decrement rarity only once."""
    from .creator_achievements import erase_pending
    if not erase_pending(session, player_id):
        return False
    rows = session.scalars(select(AchievementState).where(AchievementState.player_id == player_id)
        .order_by(AchievementState.scope).with_for_update()).all()
    cohort = session.get(AchievementCohort, player_id)
    if cohort:
        count(session, player_id, "__eligible", -1)
        for key in sorted({key for row in rows for key in row.rarity_counted}):
            count(session, player_id, key, -1)
        session.delete(cohort)
    for row in rows:
        session.delete(row)
    # Fact collection caps at 1125 per player; no race-history receipt table.
    session.execute(delete(AchievementFact).where(AchievementFact.player_id == player_id))
    session.execute(delete(AchievementRecord).where(AchievementRecord.player_id == player_id))
    return True
