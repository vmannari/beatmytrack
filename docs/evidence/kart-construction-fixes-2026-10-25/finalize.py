"""Verify all three construction corrections and create a task-scoped checkpoint."""
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess

EV = Path(__file__).resolve().parent
ROOT = EV.parents[2]
BEFORE = EV/"before"
ASSETS = Path("game/assets/vehicles/kart_refined_v1")
DOC = Path("docs/KART_CONSTRUCTION_FIXES_2026_10_25.md")
TAG = "KART-CONSTRUCTION-FIXES-20261025"


def read(p): return json.loads(Path(p).read_text(encoding="utf-8-sig"))
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def clean(data):
    if isinstance(data, float) and not math.isfinite(data): return None
    if isinstance(data, dict): return {k:clean(v) for k,v in data.items()}
    if isinstance(data, list): return [clean(v) for v in data]
    return data
def save(p, data): Path(p).write_bytes((json.dumps(clean(data),indent=2,allow_nan=False)+"\n").encode())


results = {name:read(EV/name/"report.json") for name in ["construction","fit","proportions","model","model-mobile","retained","native","native-mobile","art"]}
assert all(value["failures"] == 0 for value in results.values())
baseline = read(EV/"construction-before/report.json")
assert baseline["checks"] == 32 and baseline["failures"] == 22
parser = re.search(r"SCRIPT_PARSE: (\d+) scripts, 0 failures",(EV/"parser.log").read_text(encoding="utf-8-sig"))
assert parser
assert "KART_TESTS: 42 checks, 0 failures" in (EV/"handling.log").read_text(encoding="utf-8-sig")
assert "49 actual model captures" in (EV/"liveries.log").read_text(encoding="utf-8-sig")
assert "NEWS PHOTO FRAMING: 1 cars, 0 failures" in (EV/"news.log").read_text(encoding="utf-8-sig")
invariants = read(EV/"invariants-before.json")
allowed_concurrent = {"game/vehicle/vehicle_simulation.gd","game/vehicle/handling_config.gd","game/resources/cars/electric.tres","game/ui/garage_customisation_camera.gd"}
unchanged = {}
concurrent = []
for rel, before_hash in invariants.items():
    now = sha(ROOT/rel)
    if now == before_hash: unchanged[rel] = now
    else:
        assert rel in allowed_concurrent,rel
        concurrent.append({"path":rel,"task_start_sha256":before_hash,"final_sha256":now,"excluded_from_checkpoint":True,"attribution":"Concurrent electric launch/drift work" if "garage_" not in rel else "Garage options/main-view focus; docs/evidence/garage-options-focus-2026-10-25/report.json"})
old_model = (BEFORE/"game/vehicle/kart_model.gd").read_text()
model = (ROOT/"game/vehicle/kart_model.gd").read_text()
assert old_model[old_model.index("static func _driver("):] == model[model.index("static func _driver("):]
def without_stay_lines(text): return "\n".join(line for line in text.splitlines() if '"SeatStay"' not in line and '.seat_stays(' not in line)
assert without_stay_lines(old_model) == without_stay_lines(model)
old_helmet = (BEFORE/"game/vehicle/kart_helmet.gd").read_text()
helmet = (ROOT/"game/vehicle/kart_helmet.gd").read_text()
marker = '\tG.patch(parent,"HelmetReferenceNeckLining"'
end = '\tG.patch(parent,"HelmetReferenceChinIntake"'
assert old_helmet.split(marker)[0] == helmet.split(marker)[0]
assert old_helmet.split(end)[1] == helmet.split(end)[1]
manifest = read(ROOT/ASSETS/"manifest.json")
old_manifest = read(BEFORE/ASSETS/"manifest.json")
for key,name in [("model_sha256","kart_model.gd"),("driver_sha256","kart_driver.gd"),("helmet_sha256","kart_helmet.gd"),("geometry_sha256","kart_geometry.gd")]: assert manifest[key] == sha(ROOT/"game/vehicle"/name)
current = {x["file"] for x in manifest["meshes"]}
previous = {x["file"] for x in old_manifest["meshes"]}
assert current == {p.name for p in (ROOT/ASSETS).glob("*.res")}
identical = [name for name in current & previous if sha(ROOT/ASSETS/name) == sha(BEFORE/ASSETS/name)]
assert len(current) == 238 and len(identical) == 210
for i in range(1,5):
    p = Path(f"game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res")
    assert sha(ROOT/p) == sha(BEFORE/p)
