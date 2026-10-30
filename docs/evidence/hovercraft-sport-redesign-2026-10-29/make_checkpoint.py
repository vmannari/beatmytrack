"""Build a task-only source checkpoint and evidence manifest without touching Git's index."""
from pathlib import Path
import difflib
import hashlib
import json
import shutil
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[3]
E = Path(__file__).resolve().parent

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

runtime = ["game/vehicle/hovercraft_model.gd", "game/vehicle/hovercraft_sport_surface.gd",
           "game/vehicle/hovercraft_sport_hull.gd", "game/vehicle/hovercraft_sport_drive.gd",
           "game/vehicle/car_visual.gd", "game/vehicle/livery_catalog.gd",
           "game/vehicle/vehicle_livery.gd", "game/vehicle/vehicle_weathering.gd"]
tests = ["game/tests/test_hovercraft.gd", "game/tests/review_hovercraft_sport.gd",
         "game/tests/review_hovercraft_sport_liveries.gd", "game/tests/audit_hovercraft_sport_fit.gd",
         "game/tests/bake_hovercraft_sport_surfaces.gd", "game/tests/review_hovercraft_sport_app.gd",
         "game/tests/review_hovercraft_sport_prepared.gd", "game/tests/review_hovercraft_sport_integration.gd",
         "game/tests/inspect_hovercraft_sport_templates.gd"]
sources = runtime+tests+["licenses/ASSETS.md", "game/assets/vehicles/hovercraft_sport_v3/PROVENANCE.md"]
for relative in runtime[1:4]+tests[1:]:
    uid = relative+".uid"
    if (ROOT/uid).exists(): sources.append(uid)

patch = []
rows = []
control = ROOT/"build/hovercraft-sport-review"/("patch-control-"+uuid.uuid4().hex)
assert control.resolve().is_relative_to((ROOT/"build/hovercraft-sport-review").resolve())
for relative in sources:
    path = ROOT/relative
    old_path = E/"before"/relative
    before = old_path.read_bytes() if old_path.exists() else b""
    after = path.read_bytes()
    if before:
        target = control/relative
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(before)
    patch.extend(difflib.diff_bytes(difflib.unified_diff,before.splitlines(keepends=True),after.splitlines(keepends=True),
                                   fromfile=("a/"+relative).encode() if before else b"/dev/null",tofile=("b/"+relative).encode()))
    rows.append({"path":relative,"sha256":digest(path),"before_sha256":hashlib.sha256(before).hexdigest() if before else None})
patch_path = E/"task.patch"
patch_path.write_bytes(b"".join(patch))
prefix = str(control.relative_to(ROOT)).replace("\\","/")
def git_apply(*args):
    result = subprocess.run(["git","apply",*args,"--directory="+prefix,str(patch_path)],cwd=ROOT,capture_output=True,text=True)
    if result.returncode: raise RuntimeError(result.stderr)
git_apply("--check")
git_apply()
assert all((control/r["path"]).read_bytes() == (ROOT/r["path"]).read_bytes() for r in rows)
git_apply("--check","--reverse")
git_apply("--reverse")
for row in rows:
    path = control/row["path"]
    if row["before_sha256"] is None: assert not path.exists()
    else: assert digest(path) == row["before_sha256"]
check = subprocess.run(["git","apply","--check","--reverse",str(patch_path)],cwd=ROOT,capture_output=True,text=True)
assert check.returncode == 0,check.stderr

preserved = []
for relative in ["game/vehicle/vehicle_simulation.gd","game/vehicle/handling_config.gd","game/resources/cars/hovercraft.tres",
                 "game/assets/garage/cars_v1/classic.scn","game/assets/garage/cars_v1/formula.scn"]:
    current = ROOT/relative
    old = E/"before"/relative
    preserved.append({"path":relative,"sha256":digest(current),"exact":digest(current)==digest(old)})
assert all(item["exact"] for item in preserved)

