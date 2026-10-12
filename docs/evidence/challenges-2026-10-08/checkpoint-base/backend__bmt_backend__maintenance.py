"""Reference-aware maintenance for authentication, discovery and race history."""

import argparse
import json

from sqlalchemy import String, cast, delete, or_, select, update

from .config import Settings
from .db import make_engine, make_session_factory
from .identity_models import BrowserLogin, LoginChallenge, RateBucket, SessionFamily, now
from .object_models import ObjectPin
from .resume_models import ResumeRace, ResumeReceipt
from .rivalry_models import RivalryArchivedBest, RivalryBest, RivalryGroup, RivalryTicket
from .storage import LocalBlobStore, PinnedBlobStore, make_blob_store
from .track_models import IdempotencyRecord, OperationState, PersonalBest, Run, RunTicket, TrackVersion


def retain(factory, blobs, days: int = 90, *, apply: bool = False, offline: bool = False, online: bool = False,
           object_cursor: dict | None = None, scan_limit: int = 1000) -> dict:
    """Prune superseded/failed attempts while retaining PB ghosts, proofs and all tracks.

    Online cleanup requires the DB-pinned storage adapter; dry-run is the default.
    Permanent grant IDs and wallet balances are deliberately never expired.
    """
    if days < 1 or (apply and not offline and not (online and isinstance(blobs, PinnedBlobStore))):
        raise ValueError("Applying retention requires pinned --online or stopped writers with --offline")
    local = isinstance(getattr(blobs,"store",blobs),LocalBlobStore)
    cursor = object_cursor or ({"shard":0,"offset":0} if local else None)
    if (not 1 <= scan_limit <= 1000 or (local and (set(cursor)!={"shard","offset"}
            or any(type(v) is not int or v<0 for v in cursor.values()) or cursor["shard"]>256))):
        raise ValueError("Invalid retention cursor or scan limit")
    cutoff = now() - days * 86400
    from .resumes import expire_unsettled
    expire_unsettled(factory, cutoff, apply=apply)
    archived = archive_closed_weeks(factory, days, apply=apply)
    with factory() as session:
        if online and apply:
            maintenance = session.scalar(select(OperationState).where(OperationState.id == "object-maintenance").with_for_update())
            if maintenance is not None and maintenance.updated_at > now():
                raise RuntimeError("Object GC is paused for a consistent online backup")
        candidates = session.scalars(select(Run).where(
            Run.status.in_(("verified", "failed", "rejected")), Run.finished_at < cutoff,
            ~Run.id.in_(select(PersonalBest.run_id)),
            ~Run.id.in_(select(RivalryBest.run_id)),
            ~Run.id.in_(select(TrackVersion.creator_test_run_id).where(TrackVersion.creator_test_run_id.is_not(None))),
        ).order_by(Run.finished_at, Run.id).limit(1000)).all()
        run_ids = {r.id for r in candidates}
        unsettled = select(ResumeReceipt.race_id).where(ResumeReceipt.settled.is_(False))
        tickets = set(session.scalars(select(RunTicket.id).where(
            RunTicket.expires_at < cutoff,
            ~RunTicket.id.in_(select(Run.ticket_id).where(~Run.id.in_(run_ids))),
            ~RunTicket.id.in_(select(RivalryTicket.ticket_id)),
            ~RunTicket.id.in_(select(ResumeRace.ticket_id).where(ResumeRace.ticket_id.is_not(None),
                (ResumeRace.expires_at >= cutoff) | ResumeRace.id.in_(unsettled))),
        ).limit(1000)))
        races = set(session.scalars(select(ResumeRace.id).where(~ResumeRace.id.in_(unsettled), ResumeRace.expires_at < cutoff,
            ResumeRace.ticket_id.in_(tickets))))
        races.update(session.scalars(select(ResumeRace.id).where(~ResumeRace.id.in_(unsettled), ResumeRace.expires_at < cutoff,
            ResumeRace.ticket_id.is_(None)).order_by(ResumeRace.expires_at, ResumeRace.id).limit(1000)))
        receipts = set(session.scalars(select(ResumeReceipt.id).where(ResumeReceipt.race_id.in_(races))))
        rows, next_cursor = blobs.list_objects(cursor, scan_limit)
        eligible = [row for row in rows if row["modified"] < now()-86400]
        hashes = [row["digest"] for row in eligible]
        referenced = set(session.scalars(select(TrackVersion.content_hash).where(TrackVersion.content_hash.in_(hashes))))
        keep = [] if online else [~Run.id.in_(run_ids)]
        referenced.update(session.scalars(select(Run.replay_hash).where(Run.replay_hash.in_(hashes), *keep)))
        referenced.update(session.scalars(select(Run.ghost_hash).where(Run.ghost_hash.in_(hashes), *keep)))
        orphaned = [row for row in eligible if row["digest"] not in referenced]
        if online and apply:
            from sqlalchemy.dialects.postgresql import insert as pg_insert
            from sqlalchemy.dialects.sqlite import insert as sqlite_insert
            insert = sqlite_insert if session.bind.dialect.name == "sqlite" else pg_insert
            safe = []
            for row in orphaned:
                session.execute(insert(ObjectPin).values(digest=row["digest"],expires_at=0)
                    .on_conflict_do_nothing(index_elements=[ObjectPin.digest]))
                pin = session.scalar(select(ObjectPin).where(ObjectPin.digest==row["digest"]).with_for_update())
                if pin.expires_at > now():
                    continue
                # Reference checks and deletion follow the publication pin lock.
                # Newly-pruned run objects are collected in a later committed batch.
                key = row["digest"]
                if (session.scalar(select(TrackVersion.id).where(TrackVersion.content_hash==key).limit(1))
                        or session.scalar(select(Run.id).where(or_(Run.replay_hash==key,Run.ghost_hash==key)).limit(1))):
                    continue
                blobs.delete(key)
                safe.append(row)
            orphaned = safe
        if apply and next_cursor is not None and "shard" in next_cursor:
            next_cursor["offset"] = max(0, next_cursor["offset"]-sum(row["digest"].startswith(f"{next_cursor['shard']:02x}") for row in orphaned))
        result = {"runs": len(run_ids), "tickets": len(tickets), "resume_races": len(races),
                  "orphaned_objects": len(orphaned), "orphaned_bytes": sum(row["bytes"] for row in orphaned), "applied": apply,
                  "archived_weeks": archived, "objects_inspected":len(rows), "object_scan_limit": scan_limit,
                  "objects_deferred": next_cursor is not None, "next_object_cursor": next_cursor}
        if apply:
            session.execute(delete(ResumeReceipt).where(ResumeReceipt.race_id.in_(races)))
            session.execute(delete(ResumeRace).where(ResumeRace.id.in_(races)))
            session.execute(delete(Run).where(Run.id.in_(run_ids)))
            session.execute(delete(RunTicket).where(RunTicket.id.in_(tickets)))
            retired_reference = or_(
                IdempotencyRecord.response["run_id"].as_string().in_(run_ids),
                IdempotencyRecord.response["ticket_id"].as_string().in_(tickets),
                IdempotencyRecord.response["race_id"].as_string().in_(races),
                IdempotencyRecord.response["receipt_id"].as_string().in_(receipts),
            )
            # Retain retry identity without loading the entire history into Python.
            session.execute(update(IdempotencyRecord).where(retired_reference)
                            .values(response={"retired": True}))
            session.commit()
            if not online:
                for row in orphaned: blobs.delete(row["digest"])
        return result


