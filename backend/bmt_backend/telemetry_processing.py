"""Bounded independent telemetry stages; no global lock in a projection batch."""
import time
from collections import defaultdict
from types import SimpleNamespace

from sqlalchemy import delete, false, func, literal, or_, select, text, union_all, update
from sqlalchemy.exc import DBAPIError

from . import network_health, quality, race_statistics
from .identity_models import Player
from .network_models import NetworkHealthDay
from .quality_models import QualityFact
from .race_statistics_models import RaceStatisticsDay, RaceStatisticsReceipt
from .studio_platform_models import AnalysisDay, AnalysisPerson, AnalysisSession, AnalysisState
from .telemetry_models import ProductEvent, ProductMetric, ProductPlayerDay, ProductPublication, ProductState
from .telemetry_projection import project_actor, project_publications
from .telemetry_queue import (
    PARTITIONS,
    claim_actor,
    claim_shared,
    expire_partials,
    finish,
    fold_one,
    insert_for,
    prepare,
)
from .telemetry_queue_models import (
    TelemetryActor,
    TelemetryControl,
    TelemetryCredit,
    TelemetryFinish,
    TelemetryIntake,
    TelemetryRollup,
    TelemetryShared,
    TelemetryWork,
)
from .track_models import now


def actor_once(factory, limit=500, at=None, fact_days=180, owner_limit=16):
    stamp = now() if at is None else at
    owner = None
    owner_identity = None
    try:
        with factory() as session:
            if session.bind.dialect.name == "sqlite":
                session.execute(text("BEGIN IMMEDIATE"))
            owners = claim_actor(session, owner_limit)
            owner_identity = [row.id for row in owners]
            if not owners:
                return 0
            owner = owners[0]
            events = session.scalars(select(ProductEvent).where(ProductEvent.partition_id.in_(owner_identity),
                ProductEvent.actor_at.is_(None), ProductEvent.processed_at.is_(None))
                .order_by(ProductEvent.partition_id, ProductEvent.position).limit(limit)).all()
            owner.revision += 1
            project_actor(session, events, owner, stamp, fact_days)
            positions = {}
            for event in events:
                positions[event.partition_id] = max(positions.get(event.partition_id, 0), event.position)
            for row in owners:
                if row.id in positions:
                    row.position = positions[row.id]
                    row.serviced_at = time.time_ns() // 1000
                    row.failures = 0
                    row.metric_owner, row.metric_revision = owner.id, owner.revision
            session.commit()
            return len(events)
    except Exception as error:
        if owner_identity is not None:
            error.telemetry_owner = ("actor", owner_identity)
        raise


