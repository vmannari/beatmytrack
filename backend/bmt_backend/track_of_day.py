"""One globally shared UTC-day pick, built by discovery maintenance only."""
import secrets

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy import exists, func, select

from .daily_standings import router as standings_router
from .db import get_session
from .discovery_models import (
    DiscoveryBootstrap,
    DiscoveryEntry,
    DiscoveryHead,
    DiscoveryPartition,
    TrackOfDay,
    TrackOfDayHistory,
    TrackOfDayState,
)
from .discovery_projection import budget, insert
from .discovery_v3 import hydrate, query_budget
from .identity_models import Player
from .security import bearer, current_player
from .track_models import Track, TrackVersion, now

router = APIRouter(tags=["track of the day"])
router.include_router(standings_router)
DAY = 86400
POOL = 50
STARTUP_SUPPLY = 100
POLICY = "track-of-day-v1"


def eligible():
    return (select(DiscoveryEntry.track_id, DiscoveryEntry.version_id,
            DiscoveryEntry.recommendation_score, DiscoveryEntry.popularity, DiscoveryEntry.published_at)
        .join(DiscoveryHead, (DiscoveryHead.track_id == DiscoveryEntry.track_id)
            & (DiscoveryHead.epoch == DiscoveryEntry.epoch))
        .join(Track, Track.id == DiscoveryEntry.track_id)
        .join(TrackVersion, TrackVersion.id == DiscoveryEntry.version_id)
        .join(Player, Player.id == Track.owner_id)
        .where(DiscoveryEntry.visible.is_(True), Track.hidden.is_(False),
            TrackVersion.state == "published", Player.disabled.is_(False),
            Player.deleted_at.is_(None), Player.is_test_driver.is_(False)))


def candidates(db, *, unseen=True):
    """Top 50 composite + top 50 recent unique racers, deduplicated equally.

    Exclude all previously featured logical tracks BEFORE ranking/limiting,
    so unseen tracks below the first pools still get their turn.
    """
    query = eligible()
    if unseen:
        query = query.where(~exists(select(TrackOfDayHistory.track_id)
            .where(TrackOfDayHistory.track_id == DiscoveryEntry.track_id)))
    result = {}
    for lane in ("top", "trending"):
        field = DiscoveryEntry.recommendation_score if lane == "top" else DiscoveryEntry.popularity
        # Each partition has its own composite/popularity index. Bound the
        # intermediate result as well as the final random-choice population.
        rows = []
        ordering = [field.desc()]
        if lane == "trending":
            ordering.append(DiscoveryEntry.published_at.desc())
        ordering.append(DiscoveryEntry.track_id.desc())
        for shard in range(16):
            rows.extend(db.execute(query.where(DiscoveryEntry.partition == shard)
                .order_by(*ordering).limit(POOL)).mappings())
        key = "recommendation_score" if lane == "top" else "popularity"
        for row in sorted(rows, key=lambda r: (r[key], r["published_at"] if lane == "trending" else 0,
                r["track_id"]), reverse=True)[:POOL]:
            result.setdefault(row["track_id"], {**row, "reason": lane})
    return list(result.values())


def step(factory, *, clock=None, include_artificial=False):
    from .daily_fixed_limits import LimitsPending, prepare

    stamp = now() if clock is None else clock
    day = stamp // DAY
    with factory() as db:
        budget(db)
        # The insert also acquires SQLite's write fence; PostgreSQL serializes
        # replicas on this singleton. Day publication and history commit together.
        db.execute(insert(db, TrackOfDayState).values(id=1, mature=False, last_day=-1)
            .on_conflict_do_nothing(index_elements=["id"]))
        state = db.scalar(select(TrackOfDayState).where(TrackOfDayState.id == 1)
            .with_for_update(skip_locked=True))
        if state is None or state.last_day > day:
            db.commit()
            return False
        existing = db.get(TrackOfDay, day)
        if existing is not None:
            if existing.version_id and not existing.lap_limits:
                try:
                    existing.lap_limits = prepare(db, db.get(TrackVersion, existing.version_id), day, stamp,
                                                 include_artificial=include_artificial)
                except LimitsPending:
                    db.rollback()
                    return False
                state.last_day = day
                db.commit()
                return True
            db.commit()
            return False
        if state.last_day >= day:
            db.commit()
            return False
        ready = list(db.scalars(select(DiscoveryPartition.ready)))
        bootstrap = db.get(DiscoveryBootstrap, 1)
        if len(ready) != 16 or not all(ready) or not bootstrap or not bootstrap.ready:
            db.commit()
            return False
        supply = list(db.execute(eligible().limit(STARTUP_SUPPLY)))
        state.mature = state.mature or len(supply) >= STARTUP_SUPPLY
        pool = candidates(db)
        if not pool and supply and not state.mature:
            # Reuse exists only during small-catalogue startup, after every
            # currently eligible track has appeared. Prefer the least recent,
            # preventing consecutive repeats whenever alternatives exist.
            query = (eligible().outerjoin(TrackOfDayHistory,
                TrackOfDayHistory.track_id == DiscoveryEntry.track_id)
                .add_columns(func.coalesce(TrackOfDayHistory.last_day, -1).label("last_day"))
                .order_by(func.coalesce(TrackOfDayHistory.last_day, -1), DiscoveryEntry.track_id)
                .limit(STARTUP_SUPPLY))
            rows = list(db.execute(query).mappings())
            pool = [{**row, "reason": "startup_repeat"} for row in rows
                if row["last_day"] == rows[0]["last_day"]]
        item = secrets.choice(pool) if pool else None
        limits = {}
        if item:
            try:
                limits = prepare(db, db.get(TrackVersion, item["version_id"]), day, stamp,
                                 include_artificial=include_artificial)
            except LimitsPending:
                db.rollback()
                return False
        if item:
            history = db.get(TrackOfDayHistory, item["track_id"])
            if history is None:
                db.add(TrackOfDayHistory(track_id=item["track_id"], first_day=day, last_day=day))
            else:
                history.last_day = day
        db.add(TrackOfDay(day=day, policy=POLICY, track_id=item["track_id"] if item else None,
            version_id=item["version_id"] if item else None,
            reason=item["reason"] if item else "exhausted" if supply else "empty", selected_at=stamp,
            lap_limits=limits))
        state.last_day = day
        db.commit()
        return True


@router.get("/v1/track-of-the-day")
def today(request: Request, response: Response, db=Depends(get_session), credentials=Depends(bearer)):
    player = current_player(request, credentials, db) if credentials else None
    stamp = now()
    response.headers["Cache-Control"] = "private, no-store"
    with query_budget(db):
        chosen = db.get(TrackOfDay, stamp // DAY)
        if chosen is None:
            raise HTTPException(503, "TRACK_OF_DAY_PREPARING", headers={"Retry-After": "30"})
        if chosen.version_id and not chosen.lap_limits:
            raise HTTPException(503, "LAP_LIMITS_PREPARING", headers={"Retry-After": "30"})
        items = hydrate(db, request, [{"version_id": chosen.version_id}], player) if chosen.version_id else {}
        return {"day": chosen.day, "starts_at": chosen.day * DAY, "ends_at": (chosen.day + 1) * DAY,
            "server_now": stamp, "policy": chosen.policy, "reason": chosen.reason,
            "status": "ready" if items else "unavailable", "track": items.get(chosen.version_id)}
