"""Review-only scoped checkpoint; leaves the shared Git branch/index alone."""
from pathlib import Path
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parents[3]
evidence = root / "docs/evidence/garage-customisation-speed-2026-10-13"
repo = root / "build/garage-customisation-speed/checkpoint-repo"
after, before = {}, {}


def current(name):
    after[name] = (root / name).read_text(encoding="utf-8-sig")
    return after[name]


for name in ["game/ui/garage_page.gd", "game/ui/garage_livery_menu.gd", "game/ui/compact_kit_thumbnail.gd", "game/ui/car_showroom.gd", "game/vehicle/car_visual.gd", "game/vehicle/visual_geometry.gd"]:
    current(name)
    before[name] = (evidence / "before" / name.replace("/", "__")).read_text(encoding="utf-8-sig")

name = "game/ui/livery_tile.gd"
before[name] = current(name).replace("var _selection_ready: bool = false\n", "").replace("\tif _selection_ready and selected==value: return\n\t_selection_ready = true\n", "")
name = "game/vehicle/livery_graphics.gd"
text = current(name)
a, b = text.index("func restore_originals()"), text.index("func _restore(")
before[name] = text[:a] + text[b:]
name = "game/vehicle/compact_coachwork.gd"
before[name] = current(name).replace('''\tvar original: Node3D = car.body
\tif car.editable_kits: car.body = car.new_kit_frame("hood",car.body)
\t_build_hood_surfaces(car,paint,accent)
\tcar.body = original

static func _build_hood_surfaces(car: CarVisual, paint: Material, accent: Material) -> void:
''', "")
name = "game/vehicle/compact_detail.gd"
text = current(name)
a, b = text.index("static func rim_detail("), text.index("static func _door(")
body = text[a:b].split("\n", 1)[1].rstrip() + "\n"
body = "".join("\t" + line if line.strip() else line for line in body.splitlines(keepends=True)).replace("parent", "rotor")
text = text[:a] + text[b:]
before[name] = text.replace("\t\trim_detail(car.wheel_kit_frame(rotor),side,alloy,trim,bright)\n", body)
name = "game/vehicle/compact_kits.gd"
text = current(name)
a, b = text.index("static var use_baked:"), text.index("static func choice(")
text = text[:a] + text[b:]
text = text.replace("\t_load_prepared(key)\n", "").replace("\t\t_load_prepared(cap_key)\n", "")
for category in ["aero", "body"]:
    text = text.replace(f'''\tif kind == "stock":
\t\tif car.editable_kits: car.new_kit_frame("{category}",car.body)
\t\treturn
''', '\tif kind == "stock": return\n')
    text = text.replace(f'\tcar.register_kit_frame("{category}",root)\n', "")
before[name] = text
name = "AGENTS.md"
text = current(name)
a = text.index("## Garage customisation switch-speed override")
b = text.index("\n## ", a)
before[name] = text[:a] + text[b+1:]
for name in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    before[name] = "".join(line for line in current(name).splitlines(keepends=True) if not line.startswith("2026-10-13 GCS01-GCS04/"))
for name in ["game/tests/bake_compact_kit_previews.gd", "game/tests/profile_garage_customisation.gd", "game/tests/test_garage_customisation_speed.gd", "game/tests/test_incremental_compact_kits.gd", "docs/GARAGE_CUSTOMISATION_SPEED.md"]:
    current(name)
    if (root / (name + ".uid")).exists(): current(name + ".uid")

repo.mkdir(parents=True, exist_ok=False)


def git(*args):
    return subprocess.check_output(["git", "-C", str(repo), "-c", "core.autocrlf=false", "-c", "user.name=Codex", "-c", "user.email=codex@localhost", *args], text=True, encoding="utf-8").strip()


git("init", "--quiet")
for name, content in before.items():
    target = repo / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8", newline="\n")
git("add", "--all")
git("commit", "--quiet", "-m", "Review baseline: current Garage before customisation speed work")
base = git("rev-parse", "HEAD")
for name, content in after.items():
    (repo / name).parent.mkdir(parents=True, exist_ok=True)
    (repo / name).write_text(content, encoding="utf-8", newline="\n")
assets = {}
for path in (root / "game/assets/vehicles/compact_kits_v1").rglob("*"):
    if not path.is_file(): continue
    name = str(path.relative_to(root)).replace("\\", "/")
    (repo / name).parent.mkdir(parents=True, exist_ok=True)
    (repo / name).write_bytes(path.read_bytes())
    assets[name] = hashlib.sha256(path.read_bytes()).hexdigest()
for directory in ["baseline", "final", "final-mobile"]:
    for path in (evidence / directory).glob("*"):
        name = str(path.relative_to(root)).replace("\\", "/")
        (repo / name).parent.mkdir(parents=True, exist_ok=True)
        (repo / name).write_bytes(path.read_bytes())
git("add", "--all")
git("diff", "--cached", "--check")
git("commit", "--quiet", "-m", "Remove Garage switch stalls with prepared assets, retained controls and partial kit replacement")
task = git("rev-parse", "HEAD")
patch = subprocess.check_output(["git", "-C", str(repo), "diff", "--binary", base, task])
(evidence / "task-only.patch").write_bytes(patch)
git("apply", "--reverse", "--check", str(evidence / "task-only.patch"))
ledger = {
    "requirements": ["GCS01", "GCS02", "GCS03", "GCS04", "CKT01-CKT06", "LV01-LV06", "V04-V06", "G01", "R01", "Q01"],
    "checkpoint": str(repo.relative_to(root)), "base": base, "task": task,
    "shared_branch_and_index_modified": False,
    "source_sha256": {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in after},
    "assets_sha256": assets,
    "timings": {name: json.loads((evidence / name / "timings.json").read_text()) for name in ["baseline", "final", "final-mobile"]},
    "acceptance": ["Physical phone latency/visual/frame pacing review", "No fresh APK or deployment in this task"]
}
(evidence / "delivery.json").write_text(json.dumps(ledger, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"base": base, "task": task, "source_files": len(after), "assets": len(assets), "checkpoint": str(repo)}, indent=2))
