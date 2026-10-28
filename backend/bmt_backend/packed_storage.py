"""Durable SQL intake, bounded independent gzip frames and atomic pack publication."""
import gzip
import hashlib
import uuid
from contextlib import nullcontext

from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from .object_models import ObjectPack, ObjectPartition, PackedObject
from .pack_io import PackIO
from .storage import decode_blob_json, prepare_json
from .track_models import OperationState, now

PARTITIONS = 16
MAGIC = b"BMTPACK1"


def insert(session):
    return sqlite_insert if session.bind.dialect.name == "sqlite" else pg_insert


class PackedBlobStore:
    def __init__(self, store, factory, settings):
        self.store, self.factory, self.settings = store, factory, settings
        self.io = PackIO(store, settings.object_pack_bytes)

    def close(self):
        if hasattr(self.store, "close"):
            self.store.close()

    def put_json(self, data):
        prepared = prepare_json(data)
        raw, digest = prepared.body, prepared.digest
        encoded = gzip.compress(raw, compresslevel=3, mtime=0)
        if len(encoded) + len(MAGIC) > self.settings.object_pack_bytes:
            return self.store.put_json(prepared)
        stripe = int(digest[:2], 16) % PARTITIONS
        with self.factory() as session:
            session.execute(insert(session)(ObjectPartition).values(id=stripe, pending_bytes=0, lease_until=0, lease_token="", batch=[])
                .on_conflict_do_nothing(index_elements=[ObjectPartition.id]))
            partition = session.scalar(select(ObjectPartition).where(ObjectPartition.id == stripe).with_for_update())
            if session.get(PackedObject, digest) is not None:
                return digest
            if (partition.pending_bytes + len(encoded) > self.settings.object_pending_bytes_per_partition
                    or partition.pending_records >= self.settings.object_pending_records_per_partition):
                raise OSError("Durable object intake is full; retry after packed storage drains")
            session.add(PackedObject(digest=digest, partition=stripe, created_at=now(), pending=encoded,
                                    pack_digest=None, offset=0, length=len(encoded)))
            partition.pending_bytes += len(encoded)
            partition.pending_records += 1
            session.commit()  # The acknowledgement survives API/worker process loss.
        return digest

    def get_json(self, digest, *, session=None):
        self.io.key(digest)
        with nullcontext(session) if session is not None else self.factory() as db:
            row = db.get(PackedObject, digest)
            location = (row.pending, row.pack_digest, row.offset, row.length) if row else None
        if location is None:
            return self.store.get_json(digest)  # Existing individually stored objects remain readable.
        pending, pack, offset, length = location
        body = pending if pending is not None else self.io.get(pack, offset, length)
        return decode_blob_json(body, digest)

    def get_json_in_session(self, session, digest):
        return self.get_json(digest, session=session)

    def delete(self, digest, *, session=None):
        self.io.key(digest)
        found = False
        external = session is not None
        with nullcontext(session) if external else self.factory() as db:
            stripe = int(digest[:2], 16) % PARTITIONS
            partition = db.scalar(select(ObjectPartition).where(ObjectPartition.id == stripe).with_for_update())
            row = db.get(PackedObject, digest)
            if row:
                found = True
                if digest in (partition.batch if partition else []):
                    return False  # An in-flight publication owns these bytes; collect on a later pass.
                if row.pending is not None:
                    partition.pending_bytes -= row.length
                    partition.pending_records -= 1
                elif row.pack_digest:
                    pack = db.scalar(select(ObjectPack).where(ObjectPack.digest == row.pack_digest).with_for_update())
                    pack.dead_bytes += row.length
                db.delete(row)
                if not external:
                    db.commit()
        if not found:
            self.store.delete(digest)
        return True

    def delete_in_session(self, session, digest):
        return self.delete(digest, session=session)

    def list_objects(self, cursor, limit):
        if type(limit) is not int or not 1 <= limit <= 1000:
            raise ValueError("Invalid packed object scan limit")
        if cursor is not None and (type(cursor) is not dict or set(cursor) != {"packed", "cursor"} or type(cursor["packed"]) is not bool):
            raise ValueError("Invalid packed object cursor")
        if cursor is None or cursor["packed"]:
            after = cursor["cursor"] if cursor else ""
            if type(after) is not str or (after and (len(after) != 64 or any(c not in "0123456789abcdef" for c in after))):
                raise ValueError("Invalid packed object cursor")
            with self.factory() as session:
                rows = session.execute(select(PackedObject.digest, PackedObject.created_at, PackedObject.length)
                    .where(PackedObject.digest > after).order_by(PackedObject.digest).limit(limit)).all()
            result = [{"digest": row.digest, "modified": row.created_at, "bytes": row.length} for row in rows]
            return result, {"packed": True, "cursor": rows[-1].digest} if len(rows) == limit else {"packed": False, "cursor": None}
        rows, next_cursor = self.store.list_objects(cursor["cursor"], limit)
        return rows, {"packed": False, "cursor": next_cursor} if next_cursor else None

    def flush_once(self, *, at=None, force=False):
        stamp = now() if at is None else at
        token = str(uuid.uuid4())
        with self.factory() as session:
            partitions = session.scalars(select(ObjectPartition.id).where(ObjectPartition.pending_bytes > 0,
                ObjectPartition.lease_until <= stamp).order_by(ObjectPartition.id).limit(PARTITIONS)).all()
            chosen = None
            for stripe in partitions:
                partition = session.scalar(select(ObjectPartition).where(ObjectPartition.id == stripe,
                    ObjectPartition.lease_until <= stamp).with_for_update(skip_locked=True))
                if partition is None:
                    continue
                statement = select(PackedObject.digest, PackedObject.created_at, PackedObject.length).where(
                    PackedObject.partition == stripe, PackedObject.pending.is_not(None))
                if partition.batch:
                    statement = statement.where(PackedObject.digest.in_(partition.batch))
                rows = session.execute(statement.order_by(PackedObject.created_at, PackedObject.digest)
                    .limit(self.settings.object_pack_records)).all()
                if not rows:
                    continue
                if not force and not partition.batch and len(rows) < self.settings.object_pack_records and rows[0].created_at > stamp-self.settings.object_pack_flush_seconds:
                    continue
                selected, size = [], len(MAGIC)
                for row in rows:
                    if size + row.length > self.settings.object_pack_bytes:
                        break
                    selected.append(row.digest)
                    size += row.length
                partition.batch = selected
                partition.lease_token, partition.lease_until = token, stamp + 60
                payloads = dict(session.execute(select(PackedObject.digest, PackedObject.pending)
                    .where(PackedObject.digest.in_(selected))).all())
                chosen = stripe, [(key, payloads[key]) for key in selected]
                session.commit()
                break
        if chosen is None:
            return False
        stripe, selected = chosen
        body, offsets = bytearray(MAGIC), {}
        for digest, encoded in selected:
            decode_blob_json(encoded, digest)
            offsets[digest] = len(body), len(encoded)
            body.extend(encoded)
        pack_digest = hashlib.sha256(body).hexdigest()
        self._register_pack(pack_digest, len(body), len(selected), stamp)
        # The durable claimed digest list makes an interrupted upload deterministic.
        self.io.put(pack_digest, bytes(body))
        with self.factory() as session:
            partition = session.scalar(select(ObjectPartition).where(ObjectPartition.id == stripe).with_for_update())
            if partition.lease_token != token or partition.lease_until <= now():
                return False
            session.execute(insert(session)(ObjectPack).values(digest=pack_digest, size=len(body), records=len(selected),
                dead_bytes=0, retire_after=0, created_at=stamp, hold_until=stamp+60).on_conflict_do_nothing(index_elements=[ObjectPack.digest]))
            pack = session.get(ObjectPack, pack_digest)
            pack.retire_after, pack.hold_until = 0, 0
            for key, (offset, length) in offsets.items():
                row = session.get(PackedObject, key)
                if row is None or row.pending is None:
                    raise OSError("Claimed durable intake changed")
                row.pack_digest, row.offset, row.pending = pack_digest, offset, None
                partition.pending_bytes -= length
                partition.pending_records -= 1
            partition.batch, partition.lease_until, partition.lease_token = [], 0, ""
            session.commit()  # Locations switch together; readers still see pending bytes until commit.
        return True

    def _register_pack(self, digest, size, records, stamp):
        # Register upload intent first: lost acknowledgements cannot leak an untracked pack.
        with self.factory() as session:
            session.execute(insert(session)(ObjectPack).values(digest=digest, size=size, records=records,
                dead_bytes=0, retire_after=0, created_at=stamp, hold_until=stamp+60)
                .on_conflict_do_update(index_elements=[ObjectPack.digest], set_={"hold_until": stamp+60}))
            session.commit()

    def compact_once(self, *, at=None):
        stamp = now() if at is None else at
        token = str(uuid.uuid4())
        with self.factory() as session:
            pause = session.get(OperationState, "object-maintenance")
            if pause is not None and pause.updated_at > stamp:
                return False
            pack = session.scalar(select(ObjectPack).where(ObjectPack.dead_bytes >= ObjectPack.size/2,
                ObjectPack.retire_after == 0, ObjectPack.created_at < stamp-600)
                .order_by(ObjectPack.created_at).limit(1))
            if pack is None:
                return False
            rows = session.execute(select(PackedObject.digest, PackedObject.offset, PackedObject.length,
                PackedObject.partition).where(PackedObject.pack_digest == pack.digest)
                .order_by(PackedObject.offset).limit(129)).all()
            if not rows:
                return False
            if len(rows) > 128:
                raise OSError("Pack record bound exceeded")
            stripe = rows[0].partition
            partition = session.scalar(select(ObjectPartition).where(ObjectPartition.id == stripe,
                ObjectPartition.lease_until <= stamp).with_for_update(skip_locked=True))
            if partition is None or partition.batch:
                return False
            if any(row.partition != stripe for row in rows):
                raise OSError("Invalid pack partition")
            partition.lease_token, partition.lease_until = token, stamp+60
            old_digest, size = pack.digest, pack.size
            session.commit()
        old = self.io.get(old_digest, 0, size)
        if hashlib.sha256(old).hexdigest() != old_digest or not old.startswith(MAGIC):
            raise OSError("Pack compaction failed integrity")
        body, offsets = bytearray(MAGIC), {}
        for row in rows:
            encoded = old[row.offset:row.offset+row.length]
            decode_blob_json(encoded, row.digest)
            offsets[row.digest] = len(body), row.length
            body.extend(encoded)
        digest = hashlib.sha256(body).hexdigest()
        self._register_pack(digest, len(body), len(rows), stamp)
        self.io.put(digest, bytes(body))
        with self.factory() as session:
            partition = session.scalar(select(ObjectPartition).where(ObjectPartition.id == stripe).with_for_update())
            if partition.lease_token != token or partition.lease_until <= now():
                return False
            old_pack = session.scalar(select(ObjectPack).where(ObjectPack.digest == old_digest).with_for_update())
            new_pack = session.get(ObjectPack, digest)
            new_pack.retire_after, new_pack.hold_until = 0, 0
            for key, (offset, length) in offsets.items():
                row = session.get(PackedObject, key)
                if row is None or row.pack_digest != old_digest:
                    new_pack.dead_bytes += length
                    continue
                row.pack_digest, row.offset = digest, offset
                old_pack.dead_bytes += length
            old_pack.retire_after = stamp + max(600, self.settings.job_lease_seconds+60)
            partition.lease_token, partition.lease_until = "", 0
            session.commit()
        return True

    def collect_once(self, *, at=None):
        stamp = now() if at is None else at
        with self.factory() as session:
            pause = session.get(OperationState, "object-maintenance")
            if pause is not None and pause.updated_at > stamp:
                return False
            live = select(PackedObject.digest).where(PackedObject.pack_digest == ObjectPack.digest).exists()
            pack = session.scalar(select(ObjectPack).where(~live, ObjectPack.created_at < stamp-600, ObjectPack.hold_until <= stamp)
                .order_by(ObjectPack.created_at).limit(1).with_for_update(skip_locked=True))
            if pack is None:
                return False
            digest = pack.digest
            if not pack.retire_after:
                pack.retire_after = stamp + max(600, self.settings.job_lease_seconds+60)
                session.commit()
                return True
            if pack.retire_after > stamp:
                return False
            self.io.delete(digest)
            session.execute(delete(ObjectPack).where(ObjectPack.digest == digest))
            session.commit()
            return True


