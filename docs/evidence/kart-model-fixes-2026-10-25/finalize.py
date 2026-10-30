"""Record verified kart evidence and a task-only checkpoint; leave the main index alone."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
EV = Path(__file__).resolve().parent
BEFORE = EV / "before"
TAG = "KART-MODEL-FIXES-20261025"
PREPARED = Path("game/assets/vehicles/kart_refined_v1")
DOC = Path("docs/KART_MODEL_FIXES_2026_10_25.md")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def save(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def passing(folder):
    result = read(EV / folder / "report.json")
    assert result["failures"] == 0, folder
    return result


def without_task(raw):
    return re.sub(
        rb"(?ms)^<!-- " + TAG.encode() + rb" -->\r?\n.*?^<!-- /"
        + TAG.encode() + rb" -->\r?\n(?:\r?\n)?", b"", raw
    )


def task_block(path, text, append=False):
    raw = without_task(path.read_bytes())
    newline = b"\r\n" if b"\r\n" in raw else b"\n"
    block = (f"<!-- {TAG} -->\n{text.strip()}\n<!-- /{TAG} -->\n\n").encode()
    block = block.replace(b"\n", newline)
    path.write_bytes(raw + newline + block if append else block + raw)


focused = passing("verified")
focused_mobile = passing("verified-mobile")
model = passing("model-final")
model_mobile = passing("model-final-mobile")
native = passing("native")
native_mobile = passing("native-mobile")
art = passing("art")
parser_log = (EV / "parser.log").read_text(encoding="utf-8-sig")
parsed = re.search(r"SCRIPT_PARSE: (\d+) scripts, 0 failures", parser_log)
assert parsed, "Final full-project parser has not passed"
parser_count = int(parsed[1])
handling_log = (EV / "handling.log").read_text(encoding="utf-8-sig")
replay_log = (EV / "replay.log").read_text(encoding="utf-8-sig")
assert "0 failures" in handling_log and "0 failures" in replay_log
assert "LIVERY_PREVIEWS: kart 49 actual model captures" in (EV / "liveries.log").read_text(encoding="utf-8-sig")
assert "NEWS PHOTO FRAMING: 1 cars, 0 failures" in (EV / "news.log").read_text(encoding="utf-8-sig")
news = read(EV / "news/framing.json")
manifest = read(ROOT / PREPARED / "manifest.json")
old_manifest = read(BEFORE / "meshes/manifest.json")
assert manifest["model_sha256"] == sha(ROOT / "game/vehicle/kart_model.gd")
assert manifest["geometry_sha256"] == sha(ROOT / "game/vehicle/kart_geometry.gd")
assert manifest["helmet_sha256"] == sha(ROOT / "game/vehicle/kart_helmet.gd")
current_files = {entry["file"] for entry in manifest["meshes"]}
old_files = {entry["file"] for entry in old_manifest["meshes"]}
assert current_files == {p.name for p in (ROOT / PREPARED).glob("*.res")}
identical = [name for name in sorted(current_files & old_files)
             if sha(BEFORE / "meshes" / name) == sha(ROOT / PREPARED / name)]
invariants = []
for item in read(EV / "invariants-before.json"):
    path = Path(item["Path"])
    actual = sha(path)
    assert actual == item["Hash"].lower(), str(path)
    invariants.append({"path":path.relative_to(ROOT).as_posix(), "sha256":actual, "unchanged":True})
assert sha(BEFORE / "test_kart_model.gd") == sha(ROOT / "game/tests/test_kart_model.gd")
assert sha(BEFORE / "bake_kart_model.gd") == sha(ROOT / "game/tests/bake_kart_model.gd")
photos = sorted((ROOT / "game/assets/liveries/previews_v2/kart").glob("*.png"))
assert len(photos) == 49
assert all(sha(p) != sha(BEFORE / "liveries" / p.name) for p in photos)
for i in range(1, 5):
    assert sha(BEFORE / f"kart_shadow_{i}.res") == sha(ROOT / f"game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res")

summary = (
    "KMF01-KMF04/V02-V05/R01/G01/Q01: Fix the reviewed kart's front tyre/nose "
    "intersections, narrow and move the engine base/case/fins inboard, fit both exhaust "
    "bands to the tapered chamber and replace buried sleeve piping with continuous "
    "surface strips. A body-tilt crossmember contact and simple-model stripe clipping "
    "found during verification are corrected. Native focused172/172 and retained "
    "model75/75 Compatibility/desktopMobile, actual Garage/race14/14, handling32/replay107 "
    f"and parser{parser_count} pass; catalogue/news/all49 photos refreshed and imported. "
    "Full/simple88272/26378 triangles, 218 prepared meshes, 188 byte-identical; exact "
    "helmet/physics/config/camera sources retained. Baseline164checks/82fail and initial "
    "fixture/geometry failures remain recorded. Commands, native before/after, hashes "
    "and scoped Git-checked checkpoint: docs/KART_MODEL_FIXES_2026_10_25.md and "
    "docs/evidence/kart-model-fixes-2026-10-25/report.json. Reload and owner/device "
    "appearance/motion/cost acceptance remain. No device attachment check/test, APK, "
    "live mutation, purchase, deployment or owner-process restart; concurrent work preserved."
)
for shared in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    task_block(ROOT / shared, "## Kart model review fixes (2026-10-25)\n" + summary)
task_block(ROOT / "licenses/ASSETS.md", """## Original kart construction fixes, 2026-10-25

