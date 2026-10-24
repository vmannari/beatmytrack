"""Transactional seven-calendar-day race/replay contributions, never client counts."""
import uuid
from collections import Counter

from sqlalchemy import select

from .discovery_models import DiscoveryActivity, DiscoveryHead
from .identity_models import Player
from .track_models import Board, Run, Track, TrackVersion

DAY = 86400
CAP = 5


def contribution(row):
    return (row.races, max(0, row.races - 1)) if row.counted else (0, 0)


def apply(db, changes):
    if not changes:
        return
    heads = {h.track_id: h for h in db.scalars(select(DiscoveryHead).where(DiscoveryHead.track_id.in_(changes)))}
    for tid, (races, replays) in changes.items():
        head = heads.get(tid)
        if head is None:
            raise RuntimeError("Activity contribution has no discovery head")
        head.activity_races += races
        head.activity_replays += replays
        if min(head.activity_races, head.activity_replays) < 0:
            raise RuntimeError("Discovery activity contribution underflow")


def collect(db, shard, events, stamp):
    from .discovery_projection import eligible

    run_ids = [e.run_id for e in events if e.kind == "finish" and e.run_id]
    if not run_ids:
        return
    # Read authoritative committed runs, including the late creator-proof binding.
    rows = list(db.execute(select(Run, Board.manifest, TrackVersion, Track.owner_id, Player)
        .join(Board, Board.id == Run.board_id).join(TrackVersion, TrackVersion.id == Board.version_id)
        .join(Track, Track.id == TrackVersion.track_id).join(Player, Player.id == Run.player_id)
        .where(Run.id.in_(run_ids), Run.status == "verified")))
    counts = Counter()
    for run, manifest, version, owner, player in rows:
        if (not eligible(player) or player.id == owner or manifest.get("purpose") == "creator_test"
                or manifest.get("test_population") or version.creator_test_run_id == run.id
                or run.finished_at is None or run.finished_at > stamp
                or not stamp // DAY - 6 <= run.finished_at // DAY <= stamp // DAY):
            continue
        counts[(version.track_id, player.id, run.finished_at // DAY)] += 1
    ids = {str(uuid.uuid5(uuid.NAMESPACE_URL, f"activity:{tid}:{pid}:{day}")): (tid, pid, day, n)
        for (tid, pid, day), n in counts.items()}
    previous = {r.id: r for r in db.scalars(select(DiscoveryActivity).where(DiscoveryActivity.id.in_(ids)))} if ids else {}
    changes = {}
    for identity, (tid, pid, day, n) in ids.items():
        row = previous.get(identity)
        before = contribution(row) if row else (0, 0)
        if row is None:
            row = DiscoveryActivity(id=identity, track_id=tid, player_id=pid, partition=shard.id,
                day=day, races=0, counted=True)
            db.add(row)
        row.races = min(CAP, row.races + n)
        row.counted = True
        after = contribution(row)
        old = changes.get(tid, (0, 0))
        changes[tid] = tuple(old[i] + after[i] - before[i] for i in range(2))
    apply(db, changes)


def expire(db, shard, stamp, limit):
    rows = list(db.scalars(select(DiscoveryActivity).where(DiscoveryActivity.partition == shard,
        DiscoveryActivity.day < stamp // DAY - 6).order_by(DiscoveryActivity.day, DiscoveryActivity.id).limit(limit)))
    remove(db, rows)
    return len(rows)


def remove(db, rows):
    changes = {}
    for row in rows:
        old = changes.get(row.track_id, (0, 0))
        value = contribution(row)
        changes[row.track_id] = tuple(old[i] - value[i] for i in range(2))
        db.delete(row)
    apply(db, changes)


def owner_page(db, job, stamp, limit):
    from .discovery_projection import eligible

    player = db.get(Player, job.player_id)
    rows = list(db.scalars(select(DiscoveryActivity).where(DiscoveryActivity.player_id == job.player_id,
        DiscoveryActivity.partition == job.partition, DiscoveryActivity.id > job.cursor)
        .order_by(DiscoveryActivity.id).limit(limit)))
    changes = {}
    for row in rows:
        before = contribution(row)
        row.counted = eligible(player) and row.day >= stamp // DAY - 6
        after = contribution(row)
        old = changes.get(row.track_id, (0, 0))
        changes[row.track_id] = tuple(old[i] + after[i] - before[i] for i in range(2))
        if player is None or player.deleted_at is not None:
            db.delete(row)
    apply(db, changes)
    if rows:
        job.cursor = rows[-1].id
    else:
        db.delete(job)
