"""Native GCS contract transport; live acceptance is explicitly opt-in and isolated."""
import base64
import gzip
import hashlib
import importlib.util
import io
import json
import os
import sys
import tarfile
import uuid
from pathlib import Path
from types import SimpleNamespace
from urllib.parse import unquote

import pytest
import requests
from google.auth.exceptions import RefreshError
from urllib3.exceptions import ReadTimeoutError

from bmt_backend.config import Settings
from bmt_backend.gcs_storage import LIMIT, ORIGIN, GCSBlobStore
from bmt_backend.storage import LocalBlobStore, canonical_json, make_blob_store


class Credentials:
    def __init__(self):
        self.refreshes = 0

    def before_request(self, request, method, url, headers):
        headers["Authorization"] = "Bearer isolated-fixture"

    def refresh(self, request):
        self.refreshes += 1


class Raw(io.BytesIO):
    def read(self, size=-1, decode_content=False):
        assert decode_content is False
        return super().read(size)


class Response:
    def __init__(self, status, body=b""):
        self.status_code, self.raw = status, Raw(body)

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.raw.close()


class Peer:
    def __init__(self):
        self.objects = {}
        self.calls = []
        self.generation = 0

    def __call__(self, method, url, **kwargs):
        assert url.startswith(ORIGIN + "/")
        assert kwargs["allow_redirects"] is False and kwargs["timeout"] == (3, 10)
        assert kwargs["headers"]["Accept-Encoding"] == "identity"
        self.calls.append((method, url, kwargs))
        query = kwargs["params"]
        if method == "POST":
            assert query["ifGenerationMatch"] == "0" and "contentEncoding" not in query
            key = query["name"]
            if key in self.objects:
                return Response(412)
            self.generation += 1
            data = kwargs["data"]
            self.objects[key] = {"body": data, "generation": str(self.generation)}
            return Response(200, json.dumps({"name": key, "generation": str(self.generation), "size": str(len(data)),
                "md5Hash": base64.b64encode(hashlib.md5(data, usedforsecurity=False).digest()).decode()}).encode())
        if url.endswith("/o"):
            items = [{"name": key, "size": str(len(value["body"])), "updated": "2026-10-05T10:00:00.000Z"}
                for key, value in self.objects.items() if key.startswith(query["prefix"])]
            return Response(200, json.dumps({"items": items}).encode())
        key = unquote(url.rsplit("/o/", 1)[1])
        if key not in self.objects:
            return Response(404)
        value = self.objects[key]
        if method == "DELETE":
            assert query["ifGenerationMatch"] == value["generation"]
            del self.objects[key]
            return Response(204)
        if query.get("alt") == "media":
            return Response(200, value["body"])
        return Response(200, json.dumps({"name": key, "generation": value["generation"]}).encode())


def store(peer=None, credentials=None):
    return GCSBlobStore(Settings(object_backend="gcs", gcs_bucket="bmt-fixture", gcs_prefix="bmt/v1"),
        credentials=credentials or Credentials(), transport=peer or Peer())


def test_immutable_publication_integrity_listing_and_generation_delete():
    peer = Peer()
    adapter = store(peer)
    value = {"track": [[0, 1, 2]] * 1000, "unicode": "päivä"}
    digest = adapter.put_json(value)
    assert digest == hashlib.sha256(canonical_json(value)).hexdigest()
    assert adapter.put_json(value) == digest
    assert len(peer.objects) == 1 and adapter.get_json(digest) == value
    rows, cursor = adapter.list_objects(None, 100)
    assert cursor is None and rows[0]["digest"] == digest
    assert rows[0]["bytes"] == len(next(iter(peer.objects.values()))["body"])
    adapter.delete(digest)
    adapter.delete(digest)
    assert peer.objects == {}


def test_existing_corrupt_object_never_establishes_publication_success():
    peer = Peer()
    adapter = store(peer)
    value = {"safe": True}
    digest = adapter.put_json(value)
    peer.objects[adapter._key(digest)]["body"] = gzip.compress(b"different")
    with pytest.raises(OSError, match="integrity"):
        adapter.put_json(value)


