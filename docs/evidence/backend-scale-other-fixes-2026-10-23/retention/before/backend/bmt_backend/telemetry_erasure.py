"""Erasure and private expiry share semantic owners with telemetry projection."""
from sqlalchemy import delete, select

from .studio_platform_models import AnalysisDay, AnalysisPerson, AnalysisSession
from .telemetry_models import ProductEvent, ProductPlayerDay, ProductPublication
from .telemetry_queue import finish, lock_actor, partition, shared_partition
from .telemetry_queue_models import TelemetryActor, TelemetryErasure, TelemetryShared, TelemetryWork
from .track_models import Track, TrackVersion, now


def lock_shared(session, identities):
    for identity in sorted(set(identities)):
        session.scalar(select(TelemetryShared).where(TelemetryShared.id == identity).with_for_update())


def cancel_events(session, events):
    ids = [event.id for event in events]
    tasks = session.scalars(select(TelemetryWork).where(TelemetryWork.event_id.in_(ids))).all()
    lock_shared(session, [task.partition for task in tasks])
    # Fences may have waited for a completing reducer; refresh terminal markers
    # before returning credits so an event can never be completed twice.
    session.flush()
    events = session.scalars(select(ProductEvent).where(ProductEvent.id.in_(ids))
        .execution_options(populate_existing=True)).all()
    finish(session, [e for e in events if e.partition_id is not None], now(), processed=False)
    session.execute(delete(TelemetryWork).where(TelemetryWork.event_id.in_(ids)))


def fence_private(session, player_id):
    lock_actor(session, player_id)


def erase_publications(session, player_id, limit=16):
    """Fence retained owned versions, including not-yet-created shared facts."""
    row = session.get(TelemetryErasure, player_id)
    if row is None:
        row = TelemetryErasure(player_id=player_id, cursor="", done=False)
        session.add(row)
        session.flush()
    if row.done:
        return False
    versions = select(TrackVersion.id).join(Track).where(Track.owner_id == player_id,
        TrackVersion.id > row.cursor).union(select(ProductPublication.version_id).where(
            ProductPublication.owner_id == player_id, ProductPublication.version_id > row.cursor))
    candidates = versions.subquery()
    ids = session.scalars(select(candidates.c.id).order_by(candidates.c.id).limit(limit)).all()
    if not ids:
        row.done = True
        return False
    lock_shared(session, [shared_partition("publication", identity) for identity in ids])
    session.execute(delete(ProductPublication).where(ProductPublication.owner_id == player_id,
        ProductPublication.version_id.in_(ids)))
    tasks = session.scalars(select(TelemetryWork).where(TelemetryWork.owner_id == player_id,
        TelemetryWork.kind == "publication", TelemetryWork.key.in_(ids))).all()
    events = session.scalars(select(ProductEvent).where(ProductEvent.id.in_([t.event_id for t in tasks]))).all()
    finish(session, events, now())
    for task in tasks:
        session.delete(task)
    row.cursor = ids[-1]
    return True


def expire_people(session, at, fact_days, limit, control):
    floor = at // 86400 - fact_days
    retired = 0
    for model, criterion in ((ProductPlayerDay, ProductPlayerDay.day < floor),
                             (AnalysisDay, AnalysisDay.day < floor),
                             (AnalysisSession, AnalysisSession.last_at < at - fact_days * 86400)):
        rows = session.scalars(select(model).where(criterion).limit(limit)).all()
        # One owner at a time, no waiting on an active analytical batch.
        for row in sorted(rows, key=lambda r: partition(r.player_id)):
            owner = session.scalar(select(TelemetryActor).where(TelemetryActor.id == partition(row.player_id))
                .with_for_update(skip_locked=True))
            if owner is not None:
                identity = tuple(getattr(row, column.key) for column in model.__mapper__.primary_key)
                current = session.get(model, identity, populate_existing=True)
                # A session can receive a later event between candidate read
                # and ownership acquisition. Recheck its refreshed expiry time.
                if current is not None and (model is not AnalysisSession or current.last_at < at - fact_days * 86400):
                    session.delete(current)
                    retired += 1
    session.flush()
    # Bound candidates before testing activity. Filtering a whole old cohort
    # with NOT EXISTS can scan millions of still-active people to find one
    # expired person. A durable keyset cursor spreads that work across passes.
    rows = session.scalars(select(AnalysisPerson).where(AnalysisPerson.player_id > control.person_cursor)
        .order_by(AnalysisPerson.player_id).limit(limit)).all()
    control.person_cursor = rows[-1].player_id if rows else ""
    for row in sorted(rows, key=lambda r: partition(r.player_id)):
        if row.first_at >= floor * 86400:
            continue
        owner = session.scalar(select(TelemetryActor).where(TelemetryActor.id == partition(row.player_id))
            .with_for_update(skip_locked=True))
        # Recheck after ownership acquisition, including a concurrent first insertion.
        if owner is not None and session.scalar(select(AnalysisDay.player_id)
                .where(AnalysisDay.player_id == row.player_id).limit(1)) is None:
            session.delete(row)
            retired += 1
    return retired, bool(rows)
