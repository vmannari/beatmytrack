"""Offline native verification of the recorded current-kart five-lap race."""
from pathlib import Path
from types import SimpleNamespace
import json
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "backend"))
from bmt_backend.verifier import GodotVerifier

race = json.loads((OUT / "kart-race.json").read_text())["result"]
turning = json.loads((OUT / "turning.json").read_text())
verifier = GodotVerifier(SimpleNamespace(
    godot_bin=r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
    game_project=ROOT / "game", verifier_timeout_seconds=90))
try:
    result = verifier.verify_canonical_diagnostic(race["document"], race["replay"], "kart")
    assert result["time_ticks"] == race["time_ticks"]
    assert len(result["lap_ticks"]) == 5
    assert result["manifest"]["vehicles"]["kart"] == {
        "handling_version": "kart-6", "config_hash": turning["config_hash"]}
    assert result["manifest"]["physics_version"] == turning["physics_version"]
    fixture = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())
    expected = fixture["expected_manifest"]["vehicles"]
    absent = []
    for car, contract in result["manifest"]["vehicles"].items():
        if car not in expected:
            absent.append(car)
            continue
        assert contract == expected[car], (car, contract, expected[car])
    receipt = {"input_count": len(race["replay"]["frames"]),
               "time_ticks": result["time_ticks"], "time_ms": result["time_ms"],
               "lap_ticks": result["lap_ticks"], "kart": result["manifest"]["vehicles"]["kart"],
               "existing_local_fixture_contracts_match": True,
               "active_cars_absent_from_older_fixture": absent}
    (OUT / "canonical-verification.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt))
finally:
    verifier.close()
