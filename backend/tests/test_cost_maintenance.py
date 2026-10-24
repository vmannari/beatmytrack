"""Reference-aware retirement, physical-pack backups and provider range boundaries."""
import hashlib
import importlib.util
import os
import sqlite3
import subprocess
import sys
from dataclasses import replace
from pathlib import Path
from urllib.parse import unquote

import pytest
from sqlalchemy import func, select
from test_gcs_storage import Credentials, Peer, Response

from bmt_backend.config import Settings
from bmt_backend.db import Base, make_engine, make_session_factory
from bmt_backend.gcs_storage import GCSBlobStore
from bmt_backend.object_garbage import collect_once
from bmt_backend.object_models import ArchiveChunk, ObjectGarbageCandidate, ObjectPin, PackedObject
from bmt_backend.pack_io import PackIO
from bmt_backend.packed_storage import PackedBlobStore
from bmt_backend.storage import LocalBlobStore, PinnedBlobStore, make_blob_store
from bmt_backend.track_models import OperationState, now

ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture
def storage(tmp_path):
    database = tmp_path / "state.sqlite"
    engine = make_engine("sqlite:///" + str(database))
    Base.metadata.create_all(engine)
    factory = make_session_factory(engine)
    settings = Settings(environment="test", object_packing_enabled=True)
    packed = PackedBlobStore(LocalBlobStore(str(tmp_path / "objects")), factory, settings)
    blobs = PinnedBlobStore(packed, factory, track_gc=True)
    yield blobs, factory, database, settings
    engine.dispose()


def age(factory, key):
    with factory() as session:
        session.get(ObjectPin, key).expires_at = now()-1
        session.get(ObjectGarbageCandidate, key).due_at = now()-1
        session.commit()


def test_unreferenced_intake_is_retired_without_bucket_listing(storage, monkeypatch):
    blobs, factory, _, _ = storage
    key = blobs.put_json({"uncommitted": "publication"})
    age(factory, key)
    monkeypatch.setattr(blobs.store, "list_objects", lambda *_: pytest.fail("Full history scan is unnecessary"))
    assert collect_once(factory, blobs)
    with factory() as session:
        assert session.get(PackedObject, key) is None
        assert session.get(ObjectGarbageCandidate, key) is None


def test_active_pin_and_archive_reference_preserve_object(storage):
    blobs, factory, _, _ = storage
    key = blobs.put_json({"protected": True})
    with factory() as session:
        session.get(ObjectGarbageCandidate, key).due_at = now()-1
        session.commit()
    assert collect_once(factory, blobs)
    with factory() as session:
        assert session.get(PackedObject, key) is not None
        session.add(ArchiveChunk(digest=key, kind="reward", lower="a", upper="z", records=1, created_at=now()))
        session.commit()
    age(factory, key)
    assert collect_once(factory, blobs)
    assert blobs.get_json(key) == {"protected": True}
    with factory() as session:
        assert session.get(ObjectGarbageCandidate, key) is None


def test_garbage_collection_is_bounded_and_obeys_backup_pause(storage):
    blobs, factory, _, _ = storage
    keys = [blobs.put_json({"i": i}) for i in range(3)]
    for key in keys:
        age(factory, key)
    with factory() as session:
        session.add(OperationState(id="object-maintenance", updated_at=now()+300, details={}))
        session.commit()
    assert not collect_once(factory, blobs)
    with factory() as session:
        session.delete(session.get(OperationState, "object-maintenance"))
        session.commit()
    assert collect_once(factory, blobs, limit=1)
    with factory() as session:
        assert session.scalar(select(func.count()).select_from(PackedObject)) == 2


