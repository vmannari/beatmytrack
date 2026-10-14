"""Startup failure and partial teardown still release every owned adapter."""
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.verifier import GodotVerifier


@pytest.mark.parametrize("failure", ["warmup", "readiness", "blobs"])
def test_lifespan_cleanup_survives_failure(tmp_path, failure):
    events = []
    class Verifier(GodotVerifier):
        def __init__(self):
            pass
        def manifest(self):
            events.append("manifest")
            if failure == "warmup":
                raise RuntimeError("fixture-warmup-failure")
            return {}
        def close(self):
            events.append("verifier-close")
    class Readiness:
        def open(self):
            events.append("readiness-open")
        async def close(self):
            events.append("readiness-close")
            if failure == "readiness":
                raise RuntimeError("fixture-readiness-close-failure")
    def close_blobs():
        events.append("blobs-close")
        if failure == "blobs":
            raise RuntimeError("fixture-blobs-close-failure")
    app = create_app(Settings(database_url="sqlite://", object_dir=str(tmp_path), godot_bin="fixture"), verifier=Verifier())
    app.state.readiness = Readiness()
    app.state.blobs = SimpleNamespace(close=close_blobs)
    try:
        with pytest.raises(RuntimeError, match="fixture-"), TestClient(app):
            pass
        assert events == ["readiness-open", "manifest", "readiness-close", "blobs-close", "verifier-close"]
    finally:
        app.state.engine.dispose()