@pytest.mark.parametrize("field,value", [("size", "0"), ("md5Hash", "bad"), ("generation", "0"), ("name", "outside")])
def test_publication_acknowledgement_is_checked(field, value):
    peer = Peer()
    def transport(*args, **kwargs):
        response = peer(*args, **kwargs)
        metadata = json.loads(response.raw.getvalue())
        metadata[field] = value
        return Response(200, json.dumps(metadata).encode())
    with pytest.raises(OSError, match="acknowledgement"):
        store(transport).put_json({"ack": True})


@pytest.mark.parametrize("failure", [requests.Timeout(), ReadTimeoutError(None, "", "private transport details")])
def test_stream_and_request_errors_are_normalized(failure):
    def transport(*args, **kwargs):
        raise failure
    with pytest.raises(OSError, match="service unavailable"):
        store(transport).get_json("a" * 64)


def test_redirects_and_oversized_responses_never_follow_or_decode():
    calls = []
    def transport(*args, **kwargs):
        calls.append(kwargs)
        return Response(307, b"x" * 1025)
    adapter = store(transport)
    with pytest.raises(OSError, match="limit"):
        adapter._request("GET", limit=1024)
    assert len(calls) == 1 and calls[0]["allow_redirects"] is False
    assert calls[0]["headers"]["Authorization"] == "Bearer isolated-fixture"


def test_auth_refresh_is_bounded_and_credentials_never_fall_back_to_anonymous():
    credentials, calls = Credentials(), []
    def denied(*args, **kwargs):
        calls.append(args)
        return Response(401)
    adapter = store(denied, credentials)
    with pytest.raises(OSError):
        adapter.get_json("b" * 64)
    assert len(calls) == 2 and credentials.refreshes == 1
    def unavailable(*args):
        raise RefreshError("private credential content")
    credentials.before_request = unavailable
    with pytest.raises(OSError, match="authentication unavailable"):
        adapter.get_json("c" * 64)
    assert len(calls) == 2


def test_adc_is_lazy_and_scope_is_explicit(monkeypatch):
    calls = []
    def adc(**kwargs):
        calls.append(kwargs)
        return Credentials(), "fixture-project"
    monkeypatch.setattr("bmt_backend.gcs_storage.google.auth.default", adc)
    adapter = GCSBlobStore(Settings(object_backend="gcs", gcs_bucket="bmt-fixture"), transport=Peer())
    assert calls == []
    adapter.put_json({"adc": True})
    assert len(calls) == 1 and calls[0]["scopes"] == ("https://www.googleapis.com/auth/devstorage.read_write",)


def test_listing_filters_prefix_shards_and_rejects_repeating_cursor():
    digest = "a" * 64
    metadata = {"items": [{"name": f"bmt/v1/aa/{digest}.json", "size": "12", "updated": "2026-10-05T00:00:00Z"},
        {"name": "outside/ignored"}, {"name": f"bmt/v1/bb/{digest}.json"}], "nextPageToken": "page+/="}
    adapter = store(lambda *args, **kwargs: Response(200, json.dumps(metadata).encode()))
    rows, cursor = adapter.list_objects(None, 10)
    assert len(rows) == 1 and cursor == {"token": "page+/="}
    with pytest.raises(OSError, match="listing"):
        adapter.list_objects(cursor, 10)
    with pytest.raises(ValueError):
        adapter.list_objects({"token": ""}, 10)
    with pytest.raises(ValueError):
        adapter.list_objects(None, True)


def test_generation_change_blocks_delete():
    calls = []
    adapter = store()
    digest = "a" * 64
    def transport(method, url, **kwargs):
        calls.append(method)
        if method == "GET":
            return Response(200, json.dumps({"name": adapter._key(digest), "generation": "123"}).encode())
        assert kwargs["params"] == {"ifGenerationMatch": "123"}
        return Response(412)
    adapter.transport = transport
    with pytest.raises(OSError, match="generation changed"):
        adapter.delete(digest)
    assert calls == ["GET", "DELETE"]


