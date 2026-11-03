"""Immutable verification descriptors and strict JSON resource/validation bounds."""
import copy
from types import SimpleNamespace

import pytest
from sqlalchemy import event
from test_domains import FakeVerifier

from bmt_backend import board_cache, trajectory_verifier
from bmt_backend.contracts import BUILD_FIELDS
from bmt_backend.json_data import parse_json
from bmt_backend.track_models import OperationState


def setup(app):
    active = FakeVerifier().manifest()
    built = []

    def geometry(document):
        built.append(document)
        return {"manifest":{**copy.deepcopy(active),"track_content_hash":document.get("shape","oval")},
                "gates":[[1,0,-1,0,1,0,-10,10,0]],"start":[0,0,0],"creator_start":[0,0,0],
                "extent":[10,10],"maximum_speed":{"compact":120}}

    app.state.verifier = SimpleNamespace(manifest=lambda:copy.deepcopy(active),race_geometry=geometry)
    document = {"shape":"fixture"}
    identity = app.state.blobs.put_json(document)
    return active,built,identity,document,geometry


def test_warm_descriptor_avoids_track_storage_and_sql_and_is_not_mutable_shared_state(auth_app, monkeypatch):
    _active,built,key,document,_geometry = setup(auth_app)
    first = trajectory_verifier.prepared_geometry(auth_app,key,document)
    assert len(built) == 1
    first["gates"][0][0] = 9000

    def forbidden(*_args, **_kwargs):
        raise AssertionError("Warm descriptor performed storage/SQL/native work")

    monkeypatch.setattr(auth_app.state.blobs,"get_json",forbidden)
    monkeypatch.setattr(auth_app.state.verifier,"race_geometry",forbidden)
    event.listen(auth_app.state.engine,"before_cursor_execute",forbidden)
    try:
        second = trajectory_verifier.prepared_geometry(auth_app,key,document)
        assert second["gates"][0][0] == 1
        assert second["manifest"]["track_content_hash"] == "fixture"
    finally:
        event.remove(auth_app.state.engine,"before_cursor_execute",forbidden)


@pytest.mark.parametrize("field",BUILD_FIELDS)
def test_every_build_field_fences_prepared_geometry(auth_app, field):
    active,built,key,_document,_geometry = setup(auth_app)
    original = trajectory_verifier.prepared_geometry(auth_app,key)
    if field == "vehicles":
        active[field]["compact"]["config_hash"] = "new-handling"
    elif type(active[field]) is int:
        active[field] += 1
    else:
        active[field] += "-new"
    changed = trajectory_verifier.prepared_geometry(auth_app,key)
    assert len(built) == 2
    assert changed["manifest"][field] != original["manifest"][field]
    assert changed["manifest"][field] == active[field]


def test_cold_worker_uses_durable_descriptor_without_loading_track(auth_app, monkeypatch):
    _active,built,key,_document,_geometry = setup(auth_app)
    expected = trajectory_verifier.prepared_geometry(auth_app,key)
    with board_cache._lock:
        board_cache._caches.pop(auth_app.state.engine,None)

    def forbidden(*_args, **_kwargs):
        raise AssertionError("Durable descriptor reloaded the track or regenerated geometry")

    monkeypatch.setattr(auth_app.state.blobs,"get_json",forbidden)
    monkeypatch.setattr(auth_app.state.verifier,"race_geometry",forbidden)
    assert trajectory_verifier.prepared_geometry(auth_app,key) == expected
    assert len(built) == 1


def test_descriptor_cache_has_entry_and_byte_limits(auth_app, monkeypatch):
    _active,_built,key,_document,geometry = setup(auth_app)
    monkeypatch.setattr(trajectory_verifier,"GEOMETRY_CACHE_ENTRIES",2)
    monkeypatch.setattr(trajectory_verifier,"GEOMETRY_CACHE_BYTES",2000)
    for index in range(4):
        document = {"shape":"fixture"+str(index)}
        identity = auth_app.state.blobs.put_json(document)
        trajectory_verifier.prepared_geometry(auth_app,identity)
    with board_cache._lock:
        cache = board_cache._caches[auth_app.state.engine]["verification-geometry"]
        assert len(cache) <= 2
        assert sum(map(len,cache.values())) <= 2000
    # A descriptor larger than the memory budget still uses the durable path.
    huge = geometry({"shape":"large"})
    huge["padding"] = "x"*3000
    with auth_app.state.session_factory() as db:
        db.add(OperationState(id="geom:"+key,details=huge))
        db.commit()
    assert trajectory_verifier.prepared_geometry(auth_app,key) == huge
    with board_cache._lock:
        cache = board_cache._caches[auth_app.state.engine]["verification-geometry"]
        assert sum(map(len,cache.values())) <= 2000


