"""Fail builds on a wrong engine or Godot parse/import errors, including exit 0."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path
from types import SimpleNamespace


def check(project: Path, binary: str = "godot", fixture: Path | None = None) -> None:
    expected = (project.parent / "godot-version.txt").read_text(encoding="utf-8").strip()
    version = subprocess.run([binary, "--headless", "--version"], check=True, capture_output=True, text=True)
    if version.stdout.strip() != expected:
        raise SystemExit(f"Godot version mismatch: expected {expected}; received {version.stdout.strip()}")
    imported = subprocess.run(
        [binary, "--headless", "--path", str(project), "--editor", "--import"],
        capture_output=True,
        text=True,
        timeout=180,
        check=False,
    )
    diagnostic = imported.stdout + imported.stderr
    if imported.returncode or re.search(r"SCRIPT ERROR:|(^|\s)ERROR:|Parse Error:", diagnostic):
        raise SystemExit("Canonical verifier import failed:\n" + diagnostic)
    print("Pinned Godot version and canonical verifier import passed")
    if fixture:
        from bmt_backend.verifier import GodotVerifier

        saved = json.loads(fixture.read_text(encoding="utf-8"))
        verifier = GodotVerifier(
            SimpleNamespace(godot_bin=binary, game_project=project, verifier_timeout_seconds=90)
        )
        result = verifier.verify_canonical_diagnostic(saved["document"], saved["replay"], saved["vehicle_id"])
        if result["manifest"] != saved["expected_manifest"]:
            raise SystemExit("Canonical manifest differs from the pinned Windows regression fixture")
        if result["time_ticks"] != saved["time_ticks"] or result["lap_ticks"] != [
            2634,
            2532,
            2531,
            2530,
            2530,
        ]:
            raise SystemExit("Canonical replay differs from the pinned Windows regression fixture")
        print(f"Canonical regression fixture passed: {result['time_ticks']} ticks, five laps")
        # Exercise the versioned rewind envelope in the stripped Linux project,
        # including restoring ordered gates after a full ten-second branch.
        frames = saved["replay"]["frames"]
        rewind = {
            "schema": "bmt-replay-v2",
            "frames": frames[:3600] + frames[2400:],
            "rewinds": [{
                "receipt_id": "00000000-0000-0000-0000-000000000001",
                "input_offset": 3600, "from_tick": 3600, "to_tick": 2400,
            }],
        }
        if verifier.verify_canonical_diagnostic(saved["document"], rewind, saved["vehicle_id"]) != result:
            raise SystemExit("Canonical rewind differs from the original race result")
        print("Canonical ten-second rewind regression passed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--import-project", type=Path, required=True)
    parser.add_argument("--binary", default="godot")
    parser.add_argument("--fixture", type=Path)
    args = parser.parse_args()
    check(args.import_project, args.binary, args.fixture)
