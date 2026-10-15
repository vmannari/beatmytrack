"""Exact pinned Godot geometry/manifest comparison, not a fake verifier."""
import json
import os
from pathlib import Path

from bmt_backend.config import Settings
from bmt_backend.verifier import GodotVerifier


def test_real_verifier_redaction_changes_only_the_compiled_hash(tmp_path, monkeypatch):
    root = Path(__file__).resolve().parents[2]
    monkeypatch.setenv("APPDATA", str(tmp_path / "profile"))
    (tmp_path / "profile").mkdir()
    binary = os.environ.get("GODOT_BIN", "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe")
    verifier = GodotVerifier(Settings(godot_bin=binary, game_project=str(root / "game")))
    try:
        original = json.loads((root / "backend/bmt_backend/lab_tracks.json").read_text())["documents"][0]
        original["creator"] = "Original native fixture"
        redacted = {**original, "creator": "Removed account"}
        first, second = verifier.validate_track(original), verifier.validate_track(redacted)
        assert first["track_content_hash"] != second["track_content_hash"]
        assert {key: value for key, value in first.items() if key != "track_content_hash"} == {
            key: value for key, value in second.items() if key != "track_content_hash"}
        first_geometry, second_geometry = verifier.race_geometry(original), verifier.race_geometry(redacted)
        assert {key: value for key, value in first_geometry.items() if key != "manifest"} == {
            key: value for key, value in second_geometry.items() if key != "manifest"}
    finally:
        verifier.close()