before_interface = read(EV/"meshes-before-interface-preservation.json")
assert all(sha(ROOT/ASSETS/name) == value for name,value in before_interface.items())
photos = sorted((ROOT/"game/assets/liveries/previews_v2/kart").glob("*.png"))
assert len(photos) == 49 and all(sha(p) != sha(BEFORE/p.relative_to(ROOT)) for p in photos)
reviews = {name:read(EV/name/"metrics.json") for name in ["review","review-mobile"]}
for review in reviews.values():
    for name, expected in review["sources"].items(): assert sha(ROOT/"game/vehicle"/name) == expected
for result in results["construction"]["measurements"].values():
    assert result["unmatched_suit_edges"] == 0 and result["inconsistent_suit_edges"] == 0 and result["helmet_rays_covered"] == 9
receipts = {name:read(EV/(name+"-command.json")) for name in ["native","native-mobile","handling","parser"]}
assert all(value["shared_sources_before"] == value["shared_sources_after"] for value in receipts.values())


def strip(raw):
    return re.sub(rb"(?ms)^<!-- "+TAG.encode()+rb" -->\r?\n.*?^<!-- /"+TAG.encode()+rb" -->\r?\n(?:\r?\n)?",b"",raw)


def block(rel,content,append=False):
    p = ROOT/rel
    raw = strip(p.read_bytes())
    nl = b"\r\n" if b"\r\n" in raw else b"\n"
    addition = (f"<!-- {TAG} -->\n{content}\n<!-- /{TAG} -->\n\n").encode().replace(b"\n",nl)
    p.write_bytes(raw+nl+addition if append else addition+raw)


