"""Verify recorded results and make an isolated, task-only helmet checkpoint."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

EV = Path(__file__).resolve().parent
ROOT = EV.parents[2]
BEFORE = EV / "before"
PREPARED = Path("game/assets/vehicles/kart_refined_v1")
TAG = "KART-REFERENCE-HELMET-20261025"
DOC = Path("docs/KART_REFERENCE_HELMET_2026_10_25.md")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def save(path, data):
    Path(path).write_bytes((json.dumps(data, indent=2) + "\n").encode())


def passing(folder):
    result = read(EV / folder / "report.json")
    assert result["failures"] == 0, folder
    return result


results = {key:passing(key) for key in ["model", "model-mobile", "native", "native-mobile", "retained-fixes", "art"]}
parser = re.search(r"SCRIPT_PARSE: (\d+) scripts, 0 failures", (EV / "parser.log").read_text(encoding="utf-8-sig"))
assert parser, "Parser has not passed"
parser_count = int(parser[1])
assert "49 actual model captures" in (EV / "liveries.log").read_text(encoding="utf-8-sig")
assert "NEWS PHOTO FRAMING: 1 cars, 0 failures" in (EV / "news.log").read_text(encoding="utf-8-sig")
invariants = []
concurrent_sources = []
electric_report_path = ROOT / "docs/evidence/electric-brake-release-2026-10-25/report.json"
electric_report = read(electric_report_path)
for item in read(EV / "invariants-before.json"):
    path = Path(item["Path"])
    relative = path.relative_to(ROOT).as_posix()
    if sha(path) != item["Hash"].lower():
        assert relative in ["game/vehicle/vehicle_simulation.gd","game/vehicle/handling_config.gd"], relative
        assert sha(path) == electric_report["sha256"][relative], relative
        archived = "docs/evidence/electric-brake-release-2026-10-25/before/"+relative.replace("/","__")+".txt"
        assert item["Hash"].lower() == electric_report["sha256"][archived], relative
        concurrent_sources.append({"path":relative,"task_start_sha256":item["Hash"].lower(),"current_sha256":sha(path),"separate_task":"docs/evidence/electric-brake-release-2026-10-25/report.json","excluded_from_helmet_checkpoint":True})
    else: invariants.append({"path":relative, "sha256":sha(path), "unchanged":True})
for log in ["handling.log","replay.log"]:
    assert "0 failures" in (EV / log).read_text(encoding="utf-8-sig")
assert sha(BEFORE / "bake_kart_model.gd") == sha(ROOT / "game/tests/bake_kart_model.gd")
manifest = read(ROOT / PREPARED / "manifest.json")
old = read(BEFORE / "meshes/manifest.json")
for field, path in [("model_sha256", "kart_model.gd"), ("helmet_sha256", "kart_helmet.gd"), ("geometry_sha256", "kart_geometry.gd")]:
    assert manifest[field] == sha(ROOT / "game/vehicle" / path)
current_files = {entry["file"] for entry in manifest["meshes"]}
old_files = {entry["file"] for entry in old["meshes"]}
assert current_files == {path.name for path in (ROOT / PREPARED).glob("*.res")}
identical = [name for name in current_files & old_files if sha(BEFORE / "meshes" / name) == sha(ROOT / PREPARED / name)]
assert len(identical) == 196
for i in range(1,5):
    assert sha(BEFORE / f"kart_shadow_{i}.res") == sha(ROOT / f"game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res")
photos = sorted((ROOT / "game/assets/liveries/previews_v2/kart").glob("*.png"))
assert len(photos) == 49 and all(sha(path) != sha(BEFORE / "liveries" / path.name) for path in photos)


def strip_task(raw):
    return re.sub(rb"(?ms)^<!-- " + TAG.encode() + rb" -->\r?\n.*?^<!-- /" + TAG.encode() + rb" -->\r?\n(?:\r?\n)?", b"", raw)


def add_block(relative, text, append=False):
    path = ROOT / relative
    raw = strip_task(path.read_bytes())
    newline = b"\r\n" if b"\r\n" in raw else b"\n"
    block = (f"<!-- {TAG} -->\n{text.strip()}\n<!-- /{TAG} -->\n\n").encode().replace(b"\n",newline)
    path.write_bytes(raw+newline+block if append else block+raw)


summary = (
    "## Kart helmet reference-shape correction (2026-10-25)\n"
    "KHR01-KHR03/V02-V05/R01/G01/Q01: Owner's white full-face helmet reference replaces the "
    "previous silhouette with a round crown, continuous sculpted chin/jaw, rising rear neck edge, "
    "larger swept eye aperture, fitted smoked visor/gasket, paired pivots with recessed flat links "
    "and restrained intakes/lining. Original unbranded geometry; no reference bitmap or logo ships. "
    "Native model81Compatibility/81desktopMobile, retained kart172 and actual Garage/race14/14 "
    f"plus parser{parser_count}/import pass. Initial large carrier/vent lips and link/screw overlaps "
    "are retained in review captures and corrected. Full/simple93888/28562 triangles stay within "
    "the unchanged budget. New32 helmet meshes replace22; other196 binaries and exact kart/driver, "
    "kart-config/camera sources remain. Concurrent EV shared-physics updates are preserved and "
    "excluded, with their exact recorded hashes; kart handling32/replay107 pass on the current sources. "
    "Body shadow and catalogue/news/all49 photos refreshed. "
    "Evidence, commands, hashes and task-only Git-checked checkpoint: docs/KART_REFERENCE_HELMET_2026_10_25.md "
    "and docs/evidence/kart-reference-helmet-2026-10-25/report.json. Reload and owner/device appearance, "
    "motion/cost acceptance remain. No device attachment check/test, APK, live mutation, purchase, "
    "deployment or owner-process restart; concurrent work preserved."
)
shared = [Path(p) for p in ["AGENTS.md","DEVELOPMENT_STATUS.md","docs/PHASE_0_PLAN.md","licenses/ASSETS.md"]]
for path in shared[:3]: add_block(path,summary)
add_block(shared[3], """## Original reference-shaped kart helmet, 2026-10-25

