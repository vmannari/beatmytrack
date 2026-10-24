"""Wire sizes, current ghost authority, reusable previews and bounded preparation."""
import base64
import gzip
import struct
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace

import pytest
from fastapi import HTTPException
from test_challenges import create, normal_run, setup
from test_discovery_v3 import browse
from test_discovery_v3 import indexed as _indexed_fixture
from test_domains import domain as _domain_fixture
from test_domains import headers

from bmt_backend.config import Settings
from bmt_backend.ghost_wire import compact
from bmt_backend.http_costs import HttpCostCounters
from bmt_backend.identity_models import Player
from bmt_backend.immutable_payloads import ImmutablePayloadCache
from bmt_backend.track_models import TrackVersion

indexed = _indexed_fixture
cost_domain = _domain_fixture


def test_all_request_counters_survive_success_log_sampling(caplog):
    clock = [0.0]
    metrics = HttpCostCounters(replace(Settings(), http_success_sample_per_mille=0), clock=lambda: clock[0])
    request = {"event": "http_request", "route": "/v1/example/{id}", "method": "GET", "status": 200,
               "duration_ms": 15, "request_wire_bytes": 7, "response_wire_bytes": 20,
               "request_id": "00000000-0000-0000-0000-000000000000"}
    with caplog.at_level("INFO", logger="bmt.requests"):
        for _ in range(100):
            metrics.observe(request)
        assert not [r for r in caplog.records if '"event":"http_request"' in r.message]
        state = metrics.snapshot()["rows"][0]
        assert state["requests"] == 100 and state["response_wire_bytes"] == 2000
        assert sum(state["latency_buckets"]) == 100
        clock[0] = 61
        metrics.observe({**request, "status": 503})
    assert any("http_cost_summary" in r.message for r in caplog.records)
    assert any('"status":503' in r.message for r in caplog.records)


def test_server_counters_measure_compressed_response_body(auth_app, auth_client):
    @auth_app.get("/v1/cost-compression-fixture")
    def response():
        return {"data": "repeated immutable content "*1000}
    reply = auth_client.get("/v1/cost-compression-fixture")
    assert reply.status_code == 200 and reply.headers.get("content-encoding") == "gzip"
    row = next(r for r in auth_app.state.http_costs.snapshot()["rows"] if r["route"] == "/v1/cost-compression-fixture")
    assert row["response_wire_bytes"] < len(reply.content)/10


def test_preview_omission_keeps_exact_cards_and_fresh_counts(indexed):
    d = indexed
    first = browse(d, {"sort": "name"}, preview_cache=True)
    known = list({row["preview_hash"] for row in first["items"]})
    with d.app.state.session_factory() as session:
        version = session.get(TrackVersion, first["items"][0]["version_id"])
        version.rating_sum, version.rating_count = 50, 10
        session.commit()
    second = browse(d, cursor=first["page_cursor"], preview_cache=True, known_previews=known)
    assert [row["version_id"] for row in second["items"]] == [row["version_id"] for row in first["items"]]
    assert all("points" not in row for row in second["items"])
    assert second["items"][0]["rating_count"] == 10
    full = browse(d, cursor=first["page_cursor"])
    assert all("points" in row and "preview_hash" not in row for row in full["items"])


def test_preview_hints_are_bounded_and_validated(indexed):
    for known in (["a"*64]*33, ["invalid"]):
        response = indexed.client.post("/v1/discovery/v3/tracks", json={"query": {}, "preview_cache": True, "known_previews": known})
        assert response.status_code == 422


def test_ghost_metadata_and_304_avoid_storage_but_keep_authority(cost_domain, monkeypatch):
    d = cost_domain
    version = setup(d)
    run_id = normal_run(d, version)
    challenge = create(d, version, run_id=run_id)
    path = "/v1/challenges/"+challenge["code"]+"/ghost"
    calls = []
    original = d.app.state.blobs.get_json
    def read(key):
        calls.append(key)
        return original(key)
    monkeypatch.setattr(d.app.state.blobs, "get_json", read)
    metadata = d.client.get(path+"?metadata=true", headers=headers(d, "Bob"))
    assert metadata.status_code == 200 and "recording" not in metadata.json() and calls == []
    full = d.client.get(path, headers=headers(d, "Bob"))
    assert full.status_code == 200 and full.json()["run_id"] == run_id and len(calls) == 1
    second = d.client.get(path, headers=headers(d, "Bob"))
    assert second.content == full.content and len(calls) == 1  # Shared immutable representation.
    unchanged = d.client.get(path, headers={**headers(d, "Bob"), "If-None-Match": full.headers["etag"]})
    assert unchanged.status_code == 304 and len(calls) == 1
    changed = d.client.get(path+"?expected_run_id=another-run", headers=headers(d, "Bob"))
    assert changed.status_code == 409 and len(calls) == 1
    with d.factory() as session:
        session.get(Player, d.players["Alice"]).disabled = True
        session.commit()
    unavailable = d.client.get(path, headers={**headers(d, "Bob"), "If-None-Match": full.headers["etag"]})
    assert unavailable.status_code != 304 and unavailable.status_code >= 400


def test_packed_ghost_preserves_every_numeric_sample():
    poses = [[i*6, i*.125, -.5*i, 0, 1.25, 0, 0] for i in range(2000)]
    original = {"ticks": poses[-1][0], "poses": poses}
    result = compact(original)
    if "data" in result:
        body = gzip.decompress(base64.b64decode(result["data"]))
        assert [list(struct.unpack_from("<7d", body, index*56)) for index in range(len(poses))] == poses
    else:
        assert result == original
    tiny = {"ticks": 6, "poses": [[0, 0, 0, 0, 0, 0, 0], [6, 1, 1, 0, 0, 0, 0]]}
    assert compact(tiny) == tiny


def test_immutable_payload_cache_bounds_and_shares_inflight_reads():
    cache = ImmutablePayloadCache(maximum_bytes=8, maximum_entries=2)
    entered, release = threading.Event(), threading.Event()
    calls = []
    def produce():
        calls.append(1)
        entered.set()
        assert release.wait(1)
        return b"exact"
    with ThreadPoolExecutor(2) as workers:
        first = workers.submit(cache.get, "shared", produce)
        assert entered.wait(1)
        second = workers.submit(cache.get, "shared", produce)
        release.set()
        assert first.result() == second.result() == b"exact"
    assert len(calls) == 1
    for key in range(10):
        cache.get(key, lambda: b"1234")
        assert cache.bytes <= 8 and len(cache.entries) <= 2
    busy = ImmutablePayloadCache(parallel=0)
    with pytest.raises(HTTPException) as error:
        busy.get("missing", lambda: b"x")
    assert error.value.status_code == 503
