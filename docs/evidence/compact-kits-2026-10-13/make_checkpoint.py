"""Freeze only this task's diff in an isolated review repository."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = ROOT / "docs/evidence/compact-kits-2026-10-13"
REVIEW = ROOT / "build/compact-kits/checkpoint-final-repo"
BASE = EVIDENCE / "task-base"
after: dict[str, str] = {}
before: dict[str, str] = {}


def read(path: str) -> str:
    if path not in after:
        after[path] = (ROOT / path).read_text(encoding="utf-8-sig")
        before[path] = after[path]
    return before[path]


def replace(path: str, old: str, new: str = "", count: int = 1) -> None:
    text = read(path)
    if text.count(old) != count:
        raise ValueError(f"Scoped checkpoint anchor mismatch: {path}: {old[:80]!r}")
    before[path] = text.replace(old, new)


def drop_function(path: str, first: str, following: str) -> None:
    text = read(path)
    a, b = text.index(first), text.index(following)
    if b <= a:
        raise ValueError(path)
    before[path] = text[:a] + text[b:]


car = "game/vehicle/car_visual.gd"
replace(car, "var customisation: Dictionary = {}\n")
replace(car, "\tif not VehicleCustomisation.valid(customisation): customisation = VehicleCustomisation.defaults()\n")
replace(car, '''\t\t\tif CompactKits.choice(self,"rims") == "stock":
\t\t\t\tvar hub := VisualGeometry.cylinder(pivot, 0.228, 0.16, Vector3.ZERO, trim,true)
\t\t\t\thub.rotation.z = PI * 0.5
\t\t\t\tfor spoke: int in range(8):
\t\t\t\t\tvar a: float = spoke*TAU/8.0
\t\t\t\t\t_seam(pivot,Vector3(side*0.085,sin(a)*0.08,cos(a)*0.08),Vector3(side*0.148,sin(a)*0.222,cos(a)*0.222),0.032,rim)
\t\t\telse: CompactKits.build_wheel(self,pivot,side)
''', '''\t\t\tvar hub := VisualGeometry.cylinder(pivot, 0.228, 0.16, Vector3.ZERO, trim,true)
\t\t\thub.rotation.z = PI * 0.5
\t\t\tfor spoke: int in range(8):
\t\t\t\tvar a: float = spoke*TAU/8.0
\t\t\t\t_seam(pivot,Vector3(side*0.085,sin(a)*0.08,cos(a)*0.08),Vector3(side*0.148,sin(a)*0.222,cos(a)*0.222),0.032,rim)
''')
replace(car, '\t\t\tif CompactKits.choice(self,"rims") != "stock": CompactKits.build_caliper(pivot,side)\n')
replace(car, "\tCompactKits.build_aero(self)\n\tCompactKits.build_body(self)\n")
replace(car, '''\tif vehicle_id=="compact" and customisation != VehicleCustomisation.defaults():
\t\toutline = ROLL_OUTLINE.duplicate()
\t\tif customisation.body in ["rally","club"]:
\t\t\toutline.append_array([Vector2(-1.10,0.37),Vector2(1.10,0.37),Vector2(-1.10,0.85),Vector2(1.10,0.85)])
\t\tif customisation.aero!="stock":
\t\t\tvar half: float = 0.92 if customisation.aero=="wing" else 0.65
\t\t\tvar height: float = 1.89 if customisation.aero=="wing" else 1.64
\t\t\toutline.append_array([Vector2(-half,height),Vector2(half,height)])
''')
replace("game/vehicle/compact_coachwork.gd", '''\tif CompactKits.choice(car,"hood") != "stock":
\t\tCompactKits.build_hood(car,paint,accent)
\t\treturn
''')
replace("game/vehicle/compact_detail.gd", '\tif CompactKits.choice(car,"rims") != "stock": return\n')
replace("game/vehicle/racing_car_models.gd", '''\t# Baked stock shadows cannot describe fitted aero/hood/rim silhouettes.
\tif car.vehicle_id == "compact" and car.customisation != VehicleCustomisation.defaults(): return
''')
replace("game/vehicle/vehicle_weathering.gd", '''\t# Saved wash voxels retain the original compact's model-space mapping.
\t# Fitted aero must not stretch old strokes across the hood/body/rims.
\tif car.vehicle_id == "compact" and car.customisation != VehicleCustomisation.defaults():
\t\tbounds = AABB(Vector3(-1.115,0.181,-2.284),Vector3(2.23,1.412,4.5148))
''')
replace("game/persistence/local_records.gd", '''\t\telif field == "vehicle_customisation":
\t\t\tif not VehicleCustomisation.valid_collection(preferences[field]): return {}
''')
replace("game/core/game.gd", '''\tif preference_records != null:
\t\tcar.livery = VehicleLivery.for_car(preference_records.settings, vehicle_id)
\t\tcar.customisation = VehicleCustomisation.for_car(preference_records.settings, vehicle_id)
''', '\tif preference_records != null: car.livery = VehicleLivery.for_car(preference_records.settings, vehicle_id)\n')
showroom = "game/ui/car_showroom.gd"
drop_function(showroom, "func apply_customisation(", "func _prepare_car_reveal(")
replace(showroom, "var customisation: Dictionary = {}\n")
replace(showroom, "\tcar.customisation = customisation\n", count=2)
replace(showroom, "func replace_car(id: String, paint: Dictionary, wear: Dictionary, parts: Dictionary = {}) -> void:", "func replace_car(id: String, paint: Dictionary, wear: Dictionary) -> void:")
replace(showroom, "\tcustomisation = parts.duplicate(true) if VehicleCustomisation.valid(parts) else VehicleCustomisation.defaults()\n")
replace(showroom, '''func _exit_tree() -> void:
\t# Garage layout moves leave/re-enter the tree within the same call.
\t# Keep captures through that transfer; release real detachments/destruction.
\t_dispose_detached_reflections.call_deferred()

func _dispose_detached_reflections() -> void:
\tif not is_inside_tree() and reflections != null: reflections.dispose()

func _notification(what: int) -> void:
\tif what == NOTIFICATION_PREDELETE and reflections != null: reflections.dispose()
''', '''func _exit_tree() -> void:
\tif reflections != null: reflections.dispose()
''')
garage = "game/ui/garage_page.gd"
replace(garage, '''var kit_draft: Dictionary = {}
var kit_category: String = "hood"
var kit_cards: HBoxContainer
var kit_categories: Dictionary = {}
''')
replace(garage, '''\tkit_draft = VehicleCustomisation.for_car(records.settings,vehicle_id)
\tshowroom.customisation = kit_draft
''')
replace(garage, "\t\tmodel.customisation = VehicleCustomisation.for_car(records.settings,id)\n")
replace(garage, '''\tkit_draft = VehicleCustomisation.for_car(records.settings,vehicle_id)
\tshowroom.replace_car(vehicle_id,draft,wear,kit_draft)
''', "\tshowroom.replace_car(vehicle_id,draft,wear)\n")
replace(garage, '''\t\tvar parts: Dictionary = VehicleCustomisation.for_car(records.settings,id)
\t\tif model.customisation != parts: model.apply_customisation(parts)
''')
replace(garage, 'if section not in ["customise","tuning"]: tools.add_child', 'if section != "customise": tools.add_child')
replace(garage, '\telif section == "tuning":\n\t\t_build_tuning()\n')
drop_function(garage, "func _build_tuning(", "func _build_customise(")
replace("game/core/app.gd", "\tpage.finale_customisation = VehicleCustomisation.for_car(records.settings,rivalry.model.vehicle_id)\n")
replace("game/ui/weekly_rivalry_page.gd", "var finale_customisation: Dictionary = {}\n")
replace("game/ui/weekly_rivalry_page.gd", "\tceremony.customisation = finale_customisation\n")
replace("game/ui/weekly_rivalry_finale.gd", "var customisation: Dictionary = {}\n")
replace("game/ui/weekly_rivalry_finale.gd", "\tvehicle.customisation = customisation\n")
replace("game/ui/rivalry_victory_car.gd", "var customisation: Dictionary = {}\n")
replace("game/ui/rivalry_victory_car.gd", "\tcar.customisation = customisation\n")
replace("scripts/build_identity.ps1", "$fileDigest.ComputeHash([byte[]]$bytes, 0, $bytes.Length)", "$fileDigest.ComputeHash($bytes)")

# Documentation is also scoped by the unique task marker, retaining new logs.
agents = read("AGENTS.md")
start = agents.index("## Compact fitted customisation kits override")
end = agents.index("\n## ", start)
before["AGENTS.md"] = agents[:start] + agents[end + 1:]
for name in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    lines = read(name).splitlines(keepends=True)
    before[name] = "".join(line for line in lines if not line.startswith("2026-10-13 CKT01-CKT06/"))

new_files = ["game/vehicle/vehicle_customisation.gd", "game/vehicle/compact_kits.gd", "game/ui/compact_kit_thumbnail.gd", "game/tests/test_compact_kits.gd", "game/tests/test_compact_kit_geometry.gd", "game/tests/capture_compact_kits.gd", "docs/COMPACT_CUSTOMISATION_KITS.md"]
for name in new_files[:6]:
    if (ROOT / (name + ".uid")).exists(): new_files.append(name + ".uid")
for name in new_files:
    after[name] = (ROOT / name).read_text(encoding="utf-8-sig")

BASE.mkdir(exist_ok=True)
REVIEW.mkdir(parents=True, exist_ok=False)


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(REVIEW), "-c", "core.autocrlf=false", "-c", "user.name=Codex", "-c", "user.email=codex@localhost", *args], text=True, encoding="utf-8").strip()


git("init", "--quiet")
for name, content in before.items():
    destination = REVIEW / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(content, encoding="utf-8", newline="\n")
    baseline = BASE / name
    baseline.parent.mkdir(parents=True, exist_ok=True)
    baseline.write_text(content, encoding="utf-8", newline="\n")
git("add", "--", *sorted(before))
git("commit", "--quiet", "-m", "Review baseline: current shared sources before compact-kit additions")
baseline_commit = git("rev-parse", "HEAD")
for name, content in after.items():
    destination = REVIEW / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(content, encoding="utf-8", newline="\n")
selected_images = ["compatibility/tuning-1280.png", "mobile/tuning-1280.png", "close-compatibility/club-front.png", "close-compatibility/club-rear.png", "close-compatibility/club-aero.png", "close-compatibility/club-rim.png", "close-compatibility/rally-hood.png", "close-compatibility/street-hood.png", "close-mobile/club-aero.png"]
for image in selected_images:
    relative = "docs/evidence/compact-kits-2026-10-13/" + image
    destination = REVIEW / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes((ROOT / relative).read_bytes())
for relative in ["compatibility/geometry.json", "mobile/geometry.json", "close-compatibility/render-work.json", "close-mobile/render-work.json"]:
    destination = REVIEW / "docs/evidence/compact-kits-2026-10-13" / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes((EVIDENCE / relative).read_bytes())
git("add", "--all")
git("diff", "--cached", "--check")
git("commit", "--quiet", "-m", "Add fitted compact hood, aero, rim and body kits with local Garage selection")
task_commit = git("rev-parse", "HEAD")
patch = git("diff", "--binary", baseline_commit, task_commit)
(EVIDENCE / "task-only.patch").write_text(patch + "\n", encoding="utf-8", newline="\n")
prefixes = ["COMPACT_KITS:", "KIT_GEOMETRY:", "KIT_CAPTURES:", "GARAGE_CAR_TRANSITION:", "GARAGE_REFLECTIONS:", "CAR_WASH:", "DRIVING_TESTS:", "RECORD_TESTS:", "Rewind:", "RIVALRY_AWARDS:", "SCRIPT_PARSE:"]
latest_logs: dict[tuple[str, str], tuple[Path, str]] = {}
allowed_runs = {
    ("CAR_WASH:", "headless"), ("COMPACT_KITS:", "compatibility"), ("COMPACT_KITS:", "mobile"),
    ("DRIVING_TESTS:", "headless"), ("GARAGE_CAR_TRANSITION:", "compatibility"),
    ("GARAGE_REFLECTIONS:", "compatibility"), ("KIT_CAPTURES:", "compatibility"), ("KIT_CAPTURES:", "mobile"),
    ("KIT_GEOMETRY:", "headless"), ("RECORD_TESTS:", "headless"), ("Rewind:", "headless"),
    ("RIVALRY_AWARDS:", "compatibility"), ("SCRIPT_PARSE:", "headless")}
for directory in sorted((ROOT / "build/logs").iterdir(), key=lambda p: p.stat().st_mtime):
    if not directory.is_dir(): continue
    for log in directory.glob("*.log"):
        contents = log.read_text(encoding="utf-8-sig", errors="replace")
        for prefix in prefixes:
            summaries = [line for line in contents.splitlines() if line.startswith(prefix)]
            if not summaries or "0 failures" not in summaries[-1]: continue
            renderer = "mobile" if "Forward Mobile" in contents else "compatibility" if "Compatibility - Using" in contents else "headless"
            if (prefix, renderer) not in allowed_runs: continue
            latest_logs[prefix, renderer] = (log, summaries[-1])
command_receipts: list[dict[str, str]] = []
logs_folder = EVIDENCE / "commands"
logs_folder.mkdir(exist_ok=True)
for (label, renderer), (log, summary) in sorted(latest_logs.items()):
    target = logs_folder / (log.parent.name + "__" + log.name)
    target.write_bytes(log.read_bytes())
    command_receipts.append({"label": label, "renderer": renderer, "summary": summary, "log": str(target.relative_to(ROOT)), "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
ledger = {"requirements": ["CKT01", "CKT02", "CKT03", "CKT04", "CKT05", "CKT06", "V04", "V05", "V06", "G01", "R01", "Q01"], "checkpoint": str(REVIEW.relative_to(ROOT)), "baseline_commit": baseline_commit, "task_commit": task_commit, "shared_branch_and_index_modified": False, "scope": "Isolated review baseline preserves concurrent contents; the second commit contains only compact-kit additions and the necessary hash-overload fix.", "files": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sorted(after)}, "device": "Doctor: no attached phone; no kit device test/export/install", "geometry": {"checks": 2592, "failures": 0, "combinations_per_quality": 256, "quality_levels": 2, "maximum_triangles": 164398, "cached_part_meshes": 368}, "acceptance": ["Owner AAA visual review", "Physical-phone brightness/aliasing/touch", "Maximum-combination phone shadow/frame pacing/thermal performance"]}
ledger["command_receipts"] = command_receipts
ledger["initial_failures_corrected"] = ["Sandbox certificate access during import", "Launcher SHA256 overload", "Typed arrays and thumbnail pre-tree camera", "JSON version normalization", "Budget/winding/solid wing closure", "Merged livery helper required Import", "Preview reparent originally disposed reflection views"]
(EVIDENCE / "delivery.json").write_text(json.dumps(ledger, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"baseline_commit": baseline_commit, "task_commit": task_commit, "files": len(after), "checkpoint": str(REVIEW)}, indent=2))
