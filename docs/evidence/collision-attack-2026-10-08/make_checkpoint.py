from pathlib import Path
import difflib
import hashlib
import json
import shutil
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BEFORE = OUT / "before"
modified = [
    "game/vehicle/vehicle_audio.gd","game/core/game.gd","game/default_bus_layout.tres",
    "game/soundtrack/audio_world.gd","scripts/build_vehicle_audio.py","game/tests/test_effect_timing.gd",
    "game/assets/audio/vehicles/manifest.json","game/assets/audio/vehicles/NOTICE.txt",
    "docs/EFFECT_TIMING.md","DEVELOPMENT_STATUS.md","docs/PHASE_0_PLAN.md","licenses/ASSETS.md",
]
new = ["game/vehicle/visible_contact_audio.gd","game/vehicle/visible_contact_audio.gd.uid","scripts/review_collision_attack.py","docs/COLLISION_ATTACK.md"]
for name in ["probe_wall_audio_gap","test_visible_wall_audio","test_collision_attack","capture_collision_attack"]:
    new += ["game/tests/"+name+".gd","game/tests/"+name+".gd.uid"]
new += [(OUT/file).relative_to(ROOT).as_posix() for file in ["audition.html","review.json","capture-timing.json","wall-contact-comparison.json","loop-continuity.json","make_checkpoint.py"]]
patch = []
inventory = []
def pin(path):
    target = ROOT/path
    inventory.append(dict(path=path,bytes=target.stat().st_size,sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
for path in modified+new:
    old = (BEFORE/path).read_text(encoding="utf-8") if path in modified else ""
    now = (ROOT/path).read_text(encoding="utf-8")
    if old!=now:
        patch.append("diff --git a/"+path+" b/"+path+"\n")
        if not old: patch.append("new file mode 100644\n")
        for line in difflib.unified_diff(old.splitlines(keepends=True),now.splitlines(keepends=True),fromfile="a/"+path if old else "/dev/null",tofile="b/"+path):
            patch.append(line if line.endswith("\n") else line+"\n\\ No newline at end of file\n")
    pin(path)
for i in range(3):
    pin("game/assets/audio/vehicles/impact_"+str(i)+".wav")
for path in sorted(OUT.glob("*.wav")): pin(path.relative_to(ROOT).as_posix())
logs = OUT / "logs"
logs.mkdir(exist_ok=True)
captured = []
oldest = (BEFORE / "game/assets/audio/vehicles/manifest.json").stat().st_mtime
needles = ["WALL_AUDIO","COLLISION_ATTACK","EFFECT_TIMING_TESTS: 43","VEHICLE_AUDIO: 1442","SURFACE_IMPACT_AUDIO: 67","CONTINUOUS_DESERT_AUDIO: 28","SCRIPT_PARSE: 382","APP_TESTS: 99","Rewind: 57","List of devices attached","probe_wall_audio_gap"]
for path in (ROOT / "build/logs").glob("*/*.log"):
    if path.stat().st_mtime<oldest: continue
    data = path.read_text(encoding="utf-8",errors="replace")
    if any(x in data for x in needles) or path.parent.name.startswith("Import-"):
        target = logs/(path.parent.name+"-"+path.name)
        shutil.copy2(path,target)
        captured.append(target.name)
(OUT / "scoped-change.patch").write_text("".join(patch),encoding="utf-8")
(OUT / "source-hashes.json").write_text(json.dumps(dict(scope="SND14-SND15 visible wall contact and instant first-sample attack",files=inventory,logs=captured,
    baseline="Task-start sources; current shared documentation minus only this task's additions",
    binary_assets="Changed WAVs and native PCM are local pinned artifacts, not embedded in the patch",git="Task-only review patch; shared index/commits unchanged"),indent=2)+"\n",encoding="utf-8")
result = subprocess.run(["git","apply","--reverse","--check","--ignore-whitespace",str(OUT/"scoped-change.patch")],cwd=ROOT,capture_output=True,text=True)
print("COLLISION_ATTACK_CHECKPOINT:",len(inventory),"files;",len(captured),"logs; reverse-check",result.returncode)
if result.returncode:
    print(result.stdout,result.stderr)
    raise SystemExit(result.returncode)
