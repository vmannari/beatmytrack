"""Telemetry v2: short append/admission transactions, independent SQL owners."""
import hashlib
import time
from collections import Counter, defaultdict

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from .telemetry_models import ProductEvent, ProductMetric, ProductState
from .telemetry_queue_models import (
    TelemetryActor,
    TelemetryControl,
    TelemetryCredit,
    TelemetryFinish,
    TelemetryIntake,
    TelemetryMetric,
    TelemetryMetricFold,
    TelemetryRollup,
    TelemetryShared,
    TelemetrySharedIntake,
    TelemetryWork,
)
from .track_models import digest, now

PARTITIONS = 256
CREDIT_BUCKETS = 64


def insert_for(session, model):
    return (sqlite_insert if session.bind.dialect.name == "sqlite" else pg_insert)(model)


def partition(key):
    return int.from_bytes(hashlib.sha256(key.encode()).digest()[:4], "big") % PARTITIONS


def activate(session):
    control = session.get(TelemetryControl, 1)
    if control is None:
        raise RuntimeError("TELEMETRY_V2_MIGRATION_REQUIRED")
    if not control.active:
        control = session.scalar(select(TelemetryControl).where(TelemetryControl.id == 1)
            .with_for_update().execution_options(populate_existing=True))
        if not control.active:
            baseline = session.get(ProductState, 1)
            control.baseline_processed = baseline.processed_events
            control.baseline_truncated = baseline.truncated_profiles
            control.active = True
            control.ready = session.scalar(select(ProductEvent.id).where(
                ProductEvent.partition_id.is_(None), ProductEvent.processed_at.is_(None)).limit(1)) is None
    return control


def configure_capacity(session, capacity):
    control = activate(session)
    if control.capacity == capacity:
        return
    control = session.scalar(select(TelemetryControl).where(TelemetryControl.id == 1)
        .with_for_update().execution_options(populate_existing=True))
    rows = session.scalars(select(TelemetryCredit).order_by(TelemetryCredit.id)
        .with_for_update().execution_options(populate_existing=True)).all()
    used = {r.id: r.capacity - r.free for r in rows}
    remaining = capacity - sum(used.values())
    if remaining < 0:
        raise HTTPException(503, "TELEMETRY_BACKLOG_FULL")
    for row in rows:
        row.free = remaining // CREDIT_BUCKETS + int(row.id < remaining % CREDIT_BUCKETS)
        row.capacity = used[row.id] + row.free
    control.capacity = capacity
    session.flush()


def reserve(session, events):
    clients = [event for event in events if event.source == "client"]
    if not clients:
        return
    start = partition(clients[0].id) % CREDIT_BUCKETS
    buckets = []
    # A failed short contention attempt is retried as a transaction by the
    # caller/HTTP client. Skipped locked credits are never called 'exhausted'.
    for low, high in ((start, CREDIT_BUCKETS), (0, start)):
        cursor_id = low
        while cursor_id < high and sum(row.free for row in buckets) < len(clients):
            bucket = session.scalar(select(TelemetryCredit).where(TelemetryCredit.id >= cursor_id,
                TelemetryCredit.id < high, TelemetryCredit.free > 0).order_by(TelemetryCredit.id)
                .with_for_update(skip_locked=True).limit(1).execution_options(populate_existing=True))
            if bucket is None:
                break
            buckets.append(bucket)
            cursor_id = bucket.id + 1
    if sum(row.free for row in buckets) < len(clients):
        available = session.scalar(select(func.sum(TelemetryCredit.free))) or 0
        if available >= len(clients):
            raise HTTPException(503, "TELEMETRY_ADMISSION_BUSY", headers={"Retry-After": "1"})
        raise HTTPException(503, "TELEMETRY_BACKLOG_FULL")
    cursor = 0
    for bucket in buckets:
        amount = min(bucket.free, len(clients) - cursor)
        for event in clients[cursor:cursor + amount]:
            event.credit_bucket = bucket.id
        bucket.free -= amount
        cursor += amount
        if cursor == len(clients):
            break


