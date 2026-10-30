"""Record the neck correction and a checkpoint isolated from the normal index."""
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
ASSETS = Path("game/assets/vehicles/kart_refined_v1")
DOC = Path("docs/KART_SHORT_NECK_2026_10_25.md")
TAG = "KART-SHORT-NECK-20261025"


def read(path): return json.loads(Path(path).read_text(encoding="utf-8-sig"))
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path, data): Path(path).write_bytes((json.dumps(data, indent=2)+"\n").encode())


results = {name: read(EV/name/"report.json") for name in ["fit", "proportions", "model", "model-mobile", "retained", "native", "native-mobile", "art"]}
assert all(value["failures"] == 0 for value in results.values())
baseline = read(EV/"fit-before/report.json")
assert baseline["checks"] == 32 and baseline["failures"] == 2
parser = re.search(r"SCRIPT_PARSE: (\d+) scripts, 0 failures", (EV/"parser.log").read_text(encoding="utf-8-sig"))
assert parser
assert "KART_TESTS: 42 checks, 0 failures" in (EV/"handling.log").read_text(encoding="utf-8-sig")
assert "49 actual model captures" in (EV/"liveries.log").read_text(encoding="utf-8-sig")
assert "NEWS PHOTO FRAMING: 1 cars, 0 failures" in (EV/"news.log").read_text(encoding="utf-8-sig")
invariants = read(EV/"invariants-before.json")
for rel, expected in invariants.items(): assert sha(ROOT/rel) == expected, rel
old_source = (BEFORE/"game/vehicle/kart_driver.gd").read_text()
source = (ROOT/"game/vehicle/kart_driver.gd").read_text()
neck_line = '\tG.ellipsoid(parent,"BalaclavaNeck"'
assert old_source.split(neck_line)[0] == source.split(neck_line)[0]
assert old_source.split(neck_line)[1].split("\n",1)[1].rsplit('\tpreload("res://vehicle/kart_helmet.gd")',1)[0] == source.split(neck_line)[1].split("\n",1)[1].split('\tvar head := Node3D.new()',1)[0]
manifest = read(ROOT/ASSETS/"manifest.json")
old = read(BEFORE/ASSETS/"manifest.json")
for field, name in [("driver_sha256","kart_driver.gd"),("model_sha256","kart_model.gd"),("helmet_sha256","kart_helmet.gd"),("geometry_sha256","kart_geometry.gd")]: assert manifest[field] == sha(ROOT/"game/vehicle"/name)
current = {item["file"] for item in manifest["meshes"]}
previous = {item["file"] for item in old["meshes"]}
assert current == {p.name for p in (ROOT/ASSETS).glob("*.res")}
identical = [name for name in current & previous if sha(ROOT/ASSETS/name) == sha(BEFORE/ASSETS/name)]
assert len(identical) == 228 and len(current-previous) == 2 and len(previous-current) == 2
for item in manifest["meshes"]:
    if item["key"].startswith("Helmet"): assert item["file"] in identical
for i in range(1,5):
    rel = Path(f"game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res")
    assert sha(ROOT/rel) == sha(BEFORE/rel)
photos = sorted((ROOT/"game/assets/liveries/previews_v2/kart").glob("*.png"))
assert len(photos) == 49 and all(sha(p) != sha(BEFORE/p.relative_to(ROOT)) for p in photos)
neck_before = baseline["measurements"]["full"]["visible_neck"]
neck_after = results["fit"]["measurements"]["full"]["visible_neck"]


def strip(raw):
    return re.sub(rb"(?ms)^<!-- "+TAG.encode()+rb" -->\r?\n.*?^<!-- /"+TAG.encode()+rb" -->\r?\n(?:\r?\n)?", b"", raw)


def block(rel, content, append=False):
    p = ROOT/rel
    raw = strip(p.read_bytes())
    nl = b"\r\n" if b"\r\n" in raw else b"\n"
    addition = (f"<!-- {TAG} -->\n{content}\n<!-- /{TAG} -->\n\n").encode().replace(b"\n",nl)
    p.write_bytes(raw+nl+addition if append else addition+raw)