The kart's corrected nose, engine packaging, exhaust bands, suit trim and fitted fairing stripes are original code-authored geometry in `game/vehicle/kart_model.gd`. Its 218 native prepared meshes, body shadow, catalogue/newspaper images and 49 livery photographs have been refreshed; 188 mesh files and the helmet source remain byte-identical. No third-party model, image-generation service, manufacturer asset or new external dependency is used. The preceding provenance remains historical; current sources, native review and acceptance limits are recorded in `docs/KART_MODEL_FIXES_2026_10_25.md` and `docs/evidence/kart-model-fixes-2026-10-25/report.json`.""", append=True)

doc = f"""# Kart model review fixes - 2026-10-25

The owner requests fixes to the four findings in the preceding kart review. This changes the kart's presentation geometry and its native photographs. Driving, collisions, wheel locations, helmet design and production camera retain their exact task-start sources.

| Requirement | Correction and evidence |
| --- | --- |
| KMF01 / V02-V05 | Move the broad nose and rolled underside ahead of the front tyres' complete steering envelope; reconnect the narrow central fairing. The conservative longitudinal gap is 0.055148 model metres. Sample all body vertices against the solid rubber volumes at 25 steering angles from -0.6 to +0.6 radians in each detail level. Another 12 combinations per detail level cover pitch +/-0.03 and roll +/-0.036 radians. A small front crossmember end contact exposed by these additional poses is removed by shortening its ends by 0.03 model metres. |
| KMF02 | Narrow the engine plate from 0.39 to 0.30 model metres and shift the case, cylinder/fins/head and attached fittings inward by 0.025 model metres. Plate clearance improves from -0.021773 to +0.028227 model metres. The stricter scan also fixes the small case and lowest-fin contacts omitted by the original review's 2 mm reporting threshold. |
| KMF03 | Derive each retaining band's radius from the same tapered chamber profile. Move each chassis stay's upper end to the fitted band. More circumference segments keep the racing detail fitted too. Actual triangle rays at 16 angles per band verify an inner-band/chamber gap between -0.004 and +0.003 model metres; the old band floated up to 0.01364 metres. |
| KMF04 | Replace the buried tubes with narrow, tapered strips projected onto the outer union of the sleeve surfaces. Actual mesh rays verify cloth backing with no missing samples or buried points, in both detail levels. The retained capsule arms, pose, gloves, helmet and continuous trouser legs are unchanged. |
| R01 / G01 / Q01 | Keep the existing 75-check model suite unchanged, test the actual Garage/race views in both desktop renderers, retain source invariants, refresh all native photos and record the task-only checkpoint. |

The final visual review also found the simpler fairing's stripe clipping into its coarser triangles. Both central stripes now use clipped copies of the actual upper fairing triangles, lifted 0.0015 model metres. Native ray checks cover every stripe triangle's centre; the stripes remain continuously above their supporting surfaces. All new surface projection/clipping happens during mesh creation/baking, with immutable prepared resources used by production. No new frame callback, shader, material role, light or transparent pass is introduced.

There are **218 prepared resources**, of which **{len(identical)} are byte-identical** to the task-start cache. Thirty old keys retire and thirty new keys replace them. The complete original cache remains in `before/meshes/`; retired and intermediate resources remain in evidence. The matching body shadow is rebuilt; all four wheel shadow binaries remain identical. Visible full/simple triangles are **{model['triangles']['full']:,}/{model['triangles']['simple']:,}**, below the unchanged 95,000 detailed limit. The simple model additionally uses {sum(s['triangles'] for s in manifest['shadows']):,} shadow-only triangles. All 49 livery images, the catalogue image and newspaper photo are current native renders, imported successfully. The existing Android build-tools directory warning remains in the import log.

Matched native views:

- [Before: front steering](evidence/kart-model-fixes-2026-10-25/baseline-final-fixture/full-steering-0.0.png) and [fixed: centered](evidence/kart-model-fixes-2026-10-25/verified/full-steering-0.0.png), [left limit](evidence/kart-model-fixes-2026-10-25/verified/full-steering--0.6.png), [right limit](evidence/kart-model-fixes-2026-10-25/verified/full-steering-0.6.png).
- [Before: engine](evidence/kart-model-fixes-2026-10-25/baseline-final-fixture/full-engine.png) and [fixed engine/exhaust](evidence/kart-model-fixes-2026-10-25/verified/full-engine.png).
- [Before: sleeve trim](evidence/kart-model-fixes-2026-10-25/baseline-final-fixture/full-controls.png), [fixed full driver](evidence/kart-model-fixes-2026-10-25/verified/full-controls.png), and [simpler driver/stripe](evidence/kart-model-fixes-2026-10-25/verified/simple-controls.png).
- [Actual Garage](evidence/kart-model-fixes-2026-10-25/native/garage-1280.png) and [actual race](evidence/kart-model-fixes-2026-10-25/native/race.png). Desktop Vulkan Mobile counterparts are in `native-mobile/`, `verified-mobile/` and `model-final-mobile/`.

The final focused suite passes **172 checks in each renderer**; the retained model suite passes **75 in each**. Actual Garage/race integration passes **{native['checks']}/{native_mobile['checks']}**, with catalogue save **{art['checks']}**, all 49 livery captures and one correctly framed newspaper photograph. Kart handling/replay pass; the full-project parser passes **{parser_count} scripts**. The original and stricter source invariants all agree with task-start SHA-256 values. No existing assertion or threshold is weakened.

The final regression run against the exact backed-up old source records **164 checks / 82 failures**. Early fixture failures (duplicate Godot node names and too few sampled simple-sleeve vertices), the first tighter engine-fin scan, initial coarse clamp fit and the added crossmember body-tilt failure are retained with logs and images. The stripe issue was found by visual inspection after the mechanical checks passed; its before-image remains in `final/simple-controls.png`. The final test adds eight whole-stripe checks to the earlier 164-check regression.

Pinned Godot 4.7.2 is invoked through `scripts/dev.ps1`; APPDATA/LOCALAPPDATA and records are isolated under `build/kart-refinement`. Native Windows runs use approved certificate-store access. The substantive commands are:

```powershell
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model_fixes.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/verified')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/bake_kart_model.gd
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/model-final')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model_fixes.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/verified-mobile')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_model.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/model-final-mobile')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--bake-art','--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/art')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--vehicle=kart')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/bake_news_car_photos.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--vehicle=kart','--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/news')
./scripts/dev.ps1 Import
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/native')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--evidence-root=res://../docs/evidence/kart-model-fixes-2026-10-25/native-mobile')
./scripts/dev.ps1 TestKart
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd
```

Exact measurements, logs, source/asset hashes and the scoped checkpoint are in [report.json](evidence/kart-model-fixes-2026-10-25/report.json). The checkpoint has an isolated base of task-start kart assets and current shared documents with only this task's block removed; it excludes concurrent changes and leaves the normal branch/index alone. Its binary patch passes `git diff --cached --check` and `git apply --reverse --check` in the isolated repository.

Client reload and owner appearance review remain. Desktop renderer checks do not constitute physical-device motion/frame-pacing/cost acceptance or AAA certification. Logged desktop startup hitches are retained. No device attachment check/test, APK build/install, real authentication/purchase, live backend mutation/deployment or owner-process restart was performed.
"""
(ROOT / DOC).write_bytes(doc.encode("utf-8"))

