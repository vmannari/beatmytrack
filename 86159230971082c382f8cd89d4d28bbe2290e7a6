"""Bounded metric-weighted weekly planning, shared across skill groups and scopes."""
import logging
import math
import random
import secrets
import time
from collections import Counter

from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from .contracts import vehicle_build_contract
from .rivalry import TRACK_COUNT, eligible_query, week_window
from .rivalry_models import RivalryGroup, RivalryWeekPlan
from .track_models import OperationState, Track, TrackVersion, digest, now

WEEK = 7 * 86400
HORIZON = 4
CANDIDATE_LIMIT = 1000
logger = logging.getLogger("bmt.rivalry_planning")


def plan_contract(active, vehicle):
    return digest(vehicle_build_contract(active, vehicle))


def planning_lock(db, contract):
    identity = "rivalry-plan:" + contract
    insert = pg_insert if db.bind.dialect.name == "postgresql" else sqlite_insert
    db.execute(insert(OperationState).values(id=identity, updated_at=0, details={}).on_conflict_do_nothing())
    db.scalar(select(OperationState).where(OperationState.id == identity).with_for_update())


def candidates(db, active, vehicle, anchor):
    """A rotating indexed window; read only bounded metadata, never documents or PBs."""
    query = eligible_query(active, vehicle).where(Track.archived.is_(False))
    rows = list(db.scalars(query.where(TrackVersion.id >= anchor).order_by(TrackVersion.id).limit(CANDIDATE_LIMIT)))
    if len(rows) < CANDIDATE_LIMIT:
        rows += list(db.scalars(query.where(TrackVersion.id < anchor).order_by(TrackVersion.id)
                                .limit(CANDIDATE_LIMIT - len(rows))))
    return rows


def metric(version):
    theme = (version.discovery or {}).get("theme", "unknown")
    return {"version_id": version.id, "track_id": version.track_id, "name": version.name,
            "theme": theme if isinstance(theme, str) else "unknown",
            "rating_average": round(version.rating_sum / version.rating_count, 3) if version.rating_count else None,
            "rating_count": version.rating_count, "verified_finishers": version.verified_finishers}


def weighted_tracks(rows, seed, used, keep=()):
    """Weighted sampling without replacement; unseen tracks and biome variety first."""
    rng = random.Random(seed)
    chosen = list(keep)
    themes = Counter(item["theme"] for item in chosen)
    selected = {item["track_id"] for item in chosen}
    pool = {v.track_id: v for v in rows if v.track_id not in selected}
    while pool and len(chosen) < TRACK_COUNT:
        # Avoid repeats until the pool is exhausted across the rolling calendar.
        least_used = min(used.get(tid, 0) for tid in pool)
        available = sorted((v for tid, v in pool.items() if used.get(tid, 0) == least_used), key=lambda v: v.id)
        weights = []
        for v in available:
            # Bayesian rating (10 prior votes at 4 stars) avoids a one-vote jackpot.
            rating = (v.rating_sum + 40) / (v.rating_count + 10)
            popularity = 1 + min(2, math.log1p(max(0, v.verified_finishers)) / 4)
            weights.append(max(.1, rating - 3) * popularity / (1 + themes[metric(v)["theme"]] * 2))
        version = rng.choices(available, weights=weights, k=1)[0]
        item = metric(version)
        chosen.append(item)
        themes[item["theme"]] += 1
        del pool[version.track_id]
    return chosen


