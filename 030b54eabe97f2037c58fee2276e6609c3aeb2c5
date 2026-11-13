"""Real Godot-client/HTTP contract against an owned database and worker fixture."""
import os
import socket
import subprocess
import threading
import time
from pathlib import Path

import pytest
import uvicorn
from test_daily_standings import auth_app, feature, finish  # noqa: F401
from test_daily_standings import daily as daily_fixture

daily = daily_fixture


@pytest.mark.godot
def test_native_daily_standings_http(daily):
    d = daily
    if os.name != "nt":
        pytest.skip("Pinned Windows development entry point unavailable")
    feature(d)
    for name,ticks in (("Alice",120),("Bob",100),("Carol",110)): finish(d,ticks,name)
    listener = socket.socket()
    listener.bind(("127.0.0.1",0))
    origin = "http://127.0.0.1:"+str(listener.getsockname()[1])
    server = uvicorn.Server(uvicorn.Config(d.app,log_level="error",access_log=False))
    thread = threading.Thread(target=server.run,kwargs={"sockets":[listener]},daemon=True)
    thread.start()
    root = Path(__file__).resolve().parents[2]
    env = {**os.environ,"BMT_DAILY_HTTP_ORIGIN":origin,
        "BMT_DAILY_HTTP_TOKEN":d.identities["Alice"]["access_token"],
        "BMT_DAILY_HTTP_PLAYER":d.identities["Alice"]["player"]["id"],
        "BMT_DAILY_HTTP_VERSION":d.version.id,"BMT_DAILY_HTTP_DAY":str(d.day),
        "BMT_DAILY_HTTP_NOW":str(int(time.time()))}
    command = ["powershell","-NoProfile","-ExecutionPolicy","Bypass","-File",
        str(root/"docs/evidence/track-of-day-standings-2026-10-28/run.ps1"),
        "-Headless","-ScriptPath","res://tests/test_daily_standings_http.gd"]
    try:
        result = subprocess.run(command,cwd=root,env=env,text=True,capture_output=True,timeout=180,check=False)
        output = (result.stdout+result.stderr).replace(env["BMT_DAILY_HTTP_TOKEN"],"[fixture-token]")
        (root/"docs/evidence/track-of-day-standings-2026-10-28/logs/native-http.log").write_text(output,encoding="utf-8")
        assert result.returncode == 0, output
        assert "DAILY_STANDINGS_HTTP: 4 checks, 0 failures" in output
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        listener.close()
