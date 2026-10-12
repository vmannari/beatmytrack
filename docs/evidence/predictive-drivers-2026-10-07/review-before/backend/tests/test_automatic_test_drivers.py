"""Automatic membership, ordinary proof processing, recovery and isolation."""
import dataclasses
import json
import socket
import threading
import time

import pytest
import uvicorn
from sqlalchemy import select
from test_rivalry_http import seed
from test_test_drivers import auth
from test_test_drivers import drivers as _drivers
from test_verifier import real_verifier as _real_verifier

from bmt_backend.app import create_app
from bmt_backend.automatic_test_drivers import drive_idle
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade
from bmt_backend.rivalry_models import RivalryMember
from bmt_backend.test_population_tool import API
from bmt_backend.track_models import Run
from bmt_backend.worker import process_one

drivers = _drivers
real_verifier = _real_verifier


def test_automatic_join_is_idempotent_and_keeps_scores_empty_until_verification(drivers):
    headers = auth(drivers.login)
    body = {"vehicle_id": "compact", "test_population": True, "automatic_test_drivers": True}
    response = drivers.client.post("/v1/rivalry/join", json=body, headers=headers)
    assert response.status_code == 200, response.text
    group = response.json()
    assert group["driver_count"] == 14
    assert sum(row["is_test_driver"] for row in group["standings"]) == 13
    assert all(row["rank"] is None and row["points"] == 0 for row in group["standings"])
    assert all(row["ms"] is None for track in group["tracks"] for row in track["entries"])
    assert drivers.client.post("/v1/rivalry/join", json=body, headers=headers).json() == group
    repeated = drivers.client.post("/v1/rivalry/join", json=body, headers=auth(drivers.login)).json()
    assert repeated["group_id"] == group["group_id"] and repeated["driver_count"] == 14
    with drivers.factory() as session:
        assert len(session.scalars(select(RivalryMember).where(
            RivalryMember.group_id == group["group_id"])).all()) == 14
    ordinary = drivers.client.post("/v1/rivalry/join", json={"vehicle_id": "compact"},
                                   headers=auth(drivers.login)).json()
    assert ordinary["driver_count"] == 1 and not ordinary["test_population"]
    assert not drive_idle(drivers.app)  # A fake/no-engine backend never fabricates a result.


def test_automatic_population_requires_the_development_gate(drivers):
    invalid = drivers.client.post("/v1/rivalry/join", json={"vehicle_id": "compact",
        "automatic_test_drivers": True}, headers=auth(drivers.login))
    assert invalid.status_code == 422
    drivers.app.state.settings = dataclasses.replace(drivers.app.state.settings, test_drivers_enabled=False)
    blocked = drivers.client.post("/v1/rivalry/join", json={"vehicle_id": "compact",
        "test_population": True, "automatic_test_drivers": True}, headers=auth(drivers.login))
    assert blocked.status_code == 404 and not drive_idle(drivers.app)


@pytest.mark.godot
def test_idle_backend_drives_verifies_and_recovers_without_operator_plan(tmp_path, real_verifier):
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    url = f"http://127.0.0.1:{listener.getsockname()[1]}"
    key = "automatic-native-fixture-only-" * 3
    settings = Settings(environment="development", dev_auth_enabled=True, test_drivers_enabled=True,
        allow_sync_track_validation=True, dev_auth_key=key, public_base_url=url,
        database_url=f"sqlite:///{(tmp_path/'automatic.sqlite').as_posix()}",
        object_dir=str(tmp_path/'objects'), godot_bin=real_verifier.binary,
        game_project=str(real_verifier.project), auth_limit_per_minute=1000, write_limit_per_minute=1000)
    app = create_app(settings)
    upgrade(app.state.engine)
    seed(app)
    server = uvicorn.Server(uvicorn.Config(app, log_level="error", access_log=False))
    thread = threading.Thread(target=server.run, kwargs={"sockets": [listener]}, daemon=True)
    thread.start()
    try:
        for _ in range(200):
            if server.started:
                break
            time.sleep(0.05)
        api = API(url, key)
        group = api.call("POST", "/rivalry/join", {"vehicle_id": "compact", "test_population": True,
            "automatic_test_drivers": True}, subject="developer", idempotency="automatic-native-join")
        assert group["driver_count"] == 14
        assert process_one(app)  # Idle worker creates and uploads its own canonical drive.
        with app.state.session_factory() as session:
            uploaded = session.scalar(select(Run))
            assert uploaded.status == "queued" and uploaded.time_ticks is None
            run_id = uploaded.id
        assert process_one(app)  # Queued proof has priority over the next driver.
        view = api.call("GET", "/rivalry/"+group["group_id"], subject="developer")
        finished = [(slot, row) for slot, track in enumerate(view["tracks"])
                    for row in track["entries"] if row["ticks"] is not None]
        assert len(finished) == 1 and finished[0][1]["is_test_driver"]
        with app.state.session_factory() as session:
            assert session.get(Run, run_id).status == "verified"
        slot, driver = finished[0]
        ghost = api.call("GET", f"/rivalry/{group['group_id']}/tracks/{slot}/ghosts/{driver['id']}",
                         subject="developer")
        assert len(ghost["recording"]["poses"]) > 2 and "replay" not in ghost
        assert api.call("GET", "/track-versions/"+view["tracks"][slot]["entry"]["version_id"]+
                        "/leaderboard?vehicle_id=compact")["population"] == 0
        # Recover the same upload after complete loss of the ephemeral plan/cache.
        import shutil
        folder = tmp_path / "automatic-test-drivers"
        shutil.rmtree(folder)
        app.state.next_automatic_drive = 0
        assert drive_idle(app)
        with app.state.session_factory() as session:
            assert len(session.scalars(select(Run)).all()) == 1
        path = folder / (group["group_id"]+".json")
        assert json.loads(path.read_text())["jobs"]
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        listener.close()
        app.state.verifier.close()
        app.state.engine.dispose()
