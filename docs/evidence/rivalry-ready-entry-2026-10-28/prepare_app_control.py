"""Run the unchanged App assertions with only Rivalry edits removed from App."""
from pathlib import Path
import hashlib
import json

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
source = (evidence / "checkpoint-base/game/core/app.gd").read_text(encoding="utf-8")
app_file = root / "game/tests/_rivalry_ready_control_app.gd"
test_file = root / "game/tests/_rivalry_ready_app_control.gd"
assert not app_file.exists() and not test_file.exists()
app_file.write_text(source, encoding="utf-8", newline="\n")
original = (root / "game/tests/test_app.gd").read_text(encoding="utf-8")
test = original.replace('app = scene.instantiate()', 'app = scene.instantiate()\n\tapp.set_script(preload("res://tests/_rivalry_ready_control_app.gd"))')
test = test.replace('var resumed: Node = (load("res://core/app.tscn") as PackedScene).instantiate()', 'var resumed: Node = (load("res://core/app.tscn") as PackedScene).instantiate()\n\tresumed.set_script(preload("res://tests/_rivalry_ready_control_app.gd"))')
assert test != original and test.count('set_script(preload("res://tests/_rivalry_ready_control_app.gd"))') == 2
test_file.write_text(test, encoding="utf-8", newline="\n")
provenance = {"app_without_rivalry_patch_sha256": hashlib.sha256(app_file.read_bytes()).hexdigest(),
              "original_assertions_sha256": hashlib.sha256((root / "game/tests/test_app.gd").read_bytes()).hexdigest(),
              "control_test_sha256": hashlib.sha256(test_file.read_bytes()).hexdigest()}
(evidence / "app-control-provenance.json").write_text(json.dumps(provenance, indent=2)+"\n", encoding="utf-8")
for path in [app_file, test_file]:
    (evidence / (path.name+".txt")).write_bytes(path.read_bytes())
print(json.dumps(provenance))
