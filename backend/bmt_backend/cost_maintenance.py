"""Fair, bounded background cost work with foreground backlog and backup guards."""
import time

from sqlalchemy import delete, select

from .cost_archives import archive_once, backfill_retry_keys
from .maintenance import retain
from .object_garbage import collect_once as garbage_once
from .object_models import ArchiveChunk, ObjectGarbageCandidate
from .packed_storage import insert
from .track_models import OperationState, Run, now


class CostMaintenance:
    def __init__(self, factory, blobs, settings):
        self.factory, self.blobs, self.settings = factory, blobs, settings
        self.turn = 0
        self.check_at, self.foreground_busy = 0.0, False
        self.retention_at, self.legacy_at = 0.0, 0.0
        self.legacy_cursor = {"packed": False, "cursor": None}

    def step(self):
        tick = time.monotonic()
        if tick >= self.check_at:
            with self.factory() as session:
                oldest = session.scalar(select(Run.created_at).where(Run.status.in_(("queued", "verifying")))
                    .order_by(Run.created_at).limit(1))
                backup = session.get(OperationState, "object-maintenance")
                self.foreground_busy = ((oldest is not None and now()-oldest > self.settings.world_ranking_max_queue_age_seconds)
                    or (backup is not None and backup.updated_at > now()))
            self.check_at = tick+2
        if self.foreground_busy:
            return False
        role = self.turn % 8
        self.turn += 1
        if role in (0, 1):
            return archive_once(self.factory, self.blobs, kind="reward" if role == 0 else "retry",
                                days=self.settings.cost_archive_days, limit=self.settings.cost_archive_batch)
        if role == 2:
            return garbage_once(self.factory, self.blobs)
        if role == 3:
            if tick < self.retention_at:
                return False
            result = retain(self.factory, self.blobs, self.settings.retention_days, apply=True, online=True, scan_objects=False)
            more = any(result[name] >= 1000 for name in ("runs", "tickets", "resume_races"))
            self.retention_at = tick + (0 if more else 60)
            return more
        if role == 4:
            return self.blobs.compact_once()
        if role == 5:
            return self.blobs.collect_once() or self.blobs.io.cleanup_temporary(now()-86400)
        if role == 6:
            return backfill_retry_keys(self.factory, self.settings.cost_archive_batch) or expire_retry_archives(self.factory)
        if tick < self.legacy_at:
            return False
        result = retain(self.factory, self.blobs, self.settings.retention_days, apply=True, online=True,
                        object_cursor=self.legacy_cursor, scan_limit=100)
        self.legacy_cursor = result["next_object_cursor"] or {"packed": False, "cursor": None}
        self.legacy_at = tick + (5 if result["objects_deferred"] else 86400)
        return result["objects_deferred"]


def expire_retry_archives(factory, *, limit=100):
    # The server rejects these keys before archive lookup. Reward archives remain.
    cutoff = str(now()-100*86400)
    with factory() as session:
        rows = session.scalars(select(ArchiveChunk.digest).where(ArchiveChunk.kind == "retry", ArchiveChunk.upper < cutoff)
            .order_by(ArchiveChunk.upper).limit(limit)).all()
        if rows:
            session.execute(insert(session)(ObjectGarbageCandidate).values([{"digest": key, "due_at": now()} for key in rows])
                .on_conflict_do_nothing(index_elements=[ObjectGarbageCandidate.digest]))
            session.execute(delete(ArchiveChunk).where(ArchiveChunk.digest.in_(rows)))
            session.commit()
        return bool(rows)
