"""Checkpoint this visual follow-up without staging or touching other work."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
CHANGED = [
    "game/ui/garage_hose_rig.gd", "game/ui/garage_hose_geometry.gd",
    "game/ui/garage_hose_spray.gdshader", "game/ui/garage_hose_cable.gdshader",
    "game/tests/test_garage_hose.gd", "game/tests/test_garage_hose_refinement.gd",
]
NEW = ["docs/GARAGE_HOSE_WATER_REWORK_2026_10_24.md"] + [f"docs/evidence/hose-water-rework-2026-10-24/{name}" for name in ["run_validation.ps1", "preview.html", "doc-prefixes.json", "checkpoint.py"]]


def read(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig").replace("\r\n", "\n")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


prefixes = json.loads(read(OUT / "doc-prefixes.json"))
before = {name: read(OUT / "before" / name) for name in CHANGED}
for name, prefix in prefixes.items():
    current = read(ROOT / name)
    assert current.count(prefix) == 1, name
    before[name] = current.replace(prefix, "", 1)
patch = []
for name in [*before, *NEW]:
    previous, current = before.get(name, ""), read(ROOT / name)
    if previous == current:
        continue
    patch.append(f"diff --git a/{name} b/{name}\n")
    if name not in before:
        patch.append("new file mode 100644\n")
    for line in difflib.unified_diff(previous.splitlines(True), current.splitlines(True), fromfile=f"a/{name}" if name in before else "/dev/null", tofile=f"b/{name}"):
        patch.append(line if line.endswith("\n") else line+"\n\\ No newline at end of file\n")
(OUT / "checkpoint.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
check = subprocess.run(["git", "apply", "--reverse", "--check", str(OUT / "checkpoint.patch")], cwd=ROOT, capture_output=True, text=True)
assert check.returncode == 0, check.stderr
validation = []
for receipt in sorted(OUT.glob("*/command.json")):
    item = json.loads(read(receipt))
    item["name"] = receipt.parent.name
    item["results"] = [line for line in read(receipt.parent / "console.log").splitlines() if re.search(r"\d+ (?:checks|scripts), \d+ failures", line)]
    validation.append(item)
report = {
    "date": "2026-10-24", "requirements": ["HWR01", "HWR02", "R01", "Q01"],
    "engine": read(ROOT / "godot-version.txt").strip(),
    "changed_files": [*CHANGED, *prefixes, *NEW],
    "source_sha256": {name: sha(ROOT / name) for name in [*CHANGED, *prefixes, *NEW]},
    "before_sha256": {name: sha(OUT / "before" / name) for name in CHANGED},
    "preserved_condition_flow_sha256": {name: sha(ROOT / name) for name in ["game/ui/car_showroom.gd", "game/ui/garage_wash_effect.gd", "game/vehicle/vehicle_weathering.gd"]},
    "checkpoint_reverse_check": "passed", "checkpoint_sha256": sha(OUT / "checkpoint.patch"),
    "checkpoint_scope": "Only this follow-up against exact task-start source copies and exact added document prefixes. Earlier hose work and concurrent edits excluded. No staging or commit.",
    "visual_budget": {"water_draws": 1, "water_particles": 256, "water_triangles": 512, "retained_splash_slots": 32, "hose_diameter_m": 0.022, "hose_points": 49},
    "validation": validation,
    "native_water_controls": {folder.name: json.loads(read(folder / "metrics.json")) for folder in OUT.glob("test_garage_hose_refinement-*") if (folder / "metrics.json").is_file()},
    "native_capture_sha256": {str(p.relative_to(ROOT)).replace("\\", "/"): sha(p) for p in sorted(OUT.glob("test*/*.png"))},
    "limitations": [
        "Owner visual acceptance remains; preview is actual captured phases and is not a frame-rate benchmark.",
        "Initial too-faint water failed the retained 300-pixel readability threshold. Size/contrast corrected; no readability or cleanup assertion relaxed.",
        "Initial concurrent Garage newspaper preload and Desert envelope compilation interruptions retained; unrelated sources preserved.",
        "Full-project scan currently stops at the concurrent generated desert_wind_envelope.gd:5 LEVELS constant-expression error. Affected native hose suites pass; no full parser pass claimed.",
        "No phone/tablet attachment check or device test, APK/export/install, owner-process restart, live mutation, purchase or deployment.",
        "Earlier baseline-confirmed animation restart-test failure remains documented in the original hose report and was not rerun here.",
    ],
}
(OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False)+"\n", encoding="utf-8", newline="\n")
print(json.dumps({"checkpoint_reverse_check": "passed", "validation": {v["name"]: v["results"] for v in validation}}, indent=2))
