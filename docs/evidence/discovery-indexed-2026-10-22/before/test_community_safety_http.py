"""Native adapter against a new loopback service and disposable SQLite data."""
import os
import socket
import subprocess
import threading
from pathlib import Path

import pytest
import uvicorn
from test_community_safety import seed
from test_domains import FakeVerifier

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade


@pytest.mark.godot
def test_native_public_content_safety(tmp_path):
    root = Path(__file__).resolve().parents[2]
    binary = os.environ.get("GODOT_BIN", r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")
    if not Path(binary).is_file():
        pytest.skip("Pinned Godot unavailable")
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    key = "community-fixture-only-" * 3
    address = f"http://127.0.0.1:{listener.getsockname()[1]}"
    app = create_app(Settings(environment="development", dev_auth_enabled=True, dev_auth_key=key,
        database_url="sqlite:///" + (tmp_path / "safety.sqlite").as_posix(),
        object_dir=str(tmp_path / "objects"), public_base_url=address, write_limit_per_minute=1000),
        verifier=FakeVerifier())
    upgrade(app.state.engine)
    with app.state.session_factory() as session:
        author = Player(display_name="Safety fixture author")
        session.add(author)
        session.commit()
        author_id = author.id
    track_id, version_id = seed(app, author_id)
    server = uvicorn.Server(uvicorn.Config(app, log_level="error", access_log=False))
    thread = threading.Thread(target=server.run, kwargs={"sockets": [listener]}, daemon=True)
    thread.start()
    try:
        result = subprocess.run([binary, "--headless", "--path", str(root / "game"), "--script",
            "res://tests/test_community_safety_http.gd", "--log-file", str(tmp_path / "native.log")], env={**os.environ, "BMT_API_URL": address,
                "BMT_DEV_AUTH_KEY": key, "BMT_SAFETY_AUTHOR": author_id,
                "BMT_SAFETY_VERSION": version_id, "BMT_SAFETY_TRACK": track_id},
            capture_output=True, text=True, timeout=75, check=False)
        assert result.returncode == 0, result.stdout + result.stderr
        assert "13 checks, 0 failures" in result.stdout, result.stdout + result.stderr
        assert "SCRIPT ERROR" not in result.stderr, result.stdout + result.stderr
        print(result.stdout)
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        listener.close()
        app.state.engine.dispose()
