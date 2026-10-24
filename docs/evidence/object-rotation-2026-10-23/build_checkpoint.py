"""Build a review patch containing only this task's changes in the shared tree."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
CAPTURED = OUT / "before"

app_path = "game/core/app.gd"
app = (ROOT / app_path).read_text(encoding="utf-8")
baseline = app
for addition in [
    "\tobject_browser.rotation_requested.connect(_object_rotation_dialog)\n",
    "\tobject_browser.set_stamp_rotation(canvas.stamp_rotation)\n\tobject_browser.rotation_button.disabled = canvas.mode == \"run\"\n",
]:
    assert baseline.count(addition) == 1
    baseline = baseline.replace(addition, "", 1)
selected = '''\t\t\t_context_button("Rotate","rotate",_rotate_object).tooltip_text = "Rotate by 22.5°"
\t\t\tvar rotation_choice: Button = _context_button(preload("res://editor/object_rotation.gd").angle_text(_object_rotation()),"rotate",_object_rotation_dialog)
\t\t\trotation_choice.name = "ObjectRotation"
\t\t\trotation_choice.tooltip_text = "16 orientations or Free rotation"
'''
assert baseline.count(selected) == 1
baseline = baseline.replace(selected, '\t\t\t_context_button("Rotate","rotate",_rotate_object)\n', 1)
original_app = (CAPTURED / "app-before.gd").read_text(encoding="utf-8")
old_rotation = original_app[original_app.index("func _rotate_object()"):original_app.index("func _scale_object(")]
baseline = baseline[:baseline.index("func _rotate_object()")] + old_rotation + baseline[baseline.index("func _scale_object("):]

previous = {
    app_path: baseline,
    "game/editor/object_browser.gd": (CAPTURED / "object_browser-before.gd").read_text(encoding="utf-8"),
    "game/tests/test_editor_v2.gd": (CAPTURED / "test_editor_v2-before.gd").read_text(encoding="utf-8"),
}
added = ["game/editor/object_rotation.gd", "game/tests/test_object_rotation.gd", "docs/OBJECT_ROTATION_2026_10_23.md", "docs/evidence/object-rotation-2026-10-23/run.ps1", "docs/evidence/object-rotation-2026-10-23/build_checkpoint.py"]
patch = []
hashes = {}
for name in [*previous, *added]:
    current = (ROOT / name).read_text(encoding="utf-8")
    old = previous.get(name, "")
    patch.append("diff --git a/" + name + " b/" + name + "\n")
    if name in added:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(old.splitlines(True), current.splitlines(True), fromfile="a/"+name if name in previous else "/dev/null", tofile="b/"+name))
    hashes[name] = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
(OUT / "task-only.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
verified = subprocess.run(["git", "apply", "--reverse", "--check", str(OUT / "task-only.patch")], cwd=ROOT, capture_output=True, text=True)
results = {}
for path in sorted(OUT.glob("test_*.log")):
    raw = path.read_bytes()
    log = raw.decode("utf-16" if raw.startswith((b"\xff\xfe",b"\xfe\xff")) else "utf-8-sig")
    results[path.name] = {
        "summaries": re.findall(r"[A-Z0-9_]+TESTS: \d+ checks, \d+ failures", log),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "runner_failure": "ROTATION_TEST_EXIT" in log,
    }
report = {
    "requirements": ["OR01", "OR02", "OR03", "G01", "R01", "Q01"],
    "engine": "4.7.2.stable.official.ed1daf0bf",
    "environment": {"profile": "build/object-rotation-2026-10-23/profile", "BMT_API_URL": "audit-disabled", "audio_driver": "Dummy", "gpu": "desktop NVIDIA GeForce RTX 3090"},
    "results": results,
    "sha256": hashes,
    "checkpoint_reverse_check": {"exit": verified.returncode, "stdout": verified.stdout, "stderr": verified.stderr},
    "limitations": ["Windows sandbox certificate-store diagnostic retained", "No phone attachment check or physical-device test", "No APK or deployment", "Owner appearance/interaction and physical touch/keyboard acceptance remain"],
}
(OUT / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps(report["checkpoint_reverse_check"]))
raise SystemExit(verified.returncode)
