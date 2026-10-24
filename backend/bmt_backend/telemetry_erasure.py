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
    retired, more = 0, False
    for model, criterion in ((ProductPlayerDay, ProductPlayerDay.day < floor),
                             (AnalysisDay, AnalysisDay.day < floor),
                             (AnalysisSession, AnalysisSession.last_at < at - fact_days * 86400)):
        rows = session.scalars(select(model).where(criterion).limit(limit)).all()
        more = more or bool(rows)
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
    # A NULL deadline is upgraded once, lazily. The expiry index supplies both
    # legacy and due candidates; retained active cohorts are never swept again.
    rows = session.scalars(select(AnalysisPerson).where(AnalysisPerson.last_day.is_(None))
        .order_by(AnalysisPerson.last_day, AnalysisPerson.player_id).limit(limit)).all()
    rows += session.scalars(select(AnalysisPerson).where(AnalysisPerson.last_day < floor)
        .order_by(AnalysisPerson.last_day, AnalysisPerson.player_id).limit(limit)).all()
    more = more or bool(rows)
    for row in sorted(rows, key=lambda r: partition(r.player_id)):
        owner = session.scalar(select(TelemetryActor).where(TelemetryActor.id == partition(row.player_id))
            .with_for_update(skip_locked=True))
        if owner is None:
            continue
        current = session.get(AnalysisPerson, row.player_id, populate_existing=True)
        if current is None:
            continue
        # The indexed latest day is one lookup, even for an old active cohort.
        # Refresh after ownership acquisition so a late activity update cannot
        # be erased using the candidate's stale deadline.
        latest = session.scalar(select(AnalysisDay.day).where(AnalysisDay.player_id == row.player_id)
            .order_by(AnalysisDay.day.desc()).limit(1))
        current.last_day = max(current.last_day if current.last_day is not None else current.first_at // 86400,
                               latest if latest is not None else current.first_at // 86400)
        if current.last_day < floor and latest is None:
            session.delete(current)
            retired += 1
    # This legacy cursor is retained for mixed-schema diagnostics, not revisited.
    control.person_cursor = ""
    return retired, more