summary = (
    "## Kart shorter neck and lower helmet (2026-10-25)\n"
    "KSN01-KSN02/V02-V05/R01/G01/Q01: Owner rejects the long neck. Lower the complete unchanged helmet by 0.065 model metres and shorten the balaclava neck; actual rear collar/helmet exposure falls 0.084 to 0.019 (77.38%). "
    "Helmet/collar/torso/shoulder mesh crossings remain zero, with connected collar/lining. Corrected torso/legs/seat, hands/boots, helmet shape and canonical car/config/camera sources remain. "
    f"Fit 32, proportions 24, model 86 Compatibility/86 desktop Mobile, retained 172, Garage/race 15/15, kart 42 and parser {parser[1]} pass. Original 32-check/two-failure neck regression retained. "
    "Prepared resources 230, with all 228 other binaries including every helmet mesh identical; full/simple triangles fall to 93520/28706. Body shadow and catalogue/news/all 49 photos refreshed. Evidence/commands/scoped checkpoint: docs/KART_SHORT_NECK_2026_10_25.md and docs/evidence/kart-short-neck-2026-10-25/report.json. Reload and owner/device visual/motion/cost acceptance remain. No device attachment check/test, APK, purchase, live mutation, deployment or owner-process restart; concurrent work preserved."
)
shared = [Path(p) for p in ["AGENTS.md","DEVELOPMENT_STATUS.md","docs/PHASE_0_PLAN.md","licenses/ASSETS.md"]]
for rel in shared[:3]: block(rel, summary)
block(shared[3], "## Kart shorter neck mounting revision\n2026-10-25: Original authored neck fitting and lower helmet placement in kart_driver.gd. Existing helmet geometry/materials remain exact; native body shadow and vehicle photos refreshed. No external asset added. Evidence: docs/KART_SHORT_NECK_2026_10_25.md.", append=True)
doc = f"""# Kart shorter neck — 2026-10-25

The owner identifies the neck as still too long. KSN01-KSN02 / V02-V05 / R01 / G01 / Q01 lower the complete helmet by 0.065 model metres on a static HelmetMount and shorten the balaclava's vertical radius from 0.082 to 0.046, with centre y moving 0.787 to 0.751. The rear collar-to-shell exposure measured from actual mounted geometry falls **{neck_before:.3f} to {neck_after:.3f} model metres**, a **{100*(1-neck_after/neck_before):.2f}%** reduction. The helmet now sits close to the collar with a connected lining and zero intersections against collar, torso or shoulder cloth in both detail levels.

Only game/vehicle/kart_driver.gd and game/tests/test_kart_driver_fit.gd change. The previous fixed neck-top-at-0.85 assertion encoded the rejected tall placement; the owner's shorter-neck correction supersedes it. Its connectivity requirement is retained as actual collar/lining overlap, with new 0.004–0.030 exposure and actual helmet/cloth edge checks. The shortened chin and existing seat support/cavity/clearance checks remain. Helmet shape, visor and all helmet binary resources are exact; torso/leg/seat proportions, collar, arms/hands, boots, kart assembly, physics/config and production cameras remain exact.

Matched native views: [before side](evidence/kart-short-neck-2026-10-25/before-model/full-driver-side.png), [shorter neck](evidence/kart-short-neck-2026-10-25/model/full-driver-side.png), [before front](evidence/kart-short-neck-2026-10-25/before-model/full-driver.png), [revised front](evidence/kart-short-neck-2026-10-25/model/full-driver.png), [desktop Mobile/simple](evidence/kart-short-neck-2026-10-25/model-mobile/simple-driver.png), [actual Garage](evidence/kart-short-neck-2026-10-25/native/garage-1280.png), [actual driving](evidence/kart-short-neck-2026-10-25/native/race.png).

Final checks: **32** fit, **24** retained proportions, **86/86** Compatibility/desktop Mobile model, **172** mechanical regression, **15/15** actual Garage/race, **42** kart handling and **{parser[1]}** parsed scripts, all passing. The original exposed neck fails exactly two of the 32 focused checks; the first revised version passes. There are 230 prepared resources: two replacement neck meshes and **228 byte-identical others**, including every helmet mesh. Detailed/simple triangles decrease from 94,296/28,894 to **93,520/28,706**, retaining the 95,000 cap. All four wheel shadow binaries remain identical; the rebuilt body shadow has {manifest['shadows'][0]['triangles']} triangles. Catalogue/news/all 49 appearance photos are refreshed and imported. No new material, shader, light, per-frame callback or physics change is added.

Pinned Godot 4.7.2 runs through scripts/dev.ps1 with isolated APPDATA/LOCALAPPDATA under build/kart-short-neck. Actual job commands and exit codes are saved in *-command.json and native logs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-short-neck-2026-10-25/run.ps1 -Job before-model
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-short-neck-2026-10-25/run.ps1 -Job fit-before
foreach ($job in @('fit-draft','draft','bake','fit','proportions','model','retained','art','liveries','news','import','native','handling','parser')) {{
    powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-short-neck-2026-10-25/run.ps1 -Job $job
}}
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-short-neck-2026-10-25/run.ps1 -Job model -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-short-neck-2026-10-25/run.ps1 -Job native -Renderer mobile
python docs/evidence/kart-short-neck-2026-10-25/finalize.py
```

[report.json](evidence/kart-short-neck-2026-10-25/report.json) records outcomes, hashes, archived original resources and the isolated task-only Git checkpoint. Its patch passes whitespace and reverse-application checks; the normal index remains untouched. Concurrent work is preserved.

Client reload and owner appearance acceptance remain. No device attachment check/test, APK build/install, authentication/purchase, live mutation/deployment or owner-process restart was performed. Desktop Mobile is a desktop Vulkan test; startup hitch logs remain and no physical-device performance claim is made.
"""
(ROOT/DOC).write_bytes(doc.encode())
files = [Path(p) for p in ["game/vehicle/kart_driver.gd","game/tests/test_kart_driver_fit.gd"]]+shared+[DOC,ASSETS/"manifest.json"]+[ASSETS/name for name in sorted(current)]
files += [p.relative_to(ROOT) for p in photos]+[Path("game/assets/menu/kart_illustration_v1.png"),Path("game/assets/news/vehicles/kart.png")]+[Path(f"game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res") for i in range(5)]
save(EV/"source-asset-hashes.json",{p.as_posix():sha(ROOT/p) for p in files})
checkpoint = ROOT/"build/kart-short-neck/checkpoint"
assert not checkpoint.exists()
checkpoint.mkdir(parents=True)
index_hash = sha(ROOT/".git/index")
env = {k:v for k,v in os.environ.items() if k not in ["GIT_DIR","GIT_WORK_TREE","GIT_INDEX_FILE"]}


