"""Expanded authoring boundaries, including the real canonical process."""
from __future__ import annotations

import copy
import json
import os
from pathlib import Path
from types import SimpleNamespace

import pytest

from bmt_backend.verifier import MAX_TRACK_BYTES, GodotVerifier, VerificationError, _json_bytes

ROOT = Path(__file__).resolve().parents[2]


def test_expanded_byte_boundary():
    assert MAX_TRACK_BYTES == 1_048_576
    document = {"name": "x" * 600_000}
    assert len(_json_bytes(document, MAX_TRACK_BYTES)) > 524_288
    with pytest.raises(VerificationError):
        _json_bytes({"name": "x" * MAX_TRACK_BYTES}, MAX_TRACK_BYTES)


@pytest.mark.godot
def test_real_canonical_accepts_expanded_object_and_tyre_boundaries():
    binary = Path(os.environ.get("BMT_GODOT_BIN") or os.environ.get("GODOT_BIN")
                  or r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")
    if not binary.is_file():
        pytest.skip("Pinned Godot unavailable")
    verifier = GodotVerifier(SimpleNamespace(godot_bin=str(binary), game_project=os.environ.get("BMT_GAME_PROJECT", ROOT / "game"),
                                           verifier_timeout_seconds=90))
    base = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())["document"]
    document = copy.deepcopy(base)
    document["objects"] = [{"kind": "grass_clump", "position": [i % 100 - 50, i // 100 - 20], "rotation": 0}
                           for i in range(4096)]
    manifest = verifier.validate_track(document)
    assert manifest["track_schema"] == "creator-track-v5"
    document["objects"].append(document["objects"][0])
    with pytest.raises(VerificationError, match="Malformed creator document structure"):
        verifier.validate_track(document)
    document["objects"].pop()
    points = [[-99.8765433 + (i % 100) * 2.0, -99.2345679 + (i // 100) * 2.0] for i in range(512)]
    document["paint"] = [{"surface": 1, "width": 1.0, "shape": "round", "points": points} for _ in range(32)]
    assert 524_288 < len(_json_bytes(document, MAX_TRACK_BYTES)) < MAX_TRACK_BYTES
    assert verifier.validate_track(document)["track_schema"] == "creator-track-v5"
    document["paint"] = []
    document["objects"] = [{"kind": "tyre_wall", "position": [0, 0], "rotation": 0} for _ in range(682)]
    document["objects"] += [{"kind": "tyre_stack", "position": [0, i], "rotation": 0} for i in range(4)]
    assert verifier.validate_track(document)["track_schema"] == "creator-track-v5"
    document["objects"].append({"kind": "tyre_stack", "position": [1, 1], "rotation": 0})
    with pytest.raises(VerificationError, match="tyre stacks"):
        verifier.validate_track(document)
