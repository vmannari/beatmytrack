"""Sound timing slice only: original-source diffs, actual commands and binary hashes."""
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
    "game/vehicle/vehicle_audio.gd", "scripts/build_vehicle_audio.py", "scripts/surface_audio_mastering.py",
    "game/tests/test_vehicle_audio.gd", "game/tests/test_shallow_collisions.gd",
    "game/assets/audio/vehicles/manifest.json", "game/assets/audio/vehicles/NOTICE.txt",
    "docs/SURFACE_IMPACT_AUDIO.md", "licenses/ASSETS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md",
]
new = [
    "game/tests/test_effect_timing.gd", "game/tests/test_effect_timing.gd.uid",
    "game/tests/probe_effect_timing.gd", "game/tests/probe_effect_timing.gd.uid",
    "game/tests/capture_effect_timing.gd", "game/tests/capture_effect_timing.gd.uid",
    "scripts/review_effect_timing.py", "docs/EFFECT_TIMING.md",
]
new += [(OUT / file).relative_to(ROOT).as_posix() for file in [
    "audition.html", "before-dispatch.json", "after-dispatch.json", "timing-report.json", "loop-continuity.json", "make_checkpoint.py",
]]
patch = []
inventory = []

def pin(path):
    target = ROOT / path
    inventory.append(dict(path=path, bytes=target.stat().st_size, sha256=hashlib.sha256(target.read_bytes()).hexdigest()))

for path in modified + new:
    before = (BEFORE/path).read_text(encoding="utf-8") if path in modified else ""
    after = (ROOT/path).read_text(encoding="utf-8")
    if before != after:
        patch.append("diff --git a/"+path+" b/"+path+"\n")
        if not before: patch.append("new file mode 100644\n")
        for line in difflib.unified_diff(before.splitlines(keepends=True),after.splitlines(keepends=True),fromfile="a/"+path if before else "/dev/null",tofile="b/"+path):
            patch.append(line if line.endswith("\n") else line+"\n\\ No newline at end of file\n")
    pin(path)
for path in ["game/assets/audio/vehicles/chassis.wav", "game/assets/audio/vehicles/chassis.wav.import"]:
    pin(path)
for path in sorted(OUT.glob("*.wav")):
    pin(path.relative_to(ROOT).as_posix())
logs = OUT / "logs"
logs.mkdir(exist_ok=True)
captured_logs = []
needles = ["EFFECT_TIMING", "VEHICLE_AUDIO: 1438", "SURFACE_IMPACT_AUDIO: 67", "DESERT_AUDIO: 25", "SHALLOW_COLLISION_TESTS: 20268", "SCRIPT_PARSE: 366", "APP_TESTS: 99", "Rewind: 57", "List of devices attached"]
oldest = (OUT / "failed-cooldown-baseline.json").stat().st_mtime-300
for path in (ROOT / "build/logs").glob("*/*.log"):
    if path.stat().st_mtime < oldest: continue
    text = path.read_text(encoding="utf-8",errors="replace")
    if any(marker in text for marker in needles) or path.parent.name.startswith("Import-"):
        target = logs / (path.parent.name+"-"+path.name)
        shutil.copy2(path,target)
        captured_logs.append(target.name)
(OUT / "scoped-change.patch").write_text("".join(patch),encoding="utf-8")
(OUT / "source-hashes.json").write_text(json.dumps(dict(
    scope="SND11 event timing: direct collision dispatch and front-loaded chassis",
    baseline="Task-start source copies and exact prior event assertions; current shared documentation minus this task's addition",
    files=inventory,logs=captured_logs,
    binary_assets="WAV bytes remain pinned local artifacts, not embedded in the text patch",
    git="Reviewable scoped patch only; shared index and commits left alone",
),indent=2)+"\n",encoding="utf-8")
result = subprocess.run(["git","apply","--reverse","--check","--ignore-whitespace",str(OUT/"scoped-change.patch")],cwd=ROOT,capture_output=True,text=True)
print("TIMING_CHECKPOINT:",len(inventory),"pinned files;",len(captured_logs),"logs; reverse-check",result.returncode)
if result.returncode:
    print(result.stdout,result.stderr)
    raise SystemExit(result.returncode)
