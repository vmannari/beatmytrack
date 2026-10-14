"""Additional invalid-data and recovery cases from the second backend pass."""

import gzip
import hashlib
from pathlib import Path

import pytest
from test_auth_postgres import google_request
from test_auth_postgres import postgres_auth as postgres_auth_fixture
from test_gcs_storage import Credentials

from bmt_backend.config import Settings
from bmt_backend.gcs_storage import GCSBlobStore
from bmt_backend.s3_storage import S3BlobStore
from bmt_backend.storage import LocalBlobStore, canonical_json
from bmt_backend.verifier import VerifierUnavailable, validate_ghost

postgres_auth = postgres_auth_fixture
MALFORMED = [
    b'{"value":1e400}',
    b'{"value":-1e400}',
    b'{"value":1,"value":2}',
    b'{"value":"\\ud800"}',
    b'{"value":' + b"[" * 33 + b"0" + b"]" * 33 + b"}",
]


def stored_adapter(provider, tmp_path, monkeypatch, body, digest):
    if provider == "local":
        adapter = LocalBlobStore(str(tmp_path / "objects"))
        path = adapter._path(digest)
        path.parent.mkdir(parents=True)
        path.write_bytes(body)
    elif provider == "s3":
        adapter = S3BlobStore(
            Settings(
                object_backend="s3",
                s3_endpoint="https://objects.invalid",
                s3_bucket="review-fixture",
                s3_access_key="synthetic",
                s3_secret_key="synthetic",
            )
        )
        monkeypatch.setattr(adapter, "_request", lambda *_args, **_kwargs: (200, body))
    else:
        adapter = GCSBlobStore(
            Settings(object_backend="gcs", gcs_bucket="review-fixture"), credentials=Credentials()
        )
        monkeypatch.setattr(adapter, "_request", lambda *_args, **_kwargs: (200, body))
    return adapter


@pytest.mark.parametrize("provider", ["local", "s3", "gcs"])
@pytest.mark.parametrize("compressed", [False, True])
@pytest.mark.parametrize("raw", MALFORMED)
def test_stored_json_rejects_invalid_data_even_with_matching_hash(
    provider, compressed, raw, tmp_path, monkeypatch
):
    digest = hashlib.sha256(raw).hexdigest()
    body = gzip.compress(raw) if compressed else raw
    adapter = stored_adapter(provider, tmp_path, monkeypatch, body, digest)
    try:
        with pytest.raises(OSError, match="Invalid stored object"):
            adapter.get_json(digest)
    finally:
        if hasattr(adapter, "close"):
            adapter.close()


@pytest.mark.parametrize("provider", ["local", "s3", "gcs"])
def test_shared_storage_validation_keeps_finite_values_and_unicode(provider, tmp_path, monkeypatch):
    expected = {"name": "Caf\u00e9", "finite": 1e308, "integer": 10**400}
    raw = canonical_json(expected)
    digest = hashlib.sha256(raw).hexdigest()
    adapter = stored_adapter(provider, tmp_path, monkeypatch, gzip.compress(raw), digest)
    try:
        assert adapter.get_json(digest) == expected
    finally:
        if hasattr(adapter, "close"):
            adapter.close()


def test_reused_publication_retries_failed_directory_flush(tmp_path, monkeypatch):
    from bmt_backend import storage

    adapter = LocalBlobStore(str(tmp_path / "objects"))
    actual = storage.sync_directory
    failing = [True]

    def sync(path):
        if Path(path) != adapter.root and failing[0]:
            raise OSError("Synthetic directory sync unavailable")
        actual(path)

    monkeypatch.setattr(storage, "sync_directory", sync)
    value = {"proof": "immutable"}
    digest = hashlib.sha256(canonical_json(value)).hexdigest()
    with pytest.raises(OSError, match="directory sync"):
        adapter.put_json(value)
    assert adapter.get_json(digest) == value
    with pytest.raises(OSError, match="directory sync"):
        adapter.put_json(value)
    failing[0] = False
    assert adapter.put_json(value) == digest
    assert len(list(adapter.root.glob("*/*.json"))) == 1
    assert not list(adapter.root.glob("*/.pending-*"))


def test_expanding_unicode_name_is_rejected_without_changing_profile(auth_client, sign_in):
    signed = sign_in()
    auth = {"Authorization": "Bearer " + signed["access_token"]}
    response = auth_client.patch("/v1/me", json={"display_name": "\ufdfa" * 40}, headers=auth)
    assert response.status_code == 422 and response.json()["detail"] == "INVALID_INPUT"
    assert auth_client.get("/v1/me", headers=auth).json()["display_name"] == "alice"


@pytest.mark.postgres
def test_expanding_unicode_names_never_reach_postgres_write(postgres_auth):
    app, client = postgres_auth
    signed = client.post("/v1/auth/google", json=google_request(app, client, "normal-name")).json()
    auth = {"Authorization": "Bearer " + signed["access_token"]}
    before = client.get("/v1/me", headers=auth).json()
    renamed = client.patch("/v1/me", json={"display_name": "\ufdfa" * 40}, headers=auth)
    assert renamed.status_code == 422
    assert client.get("/v1/me", headers=auth).json() == before
    fresh = google_request(app, client, "expanding-new-player")
    fresh["display_name"] = "\ufdfa" * 40
    assert client.post("/v1/auth/google", json=fresh).status_code == 422


@pytest.mark.parametrize("coordinate", [1e300, -1e300, 100001.0])
def test_finite_but_unrenderable_ghost_is_invalid_optional_data(coordinate):
    recording = {"ticks": 10, "poses": [[0, coordinate, 0, 0, 0, 0, 0], [10, 0, 0, 0, 0, 0, 0]]}
    with pytest.raises(VerifierUnavailable, match="malformed"):
        validate_ghost(recording, 10)


def test_ghost_presentation_bound_is_inclusive():
    validate_ghost(
        {"ticks": 10, "poses": [[0, -100000, 100000, 0, 0, 0, 0], [10, 100000, -100000, 0, 0, 0, 0]]}, 10
    )
