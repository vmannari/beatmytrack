"""Indexed object retirement candidates avoid repeated full-bucket scans."""
from sqlalchemy import select, union_all

from .maintenance import ArchiveChunk, PublicationIntent, PublicationUpload, RankingArchive, Run, TrackVersion
from .object_models import ObjectGarbageCandidate, ObjectPin
from .packed_storage import insert
from .track_models import OperationState, now


def referenced(session, keys):
    return set(session.scalars(union_all(
        select(ArchiveChunk.digest).where(ArchiveChunk.digest.in_(keys)),
        select(RankingArchive.digest).where(RankingArchive.digest.in_(keys)),
        select(TrackVersion.content_hash).where(TrackVersion.content_hash.in_(keys)),
        select(Run.replay_hash).where(Run.replay_hash.in_(keys)),
        select(Run.ghost_hash).where(Run.ghost_hash.in_(keys)),
        select(PublicationIntent.content_hash).where(PublicationIntent.content_hash.in_(keys), PublicationIntent.evidence_retired.is_(False)),
        select(PublicationIntent.replay_hash).where(PublicationIntent.replay_hash.in_(keys), PublicationIntent.evidence_retired.is_(False)),
        select(PublicationUpload.content_hash).where(PublicationUpload.content_hash.in_(keys), PublicationUpload.evidence_retired.is_(False)),
        select(PublicationUpload.replay_hash).where(PublicationUpload.replay_hash.in_(keys), PublicationUpload.evidence_retired.is_(False)),
    )))


def collect_once(factory, blobs, *, limit=100, at=None):
    if not 1 <= limit <= 1000:
        raise ValueError("Invalid object retirement budget")
    stamp = now() if at is None else at
    with factory() as session:
        pause = session.get(OperationState, "object-maintenance")
        if pause is not None and pause.updated_at > stamp:
            return False
        keys = session.scalars(select(ObjectGarbageCandidate.digest).where(ObjectGarbageCandidate.due_at <= stamp)
            .order_by(ObjectGarbageCandidate.due_at, ObjectGarbageCandidate.digest).limit(limit)).all()
        # Preserve publication's Pin -> Candidate lock order across replicas.
        for key in sorted(keys):
            session.execute(insert(session)(ObjectPin).values(digest=key, expires_at=0)
                .on_conflict_do_nothing(index_elements=[ObjectPin.digest]))
            pin = session.scalar(select(ObjectPin).where(ObjectPin.digest == key).with_for_update())
            candidate = session.scalar(select(ObjectGarbageCandidate).where(ObjectGarbageCandidate.digest == key)
                .with_for_update(skip_locked=True))
            if candidate is None:
                continue
            if pin.expires_at > stamp:
                candidate.due_at = pin.expires_at+60
                continue
            if referenced(session, [key]):
                session.delete(candidate)
                continue
            removed = blobs.store.delete_in_session(session, key) if hasattr(blobs.store, "delete_in_session") else blobs.delete(key)
            if removed is False:
                candidate.due_at = stamp+60
                continue
            session.delete(candidate)
            session.delete(pin)
        session.commit()
        return bool(keys)