assets = list((ROOT/"game/assets/vehicles/hovercraft_sport_v3").glob("*"))
assets += list((ROOT/"game/assets/liveries/previews_v2/hovercraft").glob("*"))
for relative in ["game/assets/menu/hovercraft_illustration_v1.png","game/assets/menu/header_cars_v1/hovercraft.png",
                 "game/assets/garage/previews_v1/hovercraft.png","game/assets/news/vehicles/hovercraft.png",
                 "game/assets/vehicles/racing_simple_v1/hovercraft_shadow_0.res"]:
    path = ROOT/relative
    assets.append(path)
    imported = Path(str(path)+".import")
    if imported.exists(): assets.append(imported)
for car in ["compact","pickup","kart","forklift","electric","hovercraft"]:
    assets.append(ROOT/f"game/assets/garage/cars_v1/{car}.scn")
manifest = [{"path":p.relative_to(ROOT).as_posix(),"bytes":p.stat().st_size,"sha256":digest(p)} for p in sorted(set(assets)) if p.is_file()]
(E/"assets.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")

legacy = read_json(ROOT/"docs/evidence/hovercraft-model-rebuild-2026-10-28/assets.json")
legacy_assets = [row for row in legacy if row["path"].startswith("game/assets/vehicles/hovercraft_body_v2/")]
legacy_exact = all((ROOT/row["path"]).is_file() and digest(ROOT/row["path"])==row["sha256"] for row in legacy_assets)
surfaces = read_json(E/"surfaces.json")
signature_paths = [runtime[0],runtime[1],runtime[2],runtime[3]]
assert surfaces["sources"] == "".join(digest(ROOT/path) for path in signature_paths)
fit = read_json(E/"fit-audit-gl_compatibility.json")
assert fit["failures"] == 0
for key,value in fit["sources"].items(): assert digest(ROOT/"game"/key.removeprefix("res://")) == value

commands = E/"commands"
commands.mkdir(exist_ok=True)
for path in (ROOT/"build/hovercraft-sport-review").glob("*.ps1"): shutil.copyfile(path,commands/path.name)
report = {"requirements":["HSR01","HSR02","HSR03","HSR04","HSR05","R01","Q01"],
          "engine":"4.7.2.stable.official.ed1daf0bf","sources":rows,"source_checkpoint":{"forward_check":True,"forward_bytes_exact":True,"reverse_check":True,"reverse_bytes_exact":True,"live_reverse_check":True},
          "preserved":preserved,"previous_sport_v2":{"files":len(legacy_assets),"exact":legacy_exact},"assets_manifest":"assets.json",
          "surface_bake":surfaces,"fit_audit":fit,
          "before":read_json(E/"before-gl_compatibility/metrics.json"),
          "model":{method:read_json(E/f"after-{method}/metrics.json") for method in ["gl_compatibility","mobile"]},
          "liveries":{method:read_json(E/f"liveries-{method}/metrics.json") for method in ["gl_compatibility","mobile"]},
          "app":{method:read_json(E/f"app-{method}/native.json") for method in ["gl_compatibility","mobile"]},
          "game":{method:read_json(E/f"game/{method}/native.json") for method in ["gl_compatibility","mobile"]},
          "saved_appearance_recovery":read_json(E/"recovered/report.json"),
          "template_context":read_json(E/"template-context.json"),"targeted_checks":read_json(E/"targeted-checks.json"),
          "full_parser":{"exit_code":1,"fixture":"res://tests/fixtures/parking_hall_before/garage_page.gd:67","error":"_build_wash_requirement not found"},
          "limits":["Owner appearance and motion acceptance pending","No physical-device query or test and no Android FPS claim","No AAA certification",
                    "The first CheckScript invocation omitted ScriptPath and hit an unrelated startup error; explicit app/model checks passed",
                    "Electric's pre-task Garage scene was stale relative to current sources; its refreshed scene is a derivative of the concurrent Electric work",
                    "No APK/deployment/owner-save mutation/owner process restart/main-index staging or commit"]}
(E/"report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(f"CHECKPOINT: {len(rows)} source entries, {len(manifest)} asset entries; forward/reverse contents exact; preserved physics exact; v2 historical exact={legacy_exact}")