def git(*args): return subprocess.run(["git","-c","core.autocrlf=false","-c","user.name=Codex","-c","user.email=codex@local.invalid","-C",str(checkpoint),*args],env=env,check=True,capture_output=True,text=True).stdout.strip()
def copy(source, rel):
    target = checkpoint/rel
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
git("commit","--quiet","-m","Exact task-start kart neck and shared document baseline")
base = git("rev-parse","HEAD")
for name in previous-current:
    p = (checkpoint/ASSETS/name).resolve()
    assert p.parent == (checkpoint/ASSETS).resolve()
    p.unlink()
for p in files: copy(ROOT/p,p)
git("add","--all")
git("diff","--cached","--check")
git("commit","--quiet","-m","Shorten kart driver neck and lower the unchanged helmet")
commit = git("rev-parse","HEAD")
git("diff","--binary","--output="+str(EV/"task.patch"),"HEAD~1","HEAD")
git("apply","--reverse","--check",str(EV/"task.patch"))
assert not git("status","--porcelain") and sha(ROOT/".git/index") == index_hash
(EV/"checkpoint-stat.txt").write_bytes((git("show","--stat","--oneline","HEAD")+"\n").encode())
save(EV/"report.json",{"date":"2026-10-25","requirements":["KSN01","KSN02","V02","V03","V04","V05","R01","G01","Q01"],"results":results,"baseline":baseline,"parser_scripts":int(parser[1]),"kart_handling_checks":42,"visible_neck_before":neck_before,"visible_neck_after":neck_after,"unchanged_source_hashes":invariants,"prepared":{"resources":len(current),"byte_identical":len(identical),"new":sorted(current-previous),"retired":sorted(previous-current),"all_helmet_meshes_identical":True,"wheel_shadows_identical":True,"shadows":manifest["shadows"]},"art":{"appearance_photos":49,"all_photo_hashes_changed":True,"news":read(EV/"news/framing.json"),"import_log":"import.log"},"desktop_startup_hitch_ms":{name:re.findall(r"RACE_HITCH frame_ms=([0-9.]+)",(EV/(name+".log")).read_text(encoding="utf-8-sig")) for name in ["native","native-mobile"]},"commands":"run.ps1 and *-command.json","hashes":"source-asset-hashes.json","checkpoint":{"repository":str(checkpoint),"base":base,"commit":commit,"patch":"task.patch","sha256":sha(EV/"task.patch"),"whitespace_check":"passed","reverse_application_check":"passed","normal_index_unchanged":True},"remaining":["Client reload","Owner appearance review","Physical-device appearance/motion/cost acceptance"],"not_performed":["Device attachment check/test","APK build/install","Authentication/purchase","Live mutation/deployment","Owner-process restart"]})
print(json.dumps({"checkpoint":commit,"visible_neck":neck_after,"parser_scripts":int(parser[1]),"checks":{name:value["checks"] for name,value in results.items()}},indent=2))
