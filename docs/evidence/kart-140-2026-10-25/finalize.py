"""Record the verified kart-5 tune and isolate its review checkpoint."""
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
TAG = "KART-140-20261025"
DOC = Path("docs/KART_140_2026_10_25.md")


def read(path): return json.loads(Path(path).read_text(encoding="utf-8-sig"))
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path, data): Path(path).write_bytes((json.dumps(data,indent=2)+"\n").encode())
def log(name):
    raw = (EV / name).read_bytes()
    return raw.decode("utf-16" if raw.startswith((b"\xff\xfe",b"\xfe\xff")) else "utf-8-sig")


for name, marker in [("handling.log","KART_TESTS: 42 checks, 0 failures"),("replay.log","CAR_TESTS: 107 checks, 0 failures"),("shared-handling.log","HANDLING_TESTS: 88 checks, 0 failures"),("rewind-tests.log","Rewind: 61 checks, 0 failures"),("parser-final.log","SCRIPT_PARSE: 1168 scripts, 0 failures"),("backend.log","69 passed, 1 deselected")]: assert marker in log(name), name
native = read(EV / "native/report.json")
assert native == {"checks":15,"failures":0}
metrics = json.loads(re.search(r"KART_TOP_SPEED (\{[^\n]+\})",log("handling.log"))[1])
assert abs(metrics["maximum_kmh"]-140) < 0.001
assert metrics["version"] == "kart-5"
old_tune = (BEFORE / "kart.tres").read_text(encoding="utf-8-sig")
new_tune = (ROOT / "game/resources/cars/kart.tres").read_text(encoding="utf-8-sig")
assert old_tune.replace('version = "kart-4"','version = "kart-5"').replace('maximum_speed = 30.0','maximum_speed = 38.88889') == new_tune
receipt = read(EV / "canonical-verification.json")
assert receipt["kart"]["config_hash"] == metrics["config_hash"]
old_fixture = read(BEFORE / "verified_oval.json")
fixture = read(ROOT / "backend/tests/fixtures/verified_oval.json")
old_entry = old_fixture["expected_manifest"]["vehicles"]["kart"]
old_fixture["expected_manifest"]["vehicles"]["kart"] = receipt["kart"]
assert old_fixture == fixture, "Fixture changes must be limited to the kart entry"
invariants = []
for item in read(EV / "invariants-before.json"):
    path = Path(item["Path"])
    assert sha(path) == item["Hash"].lower(), str(path)
    invariants.append({"path":path.relative_to(ROOT).as_posix(),"sha256":sha(path),"unchanged":True})


def strip_task(raw): return re.sub(rb"(?ms)^<!-- "+TAG.encode()+rb" -->\r?\n.*?^<!-- /"+TAG.encode()+rb" -->\r?\n(?:\r?\n)?",b"",raw)
def block(relative, text):
    path = ROOT / relative
    raw = strip_task(path.read_bytes())
    newline = b"\r\n" if b"\r\n" in raw else b"\n"
    prefix = (f"<!-- {TAG} -->\n{text.strip()}\n<!-- /{TAG} -->\n\n").encode().replace(b"\n",newline)
    path.write_bytes(prefix+raw)


