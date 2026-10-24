"""Replayable partition-local discovery projection; never called by a GET/page.

Source triggers append receipts. Consumers use pending flags, not a sequence
watermark: a lower sequence may commit after a higher one on another connection.
"""
import time
from collections import Counter

from sqlalchemy import and_, case, delete, exists, func, or_, select, text, tuple_
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from . import discovery_retention as retention
from .discovery_models import (
    LIFETIME,
    WINDOW,
    DiscoveryBootstrap,
    DiscoveryBoundary,
    DiscoveryChange,
    DiscoveryCollection,
    DiscoveryDriver,
    DiscoveryEntry,
    DiscoveryGuard,
    DiscoveryHead,
    DiscoveryMember,
    DiscoveryOwnerJob,
    DiscoveryPartition,
    DiscoverySession,
    DiscoveryStorage,
    DiscoveryStorageBootstrap,
)
from .identity_models import Player
from .track_models import Board, Run, Track, TrackVersion, now

BATCH = 128
RANK_INTERVAL = 60


def insert(db, model):
    return (pg_insert if db.bind.dialect.name == "postgresql" else sqlite_insert)(model)


def partition(track_id):
    return int(track_id[0], 16)


def track_range(column, shard):
    prefix = format(shard, "x")
    return and_(column >= prefix, column < prefix + "~")


def eligible(player):
    return player is not None and not player.disabled and not player.is_test_driver and player.deleted_at is None


def budget(db):
    if db.bind.dialect.name == "postgresql":
        db.execute(text("SET LOCAL statement_timeout=1500"))


def backfill_runs(factory, stamp):
    """One indexed source-history page; resume safely while writers stay active."""
    with factory() as db:
        budget(db)
        job = db.scalar(select(DiscoveryBootstrap).where(DiscoveryBootstrap.id == 1,
            DiscoveryBootstrap.ready.is_(False)).with_for_update(skip_locked=True))
        if job is None:
            return False
        rows = list(db.execute(select(Run.id, Run.player_id, Run.finished_at, Board.manifest,
                TrackVersion.track_id, TrackVersion.creator_test_run_id)
            .join(Board, Board.id == Run.board_id).join(TrackVersion, TrackVersion.id == Board.version_id)
            .where(Run.status == "verified", Run.finished_at >= stamp - WINDOW,
                tuple_(Run.finished_at, Run.id) > (job.finished_at, job.run_id))
            .order_by(Run.finished_at, Run.id).limit(BATCH)))
        values = []
        for run_id, player_id, finished_at, manifest, track_id, proof in rows:
            if manifest.get("purpose") == "creator_test" or manifest.get("test_population") or proof == run_id:
                continue
            values.append({"partition": partition(track_id), "kind": "finish", "target": track_id,
                "player_id": player_id, "run_id": run_id, "finished_at": finished_at, "created_at": stamp})
        if values:
            db.execute(insert(db, DiscoveryChange).values(values).on_conflict_do_nothing(index_elements=["run_id"]))
        if rows:
            job.finished_at, job.run_id = rows[-1].finished_at, rows[-1].id
        else:
            job.ready = True
        db.commit()
        return True


def head(db, shard, track_id):
    row = db.get(DiscoveryHead, track_id)
    if row is None:
        shard.slots += 1
        row = DiscoveryHead(track_id=track_id, partition=shard.id, slot=shard.slots,
            epoch=0, popularity=0, due_at=0)
        db.add(row)
        db.flush()
    return row


def source_rows(db, track_ids):
    if not track_ids:
        return []
    latest = (select(TrackVersion.id).where(TrackVersion.track_id == Track.id,
        TrackVersion.state == "published").order_by(TrackVersion.number.desc()).limit(1).correlate(Track).scalar_subquery())
    return list(db.execute(select(Track, TrackVersion, Player).join(Player, Player.id == Track.owner_id)
        .join(TrackVersion, TrackVersion.id == latest).where(Track.id.in_(track_ids))))


