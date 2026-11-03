"""Offline native gate exports, historical shortcuts and exact canonical replay."""
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))
from bmt_backend.trajectory_verifier import check
from bmt_backend.verifier import VerificationError

OUTPUT = ROOT / "build/checkpoint-road-coverage-2026-11-03"
OLD = ROOT / "docs/evidence/hairpin-checkpoints-2026-10-18"
GODOT = os.environ.get("GODOT_BIN", "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe")


def native(label, request):
    source, target = OUTPUT / (label + "-input.json"), OUTPUT / (label + "-output.json")
    source.write_text(json.dumps(request), encoding="utf-8")
    command = [sys.executable, "scripts/run_no_crash_dialog.py", "--", GODOT, "--headless",
               "--path", "game", "--log-file", str(OUTPUT / "logs" / (label + "-engine.log")),
               "--script", "res://backend/runner.gd", "--", "--input=" + str(source), "--output=" + str(target)]
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA"):
        directory = OUTPUT / "profiles" / ("native-" + key)
        directory.mkdir(parents=True, exist_ok=True)
        env[key] = str(directory)
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, timeout=180)
    log = (result.stdout + result.stderr).decode("utf-8", errors="replace")
    (OUTPUT / "logs" / (label + ".log")).write_text(log, encoding="utf-8")
    assert result.returncode == 0 and "SCRIPT ERROR:" not in log, log[-2000:]
    # The workspace sandbox consistently denies Windows' root certificate store.
    # No networking occurs here; preserve that diagnostic explicitly.
    assert all("Failed to read the root certificate store" in line for line in log.splitlines() if "ERROR:" in line), log[-2000:]
    response = json.loads(target.read_text(encoding="utf-8"))
    assert response["ok"], response
    print(label + " native export accepted", flush=True)
    return response["result"]


def main():
    geometries, cuts = {}, []
    for case in json.loads((OLD / "hairpin-trajectories.json").read_text()):
        key = bool(case["reverse"])
        if key not in geometries:
            geometries[key] = native("geometry-" + str(key), {"operation": "race_geometry", "document": case["document"]})
        geometry = geometries[key]
        assert geometry["manifest"]["rules_key"] == "standing-5-road-gates-v24"
        proof = case["trajectory"]
        try:
            check(geometry, proof["proof"], proof["ticks"], "compact")
        except VerificationError as error:
            cuts.append({"reverse": key, "begin": case["begin"], "rejected": str(error)})
        else:
            raise AssertionError("Historical hairpin bypass accepted")
    recording = json.loads((ROOT / "build/hairpin-checkpoints-2026-10-18/star-edge-five-lap-replay.json").read_text())
    real = check(geometries[False], recording["race_proof"], recording["time_ticks"], "compact")
    assert len(real["lap_ticks"]) == 5
    canonical = native("canonical-edge", {"operation": "diagnostic_replay", "document": recording["document"],
                                          "replay": recording["replay"], "vehicle_id": "compact", "capture_ghost": False})
    assert canonical["time_ticks"] == recording["time_ticks"] == 47712
    assert canonical["manifest"]["rules_key"] == "standing-5-road-gates-v24"
    report = {"cuts": cuts, "real_sparse_lap_ticks": real["lap_ticks"], "canonical_ticks": canonical["time_ticks"],
              "canonical_lap_ticks": canonical["lap_ticks"], "manifest": canonical["manifest"],
              "environment_error": "Windows root certificate store denied by sandbox; retained in native logs"}
    (OUTPUT / "native-verifier.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"NATIVE_COVERAGE: {len(cuts)} historical cuts rejected; real five-lap proof and 47712 canonical ticks accepted")


if __name__ == "__main__":
    main()