summary = """## Kart 140 km/h top-speed override (2026-10-25)
KTS01-KTS02/R01/R03/R04/R06/R07/Q01: Owner raises the kart cap108to140km/h. Kart-5 changes only version and maximum_speed38.88889m/s; engine, grip, steering, brakes, model and shared physics0.69 sources remain. Native sustained full throttle reaches140 in2.317s, holds30s with exact replay and stops in1.358s/25.987m. Existing cap-based power falloff naturally quickens0to72 from1.025to0.975s. Kart42/replay107, shared handling88/rewind61, actual Garage-race15, backend69pass/1existing exclusion, parser1168/import and independent12787input five-lap server replay pass. Initial old-tune failures and mistaken exact-launch test assumption are retained; prior32 checks remain. Only the kart manifest entry changes; six other cars and historical records remain. Evidence, commands, hashes and scoped Git-checked checkpoint: docs/KART_140_2026_10_25.md and docs/evidence/kart-140-2026-10-25/report.json. Reload, matching online verifier rollout and owner/device driving acceptance remain. No attachment/device test, APK, live mutation, purchase, deployment or owner-process restart; concurrent work preserved."""
shared = [Path(path) for path in ["AGENTS.md","DEVELOPMENT_STATUS.md","docs/PHASE_0_PLAN.md","docs/KART.md"]]
for path in shared[:3]: block(path,summary)
block(shared[3],"## Current top speed - 2026-10-25\nKart-5 raises the cap to **140 km/h** (38.88889 m/s). Existing engine-force, steering, grip and brake settings remain. The speed-based power curve slightly quickens acceleration. See [current tuning and verification](KART_140_2026_10_25.md); the sections below retain their historical measurements.")
doc = f"""# Kart 140 km/h - 2026-10-25

The owner requests a 140 km/h top speed for the kart. KTS01 changes `game/resources/cars/kart.tres` from 30 to 38.88889 m/s. KTS02 advances its handling version from kart-4 to kart-5 and updates only the kart entry in the backend verifier fixture. Shared physics remains arcade-planar-0.69; all six other vehicle hashes are exact. Existing records are preserved under their earlier rules identity, with new runs using the new configuration hash.

| Native measurement | Result |
| --- | ---: |
| Sustained speed | {metrics['maximum_kmh']:.6f} km/h (Vector2 float precision) |
| 0 to 140 km/h | {metrics['to_140_s']:.3f} s |
| 0 to 72 km/h | 0.975 s, previously 1.025 s |
| Braking from 140 km/h to below 0.15 m/s | {metrics['brake_stop_s']:.3f} s / {metrics['brake_distance_m']:.3f} m |

Engine force, mass, steering, grip, braking, dirt penalties and all other handling fields remain. The existing simulation computes power falloff relative to maximum speed, so increasing the cap naturally changes acceleration below the old cap. Initial launch force remains identical and acceleration is at least as fast as before. This is a game-tune measurement, not real-kart performance.

The original 32 kart assertions remain. Ten additional checks cover the target/version, unchanged tuning fields, first launch tick, acceleration, reaching/holding the cap, no overspeed, exact 30-second replay, stopping and old/new PB identity. The baseline reports 41 checks/four expected failures. The first modified tune catches one invalid new-test assumption that launch snapshots would remain identical despite cap-based power falloff. The final test replaces that assumption with explicit unchanged fields, exact first-tick force and no slower launch; `initial-launch-assumption.log` preserves the failure. No shared simulation or previous threshold is changed to satisfy it.

Actual results: kart **42**, catalogue/replay **107**, shared handling **88**, rewind **61**, actual Garage/race **15**, parser **1,168 scripts**, and backend verifier **69 passed / one existing deselection**, all zero failures. Three ordinary kart circuits finish five laps with zero barrier contacts and exact replay. The new actual-App assertion checks the complete race handling snapshot against the selected current resource. Native evidence is in `native/`; no model or art is changed or rebaked.

The independent server reader accepts **{receipt['input_count']} inputs / {receipt['time_ms']} ms / five laps**, with lap ticks `{receipt['lap_ticks']}`. It agrees on kart-5 hash `{metrics['config_hash']}`, the unchanged shared physics and six other vehicle entries. A same-track old/new board digest differs, proving version separation. Only the kart entry in `backend/tests/fixtures/verified_oval.json` changes; its original document, replay and historical rules field remain.

Commands use the pinned Godot 4.7.2 wrapper and disposable workspace APPDATA/LOCALAPPDATA. Native Windows execution uses approved certificate-store access:

```powershell
./scripts/dev.ps1 TestKart
./scripts/dev.ps1 TestHandling
./scripts/dev.ps1 TestRewind
./scripts/dev.ps1 TestScript -ScriptPath res://tests/export_kart_speed_replay.gd -TestArgument @('--output=res://../docs/evidence/kart-140-2026-10-25/canonical-race.json')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_kart_refinement_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/kart-140-2026-10-25/native')
./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd
./scripts/dev.ps1 Import
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/kart-140-2026-10-25/verify_canonical.py
```

From `backend/`: `../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_verifier.py -q -k 'not postgres and not retained_over_and_under_rejection' --tb=short --basetemp ../build/kart-140-pytest`. Only the existing archived physics-050 ghost case is deselected in this module; no additional exclusion is added. One existing Starlette/httpx deprecation warning remains. Import retains the isolated Android build-tools directory warning. Initial rejected patch context and missing replay-log copy followed the failed initial test; the corrected commands and all results are retained.

[Report](evidence/kart-140-2026-10-25/report.json), [server receipt](evidence/kart-140-2026-10-25/canonical-verification.json) and logs retain source hashes and exact outcomes. The isolated task-only checkpoint uses the task-start tune/tests/fixture and current shared docs with this block removed; staged whitespace and reverse-patch checks pass. The normal branch/index and concurrent work remain intact.

Reload the client and roll out matching verifier configuration for online use. Owner driving feel and physical-device handling/frame-pacing acceptance remain. This task performs no attachment/device test, APK, live mutation, purchase, deployment or owner-process restart. Desktop native startup hitches remain recorded in `native.log`; these checks are not a phone performance benchmark.
"""
(ROOT / DOC).write_bytes(doc.encode())
files = [Path(path) for path in ["game/resources/cars/kart.tres","game/tests/test_kart.gd","game/tests/test_kart_refinement_ui.gd","game/tests/export_kart_speed_replay.gd","game/tests/export_kart_speed_replay.gd.uid","backend/tests/fixtures/verified_oval.json"]]+shared+[DOC]
save(EV / "source-hashes.json",{path.as_posix():sha(ROOT / path) for path in files})
checkpoint = ROOT / "build/kart-140/checkpoint"
resume = checkpoint.exists()
checkpoint.mkdir(parents=True,exist_ok=True)
index_hash = sha(ROOT / ".git/index")
env = {key:value for key,value in os.environ.items() if key not in ["GIT_DIR","GIT_WORK_TREE","GIT_INDEX_FILE"]}


