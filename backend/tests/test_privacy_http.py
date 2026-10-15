"""Actual pinned native app adapter against an owned, provider-free HTTP service."""
import os
import secrets
import socket
import subprocess
import threading
import time
from pathlib import Path

import uvicorn
from sqlalchemy import func, select

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Identity, Player
from bmt_backend.migrate import upgrade
from bmt_backend.privacy_models import AccountDeletion


def test_native_deletion_and_new_identity_over_http(tmp_path):
    root = Path(__file__).resolve().parents[2]
    listener = socket.socket(); listener.bind(("127.0.0.1", 0)); listener.listen()
    key = secrets.token_urlsafe(40)
    app = create_app(Settings(environment="development", dev_auth_enabled=True, dev_auth_key=key, telemetry_enabled=True,
        database_url="sqlite:///"+str(tmp_path / "db.sqlite"), object_dir=str(tmp_path / "objects")))
    upgrade(app.state.engine)
    server = uvicorn.Server(uvicorn.Config(app, log_level="error", access_log=False))
    thread = threading.Thread(target=server.run, kwargs={"sockets": [listener]}, daemon=True); thread.start()
    try:
        for _ in range(100):
            if server.started: break
            time.sleep(.05)
        assert server.started
        env = dict(os.environ)
        env.update(APPDATA=str(tmp_path / "profile"), BMT_PRIVACY_HTTP_URL=f"http://127.0.0.1:{listener.getsockname()[1]}", BMT_DEV_AUTH_KEY=key)
        (tmp_path / "profile").mkdir()
        result = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(root / "scripts/dev.ps1"),
            "-Action", "TestScript", "-ScriptPath", "res://tests/test_account_privacy_http.gd"], cwd=root, env=env,
            capture_output=True, text=True, timeout=90, check=False)
        output = (result.stdout + result.stderr).replace(key, "[REDACTED]")
        assert result.returncode == 0 and "0 failures" in output, output
        with app.state.session_factory() as session:
            assert session.scalar(select(func.count()).select_from(Player)) == 2
            assert session.scalar(select(func.count()).select_from(Identity)) == 1
            assert session.scalar(select(func.count()).select_from(AccountDeletion)) == 1
        evidence = root / "docs/evidence/account-privacy-2026-10-14"
        evidence.mkdir(parents=True, exist_ok=True)
        (evidence / "native-http.log").write_text(output, encoding="utf-8")
    finally:
        server.should_exit = True; thread.join(timeout=10); listener.close()
        app.state.verifier.close(); app.state.engine.dispose()