def shared_once(factory, limit=500, at=None, fact_days=180):
    stamp = now() if at is None else at
    owner = None
    owner_identity = None
    try:
        with factory() as session:
            if session.bind.dialect.name == "sqlite":
                session.execute(text("BEGIN IMMEDIATE"))
            owner = claim_shared(session)
            owner_identity = owner.id if owner is not None else None
            if owner is None:
                return 0
            work = session.scalars(select(TelemetryWork).where(TelemetryWork.partition == owner.id)
                .order_by(TelemetryWork.position).limit(limit)).all()
            events = {event.id: event for event in session.scalars(select(ProductEvent)
                .where(ProductEvent.id.in_([item.event_id for item in work])))}
            removed = set(session.scalars(select(Player.id).where(Player.id.in_({e.player_id for e in events.values()}),
                Player.deleted_at.is_not(None))))
            groups = defaultdict(list)
            erased = []
            owner.revision += 1
            for item in work:
                event = events.get(item.event_id)
                if event is not None and event.processed_at is None:
                    if event.player_id in removed:
                        erased.append(event)
                    elif event.occurred_at >= (stamp // 86400 - fact_days) * 86400 or item.kind == "publication":
                        groups[item.kind].append(event)
                session.delete(item)
            # Same semantic key always has the same owner, including first creation.
            quality.project(session, groups["quality"], insert_for)
            network_health.project(session, groups["network"])
            race_statistics.project(session, groups["race"])
            project_publications(session, groups["publication"], owner, stamp, fact_days)
            finish(session, erased, stamp, processed=False)
            finish(session, [e for e in events.values() if e.player_id not in removed], stamp)
            owner.position = max(item.position for item in work)
            owner.serviced_at = time.time_ns() // 1000
            owner.failures = 0
            session.commit()
            return len(work)
    except Exception as error:
        if owner_identity is not None:
            error.telemetry_owner = ("shared", owner_identity)
        raise


def record_failure(factory, error):
    identity = getattr(error, "telemetry_owner", None)
    if identity is None:
        return
    family, key = identity
    keys = key if isinstance(key, list) else [key]
    model = TelemetryActor if family == "actor" else TelemetryShared
    with factory() as session:
        for row in session.scalars(select(model).where(model.id.in_(keys)).order_by(model.id).with_for_update()):
            row.failures += 1
            row.retry_after = now() + min(60, 2 ** min(6, row.failures))
        session.commit()


def retry_stage(function, *args, **kwargs):
    for attempt in range(3):
        try:
            return function(*args, **kwargs)
        except DBAPIError as error:
            code = getattr(error.orig, "sqlstate", None)
            if code not in ("40001", "40P01") or attempt == 2:
                raise
            time.sleep(0.01 * (attempt + 1))


def progress(session):
    """One MVCC snapshot of fixed-size ownership metadata, never event history."""
    statements = []
    for name, model, fields in (
        ("intake", TelemetryIntake, ("position", "events", "clients", "latest")),
        ("finish", TelemetryFinish, ("position", "events", "clients", "processed")),
        ("actor", TelemetryActor, ("revision", "first_activity", "latest_client_at", "truncated")),
        ("shared", TelemetryShared, ("revision",)),
        ("fold", TelemetryRollup, ("revision",)),
    ):
        values = [getattr(model, key) for key in fields]
        statements.append(select(literal(name).label("kind"), model.id,
            *values, *[literal(None) for _ in range(4 - len(values))]))
    data = defaultdict(list)
    keys = {"intake": ("position", "events", "clients", "latest"),
            "finish": ("position", "events", "clients", "processed"),
            "actor": ("revision", "first_activity", "latest_client_at", "truncated"),
            "shared": ("revision",), "fold": ("revision",)}
    for kind, identity, *values in session.execute(union_all(*statements).order_by("kind", "id")):
        data[kind].append(SimpleNamespace(id=identity, **dict(zip(keys[kind], values, strict=False))))
    return data


def publish(factory, at=None, fact_days=180):
    """Fixed-size metadata barriers, independent of acceptance and projection."""
    stamp = now() if at is None else at
    with factory() as session:
        reporting = session.execute(select(TelemetryControl, ProductState, AnalysisState)
            .join(ProductState, ProductState.id == TelemetryControl.id)
            .join(AnalysisState, AnalysisState.id == TelemetryControl.id)
            .where(TelemetryControl.id == 1)
            .with_for_update(of=TelemetryControl, skip_locked=True)).one_or_none()
        if reporting is None:
            return False
        control, state, analysis = reporting
        metadata = progress(session)
        intakes, finishes = metadata["intake"], metadata["finish"]
        actors, shared, folds = metadata["actor"], metadata["shared"], metadata["fold"]
        legacy = session.scalar(select(ProductEvent.id).where(ProductEvent.partition_id.is_(None),
            ProductEvent.processed_at.is_(None)).limit(1)) is not None
        barrier = dict(control.barrier or {})
        if not barrier:
            barrier = {"at": stamp, "input": [r.position for r in intakes]}
        if not legacy and all(row.position >= required for row, required in zip(finishes, barrier["input"], strict=True)):
            if "metrics" not in barrier:
                barrier["metrics"] = [r.revision for r in actors] + [r.revision for r in shared]
            if all(row.revision >= required for row, required in zip(folds, barrier["metrics"], strict=True)):
                state.processed_through = max(state.processed_through or 0, barrier["at"])
                control.published_at = stamp
                barrier = {}
        control.barrier = barrier
        state.pending_events = sum(r.events for r in intakes) - sum(r.events for r in finishes)
        state.pending_clients = session.scalar(select(func.sum(TelemetryCredit.capacity - TelemetryCredit.free))) or 0
        state.pending_capped = legacy
        state.processed_events = control.baseline_processed + sum(r.processed for r in finishes)
        state.truncated_profiles = control.baseline_truncated + sum(r.truncated for r in actors)
        starts = [r.first_activity for r in actors if r.first_activity is not None]
        if starts:
            state.collection_started_at = min(starts + ([state.collection_started_at] if state.collection_started_at is not None else []))
        state.latest_receipt_at = max([r.latest for r in intakes] + [state.latest_receipt_at or 0]) or None
        state.observed_at, state.retained_from_day, state.fact_days = stamp, stamp // 86400 - fact_days, fact_days
        analysis.processed_through = state.processed_through
        analysis.latest_client_at = max([r.latest_client_at for r in actors] + [analysis.latest_client_at or 0]) or None
        session.commit()
        return True


def maintenance(factory, at=None, raw_days=7, fact_days=180, limit=500, force=False):
    """Bound expiry separately; drain backlogs and check idle data once a minute."""
    stamp = now() if at is None else at
    with factory() as session:
        control = session.scalar(select(TelemetryControl).where(TelemetryControl.id == 1)
            .with_for_update(skip_locked=True))
        if control is None or not force and control.maintenance_at > stamp - 60:
            return {"retired_client_events": 0, "compacted_server_receipts": 0}
        # Empty/current-only databases avoid fourteen independent expiry probes.
        # Every arm is an indexed existence check; no history count or readback.
        floor = stamp // 86400 - fact_days
        from .telemetry_queue_models import TelemetryMetric
        probes = [select(ProductEvent.id).where(ProductEvent.processed_at.is_not(None),
            ProductEvent.source == "client", ProductEvent.received_at < stamp - (raw_days + 1) * 86400,
            ProductEvent.occurred_at < stamp - 7 * 86400).exists(),
            select(ProductEvent.id).where(ProductEvent.processed_at.is_not(None), ProductEvent.source == "server",
                ProductEvent.compacted == false(), ProductEvent.received_at < stamp - raw_days * 86400).exists()]
        for model, field, threshold in ((QualityFact, QualityFact.day, floor),
                (ProductMetric, ProductMetric.day, floor), (ProductPlayerDay, ProductPlayerDay.day, floor),
                (AnalysisDay, AnalysisDay.day, floor), (AnalysisSession, AnalysisSession.last_at, stamp - fact_days * 86400),
                (RaceStatisticsReceipt, RaceStatisticsReceipt.received_at, stamp - 8 * 86400),
                (RaceStatisticsDay, RaceStatisticsDay.day, floor), (NetworkHealthDay, NetworkHealthDay.day, floor),
                (ProductPublication, ProductPublication.published_at, floor * 86400),
                (TelemetryMetric, TelemetryMetric.day, floor)):
            probes.append(select(field).select_from(model).where(field < threshold).exists())
        probes.append(select(AnalysisPerson.player_id).where(AnalysisPerson.last_day.is_(None)).exists())
        probes.append(select(AnalysisPerson.player_id).where(AnalysisPerson.last_day < floor).exists())
        if not session.scalar(select(or_(*probes))):
            control.maintenance_at = stamp
            session.commit()
            return {"retired_client_events": 0, "compacted_server_receipts": 0}
        expired = session.scalars(select(ProductEvent.id).where(ProductEvent.source == "client",
            ProductEvent.processed_at.is_not(None), ProductEvent.received_at < stamp - (raw_days + 1) * 86400,
            ProductEvent.occurred_at < stamp - 7 * 86400).limit(limit)).all()
        if expired:
            session.execute(delete(ProductEvent).where(ProductEvent.id.in_(expired)))
        old_server = session.scalars(select(ProductEvent.id).where(ProductEvent.source == "server",
            ProductEvent.processed_at.is_not(None), ProductEvent.received_at < stamp - raw_days * 86400,
            ProductEvent.compacted == false()).limit(limit)).all()
        if old_server:
            session.execute(update(ProductEvent).where(ProductEvent.id.in_(old_server)).values(properties={}, compacted=True))
        # Aggregate expiry cannot recreate data: reducers reject work below the
        # reporting floor. Per-player expiry is fenced by the same owner rows.
        aggregate_more = False
        for model, keys in ((QualityFact, (QualityFact.day, QualityFact.kind, QualityFact.dimension)),
                            (ProductMetric, (ProductMetric.day, ProductMetric.key, ProductMetric.dimension))):
            from sqlalchemy import tuple_
            rows = session.execute(select(*keys).where(model.day < stamp // 86400 - fact_days)
                .order_by(*keys).limit(limit)).all()
            if rows:
                session.execute(delete(model).where(tuple_(*keys).in_(rows)))
                aggregate_more = True
        race_more = race_statistics.cleanup(session, stamp, limit, fact_days)
        network_more = network_health.cleanup(session, stamp, limit, fact_days)
        from .telemetry_erasure import expire_people
        private_retired, people_more = expire_people(session, stamp, fact_days, min(limit, 16), control)
        partial_more = expire_partials(session, stamp // 86400 - fact_days, min(limit, 16))
        ids = session.scalars(select(ProductPublication.version_id).where(
            ProductPublication.published_at < (stamp // 86400 - fact_days) * 86400).limit(limit)).all()
        if ids:
            session.execute(delete(ProductPublication).where(ProductPublication.version_id.in_(ids)))
        more = bool(expired or old_server or aggregate_more or race_more or network_more or
                    private_retired or people_more or partial_more or ids)
        control.maintenance_at = 0 if more else stamp
        session.commit()
        return {"retired_client_events": len(expired), "compacted_server_receipts": len(old_server), "more": more}


def diagnostic_pass(factory, *, limit=500, at=None, raw_days=7, fact_days=180):
    """Bounded synchronous driver for existing offline/tests; service roles split it."""
    if not 1 <= limit <= 1000 or not 1 <= raw_days <= 30 or not 14 <= fact_days <= 366:
        raise ValueError("INVALID_PRODUCT_PROCESSOR_BUDGET")
    stamp = now() if at is None else at
    prepare(factory, limit)
    processed = 0
    while processed < limit:
        amount = retry_stage(actor_once, factory, limit - processed, stamp, fact_days, owner_limit=PARTITIONS)
        if not amount:
            break
        processed += amount
    # Each receipt has at most one shared task. This driver completes only a
    # bounded pass; independently running service roles use one stage per turn.
    for _ in range(PARTITIONS):
        if not retry_stage(shared_once, factory, limit, stamp, fact_days):
            break
    for _ in range(PARTITIONS * 4):
        if not retry_stage(fold_one, factory, stamp, fact_days, limit):
            break
    cleanup = maintenance(factory, stamp, raw_days, fact_days, limit, force=True)
    publish(factory, stamp, fact_days)
    with factory() as session:
        state = session.get(ProductState, 1)
        return {"processed": processed, "pending": state.pending_events,
                "processed_through": state.processed_through, "observed_at": stamp, **cleanup}
