"""This audio slice's source diff and binary/evidence hashes; no shared-index writes."""
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
    "game/tests/test_vehicle_audio.gd", "game/tests/test_surface_impact_audio.gd", "game/tests/test_desert_audio.gd", "game/tests/test_effect_timing.gd",
    "game/assets/audio/vehicles/manifest.json", "game/assets/audio/vehicles/NOTICE.txt",
    "docs/SURFACE_IMPACT_AUDIO.md", "docs/DESERT_AUDIO.md", "licenses/ASSETS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md",
]
new = [
    "game/tests/test_continuous_desert_audio.gd", "game/tests/test_continuous_desert_audio.gd.uid",
    "game/tests/capture_continuous_desert_audio.gd", "game/tests/capture_continuous_desert_audio.gd.uid",
    "scripts/review_continuous_desert_audio.py", "docs/DESERT_CONTINUOUS_AUDIO.md",
    "game/assets/audio/vehicles/sand_debris.wav.import",
]
new += [(OUT / file).relative_to(ROOT).as_posix() for file in ["audition.html","audio-review.json","loop-continuity.json","make_checkpoint.py"]]
patch = []
inventory = []

def pin(path):
    target = ROOT / path
    inventory.append(dict(path=path,bytes=target.stat().st_size,sha256=hashlib.sha256(target.read_bytes()).hexdigest()))

for path in modified+new:
    before = (BEFORE / path).read_text(encoding="utf-8") if path in modified else ""
    after = (ROOT / path).read_text(encoding="utf-8")
    if before != after:
        patch.append("diff --git a/"+path+" b/"+path+"\n")
        if not before: patch.append("new file mode 100644\n")
        for line in difflib.unified_diff(before.splitlines(keepends=True),after.splitlines(keepends=True),fromfile="a/"+path if before else "/dev/null",tofile="b/"+path):
            patch.append(line if line.endswith("\n") else line+"\n\\ No newline at end of file\n")
    pin(path)
pin("game/assets/audio/vehicles/sand_debris.wav")
for path in sorted(OUT.glob("*.wav")): pin(path.relative_to(ROOT).as_posix())
logs = OUT / "logs"
logs.mkdir(exist_ok=True)
captured = []
oldest = (BEFORE / "game/assets/audio/vehicles/manifest.json").stat().st_mtime
needles = ["CONTINUOUS_DESERT","VEHICLE_AUDIO: 1442","SURFACE_IMPACT_AUDIO: 67","DESERT_AUDIO: 25","EFFECT_TIMING_TESTS: 40","SCRIPT_PARSE: 368","SCRIPT_PARSE: 370","APP_TESTS: 99","Rewind: 57","List of devices attached"]
for path in (ROOT / "build/logs").glob("*/*.log"):
    if path.stat().st_mtime < oldest: continue
    text = path.read_text(encoding="utf-8",errors="replace")
    if any(marker in text for marker in needles) or path.parent.name.startswith("Import-"):
        destination = logs / (path.parent.name+"-"+path.name)
        shutil.copy2(path,destination)
        captured.append(destination.name)
(OUT / "scoped-change.patch").write_text("".join(patch),encoding="utf-8")
(OUT / "source-hashes.json").write_text(json.dumps(dict(
    scope="SND12-SND13 continuous desert noise, subdued engine balance and slight speed-frequency movement",
    baseline="Task-start sources; shared documentation baseline excludes only this task's additions",
    files=inventory,logs=captured,binary_assets="New WAV and actual mixer recordings are pinned local artifacts, not embedded in the patch",
    git="Task-only review patch/inventory; shared index and commits untouched",
),indent=2)+"\n",encoding="utf-8")
result = subprocess.run(["git","apply","--reverse","--check","--ignore-whitespace",str(OUT/"scoped-change.patch")],cwd=ROOT,capture_output=True,text=True)
print("CONTINUOUS_DESERT_CHECKPOINT:",len(inventory),"files;",len(captured),"logs; reverse-check",result.returncode)
if result.returncode:
    print(result.stdout,result.stderr)
    raise SystemExit(result.returncode)