def test_physical_pack_and_pending_intake_survive_database_object_restore(storage, tmp_path):
    blobs, _factory, database, settings = storage
    values = [{"index": i, "exact": -.125, "unicode": "päivä"} for i in range(12)]
    keys = [blobs.put_json(value) for value in values]
    while blobs.flush_once(force=True):
        pass
    pending = blobs.put_json({"still": "pending in durable SQL"})
    restored_database = tmp_path / "restored.sqlite"
    with sqlite3.connect(database) as source, sqlite3.connect(restored_database) as target:
        source.backup(target)
    helper = ROOT / "backend/deploy/object_archive.py"
    archive = subprocess.run([sys.executable, str(helper), "archive", "--root", str(blobs.store.store.root)],
        capture_output=True, env=os.environ | {"BMT_OBJECT_BACKEND": "local"}, check=False)
    assert archive.returncode == 0, archive.stderr.decode()
    destination = tmp_path / "restored-objects"
    restore = subprocess.run([sys.executable, str(helper), "restore", "--root", str(destination)],
        input=archive.stdout, capture_output=True, check=False)
    assert restore.returncode == 0, restore.stderr.decode()
    engine = make_engine("sqlite:///" + str(restored_database))
    try:
        recovered = PackedBlobStore(LocalBlobStore(str(destination)), make_session_factory(engine), settings)
        assert [recovered.get_json(key) for key in keys] == values
        assert recovered.get_json(pending) == {"still": "pending in durable SQL"}
    finally:
        engine.dispose()


class RangePeer(Peer):
    def __call__(self, method, url, **kwargs):
        requested = kwargs["headers"].get("Range")
        if method == "GET" and requested:
            key = unquote(url.rsplit("/o/", 1)[1])
            start, end = map(int, requested.removeprefix("bytes=").split("-"))
            self.calls.append((method, url, kwargs))
            return Response(206, self.objects[key]["body"][start:end+1])
        return super().__call__(method, url, **kwargs)


def test_google_pack_upload_range_listing_and_conditional_delete():
    peer = RangePeer()
    adapter = GCSBlobStore(Settings(object_backend="gcs", gcs_bucket="bmt-fixture"), credentials=Credentials(), transport=peer)
    packs = PackIO(adapter, 65536)
    body = b"BMTPACK1" + bytes(range(256))*10
    key = hashlib.sha256(body).hexdigest()
    packs.put(key, body)
    packs.put(key, body)
    assert len(peer.objects) == 1
    assert packs.get(key, 8, 17) == body[8:25]
    rows, cursor = packs.list()
    assert rows == [{"digest": key, "bytes": len(body)}] and cursor is None
    packs.delete(key)
    assert not peer.objects


def test_cost_profile_is_explicit_and_does_not_buy_commitments(tmp_path):
    path = ROOT / "backend/deploy/gcp/cost_profile.py"
    specification = importlib.util.spec_from_file_location("cost_profile_fixture", path)
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    profile = module.profile("owned-api")
    assert profile["staging_configuration_overlay"]["cost_optimisation"] is True
    assert profile["staging_configuration_overlay"]["api_instance_billing"] is False
    assert 'service_name="owned-api"' in profile["logging_exclusion"]["filter"]
    assert "httpRequest.status<400" in profile["logging_exclusion"]["filter"]
    assert "No purchases" in profile["commitments"]


def test_disabling_new_packing_writes_keeps_accepted_objects_readable(storage):
    blobs, factory, _, settings = storage
    packed = blobs.put_json({"previous": "packed"})
    while blobs.flush_once(force=True):
        pass
    pending = blobs.put_json({"previous": "pending"})
    settings = replace(settings, object_packing_enabled=False, object_dir=str(blobs.store.store.root))
    reader = make_blob_store(settings, factory)
    assert reader.get_json(packed) == {"previous": "packed"}
    assert reader.get_json(pending) == {"previous": "pending"}


def test_google_profile_reserves_packing_connection_and_explicit_billing(tmp_path):
    from test_gcp_staging import config, staging
    configuration = config()
    configuration["cost_optimisation"] = True
    with pytest.raises(ValueError, match="40-connection"):
        staging.validate(configuration)
    configuration["api_max"] = 1
    staging.validate(configuration)
    environment = staging.environment(configuration, "worker")
    assert environment["BMT_OBJECT_PACKING_ENABLED"] == "true"
    assert environment["BMT_RETENTION_DAYS"] == "7"
    commands = staging.deployment_commands(configuration, "fixture-image", tmp_path)
    assert "--memory=1024Mi" in commands["worker"]
    assert "--no-cpu-throttling" not in commands["api"]
    configuration["api_instance_billing"] = True
    assert "--no-cpu-throttling" in staging.deployment_commands(configuration, "fixture-image", tmp_path)["api"]