def test_gzip_bomb_and_non_object_are_rejected():
    payload = gzip.compress(b"x" * (LIMIT + 1))
    with pytest.raises(OSError, match="integrity"):
        store(lambda *args, **kwargs: Response(200, payload)).get_json("f" * 64)
    body = b"[1,2,3]"
    with pytest.raises(OSError, match="Invalid"):
        store(lambda *args, **kwargs: Response(200, body)).get_json(hashlib.sha256(body).hexdigest())


def test_provider_archive_restores_original_hash_and_document(tmp_path, monkeypatch):
    adapter = store()
    value = {"portable": [1, 2, 3] * 500}
    digest = adapter.put_json(value)
    spec = importlib.util.spec_from_file_location("gcs_archive_fixture", Path(__file__).parents[1] / "deploy/object_archive.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    output = io.BytesIO()
    monkeypatch.setattr(sys, "stdout", SimpleNamespace(buffer=output))
    module.archive_objects(adapter)
    restored = LocalBlobStore(str(tmp_path / "restored"))
    with tarfile.open(fileobj=io.BytesIO(output.getvalue())) as archive:
        entry = archive.getmembers()[0]
        assert entry.name == digest[:2] + "/" + digest + ".json"
        target = restored._path(digest)
        target.parent.mkdir()
        target.write_bytes(archive.extractfile(entry).read())
    assert restored.get_json(digest) == value


def test_factory_preserves_database_publication_pins(auth_app, monkeypatch):
    peer = Peer()
    adapter = store(peer)
    monkeypatch.setattr("bmt_backend.gcs_storage.GCSBlobStore", lambda settings: adapter)
    wrapped = make_blob_store(Settings(object_backend="gcs", gcs_bucket="bmt-fixture"), auth_app.state.session_factory)
    digest = wrapped.put_json({"pinned": True})
    assert wrapped.get_json(digest) == {"pinned": True}
    from bmt_backend.object_models import ObjectPin
    with auth_app.state.session_factory() as session:
        assert session.get(ObjectPin, digest).expires_at > 0


@pytest.mark.parametrize("settings", [{"gcs_bucket": "bad/bucket"}, {"gcs_bucket": ""},
    {"gcs_bucket": "bmt-fixture", "gcs_prefix": "../unsafe"}, {"gcs_bucket": "bmt-fixture", "gcs_prefix": "bmt//v1"}])
def test_provider_configuration_is_explicit_and_scoped(settings):
    with pytest.raises(ValueError):
        Settings(object_backend="gcs", **settings)


def test_real_gcs_contract_when_explicitly_configured():
    bucket = os.environ.get("BMT_TEST_GCS_BUCKET", "")
    if not bucket or os.environ.get("BMT_TEST_GCS_CONFIRM_BUCKET") != bucket:
        pytest.skip("Live GCS needs explicit bucket confirmation and operator ADC; no account is contacted by default")
    adapter = GCSBlobStore(Settings(object_backend="gcs", gcs_bucket=bucket, gcs_prefix="bmt-contract/" + uuid.uuid4().hex))
    values = [{"fixture": "track", "shape": [[0, 0], [1, 1]]}, {"fixture": "replay", "frames": [[0, 255, 0]] * 1000},
        {"fixture": "ghost", "poses": [[0, 0, 0, 0, 0, 0, 0], [60, 1, 1, 0, 0, 0, 0]]}]
    keys = []
    try:
        for value in values:
            key = adapter.put_json(value)
            keys.append(key)
            assert adapter.put_json(value) == key and adapter.get_json(key) == value
        rows, cursor = adapter.list_objects(None, 100)
        assert cursor is None and {r["digest"] for r in rows} == set(keys)
    finally:
        for key in keys:
            adapter.delete(key)