def register(session, events, *, capacity=None):
    """Call at the transaction tail, only for actually inserted receipts."""
    if not events:
        return
    activate(session)
    if capacity is not None:
        configure_capacity(session, capacity)
    events = [event for event in events if event.partition_id is None and event.processed_at is None]
    reserve(session, events)
    grouped = defaultdict(list)
    for event in events:
        grouped[partition(event.player_id)].append(event)
    intakes = {row.id: row for row in session.scalars(select(TelemetryIntake)
        .where(TelemetryIntake.id.in_(sorted(grouped))).order_by(TelemetryIntake.id)
        .with_for_update().execution_options(populate_existing=True))}
    for identity in sorted(grouped):
        intake = intakes[identity]
        for event in sorted(grouped[identity], key=lambda e: (e.received_at, e.id)):
            intake.position += 1
            event.partition_id, event.position = identity, intake.position
            intake.events += 1
            intake.clients += int(event.source == "client")
            intake.latest = max(intake.latest, event.received_at)


def register_ids(session, ids, *, capacity=None):
    if ids:
        rows = session.scalars(select(ProductEvent).where(ProductEvent.id.in_(ids))).all()
        register(session, rows, capacity=capacity)


def prepare(factory, limit=500, *, readiness=False):
    """Bounded routing of pre-cutover or explicit fixture receipts."""
    with factory() as session:
        control = activate(session)
        available = session.scalar(select(func.sum(TelemetryCredit.free))) or 0
        query = select(ProductEvent).where(ProductEvent.partition_id.is_(None), ProductEvent.processed_at.is_(None))
        if available == 0:
            query = query.where(ProductEvent.source == "server")
        rows = session.scalars(query.order_by(ProductEvent.id).limit(min(limit, max(1, available)))
            .with_for_update(skip_locked=True)).all()
        register(session, rows)
        control.ready = session.scalar(select(ProductEvent.id).where(ProductEvent.partition_id.is_(None),
            ProductEvent.processed_at.is_(None)).limit(1)) is None
        session.commit()
        return (len(rows), control.ready) if readiness else len(rows)


class PreparationSchedule:
    """Process-local empty-check coalescing; never retires legacy recovery."""
    def __init__(self, interval=5.0):
        self.interval = interval
        self.next_at = 0.0

    def step(self, factory, limit=500, *, tick=None):
        tick = time.monotonic() if tick is None else tick
        if tick < self.next_at:
            return 0
        count, ready = prepare(factory, limit, readiness=True)
        # A contended/credit-blocked queue is not ready just because we took no rows.
        self.next_at = tick + (self.interval if ready else 0)
        return count


def lock_actor(session, player_id):
    return session.scalar(select(TelemetryActor).where(TelemetryActor.id == partition(player_id))
        .with_for_update().execution_options(populate_existing=True))


def shared_identity(event):
    props, day = event.properties or {}, event.occurred_at // 86400
    version = props.get("track_version_id", props.get("track_version"))
    if event.source == "server":
        if event.name in ("track_published", "race_accepted") and version:
            return "publication", str(version)
        return None
    if event.name == "race_statistics":
        context = {"track_version_id": props.get("track_version_id", ""), "platform": event.platform,
            "build_id": event.build_id, **{name: props[name] for name in
                ("device_class", "device_model", "os_version", "outcome")}}
        if props["schema_version"] == 3:
            context.update(render_context=props["render_context"], render_context_key=digest(props["render_context"]),
                           render_context_changed=props["render_context_changed"])
        return "race", digest([day, context])
    if event.name == "network_summary":
        return "network", digest([day, event.platform, event.build_id,
            {field: props[field] for field in ("category", "device_model", "os_version")}])
    from .quality import NAMES
    discovery = event.name in ("track_exposed", "track_selected") and version
    if event.name in NAMES or discovery:
        context = {"track_version_id": version} if discovery else {
            "build_id": event.build_id, "platform": event.platform,
            **{k: v for k, v in props.items() if k not in {"samples", "slow", *("b" + str(i) for i in range(8))}}}
        return "quality", digest([day, "discovery" if discovery else event.name, context])
    return None


def shared_partition(kind, key):
    return partition(kind + "/" + key)


def defer(session, events, removed=None):
    grouped, immediate = defaultdict(list), []
    if removed is None:
        from .identity_models import Player
        creators = {event.properties.get("owner_id") for event in events}
        removed = set(session.scalars(select(Player.id).where(Player.id.in_(creators), Player.deleted_at.is_not(None))))
    for event in events:
        identity = shared_identity(event)
        if identity is None:
            immediate.append(event)
        else:
            kind, key = identity
            grouped[shared_partition(kind, key)].append((event, kind, key))
    intakes = {row.id: row for row in session.scalars(select(TelemetrySharedIntake)
        .where(TelemetrySharedIntake.id.in_(sorted(grouped))).order_by(TelemetrySharedIntake.id)
        .with_for_update().execution_options(populate_existing=True))} if grouped else {}
    for identity in sorted(grouped):
        intake = intakes[identity]
        for event, kind, key in grouped[identity]:
            intake.position += 1
            session.add(TelemetryWork(event_id=event.id, partition=identity, position=intake.position,
                kind=kind, key=key, player_id=event.player_id,
                owner_id=None if event.properties.get("owner_id") in removed else event.properties.get("owner_id")))
    return immediate