The owner supplied a white full-face helmet photograph as a shape reference. `game/vehicle/kart_helmet.gd` is original authored geometry following its rounded crown, swept jaw/neck opening and visor arrangement. No source photograph, manufacturer logo or branded asset is included in the game. The 32 new native helmet resources replace 22 earlier resources; all 196 other prepared mesh files remain identical. Current catalogue/news and all 49 livery images are native photographs of the original model. Source hashes, review captures and acceptance limits are in `docs/KART_REFERENCE_HELMET_2026_10_25.md` and `docs/evidence/kart-reference-helmet-2026-10-25/report.json`.""",append=True)

doc = f"""# Kart helmet reference shape - 2026-10-25

The owner supplies a white full-face racing helmet photograph and asks to fix the kart driver's helmet to that shape. KHR01-KHR03 / V02-V05 / R01 / G01 / Q01 supersede the prior helmet's silhouette. This is original code-authored geometry; the reference photograph and manufacturer logo are not production assets.

`game/vehicle/kart_helmet.gd` now builds a rounder crown with a shorter rear volume, integrated forward chin/jaw and a lower edge rising from front to rear. The front edge stays rounded across the chin. A deeper swept eye aperture has returned rubber edges, a fitted smoked visor/seal and a quiet brow. Two pivots per side use recessed, closed flat links and clean metal screw faces. Small crown intakes, rear extractors, a single front intake, cheek vent rings and a lining return finish the shell. The visor uses the existing opaque material approach; no transparency pass, runtime callback, extra light, external model or image service is added.

The owner reference's important shape relationships are the round cranium, front chin lower than the rear neck, eye-port lower corners rising toward the temples, and close-fitting visor hardware. It is a visual reference, not a measured scan. The original driver pose, collar, suit, kart chassis/bodywork, tyre/engine clearances, exhaust, wheel/steering geometry, lights, kart configuration and production cameras retain their exact task-start sources. A concurrent electric brake-release task changed the shared simulation and handling declarations. Both before/current hashes match its separate evidence report exactly; those sources are preserved and excluded from this helmet checkpoint. The current workspace also passes kart handling32/replay107, including three five-lap runs, after this concurrent change. The initial all-source equality audit correctly rejected the changed shared sources; it was replaced with explicit unchanged kart-asset checks and exact attribution of these two concurrent files.

The model test retains every earlier threshold/assertion. Its helmet node lookup follows the new shell name. New checks inspect the actual shell vertices for at least 0.07 model metres of chin-to-rear rise and cast nine rays through the eye port; the original aperture/chin rays remain. A diagnostic three-quarter helmet camera is added without changing production cameras. Both native detail levels use the same profile and hardware arrangement.

There are **228 prepared meshes**: 32 new helmet resources replace 22 previous ones; **196 other resource binaries are identical**. The original cache and retired resources are archived in `before/meshes/` and `retired-meshes/`. Detailed/simple visible triangles are **93,888/28,562**, below the unchanged 95,000 detailed limit. The matching body shadow has {manifest['shadows'][0]['triangles']} triangles; all four wheel shadow binaries remain identical. Catalogue/newspaper and all 49 livery photographs were refreshed and imported. The import log retains the existing Android build-tools directory warning.

Native review images:

- [Before front](evidence/kart-reference-helmet-2026-10-25/before-model/full-helmet-front.png), [before side](evidence/kart-reference-helmet-2026-10-25/before-model/full-helmet-side.png).
- [New three-quarter view](evidence/kart-reference-helmet-2026-10-25/model/full-helmet-reference.png), [front](evidence/kart-reference-helmet-2026-10-25/model/full-helmet-front.png), [side](evidence/kart-reference-helmet-2026-10-25/model/full-helmet-side.png), [seated driver](evidence/kart-reference-helmet-2026-10-25/model/full-driver.png).
- [Simpler three-quarter](evidence/kart-reference-helmet-2026-10-25/model/simple-helmet-reference.png), [desktop Mobile side](evidence/kart-reference-helmet-2026-10-25/model-mobile/simple-helmet-side.png), [actual Garage](evidence/kart-reference-helmet-2026-10-25/native/garage-1280.png), [actual race](evidence/kart-reference-helmet-2026-10-25/native/race.png).

The old model has 20 successful baseline capture checks. The first authored version passes 73 geometry/capture checks, but visual inspection finds oversized carrier patches and crown lips; `first-shape/` preserves those. The refined profile passes 79 checks, while close-ups reveal a linkage crossing screw faces. Closed, recessed flat links replace the round linkage and correct that overlap before the final bake. The final model passes **81 checks per desktop renderer**. Retained tyre/engine/exhaust/sleeve/stripe regression passes **172 checks**, and actual Garage/race integration passes **14 per renderer**. Catalogue save and newspaper framing pass, with 49 current livery captures. The full-project parser passes **{parser_count} scripts**. No assertion or budget is relaxed. An initial PowerShell hash-pipeline binding error was corrected before recording the unchanged-source manifest; an invalid combined patch operation was rejected before any file mutation.

Commands use pinned Godot 4.7.2 through `scripts/dev.ps1`, disposable `build/kart-refinement` APPDATA/LOCALAPPDATA and fixture records. Native Windows tests use approved certificate-store access. Final commands:

```powershell
./scripts/dev.ps1 TestScript -ScriptPath res://tests/bake_kart_model.gd
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/kart-reference-helmet-2026-10-25/model')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--evidence-root=res://../docs/evidence/kart-reference-helmet-2026-10-25/model-mobile')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model_fixes.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/kart-reference-helmet-2026-10-25/retained-fixes')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--bake-art','--evidence-root=res://../docs/evidence/kart-reference-helmet-2026-10-25/art')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--vehicle=kart')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/bake_news_car_photos.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--vehicle=kart','--evidence-root=res://../docs/evidence/kart-reference-helmet-2026-10-25/news')
./scripts/dev.ps1 Import
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/kart-reference-helmet-2026-10-25/native')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--evidence-root=res://../docs/evidence/kart-reference-helmet-2026-10-25/native-mobile')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd
./scripts/dev.ps1 TestKart
```

Measurements, logs, source/asset hashes and the isolated task-only checkpoint are in [report.json](evidence/kart-reference-helmet-2026-10-25/report.json). The checkpoint uses the exact task-start helmet/assets and current shared documents with only this task block removed. Its binary patch passes staged whitespace and reverse-application checks; the normal index/branch remain untouched. Concurrent work is preserved.