def test_cold_preparation_releases_sql_before_storage_and_native_work(auth_app, monkeypatch):
    _active,_built,key,_document,geometry = setup(auth_app)
    held = 0

    def checkout(*_args):
        nonlocal held
        held += 1

    def checkin(*_args):
        nonlocal held
        held -= 1

    read = auth_app.state.blobs.get_json
    def read_without_connection(identity):
        assert held == 0
        return read(identity)

    def build_without_connection(document):
        assert held == 0
        return geometry(document)

    event.listen(auth_app.state.engine,"checkout",checkout)
    event.listen(auth_app.state.engine,"checkin",checkin)
    monkeypatch.setattr(auth_app.state.blobs,"get_json",read_without_connection)
    monkeypatch.setattr(auth_app.state.verifier,"race_geometry",build_without_connection)
    try:
        trajectory_verifier.prepared_geometry(auth_app,key)
        assert held == 0
    finally:
        event.remove(auth_app.state.engine,"checkout",checkout)
        event.remove(auth_app.state.engine,"checkin",checkin)


def test_failed_preparation_is_retried_and_not_remembered(auth_app, monkeypatch):
    _active,built,key,_document,geometry = setup(auth_app)
    def unavailable(_document):
        raise RuntimeError("Unavailable test engine")
    monkeypatch.setattr(auth_app.state.verifier,"race_geometry",unavailable)
    with pytest.raises(RuntimeError,match="Unavailable"):
        trajectory_verifier.prepared_geometry(auth_app,key)
    monkeypatch.setattr(auth_app.state.verifier,"race_geometry",geometry)
    trajectory_verifier.prepared_geometry(auth_app,key)
    assert len(built) == 1


def test_generated_descriptor_cannot_cross_builds_or_content_keys(auth_app, monkeypatch):
    _active,_built,key,document,geometry = setup(auth_app)
    wrong = geometry(document)
    wrong["manifest"]["rules_key"] = "different-rules"
    monkeypatch.setattr(auth_app.state.verifier,"race_geometry",lambda _document:wrong)
    with pytest.raises(RuntimeError,match="differs from verifier build"):
        trajectory_verifier.prepared_geometry(auth_app,key)
    with auth_app.state.session_factory() as db:
        assert db.get(OperationState,"geom:"+key) is None
    monkeypatch.setattr(auth_app.state.verifier,"race_geometry",geometry)
    first = trajectory_verifier.prepared_geometry(auth_app,key)
    other = auth_app.state.blobs.put_json({"shape":"second-track"})
    second = trajectory_verifier.prepared_geometry(auth_app,other)
    assert first["manifest"]["track_content_hash"] == "fixture"
    assert second["manifest"]["track_content_hash"] == "second-track"


def test_concurrent_cold_requests_prepare_once(auth_app, monkeypatch):
    from concurrent.futures import ThreadPoolExecutor
    from threading import Event

    _active,built,key,document,geometry = setup(auth_app)
    started,release = Event(),Event()
    def paused(source):
        started.set()
        assert release.wait(5)
        return geometry(source)
    monkeypatch.setattr(auth_app.state.verifier,"race_geometry",paused)
    with ThreadPoolExecutor(max_workers=5) as pool:
        first = pool.submit(trajectory_verifier.prepared_geometry,auth_app,key,document)
        assert started.wait(5)
        others = [pool.submit(trajectory_verifier.prepared_geometry,auth_app,key,document) for _ in range(4)]
        release.set()
        expected = first.result(timeout=5)
        assert all(item.result(timeout=5) == expected for item in others)
    assert len(built) == 1


@pytest.mark.parametrize("body",[
    b'{"x":1,"x":2}', b'{"x":{"y":1,"y":2}}', b'1e400', b'NaN', b'-Infinity',
    b'{"x":"\\ud800"}', b'{"\\ud800":1}', b'["\\udc00"]', b'"\xff"',
])
def test_json_retains_duplicate_finite_and_unicode_guards(body):
    with pytest.raises((ValueError,UnicodeError)):
        parse_json(body)


def test_json_retains_exact_depth_and_node_limits():
    assert parse_json(b'[[1,2],[3,4]]',maximum_nodes=7) == [[1,2],[3,4]]
    with pytest.raises(ValueError,match="node limit"):
        parse_json(b'[[1,2],[3,4]]',maximum_nodes=6)
    assert parse_json("["*32+"0"+"]"*32)
    with pytest.raises(ValueError,match="nesting limit"):
        parse_json("["*33+"0"+"]"*33)
    assert parse_json(b'{"finite":1e308,"unicode":"Caf\\u00e9","items":[null,true,false,[],{}]}') == {
        "finite":1e308,"unicode":"Caf\u00e9","items":[None,True,False,[],{}]}