def git(*args): return subprocess.run(["git","-c","core.autocrlf=false","-c","core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol","-c","user.name=Codex","-c","user.email=codex@local.invalid","-C",str(checkpoint),*args],env=env,check=True,capture_output=True,text=True).stdout.strip()
def copy(source, relative):
    target = checkpoint / relative
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,target)


if not resume:
    git("init","--quiet")
    for name,path in [("kart.tres","game/resources/cars/kart.tres"),("test_kart.gd","game/tests/test_kart.gd"),("test_kart_refinement_ui.gd","game/tests/test_kart_refinement_ui.gd"),("verified_oval.json","backend/tests/fixtures/verified_oval.json")]: copy(BEFORE / name,Path(path))
    for path in shared:
        (checkpoint / path).parent.mkdir(parents=True,exist_ok=True)
        (checkpoint / path).write_bytes(strip_task((ROOT / path).read_bytes()))
    git("add","--all")
    git("commit","--quiet","-m","Task-start kart tune and current shared-document baseline")
else:
    assert git("rev-list","--count","HEAD") == "1", "Only resume the unfinished task-start checkpoint"
base = git("rev-parse","HEAD")
for path in files: copy(ROOT / path,path)
git("add","--all")
git("diff","--cached","--check")
git("commit","--quiet","-m","Raise kart top speed to 140 km/h with versioned replay identity")
commit = git("rev-parse","HEAD")
git("diff","--binary","--output="+str(EV / "task.patch"),"HEAD~1","HEAD")
git("apply","--reverse","--check",str(EV / "task.patch"))
assert not git("status","--porcelain") and sha(ROOT / ".git/index") == index_hash
(EV / "checkpoint-stat.txt").write_bytes((git("show","--stat","--oneline","HEAD")+"\n").encode())
save(EV / "report.json",{"date":"2026-10-25","requirements":["KTS01","KTS02","R01","R03","R04","R06","R07","Q01"],"metrics":metrics,"native":native,"canonical":receipt,"checks":{"kart":42,"replay":107,"shared_handling":88,"rewind":61,"parser":1168,"backend_passed":69,"backend_existing_deselected":1},"baseline":"baseline.log: 41 checks/four failures","initial_new_tune":"initial-launch-assumption.log: 41 checks/one failure","unchanged_sources":invariants,"previous_kart":old_entry,"fixture_only_kart_entry_changed":True,"six_other_car_hashes_unchanged":True,"source_hashes":"source-hashes.json","commands":"docs/KART_140_2026_10_25.md","checkpoint":{"repository":str(checkpoint),"base":base,"commit":commit,"patch":"task.patch","sha256":sha(EV / "task.patch"),"staged_whitespace_check":"passed","reverse_apply_check":"passed","normal_branch_and_index":"untouched; index hash unchanged during checkpoint construction"},"desktop_hitch_ms":[float(n) for n in re.findall(r"RACE_HITCH frame_ms=([0-9.]+)",log("native.log"))],"remaining_acceptance":["Client reload","Matching online verifier configuration rollout","Owner/device driving feel and frame pacing"],"not_performed":["attachment/device test","APK","live mutation or purchase","deployment","owner-process restart"]})
print(json.dumps({"checkpoint":commit,"top_speed":metrics["maximum_kmh"],"handling_version":metrics["version"],"server_five_lap_inputs":receipt["input_count"]},indent=2))
