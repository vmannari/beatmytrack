"""Production Godot Race menu against a disposable, owned loopback API."""
import json
import os
import socket
import subprocess
import threading
import time
from pathlib import Path

import pytest
import uvicorn
from sqlalchemy import update
from test_discovery_daily import build as build_daily
from test_discovery_paging import auth_app as auth_app_fixture
from test_discovery_v3 import indexed as indexed_fixture

from bmt_backend.discovery_projection import settle_for_diagnostics
from bmt_backend.track_models import TrackVersion
from bmt_backend.track_of_day import step

auth_app = auth_app_fixture
indexed = indexed_fixture


@pytest.mark.godot
def test_native_track_of_day_menu_and_race(indexed):
    d = indexed
    root = Path(__file__).resolve().parents[2]
    if os.name != "nt":
        pytest.skip("Pinned Windows Godot entry point unavailable")
    document = json.loads((root / "backend/tests/fixtures/verified_oval.json").read_text())["document"]
    digest = d.app.state.blobs.put_json(document)
    with d.app.state.session_factory() as db:
        db.execute(update(TrackVersion).values(content_hash=digest,
            discovery={"theme": "pine", "points": document["points"]}))
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory)
    build_daily(d)
    assert step(d.app.state.session_factory)
    chosen = d.client.get("/v1/track-of-the-day").json()["track"]
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    origin = f"http://127.0.0.1:{listener.getsockname()[1]}"
    server = uvicorn.Server(uvicorn.Config(d.app, log_level="error", access_log=False))
    thread = threading.Thread(target=server.run, kwargs={"sockets": [listener]}, daemon=True)
    thread.start()
    renderer = os.environ.get("BMT_TOTD_RENDERER", "headless")
    env = {**os.environ, "APPDATA": str(root / "build/track-of-day-user"),
        "BMT_API_URL": origin, "BMT_TOTD_API_URL": origin,
        "BMT_TOTD_VERSION": chosen["version_id"]}
    Path(env["APPDATA"]).mkdir(parents=True, exist_ok=True)
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(root / "scripts/dev.ps1"),
        "-Action", "TestScript", "-ScriptPath", "res://tests/test_track_of_day.gd"]
    if renderer != "headless":
        command += ["-Graphical", "-RenderingMethod", renderer]
    try:
        for _ in range(100):
            if server.started:
                break
            time.sleep(.05)
        result = subprocess.run(command, cwd=root, env=env, text=True, capture_output=True, timeout=240, check=False)
        output = root / "docs/evidence/track-of-day-2026-10-25" / f"native-{renderer}.log"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(result.stdout + result.stderr, encoding="utf-8")
        assert result.returncode == 0, result.stdout + result.stderr
        assert "0 failures" in result.stdout
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        listener.close()