def entry_values(track, version, player, popularity):
    # Same five-observation, 3.5-star prior; deterministic 18-decimal key.
    # The result is at most 5e18, within signed BIGINT, without float cursors.
    score = ((2 * version.rating_sum + 35) * 10**18 // (2 * version.rating_count + 10))
    return {"version_id": version.id, "owner_id": track.owner_id,
        "visible": not track.hidden and eligible(player), "official": track.official,
        "name": version.name, "creator": player.display_name, "name_key": version.name.lower(),
        "creator_key": player.display_name.lower(), "theme": str((version.discovery or {}).get("theme", "")),
        "published_at": version.published_at or 0, "created_at": version.created_at,
        "rating_sum": version.rating_sum, "rating_count": version.rating_count,
        "rated": version.rating_count > 0, "score": score, "finishers": version.verified_finishers,
        "popularity": popularity}


def publish(db, shard, track_ids, stamp):
    """SCD history: only changed entries get a new row, once per partition batch."""
    sources = {t.id: (t, v, p) for t, v, p in source_rows(db, track_ids)}
    heads = {h.track_id: h for h in db.scalars(select(DiscoveryHead).where(DiscoveryHead.track_id.in_(track_ids)))} if track_ids else {}
    old_entries = {r.track_id: r for r in db.scalars(select(DiscoveryEntry).where(
        DiscoveryEntry.track_id.in_(track_ids), DiscoveryEntry.until.is_(None)))} if track_ids else {}
    changed = []
    for track_id in sorted(track_ids):
        current_head = heads.get(track_id)
        source = sources.get(track_id)
        if source is None and current_head is None:
            continue
        if current_head is None:
            shard.slots += 1
            current_head = DiscoveryHead(track_id=track_id, partition=shard.id, slot=shard.slots,
                epoch=0, popularity=0, due_at=0)
            db.add(current_head)
        old = old_entries.get(track_id)
        values = entry_values(*source, current_head.popularity) if source else None
        if values is None:
            values = {c.name: getattr(old, c.name) for c in DiscoveryEntry.__table__.columns
                if c.name not in ("track_id", "epoch", "partition", "until", "retired_at")} if old else None
            if values:
                values["visible"] = False
        if values is None:
            continue
        if old is None or any(getattr(old, key) != value for key, value in values.items()):
            changed.append((current_head, old, values))
        current_head.due_at = 0
    if changed:
        shard.epoch += 1
        for current_head, old, values in changed:
            if old is not None:
                old.until, old.retired_at = shard.epoch, stamp
            db.add(DiscoveryEntry(track_id=current_head.track_id, epoch=shard.epoch,
                partition=shard.id, until=None, retired_at=None, **values))
            current_head.epoch = shard.epoch
    return len(changed)


def finish_events(db, shard, events, stamp):
    latest = {}
    run_ids = [event.run_id for event in events if event.kind == "finish" and event.run_id]
    # A creator-proof binding may be written later in the same source
    # transaction than the verified-run trigger. Read the committed binding.
    proofs = set(db.scalars(select(Run.id).join(Board, Board.id == Run.board_id)
        .join(TrackVersion, TrackVersion.id == Board.version_id).where(Run.id.in_(run_ids),
            TrackVersion.creator_test_run_id == Run.id))) if run_ids else set()
    for event in events:
        if event.kind == "finish" and event.run_id not in proofs:
            key = event.target, event.player_id
            latest[key] = max(latest.get(key, 0), event.finished_at)
    if not latest:
        return Counter()
    old = {(r.track_id, r.player_id): r for r in db.scalars(select(DiscoveryDriver).where(
        tuple_(DiscoveryDriver.track_id, DiscoveryDriver.player_id).in_(latest)))}
    players = {r.id: r for r in db.scalars(select(Player).where(Player.id.in_({p for _, p in latest})))}
    deltas = Counter()
    for (track_id, player_id), finished_at in latest.items():
        player = players.get(player_id)
        if player is None or player.deleted_at is not None:
            continue  # A delayed receipt must never recreate deleted private state.
        row = old.get((track_id, player_id))
        previous = bool(row and row.counted)
        last_at = max(finished_at, row.last_at if row else 0)
        counted = last_at >= stamp - WINDOW and eligible(player)
        if row is None:
            if last_at < stamp - WINDOW:
                continue
            row = DiscoveryDriver(track_id=track_id, player_id=player_id, partition=shard.id,
                last_at=last_at, expires_at=last_at + WINDOW, counted=counted)
            db.add(row)
        else:
            row.last_at, row.expires_at, row.counted = last_at, last_at + WINDOW, counted
        deltas[track_id] += int(counted) - int(previous)
    return deltas


def owner_job(db, shard, stamp):
    job = db.scalar(select(DiscoveryOwnerJob).where(DiscoveryOwnerJob.partition == shard.id)
        .order_by(DiscoveryOwnerJob.player_id).limit(1))
    if job is None:
        return set(), Counter()
    changed, deltas = set(), Counter()
    if job.phase == 0:
        tracks = list(db.scalars(select(Track.id).where(Track.owner_id == job.player_id,
            track_range(Track.id, shard.id), Track.id > job.cursor).order_by(Track.id).limit(BATCH)))
        changed.update(tracks)
        if tracks:
            job.cursor = tracks[-1]
        else:
            job.phase, job.cursor = 1, ""
    else:
        player = db.get(Player, job.player_id)
        rows = list(db.scalars(select(DiscoveryDriver).where(DiscoveryDriver.player_id == job.player_id,
            DiscoveryDriver.partition == shard.id, DiscoveryDriver.track_id > job.cursor)
            .order_by(DiscoveryDriver.track_id).limit(BATCH)))
        for row in rows:
            counted = eligible(player) and row.last_at >= stamp - WINDOW
            deltas[row.track_id] += int(counted) - int(row.counted)
            row.counted = counted
            if player is None or player.deleted_at is not None:
                db.delete(row)
        if rows:
            job.cursor = rows[-1].track_id
        else:
            db.delete(job)
    return changed, deltas


def cleanup(db, stamp):
    """Every transaction bounds deletion output, including collection members."""
    for model, predicate, fields in (
        (DiscoveryEntry, DiscoveryEntry.retired_at < stamp - LIFETIME - 120, (DiscoveryEntry.track_id, DiscoveryEntry.epoch)),
        (DiscoveryBoundary, DiscoveryBoundary.expires_at < stamp, (DiscoveryBoundary.id,)),
        (DiscoverySession, DiscoverySession.expires_at < stamp, (DiscoverySession.id,)),
        (DiscoveryChange, DiscoveryChange.processed_at < stamp - 120, (DiscoveryChange.id,)),
        (DiscoveryGuard, and_(DiscoveryGuard.expires_at < stamp,
            DiscoveryGuard.lease_until <= stamp*1000), (DiscoveryGuard.id,)),
    ):
        keys = list(db.execute(select(*fields).where(predicate).limit(BATCH).with_for_update(skip_locked=True)))
        if keys:
            db.execute(delete(model).where(tuple_(*fields).in_([tuple(r) for r in keys])))
    from .discovery import DiscoverySnapshot
    expired_v2 = db.scalar(select(DiscoverySnapshot.id).where(DiscoverySnapshot.expires_at < stamp)
        .limit(1).with_for_update(skip_locked=True))
    if expired_v2:
        db.execute(delete(DiscoverySnapshot).where(DiscoverySnapshot.id == expired_v2))
    expired = db.scalar(select(DiscoveryCollection).where(DiscoveryCollection.expires_at < stamp)
        .order_by(DiscoveryCollection.expires_at, DiscoveryCollection.id).limit(1).with_for_update(skip_locked=True))
    if expired:
        keys = list(db.execute(select(DiscoveryMember.kind, DiscoveryMember.track_id)
            .where(DiscoveryMember.collection_id == expired.id).limit(BATCH * 4)))
        if keys:
            retention.erase_members(db, expired, keys)
        else:
            if expired.member_rows or expired.member_bytes:
                raise RuntimeError("Discovery empty collection retains a storage charge")
            db.delete(expired)

def step(factory, *, clock=None):
    stamp = now() if clock is None else clock
    bootstrap_work = backfill_runs(factory, stamp)
    with factory() as db:
        budget(db)
        storage_work = retention.backfill(db)
        # Prefer partitions with committed work. Uniformly rotating through all
        # empty partitions throttles a single popular track by sixteen. Idle
        # partitions still get a reserved health/reconciliation turn every 30s.
        pending = exists(select(DiscoveryChange.id).where(
            DiscoveryChange.partition == DiscoveryPartition.id, DiscoveryChange.processed_at.is_(None)))
        owners = exists(select(DiscoveryOwnerJob.player_id).where(
            DiscoveryOwnerJob.partition == DiscoveryPartition.id))
        due = exists(select(DiscoveryHead.track_id).where(DiscoveryHead.partition == DiscoveryPartition.id,
            DiscoveryHead.due_at > 0, DiscoveryHead.due_at <= stamp))
        expired = exists(select(DiscoveryDriver.track_id).where(DiscoveryDriver.partition == DiscoveryPartition.id,
            DiscoveryDriver.expires_at < stamp))
        priority = case((or_(pending, owners, due, expired, DiscoveryPartition.ready.is_(False),
            DiscoveryPartition.checked_at < time.time_ns()-30_000_000_000), 0), else_=1)
        shard = db.scalar(select(DiscoveryPartition).order_by(priority, DiscoveryPartition.checked_at,
            DiscoveryPartition.id).with_for_update(skip_locked=True).limit(1))
        if shard is None:
            db.commit()
            return bool(bootstrap_work or storage_work)
        shard.checked_at = time.time_ns()
        force = set()
        if not shard.ready:
            tracks = list(db.scalars(select(Track.id).where(track_range(Track.id, shard.id),
                Track.id > shard.cursor).order_by(Track.id).limit(BATCH)))
            force.update(tracks)
            if tracks:
                shard.cursor = tracks[-1]
            else:
                shard.ready = True
                shard.cursor = ""
        elif shard.audit_at <= stamp:
            # Bounded source reconciliation catches a missed metadata receipt;
            # unchanged rows share their existing history and are not copied.
            tracks = list(db.scalars(select(Track.id).where(track_range(Track.id, shard.id),
                Track.id > shard.cursor).order_by(Track.id).limit(BATCH)))
            force.update(tracks)
            shard.cursor = tracks[-1] if tracks else ""
            shard.audit_at = stamp + 60
        events = list(db.scalars(select(DiscoveryChange).where(DiscoveryChange.partition == shard.id,
            DiscoveryChange.processed_at.is_(None)).order_by(DiscoveryChange.id).limit(BATCH)))
        stats = {event.target for event in events if event.kind == "stats"}
        stats_heads = {h.track_id: h for h in db.scalars(select(DiscoveryHead).where(
            DiscoveryHead.track_id.in_(stats)))} if stats else {}
        for track_id in stats:
            current = stats_heads.get(track_id)
            if current is None:
                force.add(track_id)
            elif not current.due_at:
                current.due_at = min(event.created_at for event in events if event.target == track_id) + RANK_INTERVAL
        for event in events:
            if event.kind == "track":
                force.add(event.target)
            elif event.kind == "owner":
                db.execute(insert(db, DiscoveryOwnerJob).values(partition=shard.id, player_id=event.target,
                    cursor="", phase=0).on_conflict_do_update(index_elements=["partition", "player_id"],
                        set_={"cursor": "", "phase": 0}))
        deltas = finish_events(db, shard, events, stamp)
        affected, owner_deltas = owner_job(db, shard, stamp)
        force.update(affected)
        deltas.update(owner_deltas)
        expired = list(db.scalars(select(DiscoveryDriver).where(DiscoveryDriver.partition == shard.id,
            DiscoveryDriver.expires_at < stamp).order_by(DiscoveryDriver.expires_at,
                DiscoveryDriver.track_id, DiscoveryDriver.player_id).limit(BATCH)))
        for row in expired:
            deltas[row.track_id] -= int(row.counted)
            db.delete(row)
        delta_heads = {h.track_id: h for h in db.scalars(select(DiscoveryHead).where(
            DiscoveryHead.track_id.in_(deltas)))} if deltas else {}
        for track_id, delta in deltas.items():
            if delta:
                row = delta_heads.get(track_id)
                if row is None:
                    shard.slots += 1
                    row = DiscoveryHead(track_id=track_id, partition=shard.id, slot=shard.slots,
                        epoch=0, popularity=0, due_at=0)
                    db.add(row)
                if row.popularity + delta < 0:
                    raise RuntimeError("Discovery popularity contribution underflow")
                row.popularity += delta
                if not row.due_at:
                    source_times = [event.created_at for event in events if event.target == track_id]
                    row.due_at = min([stamp, *source_times]) + RANK_INTERVAL
        due = set(db.scalars(select(DiscoveryHead.track_id).where(DiscoveryHead.partition == shard.id,
            DiscoveryHead.due_at > 0, DiscoveryHead.due_at <= stamp).order_by(DiscoveryHead.due_at,
                DiscoveryHead.track_id).limit(BATCH)))
        changed = publish(db, shard, force | due, stamp)
        for event in events:
            event.processed_at = stamp
        cleanup(db, stamp)
        db.commit()
        return bool(bootstrap_work or storage_work or events or force or due or expired or affected or owner_deltas or changed)


def settle_for_diagnostics(factory, *, clock=None, maximum=10000):
    """Explicit offline/test helper; never invoked by a discovery request."""
    stamp = now() if clock is None else clock
    idle = 0
    for iteration in range(maximum):
        worked = step(factory, clock=stamp)
        idle = 0 if worked else idle + 1
        if idle >= 32:
            with factory() as db:
                pending = (db.scalar(select(DiscoveryChange.id).where(DiscoveryChange.processed_at.is_(None)).limit(1))
                    or db.scalar(select(DiscoveryOwnerJob.player_id).limit(1))
                    or db.scalar(select(DiscoveryPartition.id).where(DiscoveryPartition.ready.is_(False)).limit(1)))
            if pending is None:
                return iteration + 1
            idle = 0
    raise RuntimeError("Discovery projection did not settle within its diagnostic budget")


def repair_track(factory, track_id):
    """Explicit operator repair of one derived counter, under a SQL deadline.

    Recounts the durable pair ledger, not race history. Never called by browsing
    or normal racing. A very large ledger may require a reviewed offline repair.
    """
    with factory() as db:
        budget(db)
        shard = db.scalar(select(DiscoveryPartition).where(DiscoveryPartition.id == partition(track_id))
            .with_for_update())
        current = db.get(DiscoveryHead, track_id)
        if current is None:
            return False
        current.popularity = db.scalar(select(func.count()).select_from(DiscoveryDriver).where(
            DiscoveryDriver.track_id == track_id, DiscoveryDriver.counted.is_(True)))
        publish(db, shard, {track_id}, now())
        db.commit()
        return True


def health(factory):
    """Fixed-size operational lag sample; no queue count or source scan."""
    stamp = now()
    with factory() as db:
        budget(db)
        bootstrap = db.get(DiscoveryBootstrap, 1)
        partitions = list(db.scalars(select(DiscoveryPartition).order_by(DiscoveryPartition.id)))
        values = []
        for shard in partitions:
            pending = db.scalar(select(DiscoveryChange.created_at).where(
                DiscoveryChange.partition == shard.id, DiscoveryChange.processed_at.is_(None))
                .order_by(DiscoveryChange.id).limit(1))
            values.append({"partition":shard.id,"ready":shard.ready,"epoch":shard.epoch,
                "slots":shard.slots,"checked_age_seconds":max(0,stamp-shard.checked_at//1_000_000_000),
                "pending_age_seconds":max(0,stamp-pending) if pending is not None else 0})
        return {"population_backfill_ready":bool(bootstrap and bootstrap.ready),"partitions":values,
                "storage_backfill_ready": bool(db.scalar(select(DiscoveryStorageBootstrap.ready)
                    .where(DiscoveryStorageBootstrap.id == 1))),
                "storage_partitions": [{"partition": row.id, "member_rows": row.member_rows,
                    "charged_member_bytes": row.member_bytes}
                    for row in db.scalars(select(DiscoveryStorage).order_by(DiscoveryStorage.id))]}
