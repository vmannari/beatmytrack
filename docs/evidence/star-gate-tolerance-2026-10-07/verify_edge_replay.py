"""Verify the retained whole race locally; no ticket/submission/service calls."""
from pathlib import Path
import json
import sys
from types import SimpleNamespace

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
sys.path.insert(0, str(ROOT / "backend"))
from bmt_backend.verifier import GodotVerifier

proof = json.loads((OUT / "star-edge-five-lap-replay.json").read_text())
verifier = GodotVerifier(SimpleNamespace(
    godot_bin=r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
    game_project=ROOT / "game", verifier_timeout_seconds=120,
))
result = verifier.verify_run(proof["document"], proof["replay"], proof["vehicle_id"])
assert result["time_ticks"] == proof["time_ticks"]
assert result["manifest"]["rules_key"] == proof["rules_key"] == "standing-5-road-gates-v20"
assert len(result["lap_ticks"]) == 5
receipt = {key: value for key, value in result.items() if key != "ghost"}
(OUT / "backend-verification.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
print("STAR_EDGE_BACKEND_VERIFIED", result["time_ticks"], result["lap_ticks"],
      result["manifest"]["rules_key"], result["manifest"]["physics_version"])