shared_paths = [Path(p) for p in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md", "licenses/ASSETS.md"]]
final_paths = [Path("game/vehicle/kart_model.gd"), Path("game/tests/test_kart_model_fixes.gd"),
               Path("game/tests/test_kart_model_fixes.gd.uid"), DOC, *shared_paths]
final_paths += [p.relative_to(ROOT) for p in sorted((ROOT / PREPARED).glob("*.res"))]
final_paths += [PREPARED / "manifest.json"]
final_paths += [Path(f"game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res") for i in range(5)]
final_paths += [p.relative_to(ROOT) for p in photos]
final_paths += [Path("game/assets/menu/kart_illustration_v1.png"), Path("game/assets/news/vehicles/kart.png")]
save(EV / "source-asset-hashes.json", {p.as_posix():sha(ROOT / p) for p in final_paths})

checkpoint = ROOT / "build/kart-model-fixes/checkpoint-final"
assert not checkpoint.exists(), "Keep existing checkpoints; choose a fresh location"
checkpoint.mkdir(parents=True)
index_before = sha(ROOT / ".git/index")
env = dict(os.environ)
for key in ["GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"]:
    env.pop(key, None)


def git(*args):
    return subprocess.run(["git", "-c", "core.autocrlf=false", "-c", "user.name=Codex",
                           "-c", "user.email=codex@local.invalid", "-C", str(checkpoint), *args],
                          env=env, check=True, capture_output=True, text=True).stdout.strip()


def copy(source, relative):
    destination = checkpoint / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)