def archive_closed_weeks(factory, days=90, *, apply=False):
    """Keep exact historical scores and membership; release optional replay/ghost evidence."""
    with factory() as session:
        groups = session.scalars(select(RivalryGroup).where(RivalryGroup.ends_at < now()-days*86400,
            RivalryGroup.archived.is_(False)).order_by(RivalryGroup.ends_at).limit(20)
            .with_for_update(skip_locked=True)).all()
        count = 0
        for group in groups:
            pending = session.scalar(select(Run.id).join(RivalryTicket, RivalryTicket.ticket_id==Run.ticket_id)
                .where(RivalryTicket.group_id==group.id,Run.status.in_(("queued","verifying"))).limit(1))
            if pending:
                continue
            count += 1
            if not apply:
                continue
            for best in session.scalars(select(RivalryBest).where(RivalryBest.group_id==group.id)):
                session.add(RivalryArchivedBest(group_id=group.id,player_id=best.player_id,slot=best.slot,
                    time_ticks=best.time_ticks,achieved_at=best.achieved_at))
            session.flush()
            session.execute(delete(RivalryBest).where(RivalryBest.group_id==group.id))
            session.execute(delete(RivalryTicket).where(RivalryTicket.group_id==group.id))
            group.archived = True
            group.tracks = [{**entry,"entry":{**entry["entry"],"points":[]}} for entry in group.tracks]
        if apply:
            session.commit()
        return count


