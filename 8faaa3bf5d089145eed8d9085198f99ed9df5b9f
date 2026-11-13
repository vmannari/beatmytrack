"""Pin the new physics version and EV tune in the existing historical replay fixture."""
from pathlib import Path
from types import SimpleNamespace
import json
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "backend"))
from bmt_backend.verifier import GodotVerifier  # noqa: E402

verifier = GodotVerifier(SimpleNamespace(
    godot_bin=r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
    game_project=ROOT / "game", verifier_timeout_seconds=90,
))
try:
    manifest = verifier.manifest()
finally:
    verifier.close()
old = json.loads((OUT / "before/backend__tests__fixtures__verified_oval.json.txt").read_text())
fixture = ROOT / "backend/tests/fixtures/verified_oval.json"
current = json.loads(fixture.read_text())
assert manifest["physics_version"] == "arcade-planar-0.69"
assert manifest["vehicles"]["electric"]["handling_version"] == "electric-6"
for car, tune in manifest["vehicles"].items():
    if car != "electric":
        assert tune == old["expected_manifest"]["vehicles"][car]
assert current == old, "Preserve any concurrent fixture edit before pinning"
current["expected_manifest"]["vehicles"]["electric"] = manifest["vehicles"]["electric"]
current["expected_manifest"]["physics_version"] = manifest["physics_version"]
fixture.write_text(json.dumps(current, indent=2) + "\n")
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest["vehicles"]["electric"]))
