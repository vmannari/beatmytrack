"""Crash recovery, bounded intake, immutable identity and partial-pack reclamation."""
import hashlib
import json
from dataclasses import replace

import pytest
from sqlalchemy import func, select

from bmt_backend.config import Settings
from bmt_backend.db import Base, make_engine, make_session_factory
from bmt_backend.object_models import ObjectPack, ObjectPartition, PackedObject
from bmt_backend.packed_storage import PackedBlobStore
from bmt_backend.storage import LocalBlobStore, canonical_json
from bmt_backend.track_models import OperationState


@pytest.fixture
def packed(tmp_path, monkeypatch):
    clock = [2000000000]
    monkeypatch.setattr("bmt_backend.packed_storage.now", lambda: clock[0])
    settings = Settings(environment="test", object_packing_enabled=True)
    engine = make_engine("sqlite:///" + str(tmp_path / "intake.sqlite"))
    Base.metadata.create_all(engine)
    factory = make_session_factory(engine)
    store = PackedBlobStore(LocalBlobStore(str(tmp_path / "objects")), factory, settings)
    yield store, factory, clock
    engine.dispose()


def records(count, *, stripe=0):
    values, index = [], 0
    while len(values) < count:
        value = {"sample": index, "positions": [[0, .125, -.5], [6, 1.25, 100.001]]}
        digest = hashlib.sha256(canonical_json(value)).hexdigest()
        if int(digest[:2], 16) % 16 == stripe:
            values.append(value)
        index += 1
    return values


def test_intake_survives_restart_without_cloud_put(packed, monkeypatch):
    store, factory, _ = packed
    monkeypatch.setattr(store.store, "put_json", lambda _: pytest.fail("Individual cloud PUT must not occur"))
    value = records(1)[0]
    key = store.put_json(value)
    restarted = PackedBlobStore(store.store, factory, store.settings)
    assert restarted.get_json(key) == value
    assert not list(store.store.root.rglob("*.json"))


def test_full_pack_is_one_write_with_independent_ranges(packed, monkeypatch):
    store, factory, _ = packed
    values = records(128)
    keys = [store.put_json(value) for value in values]
    assert store.flush_once()
    assert len(list(store.store.root.rglob("*.pack"))) == 1
    with factory() as session:
        assert session.scalar(select(func.sum(ObjectPartition.pending_bytes))) == 0
        assert session.scalar(select(func.count()).select_from(PackedObject).where(PackedObject.pending.is_not(None))) == 0
        pack = session.scalar(select(ObjectPack))
        size = pack.size
    original = store.io.get
    requested = []
    def read(digest, offset, length):
        requested.append((offset, length))
        return original(digest, offset, length)
    monkeypatch.setattr(store.io, "get", read)
    for key, value in zip(keys, values, strict=True):
        assert store.get_json(key) == value
    assert all(offset >= 8 and length < size for offset, length in requested)


def test_lost_upload_reply_reuses_durable_batch_after_lease(packed, monkeypatch):
    store, factory, clock = packed
    values = records(4)
    keys = [store.put_json(value) for value in values[:3]]
    original = store.io.put
    def lost(digest, body):
        original(digest, body)
        raise OSError("Reply lost after durable write")
    monkeypatch.setattr(store.io, "put", lost)
    with pytest.raises(OSError):
        store.flush_once(force=True)
    keys.append(store.put_json(values[3]))
    assert all(store.get_json(key) == value for key, value in zip(keys, values, strict=True))
    monkeypatch.setattr(store.io, "put", original)
    clock[0] += 61
    assert store.flush_once()
    assert len(list(store.store.root.rglob("*.pack"))) == 1
    with factory() as session:
        assert session.get(PackedObject, keys[-1]).pending is not None
    assert store.flush_once(force=True)
    assert all(store.get_json(key) == value for key, value in zip(keys, values, strict=True))


def test_corrupt_or_wrong_record_range_is_rejected(packed):
    store, factory, _ = packed
    values = records(2)
    first, second = (store.put_json(value) for value in values)
    assert store.flush_once(force=True)
    with factory() as session:
        a, b = session.get(PackedObject, first), session.get(PackedObject, second)
        a.offset, a.length = b.offset, b.length
        session.commit()
    with pytest.raises(OSError):
        store.get_json(first)


