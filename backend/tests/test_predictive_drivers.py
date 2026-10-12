"""Native recordings, derived-cache reuse and independent canonical proof."""
import dataclasses
import importlib.util
import json
import subprocess
import sys
import time
from pathlib import Path
from types import SimpleNamespace

import pytest
from test_test_drivers import auth, bot_login, fleet, group
from test_test_drivers import drivers as _drivers
from test_verifier import real_verifier as _real_verifier

from bmt_backend.test_driver_generator import CONTROLLER_VERSION, generate
from bmt_backend.test_drivers import profile
from bmt_backend.verifier import GodotVerifier

real_verifier = _real_verifier
drivers = _drivers
ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.godot
@pytest.mark.parametrize("track_name", ["oval", "Over and under"])
def test_cached_and_regenerated_trajectories_emit_exact_verified_inputs(tmp_path, real_verifier, track_name):
    if track_name == "oval":
        document = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())["document"]
    else:
        document = next(d for d in json.loads((ROOT / "backend/bmt_backend/lab_tracks.json").read_text())["documents"]
                        if d["name"] == track_name)
    settings = SimpleNamespace(godot_bin=real_verifier.binary, game_project=real_verifier.project,
                               verifier_timeout_seconds=90, object_dir=str(tmp_path / "objects"))
    traits = profile(27, 6, 13, 0.42, 0.58)[2]
    cold = generate(settings, document, "compact", traits)
    warm = generate(settings, document, "compact", traits)
    assert not cold["diagnostics"]["cache_hit"] and warm["diagnostics"]["cache_hit"]
    assert cold["replay"] == warm["replay"]
    assert cold["time_ticks"] == warm["time_ticks"]
    assert warm["diagnostics"]["planning_ms"] < cold["diagnostics"]["planning_ms"]
    assert cold["diagnostics"]["mean_update_ms"] < 100  # 10 Hz update interval.
    assert cold["telemetry"]["samples"] and "reference_v_mps" in cold["telemetry"]["columns"]
    verified = real_verifier.verify_run(document, cold["replay"], "compact")
    assert verified["time_ticks"] == cold["time_ticks"] and len(verified["lap_ticks"]) == 5
    cache = next((tmp_path / "driver-trajectories").glob("*.json"))
    stale = json.loads(cache.read_text())
    stale["key"] = "old-physics-rules-or-handling"
    cache.write_text(json.dumps(stale))
    rebuilt = generate(settings, document, "compact", traits)
    assert not rebuilt["diagnostics"]["cache_hit"] and rebuilt["replay"] == cold["replay"]
    cache.write_text("broken derived cache")
    repaired = generate(settings, document, "compact", traits)
    assert not repaired["diagnostics"]["cache_hit"] and repaired["replay"] == cold["replay"]
    assert not list(cache.parent.glob("*.tmp"))


@pytest.mark.godot
def test_packaged_worker_contains_predictive_driver_and_current_dependencies(tmp_path, real_verifier):
    spec = importlib.util.spec_from_file_location("stage_predictive_worker", ROOT / "backend/deploy/stage_verifier.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    project = tmp_path / "game"
    module.stage(ROOT, project)
    imported = subprocess.run([real_verifier.binary, "--headless", "--path", str(project), "--editor", "--import"],
                              capture_output=True, text=True, timeout=90, check=False)
    assert imported.returncode == 0 and "SCRIPT ERROR" not in imported.stdout + imported.stderr
    settings = SimpleNamespace(godot_bin=real_verifier.binary, game_project=project,
                               verifier_timeout_seconds=90, object_dir=str(tmp_path / "objects"))
    document = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())["document"]
    recording = generate(settings, document, "compact", profile(27, 6, 13, 0.42, 0.58)[2])
    assert recording["controller_version"] == CONTROLLER_VERSION
    verifier = GodotVerifier(settings)
    try:
        verified = verifier.verify_run(document, recording["replay"], "compact")
        assert verified["time_ticks"] == recording["time_ticks"] and len(verified["lap_ticks"]) == 5
    finally:
        verifier.close()


def test_committed_upload_recovery_is_private_and_development_gated(drivers):
    population = fleet(drivers, count=2)["profiles"]
    first, second = [bot_login(drivers, p) for p in population]
    field = group(drivers, login=first)
    ticket = drivers.client.post("/v1/run-tickets", json={
        "version_id": field["tracks"][0]["entry"]["version_id"],
        "vehicle_id": "compact", "test_population": True,
    }, headers=auth(first)).json()
    key = "a" * 64 + "-upload-0"
    headers = {**auth(first), "Idempotency-Key": key}
    uploaded = drivers.client.post("/v1/runs", json={"ticket_id": ticket["ticket_id"],
        "replay": {"schema": "bmt-replay-v1", "frames": [[0, 166, 0]]}}, headers=headers)
    assert uploaded.status_code == 202, uploaded.text
    route = "/v1/dev/test-drivers/uploads/" + key
    recovered = drivers.client.get(route, headers=auth(first, operator=True))
    assert recovered.status_code == 200
    assert recovered.json()["run"]["run_id"] == uploaded.json()["run_id"]
    assert recovered.json()["run"]["time_ticks"] is None and "replay" not in recovered.json()
    assert drivers.client.get(route, headers=auth(second, operator=True)).json()["run"] is None
    assert drivers.client.get(route, headers=auth(first)).status_code == 401
    assert drivers.client.get(route, headers=auth(drivers.login, operator=True)).status_code == 404
    drivers.app.state.settings = dataclasses.replace(drivers.app.state.settings, test_drivers_enabled=False)
    assert drivers.client.get(route, headers=auth(first, operator=True)).status_code in (401, 404)


def test_controller_parse_errors_fail_promptly_and_stop_owned_process(monkeypatch):
    import bmt_backend.test_driver_generator as controller
    spawned = []
    original = subprocess.Popen
    class FixtureVerifier:
        binary = sys.executable
        project = ROOT / "game"
        timeout = 5
        def __init__(self, settings):
            pass
        def _check_engine(self):
            pass
    def fail_process(command, **kwargs):
        if command[0] != sys.executable:
            return original(command, **kwargs)
        process = original([sys.executable, "-c",
            "import time;print('SCRIPT ERROR: fixture parse error',flush=True);time.sleep(30)"], **kwargs)
        spawned.append(process)
        return process
    monkeypatch.setattr(controller, "GodotVerifier", FixtureVerifier)
    monkeypatch.setattr(controller.subprocess, "Popen", fail_process)
    started = time.monotonic()
    with pytest.raises(RuntimeError, match="engine error"):
        controller.generate(SimpleNamespace(), {}, "compact", {})
    assert time.monotonic()-started < 3 and all(p.poll() is not None for p in spawned)


@pytest.mark.godot
@pytest.mark.parametrize("name", ["star_spline_lap", "spline_circuit"])
def test_arbitrary_creator_splines_generate_ordered_verified_five_laps(tmp_path, real_verifier, name):
    document = json.loads((ROOT / "game/tests/fixtures" / (name + ".json")).read_text())
    settings = SimpleNamespace(godot_bin=real_verifier.binary, game_project=real_verifier.project,
                               verifier_timeout_seconds=90, object_dir=str(tmp_path / "objects"))
    traits = profile(27, 6, 13, 0.42, 0.58)[2]
    result = generate(settings, document, "compact", traits)
    verified = real_verifier.verify_run(document, result["replay"], "compact")
    assert result["time_ticks"] == verified["time_ticks"] and len(verified["lap_ticks"]) == 5
    assert result["diagnostics"]["fallback_ticks"] == 0
