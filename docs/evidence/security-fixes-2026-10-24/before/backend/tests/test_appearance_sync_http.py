"""Two native clients and restart recovery against a disposable real HTTP server."""
import os
import socket
import subprocess
import threading
import time
from pathlib import Path

import pytest
import uvicorn
from test_domains import FakeVerifier

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade


@pytest.mark.godot
def test_native_cross_device_appearance_sync(tmp_path):
    root = Path(__file__).resolve().parents[2]
    key = "isolated-appearance-fixture-key-2026"
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    url = f"http://127.0.0.1:{listener.getsockname()[1]}"
    app = create_app(Settings(
        environment="development", dev_auth_enabled=True, dev_auth_key=key,
        database_url=f"sqlite:///{(tmp_path / 'garage.sqlite').as_posix()}",
        object_dir=str(tmp_path / "objects"), rate_limit_per_minute=1000,
        write_limit_per_minute=1000, public_base_url=url,
    ), verifier=FakeVerifier())
    upgrade(app.state.engine)
    server = uvicorn.Server(uvicorn.Config(app, log_level="error", access_log=False))
    thread = threading.Thread(target=server.run, kwargs={"sockets": [listener]}, daemon=True)
    thread.start()
    try:
        for _ in range(100):
            if server.started:
                break
            time.sleep(0.05)
        assert server.started
        data = tmp_path / "appdata"
        data.mkdir()
        env = {**os.environ, "APPDATA": str(data), "BMT_API_URL": url, "BMT_DEV_AUTH_KEY": key}
        command = [
            "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(root / "scripts/dev.ps1"),
            "-Action", "TestScript", "-ScriptPath", "res://tests/test_appearance_sync_http.gd",
            "-CommandTimeoutSeconds", "90",
        ]
        if env.get("BMT_APPEARANCE_CAPTURE"):
            command += ["-Graphical", "-RenderingMethod", "gl_compatibility"]
        result = subprocess.run(command, env=env, cwd=root, capture_output=True,
                                text=True, timeout=110, check=False)
        (tmp_path / "native.log").write_text(result.stdout + result.stderr, encoding="utf-8")
        print(result.stdout)
        assert result.returncode == 0, result.stdout + result.stderr
        assert "APPEARANCE_SYNC_HTTP:" in result.stdout and "0 failures" in result.stdout
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        listener.close()
        app.state.engine.dispose()