def finish(session, events, at, *, processed=True):
    """Terminal changes and grouped credit returns are one caller transaction."""
    grouped, credits = defaultdict(list), Counter()
    for event in events:
        if event.processed_at is not None:
            continue
        event.processed_at = at
        event.actor_at = event.actor_at or at
        grouped[event.partition_id].append(event)
        if event.credit_bucket is not None:
            credits[event.credit_bucket] += 1
            event.credit_bucket = None
    session.flush()
    rows = session.scalars(select(TelemetryFinish).where(TelemetryFinish.id.in_(sorted(grouped)))
        .order_by(TelemetryFinish.id).with_for_update().execution_options(populate_existing=True)).all() if grouped else []
    earliest = select(func.min(ProductEvent.position)).where(ProductEvent.partition_id == TelemetryIntake.id,
        ProductEvent.processed_at.is_(None)).scalar_subquery()
    positions = {identity: (head, pending) for identity, head, pending in session.execute(
        select(TelemetryIntake.id, TelemetryIntake.position, earliest).where(TelemetryIntake.id.in_(sorted(grouped))))} if grouped else {}
    for row in rows:
        items = grouped[row.id]
        row.events += len(items)
        row.clients += sum(e.source == "client" for e in items)
        row.processed += len(items) if processed else 0
        head, pending = positions[row.id]
        row.position = max(row.position, pending - 1 if pending is not None else head)
    if credits:
        from sqlalchemy import bindparam
        statement = TelemetryCredit.__table__.update().where(TelemetryCredit.id == bindparam("credit_id"),
            TelemetryCredit.free <= TelemetryCredit.capacity - bindparam("returned"))
        changed = session.execute(statement.values(free=TelemetryCredit.free + bindparam("returned")),
            [{"credit_id": identity, "returned": amount} for identity, amount in sorted(credits.items())])
        if changed.rowcount != len(credits):
            raise RuntimeError("Telemetry credit conservation failed")


def write_metrics(session, owner, revision, deltas):
    values = [{"owner": owner, "revision": revision, "day": day, "key": key,
               "dimension": dimension, "value": value}
              for (day, key, dimension), value in sorted(deltas.items()) if value]
    if values:
        statement = insert_for(session, TelemetryMetric).values(values)
        session.execute(statement.on_conflict_do_update(index_elements=["owner", "day", "key", "dimension"],
            set_={"value": TelemetryMetric.value + statement.excluded.value, "revision": revision}))


def claim_actor(session, limit=16):
    pending = select(ProductEvent.id).where(ProductEvent.partition_id == TelemetryActor.id,
        ProductEvent.actor_at.is_(None), ProductEvent.processed_at.is_(None)).exists()
    folded = select(TelemetryRollup.id).where(TelemetryRollup.id == TelemetryActor.metric_owner,
        TelemetryRollup.revision >= TelemetryActor.metric_revision).exists()
    # Combined batches can place a player's contribution in a different owner's
    # partial. Fold it before a later batch can emit a negative restatement.
    rows = session.scalars(select(TelemetryActor).where(pending, TelemetryActor.retry_after <= now(),
        TelemetryActor.metric_owner.is_(None) | folded)
        .order_by(TelemetryActor.serviced_at, TelemetryActor.id).with_for_update(skip_locked=True).limit(limit)).all()
    # Isolate retries after a failed combined batch, rather than repeatedly
    # aborting healthy partitions alongside the failing receipt.
    return rows[:1] if rows and rows[0].failures else rows


def claim_shared(session):
    pending = select(TelemetryWork.event_id).where(TelemetryWork.partition == TelemetryShared.id).exists()
    return session.scalar(select(TelemetryShared).where(pending, TelemetryShared.retry_after <= now()).order_by(
        TelemetryShared.serviced_at, TelemetryShared.id).with_for_update(skip_locked=True).limit(1))