def ensure_vehicle(db, active, vehicle, timestamp, *, include_current=True):
    """One serialized transaction; retain valid plans and manual choices on every run."""
    start = week_window(timestamp)[0]
    contract = plan_contract(active, vehicle)
    planning_lock(db, contract)
    plans = list(db.scalars(select(RivalryWeekPlan).where(RivalryWeekPlan.vehicle_id == vehicle,
        RivalryWeekPlan.week_start >= start - 8 * WEEK, RivalryWeekPlan.week_start <= start + HORIZON * WEEK)
        .order_by(RivalryWeekPlan.week_start, RivalryWeekPlan.id).limit(1000)))
    current = {p.week_start: p for p in plans if p.contract_key == contract and p.week_start >= start}
    used = Counter()
    # Count a track at most once per week even across historical build revisions.
    seen = set()
    for p in plans:
        if p.week_start < start:
            for item in p.tracks:
                seen.add((p.week_start, item["track_id"]))
    historical = db.execute(select(RivalryGroup.week_start, RivalryGroup.tracks).where(
        RivalryGroup.vehicle_id == vehicle, RivalryGroup.week_start >= start - 8 * WEEK,
        RivalryGroup.week_start < start).order_by(RivalryGroup.week_start.desc(), RivalryGroup.id).limit(1000))
    for week, tracks in historical:
        for item in tracks:
            track_id = item.get("entry", {}).get("track_id")
            if track_id:
                seen.add((week, track_id))
    used.update(tid for _, tid in seen)
    used.update(item["track_id"] for p in current.values() if p.week_start >= start for item in p.tracks)
    anchor = digest({"contract": contract, "week": start})[:32]
    # UUID text IDs: use a stable per-week point in the index, avoiding prefix bias.
    anchor = f"{anchor[:8]}-{anchor[8:12]}-{anchor[12:16]}-{anchor[16:20]}-{anchor[20:]}"
    rows = candidates(db, active, vehicle, anchor)
    pinned_ids = {item["version_id"] for p in current.values() for item in p.tracks}
    if pinned_ids:
        # Previously pinned eligible choices remain valid outside this week's window.
        extra = db.scalars(eligible_query(active, vehicle).where(TrackVersion.id.in_(pinned_ids), Track.archived.is_(False)))
        rows = list({v.id: v for v in [*rows, *extra]}.values())
    eligible = {v.id: v for v in rows}
    changes = 0
    for offset in range(0 if include_current else 1, HORIZON + 1):
        week = start + offset * WEEK
        plan = current.get(week)
        if plan:
            valid = [item for item in plan.tracks if item["version_id"] in eligible]
            if len(valid) == TRACK_COUNT or week <= timestamp:
                continue
        else:
            valid = []
        seed = plan.seed if plan else secrets.token_hex(32)
        selection = weighted_tracks(rows, seed, used, valid)
        if len(selection) != TRACK_COUNT:
            continue  # Surface the shortfall; never fabricate or relax eligibility.
        if plan:
            replacements = iter(selection[len(valid):])
            selection = [item if item["version_id"] in eligible else next(replacements) for item in plan.tracks]
            used.subtract(item["track_id"] for item in plan.tracks)
        if plan is None:
            plan = RivalryWeekPlan(week_start=week, contract_key=contract, vehicle_id=vehicle,
                tracks=selection, seed=seed, revision=0, source="automatic", created_at=timestamp, updated_at=timestamp)
            db.add(plan)
        else:
            plan.tracks, plan.revision, plan.source, plan.updated_at = selection, plan.revision + 1, "repaired", timestamp
        used.update(item["track_id"] for item in selection)
        changes += 1
    db.flush()
    return changes


def planned_versions(db, active, vehicle, timestamp):
    start = week_window(timestamp)[0]
    contract = plan_contract(active, vehicle)
    plan = db.scalar(select(RivalryWeekPlan).where(RivalryWeekPlan.week_start == start,
        RivalryWeekPlan.contract_key == contract))
    if plan is None:
        ensure_vehicle(db, active, vehicle, timestamp)
        plan = db.scalar(select(RivalryWeekPlan).where(RivalryWeekPlan.week_start == start,
            RivalryWeekPlan.contract_key == contract))
    if plan is None:
        return []
    ids = [item["version_id"] for item in plan.tracks]
    # A new publication does not silently replace an already scheduled revision.
    # Eligibility is rechecked by the planner for future weeks. Active pins only
    # require the original publication and its owner to remain available.
    from .identity_models import Player
    valid = set(db.scalars(select(TrackVersion.id).join(Track).join(Player, Player.id == Track.owner_id)
        .where(TrackVersion.id.in_(ids), TrackVersion.state == "published", Track.hidden.is_(False),
            Track.archived.is_(False), Player.disabled.is_(False))))
    return ids if len(valid) == TRACK_COUNT else []


def maintain(app):
    """Called before worker claims, including under load; globally coalesced to 60s."""
    monotonic = time.monotonic()
    if monotonic < getattr(app.state, "rivalry_planning_next_check", 0):
        return
    app.state.rivalry_planning_next_check = monotonic + 60
    try:
        active = app.state.verifier.manifest()
        timestamp = now()
        with app.state.session_factory() as db:
            insert = pg_insert if db.bind.dialect.name == "postgresql" else sqlite_insert
            db.execute(insert(OperationState).values(id="rivalry-planning", updated_at=0, details={})
                       .on_conflict_do_nothing())
            claimed = db.execute(update(OperationState).where(OperationState.id == "rivalry-planning",
                OperationState.updated_at <= timestamp - 60).values(updated_at=timestamp)).rowcount
            if claimed:
                changes = sum(ensure_vehicle(db, active, v, timestamp) for v in sorted(active.get("vehicles", {})))
                from .world_circuit import ensure_circuits
                ensure_circuits(db, app, active, timestamp)
                db.get(OperationState, "rivalry-planning").details = {"plans_changed": changes}
            db.commit()
    except Exception:
        logger.exception("rivalry_planning_failed")
