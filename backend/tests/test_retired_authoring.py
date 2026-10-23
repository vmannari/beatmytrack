"""Retired endpoints stay inert even in an explicitly configured test service."""
from dataclasses import replace

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from bmt_backend.app import create_app
from bmt_backend.track_models import Track, TrackVersion

PATHS = (
    ("POST", "/v1/tracks"),
    ("POST", "/v1/tracks/{track_id}/versions"),
    ("POST", "/v1/me/track-versions/{version_id}/retry-validation"),
    ("POST", "/v1/track-versions/{version_id}/publish"),
    ("POST", "/v1/me/drafts/{authoring_id}/archive"),
    ("GET", "/v1/me/drafts/{authoring_id}/head"),
)


@pytest.mark.parametrize("local_drafts_only", [True, False])
def test_retired_routes_cannot_resume_remote_authoring(auth_app, sign_in, monkeypatch, local_drafts_only):
    signed = sign_in("retirement-owner", analytics=False)
    peer = create_app(
        replace(auth_app.state.settings, environment="test", local_drafts_only=local_drafts_only),
        engine=auth_app.state.engine, identity_verifier=auth_app.state.identity_verifier,
    )
    with peer.state.session_factory() as db:
        track = Track(owner_id=signed["player"]["id"])
        db.add(track)
        db.flush()
        db.add(TrackVersion(id="historical", track_id=track.id, number=1, name="Retained draft",
                            content_hash="a"*64, manifest={}, state="draft"))
        db.commit()

    def forbidden(*_args, **_kwargs):
        pytest.fail("Retired remote authoring accessed document storage or the verifier")

    monkeypatch.setattr(peer.state.blobs, "put_json", forbidden)
    monkeypatch.setattr(peer.state.blobs, "get_json", forbidden)
    monkeypatch.setattr(peer.state.verifier, "validate_track", forbidden)
    headers = {"Authorization": "Bearer " + signed["access_token"]}
    with TestClient(peer) as client:
        for method, path in PATHS:
            actual = path.format(track_id="historical", version_id="historical", authoring_id="historical")
            result = client.request(method, actual, headers=headers,
                                    **({"json": {"document": {"schema": "creator-track-v5"}}} if method == "POST" else {}))
            assert result.status_code == 410, result.text
            assert "LOCAL_DRAFTS_ONLY" in result.json()["detail"]
        schema = client.get("/openapi.json").json()["paths"]
        assert all(method.lower() not in schema.get(path, {}) for method, path in PATHS)
    with peer.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(Track)) == 1
        kept = db.get(TrackVersion, "historical")
        assert (kept.name, kept.content_hash, kept.state) == ("Retained draft", "a"*64, "draft")
