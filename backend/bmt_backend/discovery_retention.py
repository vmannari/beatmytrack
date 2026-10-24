"""Bounded retained-member accounting, including incremental migration recovery."""
from fastapi import HTTPException
from sqlalchemy import and_, delete, or_, select, tuple_

from .discovery_guard import busy, claim, short_locks
from .discovery_models import (
    DiscoveryCollection,
    DiscoveryEntry,
    DiscoveryMember,
    DiscoveryStorage,
    DiscoveryStorageBootstrap,
)


def weight(kind, identifier):
    # Charged storage units include a fixed key/index allowance, not a promise
    # about PostgreSQL heap/WAL bytes or filesystem allocation.
    return 128 + len(kind.encode()) + len(identifier.encode())


def known_ids(db, values, epochs, check):
    result = []
    for start in range(0, len(values), 256):
        check()
        result.extend(db.scalars(select(DiscoveryEntry.track_id).where(
            DiscoveryEntry.track_id.in_(values[start:start+256]),
            or_(*(and_(DiscoveryEntry.partition == part, DiscoveryEntry.epoch <= epoch,
                or_(DiscoveryEntry.until.is_(None), DiscoveryEntry.until > epoch))
                for part, epoch in enumerate(epochs))))))
    return sorted(set(result))


def reserve(db, actor, settings, size, byte_size):
    claim(db, actor, settings, "storage")
    bootstrap = db.get(DiscoveryStorageBootstrap, 1)
    if not bootstrap or not bootstrap.ready:
        raise busy("DISCOVERY_STORAGE_PREPARING", 2)
    rows = list(db.scalars(select(DiscoveryCollection).where(DiscoveryCollection.scope == actor).limit(33)))
    if any(not row.accounted for row in rows):
        raise busy("DISCOVERY_STORAGE_PREPARING", 2)
    if (len(rows) >= 32 or size + sum(row.member_rows for row in rows) > settings.discovery_actor_member_rows
            or byte_size + sum(row.member_bytes for row in rows) > settings.discovery_actor_member_bytes):
        raise HTTPException(429, "DISCOVERY_STORAGE_LIMIT", headers={"Retry-After": "60"})
    part = int(actor[:2], 16) % 16
    with short_locks(db):
        counter = db.scalar(select(DiscoveryStorage).where(DiscoveryStorage.id == part).with_for_update(nowait=True))
        row_limit = settings.discovery_storage_member_rows//16 + int(part < settings.discovery_storage_member_rows % 16)
        byte_limit = settings.discovery_storage_member_bytes//16 + int(part < settings.discovery_storage_member_bytes % 16)
        if counter.member_rows+size > row_limit or counter.member_bytes+byte_size > byte_limit:
            raise HTTPException(429, "DISCOVERY_STORAGE_LIMIT", headers={"Retry-After": "60"})
        counter.member_rows += size
        counter.member_bytes += byte_size
        db.flush()
    return part


def backfill(db, batch=512):
    collection = db.scalar(select(DiscoveryCollection).where(DiscoveryCollection.accounted.is_(False))
        .order_by(DiscoveryCollection.id).limit(1).with_for_update(skip_locked=True))
    if collection is None:
        # Do not mistake another worker's locked collection for an empty queue.
        if db.scalar(select(DiscoveryCollection.id).where(DiscoveryCollection.accounted.is_(False)).limit(1)) is None:
            state = db.get(DiscoveryStorageBootstrap, 1)
            if state and not state.ready:
                state.ready = True
                return 1
        return 0
    part = int(collection.scope[:2], 16) % 16
    counter = db.scalar(select(DiscoveryStorage).where(DiscoveryStorage.id == part)
        .with_for_update(skip_locked=True))
    if counter is None:
        return 0
    collection.capacity_partition = part
    rows = list(db.execute(select(DiscoveryMember.kind, DiscoveryMember.track_id).where(
        DiscoveryMember.collection_id == collection.id,
        tuple_(DiscoveryMember.kind, DiscoveryMember.track_id) >
        (collection.member_cursor_kind, collection.member_cursor_id))
        .order_by(DiscoveryMember.kind, DiscoveryMember.track_id).limit(batch)))
    if rows:
        amount = sum(weight(kind, identifier) for kind, identifier in rows)
        collection.member_rows += len(rows)
        collection.member_bytes += amount
        counter.member_rows += len(rows)
        counter.member_bytes += amount
        collection.member_cursor_kind, collection.member_cursor_id = rows[-1]
    else:
        collection.accounted = True
    return len(rows) or 1


def erase_members(db, collection, rows):
    """Caller owns the collection lock. Return False to skip a busy stripe."""
    charged = rows if collection.accounted else []
    if not collection.accounted and collection.capacity_partition is not None:
        # Compare with the same database collation as the backfill cursor.
        # Legacy identifiers may contain Unicode/punctuation; Python ordering
        # can differ from the database's locale.
        charged = list(db.execute(select(DiscoveryMember.kind, DiscoveryMember.track_id).where(
            DiscoveryMember.collection_id == collection.id,
            tuple_(DiscoveryMember.kind, DiscoveryMember.track_id).in_([tuple(row) for row in rows]),
            tuple_(DiscoveryMember.kind, DiscoveryMember.track_id) <=
            (collection.member_cursor_kind, collection.member_cursor_id))))
    if charged and collection.capacity_partition is not None:
        counter = db.scalar(select(DiscoveryStorage).where(DiscoveryStorage.id == collection.capacity_partition)
            .with_for_update(skip_locked=True))
        if counter is None:
            return False
        amount = sum(weight(kind, identifier) for kind, identifier in charged)
        if counter.member_rows < len(charged) or counter.member_bytes < amount:
            raise RuntimeError("Discovery retained-member accounting underflow")
        counter.member_rows -= len(charged)
        counter.member_bytes -= amount
        collection.member_rows -= len(charged)
        collection.member_bytes -= amount
    db.execute(delete(DiscoveryMember).where(DiscoveryMember.collection_id == collection.id,
        tuple_(DiscoveryMember.kind, DiscoveryMember.track_id).in_([tuple(row) for row in rows])))
    return True
