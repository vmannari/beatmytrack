"""Resumable daily Free Race curation, preceding indexed catalogue continuation."""
import hashlib
import math
from collections import Counter

from sqlalchemy import delete, select

from .discovery_models import (
    DiscoveryActivity,
    DiscoveryBootstrap,
    DiscoveryDay,
    DiscoveryEntry,
    DiscoveryHead,
    DiscoveryPartition,
)
from .identity_models import Player
from .track_models import Track, TrackVersion, now

POLICY = "daily-tracks-v1"
DAY = 86400
SIZE = 100
BATCH = 128
POOL = 500


def score(*, rating_sum, rating_count, recent_players, lifetime_players, races, replays, created_at, stamp):
    """0..1 signals; fixed weights, saturation and evidence shrinkage."""
    def volume(value, ceiling):
        return min(1.0, math.log1p(max(0, value)) / math.log1p(ceiling))

    quality = (max(0, rating_sum) + 17.5) / (max(0, rating_count) + 5) / 5
    # Include repeated finishes within a day and returns on subsequent days.
    repeat = max(replays, races - recent_players, 0) / (max(0, races) + 20)
    signals = {"rating": min(1.0, quality), "recent_players": volume(recent_players, 1000),
        "replay": min(1.0, repeat), "races": volume(races, 5000),
        "freshness": max(0.0, 1 - max(0, stamp - created_at) / (14 * DAY)),
        "lifetime_players": volume(lifetime_players, 10000)}
    weights = {"rating": 30, "recent_players": 20, "replay": 20,
        "races": 10, "freshness": 15, "lifetime_players": 5}
    return round(sum(signals[k] * weights[k] for k in weights) * 10000)


def lane_key(item, lane):
    if lane == "ranked":
        return item["score"], item["rotation"], item["track_id"]
    if lane == "fresh":
        return item["rotation"], item["score"], item["track_id"]
    return item["unseen"], item["rotation"], item["track_id"]


def retain(items, lane):
    owners = Counter()
    result = []
    for item in sorted(items, key=lambda x: lane_key(x, lane), reverse=True):
        # Bound each creator as well as the whole pool, preserving alternatives.
        if owners[item["owner_id"]] >= SIZE:
            continue
        owners[item["owner_id"]] += 1
        result.append(item)
        if len(result) == POOL:
            break
    return result


def select_mix(pools):
    """60% ranked, 20% new, 20% rotating; soft creator/biome diversity."""
    result, seen = [], set()
    owners, themes = Counter(), Counter()
    pattern = ("ranked", "ranked", "fresh", "ranked", "explore")
    for owner_cap, theme_cap in ((3, 35), (10, 60), (SIZE, SIZE)):
        while len(result) < SIZE:
            lane = pattern[len(result) % len(pattern)]
            candidate = next(((item, source) for source in (lane, "ranked", "fresh", "explore")
                for item in pools.get(source, []) if item["track_id"] not in seen
                and owners[item["owner_id"]] < owner_cap and themes[item["theme"]] < theme_cap), None)
            if candidate is None:
                break
            item, source = candidate
            result.append({**item, "reason": source})
            seen.add(item["track_id"])
            owners[item["owner_id"]] += 1
            themes[item["theme"]] += 1
    return result


def step(factory, *, clock=None):
    from .discovery_projection import budget, insert

    stamp = now() if clock is None else clock
    day = stamp // DAY
    with factory() as db:
        budget(db)
        # Singleton daily row is also the cross-worker fence. No source locks.
        db.execute(insert(db, DiscoveryDay).values(day=day, policy=POLICY, shard=0, cursor="",
            pools={}, items=[], published_at=0).on_conflict_do_nothing(index_elements=["day"]))
        job = db.scalar(select(DiscoveryDay).where(DiscoveryDay.day == day).with_for_update(skip_locked=True))
        if job is None:
            return False
        if job.published_at:
            # Fixed retention: active sessions live only thirty minutes.
            old = list(db.scalars(select(DiscoveryDay.day).where(DiscoveryDay.day < day - 2).limit(16)))
            if old:
                db.execute(delete(DiscoveryDay).where(DiscoveryDay.day.in_(old)))
            db.commit()
            return False
        ready = list(db.scalars(select(DiscoveryPartition.ready).order_by(DiscoveryPartition.id)))
        bootstrap = db.get(DiscoveryBootstrap, 1)
        if len(ready) != 16 or not all(ready) or bootstrap is None or not bootstrap.ready:
            db.commit()
            return False
        # The projection expires yesterday's contributions before this shard
        # is sampled. Midnight never scores an eighth activity day.
        expired = db.scalar(select(DiscoveryActivity.id).where(DiscoveryActivity.partition == job.shard,
            DiscoveryActivity.day < day - 6).limit(1))
        if expired is not None:
            db.commit()
            return False
        previous = db.get(DiscoveryDay, day - 1)
        shown = {i["track_id"] for i in previous.items} if previous and previous.published_at else set()
        # Traverse narrow current heads in primary-key order. Even ineligible
        # rows advance the checkpoint, so work and memory stay bounded.
        heads = list(db.scalars(select(DiscoveryHead).where(DiscoveryHead.partition == job.shard,
            DiscoveryHead.track_id > job.cursor).order_by(DiscoveryHead.track_id).limit(BATCH)))
        rows = list(db.execute(select(DiscoveryEntry, Track.created_at, DiscoveryHead.activity_races,
            DiscoveryHead.activity_replays).join(DiscoveryHead,
                (DiscoveryHead.track_id == DiscoveryEntry.track_id) & (DiscoveryHead.epoch == DiscoveryEntry.epoch))
            .join(Track, Track.id == DiscoveryEntry.track_id).join(Player, Player.id == Track.owner_id)
            .join(TrackVersion, TrackVersion.id == DiscoveryEntry.version_id)
            .where(DiscoveryHead.track_id.in_([h.track_id for h in heads]), DiscoveryEntry.visible.is_(True),
                Track.hidden.is_(False), TrackVersion.state == "published", Player.disabled.is_(False),
                Player.deleted_at.is_(None), Player.is_test_driver.is_(False)))) if heads else []
        pools = {lane: list(job.pools.get(lane, [])) for lane in ("ranked", "fresh", "explore")}
        for entry, created, races, replays in rows:
            value = score(rating_sum=entry.rating_sum, rating_count=entry.rating_count,
                recent_players=entry.popularity, lifetime_players=entry.finishers, races=races, replays=replays,
                created_at=created, stamp=day * DAY)
            rotation = hashlib.sha256(f"{POLICY}:{day}:{entry.track_id}".encode()).hexdigest()
            item = {"track_id": entry.track_id, "version_id": entry.version_id, "owner_id": entry.owner_id,
                "theme": entry.theme, "score": value, "rotation": rotation, "unseen": entry.track_id not in shown}
            pools["ranked"].append(item)
            pools["explore"].append(item)
            if created >= (day - 14) * DAY:
                pools["fresh"].append(item)
        job.pools = {lane: retain(items, lane) for lane, items in pools.items()}
        if heads:
            job.cursor = heads[-1].track_id
        else:
            job.shard += 1
            job.cursor = ""
        if job.shard == 16:
            job.items = select_mix(job.pools)
            job.pools = {}
            job.published_at = stamp
        db.commit()
        return True
