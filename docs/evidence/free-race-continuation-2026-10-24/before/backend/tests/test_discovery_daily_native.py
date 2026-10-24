"""Pinned Godot menu against an owned HTTP server, never an existing service."""
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
from test_discovery_daily import build
from test_discovery_paging import auth_app as auth_app_fixture
from test_discovery_v3 import indexed as indexed_fixture

from bmt_backend.discovery_projection import settle_for_diagnostics
from bmt_backend.track_models import TrackVersion

auth_app = auth_app_fixture
indexed = indexed_fixture


@pytest.mark.godot
def test_native_daily_feed_and_global_search(indexed):
    d = indexed
    root = Path(__file__).resolve().parents[2]
    if os.name != "nt" or not Path(r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe").is_file():
        pytest.skip("Pinned Windows native menu runner unavailable")
    document = json.loads((root / "backend/tests/fixtures/verified_oval.json").read_text())["document"]
    digest = d.app.state.blobs.put_json(document)
    with d.app.state.session_factory() as db:
        db.execute(update(TrackVersion).values(content_hash=digest,
            discovery={"theme": "pine", "points": document["points"]}))
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory)
    selected = {i["track_id"] for i in build(d)}
    missing = next(i for i, t in enumerate(d.tracks) if t["id"] not in selected)
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    origin = f"http://127.0.0.1:{listener.getsockname()[1]}"
    server = uvicorn.Server(uvicorn.Config(d.app, log_level="error", access_log=False))
    thread = threading.Thread(target=server.run, kwargs={"sockets": [listener]}, daemon=True)
    thread.start()
    renderer = os.environ.get("BMT_DAILY_NATIVE_RENDERER", "headless")
    env = {**os.environ, "APPDATA": str(root / "build/daily-track-selection-user"),
        "BMT_DAILY_API_URL": origin, "BMT_DAILY_MISSING_ID": d.tracks[missing]["id"],
        "BMT_DAILY_MISSING_NAME": d.versions[missing]["name"]}
    Path(env["APPDATA"]).mkdir(parents=True, exist_ok=True)
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(root / "scripts/dev.ps1"),
        "-Action", "TestScript", "-ScriptPath", "res://tests/test_daily_track_selection.gd"]
    if renderer != "headless":
        command += ["-Graphical", "-RenderingMethod", renderer]
    try:
        for _ in range(100):
            if server.started:
                break
            time.sleep(.05)
        result = subprocess.run(command, cwd=root, env=env, text=True, capture_output=True, timeout=120, check=False)
        print(result.stdout + result.stderr)
        if env.get("BMT_DAILY_EVIDENCE_DIR"):
            output = Path(env["BMT_DAILY_EVIDENCE_DIR"]).parent / f"native-{renderer}.log"
            output.write_text(result.stdout + result.stderr, encoding="utf-8")
        assert result.returncode == 0, result.stdout + result.stderr
        assert "0 failures" in result.stdout and "SCRIPT ERROR" not in result.stdout + result.stderr
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        listener.close()
