"""Offline native geometry/trajectory/canonical checks; no service or DB writes."""
import json
from pathlib import Path
from types import SimpleNamespace

from bmt_backend.trajectory_verifier import check
from bmt_backend.verifier import GodotVerifier, VerificationError

repo = Path(__file__).resolve().parents[3]
evidence = Path(__file__).parent
verifier = GodotVerifier(SimpleNamespace(
    godot_bin=r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
    game_project=repo / "game", verifier_timeout_seconds=180,
))
rows = []
for case in json.loads((evidence / "hairpin-trajectories.json").read_text()):
    geometry = verifier.race_geometry(case["document"])
    assert geometry["manifest"]["rules_key"] == "standing-5-road-gates-v23"
    proof = case["trajectory"]
    old = {**geometry, "gates": case["old_gates"], "manifest": {**geometry["manifest"], "rules_key": "standing-5-road-gates-v22"}}
    accepted = check(old, proof["proof"], proof["ticks"], "compact")
    assert len(accepted["lap_ticks"]) == 5
    try:
        check(geometry, proof["proof"], proof["ticks"], "compact")
    except VerificationError as exc:
        rows.append({"reverse": case["reverse"], "begin": case["begin"],
                     "old_laps": len(accepted["lap_ticks"]), "new_rejection": str(exc)})
    else:
        raise AssertionError(f"Hairpin bypass accepted: {case['reverse']}/{case['begin']}")

legal = json.loads((evidence / "trajectories.json").read_text())
geometry = verifier.race_geometry(legal["document"])
accepted = check(geometry, legal["legal"]["proof"], legal["legal"]["ticks"], "compact")
assert len(accepted["lap_ticks"]) == 5
recording = json.loads((repo / "build/hairpin-checkpoints-2026-10-18/star-edge-five-lap-replay.json").read_text())
if "race_proof" in recording:
    real = check(verifier.race_geometry(recording["document"]), recording["race_proof"], recording["time_ticks"], "compact")
    assert len(real["lap_ticks"]) == 5
canonical = verifier.verify_canonical_diagnostic(recording["document"], recording["replay"], "compact", capture_ghost=False)
assert canonical["time_ticks"] == recording["time_ticks"] == 47712
assert canonical["manifest"]["rules_key"] == "standing-5-road-gates-v23"
result = {"cuts": rows, "legal_lap_ticks": accepted["lap_ticks"],
          "real_sparse_lap_ticks": real["lap_ticks"], "real_sparse_samples": len(recording["race_proof"]["samples"]),
          "canonical_ticks": canonical["time_ticks"], "canonical_lap_ticks": canonical["lap_ticks"],
          "manifest": canonical["manifest"]}
(evidence / "native-verifier.json").write_text(json.dumps(result, indent=2)+"\n")
print(f"HAIRPIN_NATIVE: {len(rows)} historical cuts rejected; five legal and real sparse trajectory laps and 47712 canonical ticks accepted")
