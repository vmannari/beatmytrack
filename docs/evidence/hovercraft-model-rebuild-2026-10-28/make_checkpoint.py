"""Read-only Git checkpoint plus explicit task evidence; no index or owner files."""
from pathlib import Path
import difflib
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
E = Path(__file__).resolve().parent

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

runtime = ["game/vehicle/hovercraft_model.gd", "game/vehicle/hovercraft_surface.gd",
           "game/vehicle/car_visual.gd", "game/vehicle/livery_catalog.gd"]
helpers = ["game/tests/bake_hovercraft_surfaces.gd", "game/tests/review_hovercraft_model.gd",
           "game/tests/review_hovercraft_app.gd", "game/tests/review_hovercraft_prepared.gd",
           "game/tests/inspect_hovercraft_template_context.gd", "game/tests/capture_hovercraft_ufo_drive.gd"]
patch = []
sources = []
for relative in runtime + helpers:
    path = ROOT / relative
    before_path = E / "before" / relative
    after = path.read_bytes().decode("utf-8")
    before = before_path.read_bytes().decode("utf-8") if before_path.exists() else ""
    reconstructed = False
    if relative.endswith("car_visual.gd"):
        mount_after = '"hovercraft":Vector3(0.59,0.80,-1.933)'
        mount_before = '"hovercraft":Vector3(0.64,0.76,-1.72)'
        insertion = '\t\tif vehicle_id == "hovercraft":\n\t\t\tif side < 0.0: preload("res://vehicle/hovercraft_model.gd").night_lens(headlights,lens)\n\t\t\tcontinue\n'
        if insertion not in after:
            insertion = insertion.replace("\n", "\r\n")
        assert after.count(mount_after) == 1 and after.count(insertion) == 1
        before = after.replace(mount_after,mount_before,1).replace(insertion,"",1)
        reconstructed = True  # Preserve the concurrent Kart presentation changes.
    if relative.endswith("capture_hovercraft_ufo_drive.gd"):
        insertion = '\tfor argument: String in OS.get_cmdline_user_args():\n\t\tif argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")\n'
        assert after.count(insertion) == 1
        before = after.replace(insertion, "", 1)
        reconstructed = True
    patch.extend(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True),
                                     fromfile="a/"+relative if before else "/dev/null", tofile="b/"+relative))
    sources.append({"path":relative,"sha256":sha(path),"before_sha256":hashlib.sha256(before.encode()).hexdigest() if before else None,
                    "before_reconstructed_from_exact_owned_insertion_only":reconstructed})
(E / "task.patch").write_text("".join(patch), encoding="utf-8", newline="")
check = subprocess.run(["git", "apply", "--check", "--reverse", str(E/"task.patch")], cwd=ROOT, capture_output=True, text=True)
assert check.returncode == 0, check.stderr

assets = list((ROOT/"game/assets/vehicles/hovercraft_body_v2").glob("*"))
assets += list((ROOT/"game/assets/liveries/previews_v2/hovercraft").glob("*"))
for relative in ["game/assets/menu/hovercraft_illustration_v1.png", "game/assets/menu/header_cars_v1/hovercraft.png",
                 "game/assets/garage/previews_v1/hovercraft.png", "game/assets/news/vehicles/hovercraft.png",
                 "game/assets/vehicles/racing_simple_v1/hovercraft_shadow_0.res"]:
    path = ROOT/relative
    assets.append(path)
    if Path(str(path)+".import").exists(): assets.append(Path(str(path)+".import"))
for name in ["compact", "pickup", "kart", "forklift", "electric", "hovercraft"]:
    assets.append(ROOT/f"game/assets/garage/cars_v1/{name}.scn")
manifest = [{"path":str(p.relative_to(ROOT)).replace("\\","/"),"bytes":p.stat().st_size,"sha256":sha(p)} for p in sorted(set(assets)) if p.is_file()]
(E/"assets.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
preserved = []
for relative in ["game/vehicle/vehicle_simulation.gd", "game/vehicle/handling_config.gd", "game/resources/cars/hovercraft.tres",
                 "game/assets/garage/cars_v1/classic.scn", "game/assets/garage/cars_v1/formula.scn"]:
    path = ROOT/relative
    preserved.append({"path":relative,"sha256":sha(path),"exact":sha(path)==sha(E/"before"/relative)})
assert all(row["exact"] for row in preserved)

commands = E/"commands"
commands.mkdir(exist_ok=True)
for path in (ROOT/"build/hovercraft-model-review").glob("*.ps1"):
    shutil.copyfile(path, commands/path.name)
runs = E/"runs"
runs.mkdir(exist_ok=True)
for name in ["30656","9556","26796","38676","33728","37144","21144","2592","11968","21924","21668","2248","13852"]:
    path = ROOT/f"build/logs/TestScript-{name}/test-script.log"
    if path.exists(): shutil.copyfile(path,runs/f"TestScript-{name}.log")

report = {"requirements":["HMR01","HMR02","HMR03","HMR04","HMR05","R01","Q01"],
          "engine":"4.7.2.stable.official.ed1daf0bf", "runtime_sources":sources[:4], "test_helpers":sources[4:],
          "source_only_patch_reverse_check":True,"preserved":preserved,
          "artifacts_manifest":"assets.json","resources_roundtrip":json.loads((E/"surfaces.json").read_text()),
          "models":{method:json.loads((E/f"after-{method}/metrics.json").read_text()) for method in ["gl_compatibility","mobile"]},
          "actual_app":{method:json.loads((E/f"app-{method}/native.json").read_text()) for method in ["gl_compatibility","mobile"]},
          "actual_game":{method:json.loads((E/f"game/{method}/native.json").read_text()) for method in ["gl_compatibility","mobile"]},
          "prepared":json.loads((E/"prepared.json").read_text()),
          "prepared_wrong_glass_control":json.loads((E/"prepared-wrong.json").read_text()),
          "template_context":json.loads((E/"template-context.json").read_text()),
          "retained_racing_checks":{"checks":22,"failures":0},
          "broader_validation":{"raw_prepared":{"checks":24,"failures":4,"reason":"implicit shader defaults versus serialized values"},
                                "concurrent_source_guard_attempts":{"checks":24,"failures":6},
                                "full_parser":{"status":"blocked","path":"tests/fixtures/parking_hall_before/garage_page.gd:67","error":"_build_wash_requirement missing"},
                                "preferred_runtime_check":{"status":"blocked by concurrent source","path":"vehicle/electric_coachwork.gd:521","error":"theta undeclared"}},
          "limits":["Owner appearance acceptance pending", "No physical-device query/test or FPS claim", "No AAA certification",
                    "Concurrent Electric work can invalidate the broad Garage source guard", "Raw prepared fixture compares implicit uniforms against serialized defaults",
                    "No APK/deployment/owner-save mutation/owner restart/main-index staging or commit"]}
(E/"report.json").write_text(json.dumps(report,indent=2)+"\n", encoding="utf-8")
print(f"CHECKPOINT: {len(sources)} source files, {len(manifest)} asset entries, preserved hashes exact, source-only patch reverse-check passed")
