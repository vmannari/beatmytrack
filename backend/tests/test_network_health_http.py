"""Actual pinned Godot transport and packet ingress against a fresh loopback service."""
import json
import os
import secrets
import socket
import subprocess
import threading
import time
from pathlib import Path

import pytest
import uvicorn
from fastapi import Request
from fastapi.responses import JSONResponse
from sqlalchemy import func, select

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade
from bmt_backend.network_models import NetworkHealthDay
from bmt_backend.product_analytics import project_pending
from bmt_backend.track_models import Run


@pytest.mark.godot
def test_real_native_network_packet_and_server_request_id_correlation(tmp_path):
    root = Path(__file__).resolve().parents[2]
    key, analyst = secrets.token_urlsafe(32), secrets.token_urlsafe(32)
    listener = socket.socket(); listener.bind(("127.0.0.1", 0))
    base = f"http://127.0.0.1:{listener.getsockname()[1]}"
    app = create_app(Settings(environment="development", dev_auth_enabled=True, dev_auth_key=key,
        telemetry_enabled=True, client_quality_enabled=True, admin_analyst_key=analyst,
        database_url="sqlite:///" + str(tmp_path / "fixture.sqlite"), object_dir=str(tmp_path / "objects"),
        auth_limit_per_minute=1000, write_limit_per_minute=1000))
    upgrade(app.state.engine)
    identifiers = []

    @app.get("/v1/net-fixture-failure")
    async def failed(request: Request):
        identifiers.append(request.state.request_id)
        return JSONResponse({"detail": "FICTIONAL_DIAGNOSTIC_FAILURE"}, status_code=503)

    @app.get("/v1/net-fixture-rate")
    async def throttled(request: Request):
        identifiers.append(request.state.request_id)
        return JSONResponse({"detail": "FICTIONAL_DIAGNOSTIC_THROTTLE"}, status_code=429)

    server = uvicorn.Server(uvicorn.Config(app, log_level="error", access_log=False))
    thread = threading.Thread(target=server.run, kwargs={"sockets": [listener]}, daemon=True); thread.start()
    try:
        for _ in range(100):
            if server.started: break
            time.sleep(.05)
        assert server.started
        env = dict(os.environ)
        env.update(BMT_NETWORK_HTTP_URL=base, BMT_DEV_AUTH_KEY=key,
            BMT_NETWORK_HTTP_EVIDENCE=str(tmp_path / "packet.json"), APPDATA=str(tmp_path / "profile"))
        (tmp_path / "profile").mkdir()
        result = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(root / "scripts/dev.ps1"),
            "-Action", "TestScript", "-ScriptPath", "res://tests/test_network_health_http.gd"],
            cwd=root, env=env, text=True, capture_output=True, timeout=90, check=False)
        output = (result.stdout + result.stderr).replace(key, "[REDACTED]")
        assert result.returncode == 0 and "0 failures" in output, output
        packet = json.loads((tmp_path / "packet.json").read_text())
        failures = [event["properties"] for event in packet["events"] if event["name"] == "network_failure"]
        assert set(identifiers) <= {row.get("request_id") for row in failures}
        assert all("url" not in row and "payload" not in row and "token" not in row for row in failures)
        project_pending(app.state.session_factory)
        with app.state.session_factory() as session:
            rows = session.scalars(select(NetworkHealthDay)).all()
            assert sum(row.counters["attempts"] for row in rows) == 5
            assert sum(row.counters["throttled"] for row in rows) == 1
            assert sum(row.counters["retries"] for row in rows) == 1
            assert session.scalar(select(func.count()).select_from(Run)) == 0
        evidence = root / "docs/evidence/network-health-2026-10-13"
        evidence.mkdir(parents=True, exist_ok=True)
        (evidence / "native-http.log").write_text(output, encoding="utf-8")
        (evidence / "native-http-packet.json").write_text(json.dumps(packet, indent=2) + "\n", encoding="utf-8")
    finally:
        server.should_exit = True; thread.join(timeout=10); listener.close()
        app.state.verifier.close(); app.state.engine.dispose()