git("init", "--quiet")
copy(BEFORE / "kart_model.gd", Path("game/vehicle/kart_model.gd"))
for file in (BEFORE / "meshes").iterdir():
    copy(file, PREPARED / file.name)
for file in (BEFORE / "liveries").glob("*.png"):
    copy(file, Path("game/assets/liveries/previews_v2/kart") / file.name)
for i in range(5):
    copy(BEFORE / f"kart_shadow_{i}.res", Path(f"game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res"))
copy(BEFORE / "kart_illustration_v1.png", Path("game/assets/menu/kart_illustration_v1.png"))
copy(BEFORE / "kart.png", Path("game/assets/news/vehicles/kart.png"))
for path in shared_paths:
    (checkpoint / path).parent.mkdir(parents=True, exist_ok=True)
    (checkpoint / path).write_bytes(without_task((ROOT / path).read_bytes()))
git("add", "--all")
git("commit", "--quiet", "-m", "Task-start kart and current shared-document baseline")
base_commit = git("rev-parse", "HEAD")
for file in (checkpoint / PREPARED).glob("*.res"):
    if file.name not in current_files:
        assert file.resolve().parent == (checkpoint / PREPARED).resolve()
        file.unlink()
for path in final_paths:
    copy(ROOT / path, path)
git("add", "--all")
git("diff", "--cached", "--check")
git("commit", "--quiet", "-m", "Fix reviewed kart clearances, clamps, suit trim and fairing stripes")
commit = git("rev-parse", "HEAD")
git("diff", "--binary", "--output=" + str(EV / "task.patch"), "HEAD~1", "HEAD")
git("apply", "--reverse", "--check", str(EV / "task.patch"))
assert not git("status", "--porcelain")
assert index_before == sha(ROOT / ".git/index"), "Normal index changed concurrently"
(EV / "checkpoint-stat.txt").write_text(git("show", "--stat", "--oneline", "HEAD") + "\n", encoding="utf-8")

