"""Verify the actual kart-5 recording through the independent local server reader."""
from pathlib import Path
from types import SimpleNamespace
import json
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "backend"))

from bmt_backend.runs import board_manifest
from bmt_backend.track_models import digest
from bmt_backend.verifier import GodotVerifier


def verify():
    generated = json.loads((OUT / "canonical-race.json").read_text())
    assert generated["ok"]
    race = generated["result"]
    assert race["vehicle_id"] == "kart"
    verifier = GodotVerifier(SimpleNamespace(
        godot_bin=r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
        game_project=ROOT / "game", verifier_timeout_seconds=90,
    ))
    try:
        result = verifier.verify_canonical_diagnostic(race["document"],race["replay"],"kart")
        assert result["time_ticks"] == race["time_ticks"] and len(result["lap_ticks"]) == 5
        manifest = result["manifest"]
        current = manifest["vehicles"]["kart"]
        assert current == {"handling_version":"kart-5","config_hash":"0d232a39393d7146aafa737e59d8b0bfd87292f1c4556614089a82e445e00873"}
        old = json.loads((OUT / "before/verified_oval.json").read_text())["expected_manifest"]
        for car in manifest["vehicles"]:
            if car != "kart": assert old["vehicles"][car] == manifest["vehicles"][car], car
        assert old["physics_version"] == manifest["physics_version"] == "arcade-planar-0.69"
        old_same_track = {**manifest,"vehicles":{**manifest["vehicles"],"kart":old["vehicles"]["kart"]}}
        before_board = digest(board_manifest(SimpleNamespace(manifest=old_same_track),"kart"))
        after_board = digest(board_manifest(SimpleNamespace(manifest=manifest),"kart"))
        assert before_board != after_board
        fixture = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())
        assert fixture["expected_manifest"]["vehicles"]["kart"] == current
        receipt = {"input_count":len(race["replay"]["frames"]),"time_ticks":result["time_ticks"],"time_ms":result["time_ms"],"lap_ticks":result["lap_ticks"],"kart":current,"six_other_car_entries_unchanged":True,"physics_version":manifest["physics_version"],"old_same_track_board":before_board,"new_board":after_board}
        (OUT / "canonical-verification.json").write_bytes((json.dumps(receipt,indent=2)+"\n").encode())
        print("KART_140_VERIFIER:",json.dumps(receipt))
    finally:
        verifier.close()


if __name__ == "__main__": verify()