Client reload and owner visual acceptance remain. Desktop Mobile/Vulkan is not a physical-device test or AAA certification. Logged desktop startup hitches remain recorded, with phone motion/frame-pacing/cost acceptance outstanding. No device attachment check/test, APK, real authentication/purchase, live backend mutation/deployment or owner-process restart was performed.
"""
(ROOT / DOC).write_bytes(doc.encode())

files = [Path("game/vehicle/kart_helmet.gd"),Path("game/tests/test_kart_model.gd"),DOC,*shared,PREPARED / "manifest.json"]
files += [path.relative_to(ROOT) for path in sorted((ROOT / PREPARED).glob("*.res"))]
files += [path.relative_to(ROOT) for path in photos]
files += [Path("game/assets/menu/kart_illustration_v1.png"),Path("game/assets/news/vehicles/kart.png")]
files += [Path(f"game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res") for i in range(5)]
save(EV / "source-asset-hashes.json",{path.as_posix():sha(ROOT / path) for path in files})
checkpoint = ROOT / "build/kart-reference-helmet/checkpoint"
assert not checkpoint.exists()
checkpoint.mkdir(parents=True)
index_hash = sha(ROOT / ".git/index")
env = {key:value for key,value in os.environ.items() if key not in ["GIT_DIR","GIT_WORK_TREE","GIT_INDEX_FILE"]}


def git(*args):
    return subprocess.run(["git","-c","core.autocrlf=false","-c","user.name=Codex","-c","user.email=codex@local.invalid","-C",str(checkpoint),*args],env=env,check=True,capture_output=True,text=True).stdout.strip()


def copy(source, relative):
    target = checkpoint / relative
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,target)


git("init","--quiet")
for name, relative in [("kart_helmet.gd","game/vehicle/kart_helmet.gd"),("test_kart_model.gd","game/tests/test_kart_model.gd"),("kart_illustration_v1.png","game/assets/menu/kart_illustration_v1.png"),("kart.png","game/assets/news/vehicles/kart.png")]: copy(BEFORE / name,Path(relative))
for path in (BEFORE / "meshes").iterdir(): copy(path,PREPARED / path.name)
for path in (BEFORE / "liveries").glob("*.png"): copy(path,Path("game/assets/liveries/previews_v2/kart") / path.name)
for i in range(5): copy(BEFORE / f"kart_shadow_{i}.res",Path(f"game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res"))
for path in shared:
    (checkpoint / path).parent.mkdir(parents=True,exist_ok=True)
    (checkpoint / path).write_bytes(strip_task((ROOT / path).read_bytes()))
git("add","--all")
git("commit","--quiet","-m","Task-start helmet and current shared-document baseline")
base = git("rev-parse","HEAD")
for path in (checkpoint / PREPARED).glob("*.res"):
    if path.name not in current_files:
        assert path.resolve().parent == (checkpoint / PREPARED).resolve()
        path.unlink()
for path in files: copy(ROOT / path,path)
git("add","--all")
git("diff","--cached","--check")
git("commit","--quiet","-m","Reshape kart helmet to owner reference and refresh native art")
commit = git("rev-parse","HEAD")
git("diff","--binary","--output="+str(EV / "task.patch"),"HEAD~1","HEAD")
git("apply","--reverse","--check",str(EV / "task.patch"))
assert not git("status","--porcelain")
assert index_hash == sha(ROOT / ".git/index")
(EV / "checkpoint-stat.txt").write_bytes((git("show","--stat","--oneline","HEAD")+"\n").encode())
report = {
    "date":"2026-10-25","requirements":["KHR01","KHR02","KHR03","V02","V03","V04","V05","R01","G01","Q01"],
    "reference":"Owner-supplied white full-face helmet photograph in this conversation, used for generic silhouette and fitting arrangement; no source image or manufacturer logo ships.",
    "design":"Round crown, continuous lowered chin and rising neck edge, deeper swept eye port, fitted smoked visor, paired pivots and closed recessed links, small intake/extractor and lining details.",
    "results":results,"parser":{"scripts":parser_count,"failures":0},"before":read(EV / "before-model/report.json"),
    "prepared":{"resources":len(current_files),"byte_identical":len(identical),"retired":sorted(old_files-current_files),"new":sorted(current_files-old_files),"bytes":sum((ROOT / PREPARED / name).stat().st_size for name in current_files),"shadows":manifest["shadows"],"wheel_shadow_binaries_unchanged":True,"source_manifest_matches":True},
    "unchanged_invariants":invariants,"concurrent_shared_sources":concurrent_sources,"hashes":"source-asset-hashes.json",
    "current_kart_handling":{"checks":32,"failures":0,"log":"handling.log"},"current_kart_replay":{"checks":107,"failures":0,"log":"replay.log","five_lap_tracks":["arto4","hiekka","ovaali3"]},
    "art":{"livery_photos":49,"all49_hashes_changed":True,"news":read(EV / "news/framing.json"),"import_log":"import.log"},
    "observed_desktop_startup_hitch_ms":{key:[float(n) for n in re.findall(r"RACE_HITCH frame_ms=([0-9.]+)",(EV / (key+".log")).read_text(encoding="utf-8-sig"))] for key in ["native","native-mobile"]},
    "initial_review_retained":["first-shape/","refined-shape/"],"initial_corrections":"Oversized carrier patches and raised vent lips, then linkage/screw overlap, corrected through native review. Initial PowerShell hash-pipeline and rejected combined-patch errors corrected without weakening tests.",
    "commands":"docs/KART_REFERENCE_HELMET_2026_10_25.md; native logs saved beside report",
    "checkpoint":{"repository":str(checkpoint),"base":base,"commit":commit,"patch":"task.patch","sha256":sha(EV / "task.patch"),"git_diff_cached_check":"passed","git_apply_reverse_check":"passed","normal_branch_and_index":"untouched; index hash unchanged during checkpoint construction"},
    "remaining_acceptance":["Client reload","Owner reference-shape appearance review","Physical-device motion/frame-pacing/cost acceptance"],
    "not_performed":["device attachment check or test","APK","real authentication/purchase","live backend mutation/deployment","owner-process restart","AAA certification"]
}
save(EV / "report.json",report)
print(json.dumps({"checkpoint":commit,"model_checks":[results["model"]["checks"],results["model-mobile"]["checks"]],"native_checks":[results["native"]["checks"],results["native-mobile"]["checks"]],"retained_checks":results["retained-fixes"]["checks"],"parser":parser_count,"prepared":len(current_files),"unchanged":len(identical)},indent=2))
