"""Pinned canonical recordings and an actual 14-driver HTTP championship."""

import json
import socket
import threading
import time
from pathlib import Path
from types import SimpleNamespace

import pytest
import uvicorn
from sqlalchemy import select
from test_rivalry_http import seed
from test_verifier import real_verifier as _real_verifier

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade
from bmt_backend.test_driver_generator import generate
from bmt_backend.test_drivers import profile
from bmt_backend.test_population_tool import API, prepare, tick
from bmt_backend.track_models import Run
from bmt_backend.worker import process_one

real_verifier = _real_verifier
ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.godot
def test_profiles_generate_repeatable_distinct_verified_five_lap_races(real_verifier):
    fixture = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())
    settings = SimpleNamespace(
        godot_bin=real_verifier.binary, game_project=real_verifier.project, verifier_timeout_seconds=90
    )
    times, replays = [], []
    for skill in (0.1, 0.5, 0.9):
        traits = profile(27, 6, 13, 0.42, 0.58)[2]
        traits["skill"] = skill
        result = generate(settings, fixture["document"], "compact", traits)
        verified = real_verifier.verify_run(fixture["document"], result["replay"], "compact")
        assert result["time_ticks"] == verified["time_ticks"]
        assert len(verified["lap_ticks"]) == 5 and len(verified["ghost"]["poses"]) > 2
        times.append(result["time_ticks"])
        replays.append(result["replay"])
    assert times[0] > times[1] > times[2]
    traits["skill"] = 0.5
    assert generate(settings, fixture["document"], "compact", traits)["replay"] == replays[1]
    assert generate(settings, fixture["document"], "compact", traits, 1)["replay"] != replays[1]


@pytest.mark.godot
def test_fill_tool_drives_and_verifies_an_actual_field(tmp_path, real_verifier):
    key = "test-driver-http-fixture-only-" * 3
    settings = Settings(
        environment="development",
        dev_auth_enabled=True,
        dev_auth_key=key,
        test_drivers_enabled=True,
        database_url=f"sqlite:///{(tmp_path / 'population.sqlite').as_posix()}",
        object_dir=str(tmp_path / "objects"),
        godot_bin=real_verifier.binary,
        game_project=str(real_verifier.project),
        rate_limit_per_minute=2000,
        auth_limit_per_minute=1000,
        write_limit_per_minute=1000,
    )
    app = create_app(settings)
    upgrade(app.state.engine)
    seed(app)
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    server = uvicorn.Server(uvicorn.Config(app, log_level="error", access_log=False))
    thread = threading.Thread(target=server.run, kwargs={"sockets": [listener]}, daemon=True)
    thread.start()
    try:
        for _ in range(100):
            if server.started:
                break
            time.sleep(0.05)
        api = API(f"http://127.0.0.1:{listener.getsockname()[1]}", key)
        arguments = SimpleNamespace(
            command="fill",
            state=tmp_path / "population.json",
            count=14,
            seed=27,
            vehicle="compact",
            target_subject="developer",
            instant=True,
            pace_reference=None,
        )
        plan = prepare(api, arguments)
        # Keep the slow end-to-end test focused on the first due drive per circuit.
        plan["jobs"] = [job for job in plan["jobs"] if job["attempt"] == 0]
        for _ in range(15):
            counts = tick(api, plan, settings, arguments.state, 10)
            while process_one(app):
                pass
            if not counts.get("waiting") and not counts.get("submitted"):
                break
        assert all(job["status"] == "verified" for job in plan["jobs"])
        assert len(plan["jobs"]) >= 60
        with app.state.session_factory() as session:
            assert len(session.scalars(select(Run)).all()) == len(plan["jobs"])
        view = api.call("GET", "/rivalry/" + plan["group_id"], subject="developer")
        assert view["driver_count"] == 14 and view["test_population"]
        assert sum(row["is_test_driver"] for row in view["standings"]) == 13
        assert sum(row["points"] for row in view["standings"]) > 0
        for job in plan["jobs"]:
            assert job["time_ticks"] == job["generated_ticks"]
        best = next(row for row in view["tracks"][0]["entries"] if row["ticks"] is not None)
        ghost = api.call(
            "GET", f"/rivalry/{plan['group_id']}/tracks/0/ghosts/{best['id']}", subject="developer"
        )
        # The ghost ends at the fractional line crossing inside its final tick.
        assert 0 <= best["ticks"] - ghost["recording"]["ticks"] < 1
        assert len({row["ticks"] for row in view["tracks"][0]["entries"] if row["ticks"]}) >= 10
        public = api.call(
            "GET",
            "/track-versions/" + view["tracks"][0]["entry"]["version_id"] + "/leaderboard?vehicle_id=compact",
        )
        assert public["population"] == 0
        evidence = ROOT / "docs/evidence/test-drivers-2026-10-04"
        evidence.mkdir(parents=True, exist_ok=True)
        (evidence / "verified-field.json").write_text(json.dumps(view, indent=2))
        (evidence / "verification-summary.json").write_text(
            json.dumps(
                {
                    "driver_count": 14,
                    "test_drivers": 13,
                    "verified_races": len(plan["jobs"]),
                    "public_population": 0,
                    "verified_ghost_poses": len(ghost["recording"]["poses"]),
                    "times": [
                        {"subject": j["subject"], "slot": j["slot"], "ticks": j["time_ticks"]}
                        for j in plan["jobs"]
                    ],
                },
                indent=2,
            )
        )
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        listener.close()
        app.state.engine.dispose()