summary = (
    "## Kart construction findings corrected (2026-10-25)\n"
    "KCF01-KCF03/KCR01-KCR03/V02-V05/R01/G01/Q01: Fit seat stays to derived bucket mounts with closed pads/fasteners; formed dark helmet padding closes all nine tested lower sight lines; shared torso openings and Hermite limb transitions replace the open shoulder/hip roots. The suit has zero unmatched edges or inconsistent winding, with 96/48 matched join vertices and 0.0188deg maximum normal difference. "
    f"Construction 32, fit 32, proportions 24, model 86 Compatibility/86 desktop Mobile, retained 172, Garage/race 15/15, kart 42 and parser {parser[1]} pass. Original-source 32-check/22-failure regression and initial cap-tangent/winding/reload failures remain. "
    "Full/simple 94128/29006 triangles retain the unchanged 95000 budget; 238 prepared resources include 210 exact originals. Body shadow and catalogue/news/all 49 photos refreshed. Kart configuration, corrected short-neck/helmet silhouette, controls, wheels/engine/exhaust and original regression assertions remain; concurrent EV simulation/config and Garage camera work is preserved and excluded with exact hashes. Evidence, commands, matched views and scoped checkpoint: docs/KART_CONSTRUCTION_FIXES_2026_10_25.md and docs/evidence/kart-construction-fixes-2026-10-25/report.json. Reload and owner/device appearance/motion/cost acceptance remain. No device attachment check/test, APK, purchase, live mutation, deployment or owner-process restart."
)
shared = [Path(p) for p in ["AGENTS.md","DEVELOPMENT_STATUS.md","docs/PHASE_0_PLAN.md","licenses/ASSETS.md"]]
for p in shared[:3]: block(p,summary)
block(shared[3],"## Original kart construction corrections\n2026-10-25: Original authored seat mounting pads/stays, formed opaque helmet padding and stitched driver shoulder/hip topology. Existing CompactFinish materials and fictional kart identity retained; native prepared resources, body shadow and catalogue/news/49 appearance photos refreshed. No external model/image added. Provenance and evidence: docs/KART_CONSTRUCTION_FIXES_2026_10_25.md.",append=True)
doc = f"""# Kart construction fixes — 2026-10-25

The owner asks to fix all three findings in the preceding review. KCF01-KCF03 / KCR01-KCR03 / V02-V05 / R01 / G01 / Q01 close those specific findings.

| Finding | Correction and validation |
| --- | --- |
| KCF01 / KCR01 — detached seat stays | Derive attachment positions and frames from the actual bucket's surface/normal, place closed shaped pads and fasteners, and route both stays from the existing chassis rails into those pads. The old end-rim-to-seat gap of about 0.191 model metres becomes 0.00393 detailed / at most 0.00593 simple, with the pad filling that small offset. Actual end-to-bucket rays pass, and both pads and stays are present. |
| KCF02 / KCR02 — see-through helmet underside | Reform the existing dark lining from the lower binding's actual inner edge to a small neck opening tucked inside the balaclava. All nine lower sight-line rays meet opaque liner/neck geometry before the upper shell. External helmet geometry, visor, hardware, short chin and lowered head pose remain exact. |
| KCF03 / KCR03 — open/angular suit joins | Remove four matching patches from the torso grid and form shared shoulder/hip boundary rings. Hermite transitions meet the existing limb surfaces with shared positions and normals. End caps close the hidden wrist/ankle and torso ends. The complete core suit has **zero unmatched edges and zero inconsistent directed edges**, with **96 detailed / 48 simple** shared seam vertices and **0.01875 degrees** maximum normal difference. Distal arms/legs, hands and boots retain their original locations; sleeve trim starts after the new shoulder transition and passes its original actual-surface backing checks. |

The existing driver build interface is preserved. Seat attachment creation is called from the kart chassis builder with its existing metal material; no extra material role, shader, light, frame callback or canonical simulation operation is introduced. Complex seam generation runs only when authoring/baking immutable resources. Production loads the prepared meshes.

Matched native review images:

- [Before supports/helmet underside](evidence/kart-construction-review-2026-10-25/gl_compatibility/full-batched-seat-support.png), [fixed](evidence/kart-construction-fixes-2026-10-25/review/full-batched-seat-support.png).
- [Before shoulder](evidence/kart-construction-review-2026-10-25/gl_compatibility/full-shoulder-front.png), [shared smooth shoulder](evidence/kart-construction-fixes-2026-10-25/review/full-shoulder-front.png), [simple rear shoulder](evidence/kart-construction-fixes-2026-10-25/review-mobile/simple-batched-shoulder.png).
- [Complete revised driver](evidence/kart-construction-fixes-2026-10-25/model/full-driver.png), [side](evidence/kart-construction-fixes-2026-10-25/model/full-driver-side.png), [actual Garage](evidence/kart-construction-fixes-2026-10-25/native/garage-1280.png), [actual race](evidence/kart-construction-fixes-2026-10-25/native/race.png).

Final validation passes **32 construction**, **32 existing fit**, **24 existing proportions**, **86/86** Compatibility/desktop Mobile model, **172 existing mechanical**, **15/15 actual Garage/race**, **42 kart handling**, and **{parser[1]}** parsed scripts. The previous assertions and tolerances remain unchanged. Original task-start sources reloaded only inside a disposable process give **32 checks / 22 failures**, demonstrating the three defects. Undefined old attachment distances are retained in the raw Godot report as its overflow numeric representation; the summary uses null for missing ray hits.

The first implementation's new cap vertices exposed an auto-generated tangent-array length mismatch; clearing the stale generated tangents corrected it. The added directed-edge audit then caught local triangle flips in the underarm transition. Preserving the tube's global parameter winding and analytic normals corrects all of them without relaxing the audit. The first isolated baseline reload also caught a changed build signature; the original interface is restored and the exact old-source regression now runs. These logs and the original pre-winding images remain in evidence. All 238 prepared mesh binaries are identical across the later interface-preservation refactor. A final bake repins the exact source hashes.

The original review's horizontal torso-ray counters can classify shared seam edges as outside after the torso has real joint openings. Those legacy counters are retained unchanged; they are not a valid closure test for this topology. Their nearest-triangle distances now fall below 0.000063 model metres, while the new independent actual-face edge/normal audit proves the seams close. No old invariant is removed.

Detailed/simple visible triangles are **94,128/29,006**, below the unchanged 95,000 detailed cap. There are **238 prepared meshes**, **210 byte-identical** to task start; fourteen old keys retire, twenty-two new keys are added and six existing binaries change. Original resources and retired keys are archived. The rebuilt body shadow has {manifest['shadows'][0]['triangles']} triangles; all four wheel shadow binaries are identical. Catalogue/news and all 49 appearance photos are refreshed and imported.

Kart configuration, wheel/pedal/steering positions, engine/exhaust geometry, shared geometry helper and original regression test sources remain exact. Concurrent electric launch/drift work changes the shared simulation/handling and EV configuration; the Garage focus work changes garage_customisation_camera.gd. Their task-start/final hashes and per-command shared-source receipts are recorded, and those changes are preserved and excluded from this checkpoint. A concurrent camera save occurred during an otherwise passing parser run; its original receipt/log are retained as parser-concurrent-save-command.json and parser-concurrent-save.log, and the final parser check is rerun with stable source hashes. Actual Garage/race and handling checks use the current shared sources. No verifier/config rollout or physics claim is made for this visual task.

Changed source files: game/vehicle/kart_model.gd, kart_driver.gd and kart_helmet.gd; a new game/tests/test_kart_construction.gd adds the independent regression. The review diagnostic gains optional evidence-root and unbaked flags to preserve historical captures. Exact file hashes and results are in [report.json](evidence/kart-construction-fixes-2026-10-25/report.json).

Actual commands use pinned Godot 4.7.2 through scripts/dev.ps1, isolated APPDATA/LOCALAPPDATA under build/kart-construction-fixes and approved native Windows access. Job arguments/exit codes and shared-source hashes are saved in *-command.json; logs retain failed attempts:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-construction-fixes-2026-10-25/run.ps1 -Job construction-before
foreach ($job in @('construction-draft','fit-draft','proportions-draft','draft','review-draft','bake','construction','fit','proportions','model','retained','review','art','liveries','news','import','native','handling','parser')) {{
    powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-construction-fixes-2026-10-25/run.ps1 -Job $job
}}
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-construction-fixes-2026-10-25/run.ps1 -Job model -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-construction-fixes-2026-10-25/run.ps1 -Job review -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-construction-fixes-2026-10-25/run.ps1 -Job native -Renderer mobile
python docs/evidence/kart-construction-fixes-2026-10-25/finalize.py
```

The isolated Git checkpoint compares exact task-start kart sources/assets and current shared documents with only this task block removed. Its binary patch passes whitespace/reverse-application checks; the normal index is untouched and concurrent work is preserved.

Client reload and owner visual acceptance remain. No device attachment check/test, APK build/install, real authentication/purchase, live mutation/deployment or owner-process restart was performed. Desktop Mobile is a desktop Vulkan test; startup hitch logs are retained and no physical-device motion/performance claim is made.
"""
(ROOT/DOC).write_bytes(doc.encode())
sources = [Path(p) for p in ["game/vehicle/kart_model.gd","game/vehicle/kart_driver.gd","game/vehicle/kart_helmet.gd","game/tests/review_kart_model.gd","game/tests/test_kart_construction.gd","game/tests/test_kart_construction.gd.uid"]]
files = sources+shared+[DOC,ASSETS/"manifest.json"]+[ASSETS/name for name in sorted(current)]+[p.relative_to(ROOT) for p in photos]
files += [Path("game/assets/menu/kart_illustration_v1.png"),Path("game/assets/news/vehicles/kart.png")]+[Path(f"game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res") for i in range(5)]
save(EV/"source-asset-hashes.json",{p.as_posix():sha(ROOT/p) for p in files})
checkpoint = ROOT/"build/kart-construction-fixes/checkpoint"
assert not checkpoint.exists()
checkpoint.mkdir(parents=True)
index_hash = sha(ROOT/".git/index")
env = {k:v for k,v in os.environ.items() if k not in ["GIT_DIR","GIT_WORK_TREE","GIT_INDEX_FILE"]}


