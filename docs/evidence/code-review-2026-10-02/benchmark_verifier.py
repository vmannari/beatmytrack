"""Desktop verifier timings, without API traffic or a shared database."""

import json
import os
import statistics
import sys
import time
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend"))
from bmt_backend.verifier import GodotVerifier


def run():
    verifier = GodotVerifier(SimpleNamespace(
        godot_bin=os.environ.get("BMT_GODOT_BIN", "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe"),
        game_project=ROOT / "game", verifier_timeout_seconds=90,
    ))
    fixture = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())
    begin = time.perf_counter()
    verifier.manifest()
    manifest_seconds = time.perf_counter() - begin
    validation, verification = [], []
    for _ in range(3):
        begin = time.perf_counter()
        verifier.validate_track(fixture["document"])
        validation.append(time.perf_counter() - begin)
        begin = time.perf_counter()
        verifier.verify_run(fixture["document"], fixture["replay"], "compact")
        verification.append(time.perf_counter() - begin)
    output = {"platform": sys.platform, "frames": len(fixture["replay"]["frames"]),
              "cold_manifest_seconds": manifest_seconds, "track_validation_seconds": validation,
              "verification_seconds": verification, "median_verification_seconds": statistics.median(verification),
              "serialized_worker_replays_per_minute_estimate": 60 / statistics.median(verification),
              "limitations": "Warm desktop process-launch samples for one oval, excluding DB/API/storage and NAS hardware. Not a capacity guarantee."}
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    run()
