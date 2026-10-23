"""Native News adapter against an isolated loopback API and real Bearer sessions."""
import os
import socket
import subprocess
import threading
from pathlib import Path

import pytest
import uvicorn
from fastapi.testclient import TestClient
from test_community_safety import seed
from test_domains import FakeVerifier

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.news import capture_publication, emit, process_requested
from bmt_backend.track_models import Track, TrackVersion, now


@pytest.mark.godot
@pytest.mark.parametrize("with_publication", [False, True])
def test_native_news_wire(tmp_path, with_publication):
    root = Path(__file__).resolve().parents[2]
    binary = os.environ.get("GODOT_BIN", r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")
    if not Path(binary).is_file():
        pytest.skip("Pinned Godot unavailable")
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    address = f"http://127.0.0.1:{listener.getsockname()[1]}"
    key = "news-disposable-fixture-" * 3
    app = create_app(Settings(environment="development", dev_auth_enabled=True, dev_auth_key=key,
        database_url="sqlite:///" + (tmp_path / "news.sqlite").as_posix(),
        object_dir=str(tmp_path / "objects"), public_base_url=address, write_limit_per_minute=1000),
        verifier=FakeVerifier())
    upgrade(app.state.engine)
    with TestClient(app) as client:
        signed = []
        for name in ("Alice", "Bob"):
            response = client.post("/v1/auth/development", json={"subject":"news-wire-"+name,
                "display_name":"News wire "+name}, headers={"X-Dev-Auth-Key":key})
            assert response.status_code == 200, response.text
            signed.append(response.json())
        alice, bob = signed
        client.post("/v1/news/friends", json={"name":"News wire Alice"},
                    headers={"Authorization":"Bearer " + bob["access_token"]})
        if with_publication:
            accepted = client.put("/v1/news/friends/" + bob["player"]["id"],
                headers={"Authorization":"Bearer " + alice["access_token"]})
            assert accepted.status_code == 200
    _, version = seed(app, alice["player"]["id"])
    with app.state.session_factory() as session:
        emit(session, alice["player"]["id"], ["native-fixture"], "milestone", version, count=1000)
        session.commit()
    if with_publication:
        track_id, published_version = seed(app, bob["player"]["id"], name="Bob's fresh circuit")
        with app.state.session_factory() as session:
            published = session.get(TrackVersion, published_version)
            published.published_at = now()  # This fixture event occurs after acceptance.
            capture_publication(session, published,
                session.get(Track, track_id), session.get(Player, bob["player"]["id"]))
            session.commit()
    server = uvicorn.Server(uvicorn.Config(app, log_level="error", access_log=False))
    thread = threading.Thread(target=server.run, kwargs={"sockets":[listener]}, daemon=True)
    thread.start()
    try:
        result = subprocess.run([binary, "--headless", "--path", str(root / "game"), "--script",
            "res://tests/test_garage_news_http.gd", "--log-file", str(tmp_path / "native.log")],
            env={**os.environ, "BMT_API_URL":address, "BMT_DEV_AUTH_KEY":key, "BMT_NEWS_BOB":bob["player"]["id"],
                 "BMT_NEWS_PUBLICATION": "1" if with_publication else "0"},
            capture_output=True, text=True, timeout=60, check=False)
        assert result.returncode == 0, result.stdout + result.stderr
        assert f"NEWS_HTTP: {14 if with_publication else 11} checks, 0 failures" in result.stdout, result.stdout + result.stderr
        assert "SCRIPT ERROR" not in result.stderr, result.stdout + result.stderr
        assert process_requested(app) # Only the explicit native entry scheduled work.
        assert not process_requested(app)
        print(result.stdout)
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        listener.close()
        app.state.engine.dispose()
