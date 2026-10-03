"""Reference-aware maintenance for authentication, discovery and race history."""

import argparse
import json
import os
from itertools import islice

from sqlalchemy import String, cast, delete, or_, select, update

from .config import Settings
from .db import make_engine, make_session_factory
from .identity_models import BrowserLogin, LoginChallenge, RateBucket, SessionFamily, now
from .resume_models import ResumeRace, ResumeReceipt
from .storage import LocalBlobStore
from .track_models import IdempotencyRecord, OperationState, PersonalBest, Run, RunTicket, TrackVersion


def retain(factory, blobs, days: int = 90, *, apply: bool = False, offline: bool = False,
           object_cursor: dict | None = None, scan_limit: int = 1000) -> dict:
    """Prune superseded/failed attempts while retaining PB ghosts, proofs and all tracks.

    Destructive object cleanup requires stopped writers; dry-run is the default.
    Permanent grant IDs and wallet balances are deliberately never expired.
    """
    if days < 1 or (apply and not offline):
        raise ValueError("Applying retention requires --offline after stopping API and workers")
    cursor = object_cursor or {"shard": 0, "offset": 0}
    if (set(cursor) != {"shard", "offset"} or any(type(v) is not int or v < 0 for v in cursor.values())
            or cursor["shard"] > 256 or not 1 <= scan_limit <= 1000):
        raise ValueError("Invalid retention cursor or scan limit")
    cutoff = now() - days * 86400
    with factory() as session:
        candidates = session.scalars(select(Run).where(
            Run.status.in_(("verified", "failed", "rejected")), Run.finished_at < cutoff,
            ~Run.id.in_(select(PersonalBest.run_id)),
            ~Run.id.in_(select(TrackVersion.creator_test_run_id).where(TrackVersion.creator_test_run_id.is_not(None))),
        ).order_by(Run.finished_at, Run.id).limit(1000)).all()
        run_ids = {r.id for r in candidates}
        tickets = set(session.scalars(select(RunTicket.id).where(
            RunTicket.expires_at < cutoff,
            ~RunTicket.id.in_(select(Run.ticket_id).where(~Run.id.in_(run_ids))),
            ~RunTicket.id.in_(select(ResumeRace.ticket_id).where(ResumeRace.ticket_id.is_not(None), ResumeRace.expires_at >= cutoff)),
        ).limit(1000)))
        races = set(session.scalars(select(ResumeRace.id).where(ResumeRace.expires_at < cutoff,
            ResumeRace.ticket_id.in_(tickets))))
        races.update(session.scalars(select(ResumeRace.id).where(ResumeRace.expires_at < cutoff,
            ResumeRace.ticket_id.is_(None)).order_by(ResumeRace.expires_at, ResumeRace.id).limit(1000)))
        receipts = set(session.scalars(select(ResumeReceipt.id).where(ResumeReceipt.race_id.in_(races))))
        # Bound traversal to content-addressed JSON files inside the resolved object root.
        inspected, eligible = 0, []
        shard, offset = cursor["shard"], cursor["offset"]
        while shard < 256 and inspected < scan_limit:
            directory = blobs.root / f"{shard:02x}"
            if not directory.is_dir() or directory.is_symlink():
                shard, offset = shard + 1, 0
                continue
            with os.scandir(directory) as stream:
                # Resume skips names only; stat calls and database work are bounded.
                remaining = islice(stream, offset, None)
                exhausted = True
                for entry in remaining:
                    inspected += 1
                    offset += 1
                    path = directory / entry.name
                    if (entry.is_file(follow_symlinks=False) and path.suffix == ".json"
                            and len(path.stem) == 64 and path.stem.startswith(directory.name)
                            and all(c in "0123456789abcdef" for c in path.stem)
                            and entry.stat(follow_symlinks=False).st_mtime < now() - 86400):
                        eligible.append(path)
                    if inspected >= scan_limit:
                        exhausted = False
                        break
                if exhausted:
                    shard, offset = shard + 1, 0
        hashes = [p.stem for p in eligible]
        referenced = set(session.scalars(select(TrackVersion.content_hash).where(TrackVersion.content_hash.in_(hashes))))
        referenced.update(session.scalars(select(Run.replay_hash).where(Run.replay_hash.in_(hashes), ~Run.id.in_(run_ids))))
        orphaned = [p for p in eligible if p.stem not in referenced]
        if apply:
            offset -= sum(p.parent.name == f"{shard:02x}" for p in orphaned)
        next_cursor = {"shard": shard, "offset": offset} if shard < 256 else None
        result = {"runs": len(run_ids), "tickets": len(tickets), "resume_races": len(races),
                  "orphaned_objects": len(orphaned), "orphaned_bytes": sum(p.stat().st_size for p in orphaned), "applied": apply,
                  "objects_inspected": inspected, "object_scan_limit": scan_limit,
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
            for path in orphaned: path.unlink()
        return result


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
        session.commit()
        return result


def backfill_discovery(factory, blobs, limit: int = 100) -> dict:
    """Bounded resumable legacy metadata backfill; immutable source stays unchanged."""
    from .tracks import discovery_projection
    with factory() as session:
        missing = or_(TrackVersion.discovery.is_(None), cast(TrackVersion.discovery, String) == "null")
        rows = session.scalars(select(TrackVersion).where(missing).order_by(TrackVersion.id).limit(limit)).all()
        for row in rows:
            row.discovery = discovery_projection(blobs.get_json(row.content_hash))
        session.commit()
        return {"backfilled":len(rows), "batch_limit":limit}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--retention", action="store_true", help="Report reference-aware retention candidates")
    parser.add_argument("--apply-retention", action="store_true")
    parser.add_argument("--offline", action="store_true", help="API and all workers have been stopped")
    parser.add_argument("--object-cursor", type=json.loads, help="next_object_cursor from the previous retention batch")
    parser.add_argument("--backfill-discovery", action="store_true", help="Backfill at most 100 legacy preview projections")
    args = parser.parse_args()
    settings = Settings.from_env()
    engine = make_engine(settings.database_url)
    if args.backfill_discovery:
        print(json.dumps(backfill_discovery(make_session_factory(engine), LocalBlobStore(settings.object_dir))))
    elif args.retention or args.apply_retention:
        print(json.dumps(retain(make_session_factory(engine), LocalBlobStore(settings.object_dir), settings.retention_days, apply=args.apply_retention, offline=args.offline, object_cursor=args.object_cursor)))
    else:
        print(json.dumps(cleanup(make_session_factory(engine))))
    engine.dispose()


if __name__ == "__main__":
    main()
