"""Real game/cloud/cache/rating integration with canonical replay verification."""

import json
import os
import socket
import subprocess
import threading
import time
from pathlib import Path

import pytest
import uvicorn

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade
from bmt_backend.worker import process_one


@pytest.mark.godot
def test_cloud_library_against_http(tmp_path):
    run_client(tmp_path, "res://tests/test_cloud_tracks.gd")


@pytest.mark.godot
def test_durable_track_lifecycle_against_http(tmp_path):
    run_client(tmp_path, "res://tests/test_track_lifecycle.gd", settings_overrides={"purchase_simulation_enabled": True})


def run_client(tmp_path, script, prepare=None, settings_overrides=None, extra_env=None):
    root = Path(__file__).resolve().parents[2]
    binary = os.environ.get("GODOT_BIN", r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")
    if not Path(binary).is_file():
        pytest.skip("Pinned Godot unavailable")
    key = "cloud-test-only-" * 4
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    app = create_app(Settings(
        environment="development", allow_sync_track_validation=True, dev_auth_enabled=True, dev_auth_key=key,
        database_url=f"sqlite:///{(tmp_path / 'cloud.sqlite').as_posix()}",
        object_dir=str(tmp_path / "objects"), godot_bin=binary,
        game_project=str(root / "game"), write_limit_per_minute=1000,
        **(settings_overrides or {}),
    ))
    upgrade(app.state.engine)
    if prepare is not None:
        prepare(app)
    server = uvicorn.Server(uvicorn.Config(app, log_level="error", access_log=False))
    thread = threading.Thread(target=server.run, kwargs={"sockets": [listener]}, daemon=True)
    thread.start()
    stop = threading.Event()
    errors = []

    def work():
        while not stop.wait(0.1):
            try:
                process_one(app)
            except Exception as exc:  # noqa: BLE001 - surface background test failures in the parent
                errors.append(str(exc))
                return

    worker = threading.Thread(target=work, daemon=True)
    worker.start()
    try:
        for _ in range(100):
            if server.started:
                break
            time.sleep(0.05)
        fixture = json.loads((root / "backend/tests/fixtures/verified_oval.json").read_text())
        fixture_path = tmp_path / "fixture.json"
        fixture_path.write_text(json.dumps(fixture))
        env = {**os.environ, "BMT_API_URL": f"http://127.0.0.1:{listener.getsockname()[1]}",
               "BMT_DEV_AUTH_KEY": key, "BMT_CLOUD_FIXTURE": str(fixture_path)}
        env.update(extra_env or {})
        args = [] if env.get("BMT_CAPTURE_CLOUD") else ["--headless"]
        result = subprocess.run(
            [binary, *args, "--path", str(root / "game"), "--script", script],
            env=env, capture_output=True, text=True, timeout=150, check=False,
        )
        assert not errors, errors
        assert result.returncode == 0, result.stdout + result.stderr
        assert "0 failures" in result.stdout, result.stdout + result.stderr
        assert "SCRIPT ERROR" not in result.stderr, result.stdout + result.stderr
        print(result.stdout)
    finally:
        stop.set()
        worker.join(timeout=30)
        server.should_exit = True
        thread.join(timeout=10)
        listener.close()
        app.state.verifier.close()
        app.state.engine.dispose()