def main():
    import logging
    import signal
    import threading
    from dataclasses import replace

    from sqlalchemy.exc import SQLAlchemyError

    from .config import Settings
    from .cost_maintenance import CostMaintenance
    from .database_privileges import verify_runtime
    from .db import make_engine, make_session_factory
    from .observability import configure_logging
    from .storage import make_blob_store

    settings = Settings.from_env()
    configure_logging()
    if not settings.object_packing_enabled:
        raise ValueError("Packed storage worker requires explicit enablement")
    if settings.workload_role != "worker":
        raise ValueError("Packed storage daemon requires the worker credential role")
    engine = make_engine(settings.database_url, replace(settings, database_pool_size=1, database_pool_overflow=0))
    verify_runtime(engine, settings)
    factory = make_session_factory(engine)
    blobs = make_blob_store(settings, factory)
    maintenance = CostMaintenance(factory, blobs, settings)
    stop = threading.Event()
    for signum in (signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, lambda *_args: stop.set())
    delay = .05
    try:
        while not stop.is_set():
            try:
                # Intake always drains, even while expensive maintenance yields.
                flushed = blobs.flush_once()
                worked = maintenance.step() or flushed
                delay = .05 if worked else min(2, delay*2)
            except (OSError, SQLAlchemyError) as error:
                logging.getLogger("bmt.packs").error("packed_storage_dependency_unavailable", extra={"exception_type": type(error).__name__})
                delay = 2
            stop.wait(delay)
    finally:
        blobs.close()
        engine.dispose()


if __name__ == "__main__":
    main()