report = {
    "date":"2026-10-25", "requirements":["KMF01","KMF02","KMF03","KMF04","V02","V03","V04","V05","R01","G01","Q01"],
    "focused_compatibility":focused, "focused_desktop_mobile":focused_mobile,
    "model_compatibility":model, "model_desktop_mobile":model_mobile,
    "actual_garage_race_compatibility":native, "actual_garage_race_desktop_mobile":native_mobile,
    "baseline_final_fixture":read(EV / "baseline-final-fixture/report.json"),
    "parser":{"scripts":parser_count,"failures":0,"log":"parser.log"},
    "handling":{"checks":32,"failures":0,"log":"handling.log"},
    "replay":{"checks":107,"failures":0,"log":"replay.log","five_lap_tracks":["arto4","hiekka","ovaali3"],"contacts":0},
    "art":{"catalogue":art,"livery_photos":49,"all49_hashes_changed":True,"news":news,"import_log":"import.log"},
    "prepared":{"resources":len(current_files),"byte_identical":len(identical),"retired_keys":sorted(old_files-current_files),
                "new_keys":sorted(current_files-old_files),"bytes":sum((ROOT / PREPARED / p).stat().st_size for p in current_files),
                "shadows":manifest["shadows"],"wheel_shadow_binaries_unchanged":True,"source_manifest_matches":True},
    "unchanged_invariants":invariants,
    "existing_model_tests_and_bake_unchanged":True,
    "observed_desktop_startup_hitch_ms":{
        name:[float(value) for value in re.findall(r"RACE_HITCH frame_ms=([0-9.]+)", (EV / log).read_text(encoding="utf-8-sig"))]
        for name,log in [("compatibility","native.log"),("mobile","native-mobile.log")]
    },
    "hashes":"source-asset-hashes.json",
    "initial_results_retained":["initial-fixture/","baseline/","baseline-final-fixture/","authored/","authored-tilt/","final/","final-fitted-inlays/"],
    "initial_checkpoint_check":"The first isolated checkpoint rejected CRLF in the new document as trailing whitespace. The document now uses LF, with the initial check retained in checkpoint-initial-whitespace.log and build/kart-model-fixes/checkpoint.",
    "visual_review":"Viewed native front at centered/maximum steering, detailed/simple sleeve close-ups, engine/exhaust, rear, actual Garage/race and desktop Mobile views. Fixed the simple fairing stripe artifact found in final/simple-controls.png.",
    "commands":"docs/KART_MODEL_FIXES_2026_10_25.md; all substantive native logs retained beside this report",
    "checkpoint":{"repository":str(checkpoint),"base_commit":base_commit,"commit":commit,"patch":"task.patch",
                  "patch_sha256":sha(EV / "task.patch"),"git_diff_cached_check":"passed","git_apply_reverse_check":"passed",
                  "normal_branch_and_index":"untouched; index hash identical across checkpoint construction"},
    "remaining_acceptance":["Client reload","Owner appearance review","Physical-device motion, frame-pacing and rendering cost acceptance"],
    "not_performed":["device attachment check or test","APK build/install","owner-process restart","real sign-in or purchase","live backend mutation or deployment","AAA certification"],
}
save(EV / "report.json", report)
print(json.dumps({"checkpoint":commit,"focused":[focused["checks"],focused_mobile["checks"]],
                  "models":[model["checks"],model_mobile["checks"]],"native":[native["checks"],native_mobile["checks"]],
                  "parser":parser_count,"triangles":model["triangles"],"meshes":len(current_files),"identical":len(identical)}, indent=2))
