"""Verify the actual recorded electric-4 race through the local server reader."""
from pathlib import Path
from types import SimpleNamespace
import json
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "backend"))

from bmt_backend.runs import board_manifest  # noqa: E402
from bmt_backend.track_models import digest  # noqa: E402
from bmt_backend.verifier import GodotVerifier  # noqa: E402


def verify() -> None:
    generated = json.loads((OUT / "canonical-race.json").read_text())
    assert generated["ok"], generated.get("error")
    race = generated["result"]
    assert race["vehicle_id"] == "electric"
    verifier = GodotVerifier(SimpleNamespace(
        godot_bin=r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
        game_project=ROOT / "game",
        verifier_timeout_seconds=90,
    ))
    try:
        result = verifier.verify_canonical_diagnostic(race["document"], race["replay"], "electric")
        assert result["time_ticks"] == race["time_ticks"]
        assert len(result["lap_ticks"]) == 5
        assert result["manifest"]["physics_version"] == "arcade-planar-0.68"
        electric = result["manifest"]["vehicles"]["electric"]
        assert electric["handling_version"] == "electric-4"
        assert electric["config_hash"] == "f70168e47f9d940b98b8acd84b97921ba75ef397dbd355ec7d1ddc57be84b3c7"
        old = json.loads((OUT / "before/backend__tests__fixtures__verified_oval.json.txt").read_text())["expected_manifest"]
        old_board = digest(board_manifest(SimpleNamespace(manifest=old), "electric"))
        new_board = digest(board_manifest(SimpleNamespace(manifest=result["manifest"]), "electric"))
        # Equal document identity makes this a test of the tune, not the track.
        old_same_track = {**old, "track_content_hash": result["manifest"]["track_content_hash"]}
        assert digest(board_manifest(SimpleNamespace(manifest=old_same_track), "electric")) != new_board
        receipt = {
            "input_count": len(race["replay"]["frames"]),
            "time_ticks": result["time_ticks"],
            "time_ms": result["time_ms"],
            "lap_ticks": result["lap_ticks"],
            "electric": electric,
            "previous_fixture_board": old_board,
            "new_board": new_board,
            "same_track_old_tune_board_is_distinct": True,
        }
        (OUT / "canonical-verification.json").write_text(json.dumps(receipt, indent=2) + "\n")
        print("ELECTRIC_RESPONSE_VERIFIER:", json.dumps(receipt))
    finally:
        verifier.close()


if __name__ == "__main__":
    verify()