def git(*args): return subprocess.run(["git","-c","core.autocrlf=false","-c","user.name=Codex","-c","user.email=codex@local.invalid","-C",str(checkpoint),*args],env=env,check=True,capture_output=True,text=True).stdout.strip()
def copy(source,relative):
    target = checkpoint/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,target)


git("init","--quiet")
copy(ROOT/".gitattributes",Path(".gitattributes"))
for p in BEFORE.rglob("*"):
    if p.is_file(): copy(p,p.relative_to(BEFORE))
for p in shared:
    target = checkpoint/p
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(strip((ROOT/p).read_bytes()))
git("add","--all")
git("commit","--quiet","-m","Exact task-start kart construction and shared document baseline")
base = git("rev-parse","HEAD")
for name in previous-current:
    p = (checkpoint/ASSETS/name).resolve()
    assert p.parent == (checkpoint/ASSETS).resolve()
    p.unlink()
for p in files: copy(ROOT/p,p)
git("add","--all")
git("diff","--cached","--check")
git("commit","--quiet","-m","Fit kart seat mounts, close helmet lining and join the driver suit")
commit = git("rev-parse","HEAD")
git("diff","--binary","--output="+str(EV/"task.patch"),"HEAD~1","HEAD")
git("apply","--reverse","--check",str(EV/"task.patch"))
assert not git("status","--porcelain") and sha(ROOT/".git/index") == index_hash
(EV/"checkpoint-stat.txt").write_bytes((git("show","--stat","--oneline","HEAD")+"\n").encode())
save(EV/"report.json",{"date":"2026-10-25","requirements":["KCF01","KCF02","KCF03","KCR01","KCR02","KCR03","V02","V03","V04","V05","R01","G01","Q01"],"results":results,"original_source_regression":baseline,"reviews":reviews,"parser_scripts":int(parser[1]),"kart_handling":{"checks":42,"failures":0},"prepared":{"resources":len(current),"byte_identical":len(identical),"retired":sorted(previous-current),"new":sorted(current-previous),"changed_same_key":len(current&previous)-len(identical),"body_shadow":manifest["shadows"][0],"wheel_shadow_binaries_identical":True,"all_238_meshes_identical_after_interface_refactor":True},"unchanged_sources":unchanged,"concurrent_sources":concurrent,"shared_source_receipts":receipts,"art":{"appearance_photos":49,"all_photo_hashes_changed":True,"news":read(EV/"news/framing.json"),"import_log":"import.log"},"initial_failures":["initial-tangent-array.log","initial-winding.log","initial-winding.json","initial-baseline-reload.log","construction-before-first.log","construction-before-first.json"],"desktop_startup_hitch_ms":{name:re.findall(r"RACE_HITCH frame_ms=([0-9.]+)",(EV/(name+".log")).read_text(encoding="utf-8-sig")) for name in ["native","native-mobile"]},"commands":"run.ps1 and *-command.json","hashes":"source-asset-hashes.json","checkpoint":{"repository":str(checkpoint),"base":base,"commit":commit,"patch":"task.patch","sha256":sha(EV/"task.patch"),"whitespace_check":"passed","reverse_application_check":"passed","normal_index_unchanged":True},"remaining":["Client reload","Owner appearance acceptance","Physical-device appearance/motion/cost acceptance"],"not_performed":["Device attachment check/test","APK","Real authentication/purchase","Live mutation/deployment","Owner-process restart"]})
print(json.dumps({"checkpoint":commit,"parser_scripts":int(parser[1]),"prepared":len(current),"unchanged_meshes":len(identical),"checks":{name:value["checks"] for name,value in results.items()}},indent=2))
