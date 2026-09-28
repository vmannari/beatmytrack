"""Exercise the real Godot menu against a real HTTP API with disposable data."""

import os
import secrets
import socket
import subprocess
import threading
import time
from dataclasses import replace
from pathlib import Path

import pytest
import uvicorn

from bmt_backend.app import create_app


class FixtureGoogle:
    """Test only: the nonce is the fixture ID token; never installed in the runtime."""

    def verify(self, token):
        return {"sub": "fixture-google-user", "nonce": token, "aud": "test-client"}


@pytest.mark.godot
def test_account_menu_against_http_server(auth_app):
    root = Path(__file__).resolve().parents[2]
    binary = os.environ.get("GODOT_BIN", r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")
    if not Path(binary).is_file():
        pytest.skip("Pinned Godot binary not available")
    assert (
        subprocess.check_output([binary, "--version"], text=True).strip()
        == (root / "godot-version.txt").read_text().strip()
    )
    key = secrets.token_urlsafe(32)
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    base_url = f"http://127.0.0.1:{listener.getsockname()[1]}"
    settings = replace(
        auth_app.state.settings,
        environment="development",
        dev_auth_enabled=True,
        dev_auth_key=key,
        google_web_client_id="test-client",
        public_base_url=base_url,
    )
    app = create_app(settings, engine=auth_app.state.engine, identity_verifier=FixtureGoogle())
    server = uvicorn.Server(uvicorn.Config(app, log_level="error", access_log=False))
    thread = threading.Thread(target=server.run, kwargs={"sockets": [listener]}, daemon=True)
    thread.start()
    try:
        for _ in range(100):
            if server.started:
                break
            time.sleep(0.05)
        assert server.started
        env = {
            **os.environ,
            "BMT_API_URL": f"http://127.0.0.1:{listener.getsockname()[1]}",
            "BMT_DEV_AUTH_KEY": key,
        }
        args = [] if env.get("BMT_CAPTURE_ACCOUNT") else ["--headless"]
        result = subprocess.run(
            [binary, *args, "--path", str(root / "game"), "--script", "res://tests/test_account.gd"],
            env=env,
            capture_output=True,
            text=True,
            timeout=90,
            check=False,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        assert "0 failures" in result.stdout, result.stdout + result.stderr
        assert "SCRIPT ERROR" not in result.stderr, result.stdout + result.stderr
        print(result.stdout)
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        listener.close()
