"""Capture only the owner-requested connected hose and broad spray follow-up."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
RUNTIME = ["game/ui/car_showroom.gd", "game/ui/garage_wash_effect.gd", "game/ui/garage_wash_geometry.gd", "game/vehicle/vehicle_weathering.gd"]
NEW = [
    "game/ui/garage_hose_rig.gd", "game/ui/garage_hose_rig.gd.uid",
    "game/ui/garage_hose_geometry.gd", "game/ui/garage_hose_geometry.gd.uid",
    "game/ui/garage_hose_cable.gdshader", "game/ui/garage_hose_cable.gdshader.uid",
    "game/ui/garage_hose_spray.gdshader", "game/ui/garage_hose_spray.gdshader.uid",
    "game/tests/test_garage_hose_refinement.gd", "game/tests/test_garage_hose_refinement.gd.uid",
    "docs/GARAGE_HOSE_SPRAY_2026_10_24.md",
    "docs/evidence/hose-spray-refinement-2026-10-24/run_validation.ps1",
    "docs/evidence/hose-spray-refinement-2026-10-24/preview.html",
    "docs/evidence/hose-spray-refinement-2026-10-24/doc-prefixes.json",
    "docs/evidence/hose-spray-refinement-2026-10-24/checkpoint.py",
]


def read(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig").replace("\r\n", "\n")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


prefixes = json.loads(read(OUT / "doc-prefixes.json"))
before = {name: read(OUT / "before" / name) for name in RUNTIME}
for name, prefix in prefixes.items():
    content = read(ROOT / name)
    assert content.count(prefix) == 1, name
    before[name] = content.replace(prefix, "", 1)
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
checked = subprocess.run(["git", "apply", "--reverse", "--check", str(OUT / "checkpoint.patch")], cwd=ROOT, text=True, capture_output=True)
assert checked.returncode == 0, checked.stderr

validation = []
for receipt in sorted(OUT.glob("*/command.json")):
    item = json.loads(read(receipt))
    item["name"] = receipt.parent.name
    item["result"] = [line for line in read(receipt.parent / "console.log").splitlines() if re.search(r"\d+ (?:checks|scripts), \d+ failures", line)]
    validation.append(item)
report = {
    "date": "2026-10-24", "requirements": ["HSR01", "HSR02", "HSR03", "R01", "Q01"],
    "engine": read(ROOT / "godot-version.txt").strip(),
    "changed_files": [*RUNTIME, *prefixes, *NEW],
    "source_sha256": {name: sha(ROOT / name) for name in [*RUNTIME, *prefixes, *NEW]},
    "before_sha256": {name: sha(OUT / "before" / name) for name in RUNTIME},
    "checkpoint_sha256": sha(OUT / "checkpoint.patch"), "checkpoint_reverse_check": "passed",
    "checkpoint_scope": "Only this follow-up: exact task-start runtime copies and exact added documentation prefixes. Earlier hose implementation and concurrent changes excluded. No staging or commit.",
    "tuning": {"previous_radius": 0.72, "radius": 1.08, "nominal_surface_area_ratio": 2.25, "normal_depth": 0.24, "film_rate": 1.6, "primary_grime_rate": 0.025, "tube_points": 49, "tube_triangles": 960, "filaments": 12, "droplet_slots": 32},
    "validation": validation,
    "water_visibility_controls": {folder.name: json.loads(read(folder / "metrics.json")) for folder in sorted(OUT.glob("test_garage_hose_refinement-*")) if (folder / "metrics.json").is_file()},
    "native_images_sha256": {str(p.relative_to(ROOT)).replace("\\", "/"): sha(p) for p in sorted(OUT.glob("test*/*.png"))},
    "limitations": [
        "Owner hose/spray appearance and washing-effort acceptance remains; client reload required.",
        "No phone/tablet attachment check or device test, APK/export/install, owner-process restart, live backend/account mutation, purchase or deployment.",
        "Native desktop pixel visibility is not phone fragment-cost, thermal or FPS certification.",
        "Earlier baseline-confirmed animation restart assertion remains documented in the first hose slice; not rerun or changed here.",
        "Initial fixture initialization error, rejected sparse-strand visual and concurrent recording-cache parser interruption retained. No existing assertion was relaxed.",
    ],
}
(OUT / "report.json").write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n",encoding="utf-8",newline="\n")
print(json.dumps({"checkpoint_reverse_check":"passed", "results": {v["name"]: v["result"] for v in validation}},indent=2))