def test_reused_content_has_one_durable_record(packed):
    store, factory, _ = packed
    value = records(1)[0]
    key = store.put_json(value)
    assert store.put_json(json.loads(json.dumps(value))) == key
    with factory() as session:
        row = session.get(PackedObject, key)
        assert session.get(ObjectPartition, row.partition).pending_bytes == row.length
        assert session.scalar(select(func.count()).select_from(PackedObject)) == 1


def test_compaction_releases_dead_frames_without_pinning_whole_pack(packed):
    store, factory, clock = packed
    values = records(8)
    keys = [store.put_json(value) for value in values]
    assert store.flush_once(force=True)
    with factory() as session:
        old = session.get(PackedObject, keys[0]).pack_digest
    for key in keys[:6]:
        store.delete(key)
    clock[0] += 601
    assert store.compact_once()
    assert all(store.get_json(key) == value for key, value in zip(keys[6:], values[6:], strict=True))
    assert not store.collect_once()  # Readers may still own the old location.
    clock[0] += 601
    assert store.collect_once()
    assert not (store.store.root / store.io.key(old)).exists()
    assert all(store.get_json(key) == value for key, value in zip(keys[6:], values[6:], strict=True))


def test_backup_pause_prevents_pack_reclamation(packed):
    store, factory, clock = packed
    key = store.put_json(records(1)[0])
    store.flush_once(force=True)
    store.delete(key)
    clock[0] += 601
    with factory() as session:
        session.add(OperationState(id="object-maintenance", updated_at=clock[0]+300, details={}))
        session.commit()
    assert not store.collect_once()


def test_legacy_objects_and_bounded_listing_remain_available(packed):
    store, _, _ = packed
    legacy = store.store.put_json({"legacy": True})
    keys = [store.put_json(value) for value in records(4)]
    rows, cursor, seen = [], None, set()
    for _ in range(20):
        rows, cursor = store.list_objects(cursor, 2)
        assert len(rows) <= 2
        seen.update(row["digest"] for row in rows)
        if cursor is None:
            break
    assert seen == {*keys, legacy}
    assert store.get_json(legacy) == {"legacy": True}


def test_intake_budget_rejection_preserves_acknowledged_data(packed):
    import random
    store, factory, _ = packed
    store.settings = replace(store.settings, object_pack_bytes=65536, object_pending_bytes_per_partition=65536)
    values = []
    rng = random.Random(72)
    while len(values) < 2:
        value = {"data": rng.randbytes(45000).hex()}
        if int(hashlib.sha256(canonical_json(value)).hexdigest()[:2], 16) % 16 == 0:
            values.append(value)
    key = store.put_json(values[0])
    with pytest.raises(OSError, match="intake is full"):
        store.put_json(values[1])
    assert store.get_json(key) == values[0]
    with factory() as session:
        assert session.scalar(select(func.count()).select_from(PackedObject)) == 1


def test_pack_gc_cannot_remove_upload_before_location_publication(packed, monkeypatch):
    store, factory, clock = packed
    value = records(1)[0]
    key = store.put_json(value)
    original = store.io.put
    def upload(digest, body):
        original(digest, body)
        with factory() as session:
            pack = session.get(ObjectPack, digest)
            pack.created_at, pack.retire_after = clock[0]-1200, clock[0]-1
            session.commit()
        assert not store.collect_once()
    monkeypatch.setattr(store.io, "put", upload)
    assert store.flush_once(force=True)
    assert store.get_json(key) == value


def test_intake_record_budget_and_delete_reclaim(packed):
    store, factory, _ = packed
    store.settings = replace(store.settings, object_pending_records_per_partition=1)
    first, second = records(2)
    key = store.put_json(first)
    with pytest.raises(OSError, match="intake is full"):
        store.put_json(second)
    store.delete(key)
    other = store.put_json(second)
    assert store.get_json(other) == second
    with factory() as session:
        partition = session.get(ObjectPartition, 0)
        assert partition.pending_records == 1