def cleanup(factory) -> dict:
    current = now()
    with factory() as session:
        result = {}
        for name, model in (
            ("browser_logins", BrowserLogin),
            ("rate_buckets", RateBucket),
            ("login_challenges", LoginChallenge),
            ("session_families", SessionFamily),
        ):
            result[name] = session.execute(delete(model).where(model.expires_at < current)).rowcount
        result["worker_heartbeats"] = session.execute(delete(OperationState).where(OperationState.id.startswith("worker:"), OperationState.updated_at < current-86400)).rowcount
        # Only versioned expiring keys can be removed. Legacy retry identities
        # and permanent provider/store ResumeGrant IDs are never discarded.
        keys = session.execute(select(IdempotencyRecord.player_id,IdempotencyRecord.scope,IdempotencyRecord.key)
            .where(IdempotencyRecord.key.startswith("v2."),IdempotencyRecord.created_at < current-92*86400)
            .order_by(IdempotencyRecord.created_at).limit(1000)).all()
        for player,scope,key in keys:
            session.execute(delete(IdempotencyRecord).where(IdempotencyRecord.player_id==player,
                IdempotencyRecord.scope==scope,IdempotencyRecord.key==key))
        result["expired_retry_keys"] = len(keys)
        expired_pins = session.scalars(select(ObjectPin.digest).where(ObjectPin.expires_at < current-86400).limit(1000)).all()
        session.execute(delete(ObjectPin).where(ObjectPin.digest.in_(expired_pins),ObjectPin.expires_at < current-86400))
        result["expired_object_pins"] = len(expired_pins)
        session.commit()
        return result


def backfill_discovery(factory, blobs, limit: int = 100) -> dict:
    """Bounded resumable legacy metadata backfill; immutable source stays unchanged."""
    from .tracks import discovery_projection
    with factory() as session:
        missing = or_(TrackVersion.discovery.is_(None), cast(TrackVersion.discovery, String) == "null")
        rows = session.execute(select(TrackVersion.id, TrackVersion.content_hash).where(missing)
            .order_by(TrackVersion.id).limit(limit)).all()
    for version_id, content_hash in rows:
        projection = discovery_projection(blobs.get_json(content_hash))
        with factory() as session:
            session.execute(update(TrackVersion).where(TrackVersion.id == version_id, missing).values(discovery=projection))
            session.commit()
    return {"backfilled":len(rows), "batch_limit":limit}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--retention", action="store_true", help="Report reference-aware retention candidates")
    parser.add_argument("--apply-retention", action="store_true")
    parser.add_argument("--offline", action="store_true", help="API and all workers have been stopped")
    parser.add_argument("--online", action="store_true", help="Use publication pins while API and workers continue")
    parser.add_argument("--object-cursor", type=json.loads, help="next_object_cursor from the previous retention batch")
    parser.add_argument("--backfill-discovery", action="store_true", help="Backfill at most 100 legacy preview projections")
    args = parser.parse_args()
    settings = Settings.from_env()
    engine = make_engine(settings.database_url,settings)
    factory = make_session_factory(engine)
    blobs = make_blob_store(settings,factory)
    if args.backfill_discovery:
        print(json.dumps(backfill_discovery(factory,blobs)))
    elif args.retention or args.apply_retention:
        print(json.dumps(retain(factory,blobs,settings.retention_days,apply=args.apply_retention,offline=args.offline,online=args.online,object_cursor=args.object_cursor)))
    else:
        print(json.dumps(cleanup(factory)))
    engine.dispose()


if __name__ == "__main__":
    main()