def expire_partials(session, floor, limit=16):
    from sqlalchemy import delete, tuple_
    rows = session.scalars(select(TelemetryMetric).where(TelemetryMetric.day < floor)
        .order_by(TelemetryMetric.day, TelemetryMetric.owner).limit(limit)).all()
    for row in sorted(rows, key=lambda r: r.owner):
        fold = session.scalar(select(TelemetryRollup).where(TelemetryRollup.id == row.owner)
            .with_for_update(skip_locked=True))
        model = TelemetryActor if row.owner < PARTITIONS else TelemetryShared
        owner = session.scalar(select(model).where(model.id == row.owner % PARTITIONS)
            .with_for_update(skip_locked=True)) if fold is not None else None
        if owner is not None:
            key = row.owner, row.day, row.key, row.dimension
            session.execute(delete(TelemetryMetricFold).where(tuple_(TelemetryMetricFold.owner,
                TelemetryMetricFold.day, TelemetryMetricFold.key, TelemetryMetricFold.dimension).in_([key])))
            session.delete(row)
    return bool(rows)


def fold_one(factory, at, fact_days=180, limit=500):
    """Only summaries share rows, in a short independent atomic rollup."""
    with factory() as session:
        if session.bind.dialect.name == "postgresql":
            session.connection(execution_options={"isolation_level": "REPEATABLE READ"})
        actor_revision = select(TelemetryActor.revision).where(
            TelemetryActor.id == TelemetryRollup.id).scalar_subquery()
        shared_revision = select(TelemetryShared.revision).where(
            TelemetryShared.id == TelemetryRollup.id - PARTITIONS).scalar_subquery()
        from sqlalchemy import case
        source = case((TelemetryRollup.id < PARTITIONS, actor_revision), else_=shared_revision)
        owner = session.scalar(select(TelemetryRollup).where(TelemetryRollup.revision < source)
            .order_by(TelemetryRollup.serviced_at, TelemetryRollup.id)
            .with_for_update(skip_locked=True).limit(1))
        if owner is None:
            return False
        target = session.get(TelemetryActor if owner.id < PARTITIONS else TelemetryShared,
            owner.id % PARTITIONS).revision
        match = ((TelemetryMetricFold.owner == TelemetryMetric.owner) &
            (TelemetryMetricFold.day == TelemetryMetric.day) & (TelemetryMetricFold.key == TelemetryMetric.key) &
            (TelemetryMetricFold.dimension == TelemetryMetric.dimension))
        partials = session.scalars(select(TelemetryMetric).outerjoin(TelemetryMetricFold, match).where(
            TelemetryMetric.owner == owner.id, TelemetryMetric.revision > owner.revision,
            (TelemetryMetricFold.value.is_(None)) | (TelemetryMetricFold.value != TelemetryMetric.value))
            .order_by(TelemetryMetric.revision,
                TelemetryMetric.day, TelemetryMetric.key, TelemetryMetric.dimension).limit(limit + 1)).all()
        incomplete = len(partials) > limit
        fields = partials[:limit]
        from sqlalchemy import tuple_
        keys = [(r.owner, r.day, r.key, r.dimension) for r in fields]
        previous = {(r.owner, r.day, r.key, r.dimension): r.value for r in session.scalars(
            select(TelemetryMetricFold).where(tuple_(TelemetryMetricFold.owner, TelemetryMetricFold.day,
                TelemetryMetricFold.key, TelemetryMetricFold.dimension).in_(keys)))} if keys else {}
        changes, checkpoints = [], []
        for row in fields:
            delta = row.value - previous.get((row.owner, row.day, row.key, row.dimension), 0)
            if delta and row.day >= at // 86400 - fact_days:
                changes.append({"day": row.day, "key": row.key, "dimension": row.dimension, "value": delta})
            checkpoints.append({"owner": row.owner, "day": row.day, "key": row.key,
                "dimension": row.dimension, "value": row.value})
        if changes:
            statement = insert_for(session, ProductMetric).values(changes)
            session.execute(statement.on_conflict_do_update(index_elements=["day", "key", "dimension"],
                set_={"value": ProductMetric.value + statement.excluded.value}))
        if checkpoints:
            statement = insert_for(session, TelemetryMetricFold).values(checkpoints)
            session.execute(statement.on_conflict_do_update(index_elements=["owner", "day", "key", "dimension"],
                set_={"value": statement.excluded.value}))
        if not incomplete:
            owner.revision = target
        owner.serviced_at = at
        session.commit()
        return True
