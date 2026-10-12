"""Task-start source diff and binary hash inventory; leaves the shared index alone."""
from pathlib import Path
import difflib
import hashlib
import json
import shutil
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BEFORE = OUT / "before"
MODIFIED = [
    "game/vehicle/vehicle_audio.gd", "scripts/build_vehicle_audio.py",
    "game/tests/test_vehicle_audio.gd", "game/assets/audio/vehicles/manifest.json",
    "game/assets/audio/vehicles/NOTICE.txt", "docs/VEHICLE_AUDIO.md", "docs/DESERT_AUDIO.md",
    "licenses/ASSETS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md",
]
NEW = [
    "game/vehicle/surface_audio_model.gd", "game/vehicle/surface_audio_model.gd.uid",
    "game/tests/decode_surface_sources.gd", "game/tests/decode_surface_sources.gd.uid",
    "game/tests/test_surface_impact_audio.gd", "game/tests/test_surface_impact_audio.gd.uid",
    "game/tests/capture_surface_impact_audio.gd", "game/tests/capture_surface_impact_audio.gd.uid",
    "scripts/surface_audio_mastering.py", "scripts/fetch_surface_audio.py", "scripts/review_surface_audio.py",
    "docs/SURFACE_IMPACT_AUDIO.md",
]
NEW += [(OUT / file).relative_to(ROOT).as_posix() for file in ["audition.html", "capture-levels.json", "loop-continuity.json", "make_checkpoint.py"]]
patch = []
inventory = []

def add(path, before, after):
    if before == after:
        return
    patch.append("diff --git a/" + path + " b/" + path + "\n")
    if not before:
        patch.append("new file mode 100644\n")
    for line in difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True),
                                     fromfile="a/"+path if before else "/dev/null", tofile="b/"+path):
        patch.append(line if line.endswith("\n") else line+"\n\\ No newline at end of file\n")

def pin(path):
    target = ROOT / path
    inventory.append(dict(path=path, bytes=target.stat().st_size,
                          sha256=hashlib.sha256(target.read_bytes()).hexdigest()))

for path in MODIFIED + NEW:
    before = (BEFORE / path).read_text(encoding="utf-8") if path in MODIFIED else ""
    after = (ROOT / path).read_text(encoding="utf-8")
    add(path, before, after)
    pin(path)
old = json.loads((BEFORE / "game/assets/audio/vehicles/manifest.json").read_text())
now = json.loads((ROOT / "game/assets/audio/vehicles/manifest.json").read_text())
old_map = {item["file"]: item["sha256"] for item in old["outputs"]}
for clip in now["outputs"]:
    if old_map.get(clip["file"]) == clip["sha256"]:
        continue
    path = "game/assets/audio/vehicles/" + clip["file"]
    pin(path)
    pin(path + ".import")
    # Existing importer metadata is unchanged for replaced clips. Include the
    # newly created import as a normal source addition for a reviewable patch.
    if clip["file"] not in old_map:
        add(path+".import", "", (ROOT / (path+".import")).read_text(encoding="utf-8"))
for target in sorted(OUT.glob("*.wav")):
    pin(target.relative_to(ROOT).as_posix())
# Retain the actual relevant command logs, including failed/interrupted runs.
needles = ["SURFACE_IMPACT", "VEHICLE_AUDIO: 1438", "DESERT_AUDIO: 25", "SCRIPT_PARSE: 359", "SCRIPT_PARSE: 360", "DECODED: collision_cc0", "HANDLING_TESTS: 88", "APP_TESTS: 99", "Rewind: 57", "test_histograms"]
logs = OUT / "logs"
logs.mkdir(exist_ok=True)
captured = []
for source in (ROOT / "build/logs").glob("*/*.log"):
    if source.stat().st_mtime < (OUT / "failed-queued-capture/desert-full.wav").stat().st_mtime - 3600:
        continue
    content = source.read_text(encoding="utf-8", errors="replace")
    if any(marker in content for marker in needles) or source.parent.name in ["Doctor-1084", "Import-13952", "TestScript-39332"]:
        destination = logs / (source.parent.name + "-" + source.name)
        shutil.copy2(source,destination)
        captured.append(destination.name)
(OUT / "scoped-change.patch").write_text("".join(patch),encoding="utf-8")
(OUT / "source-hashes.json").write_text(json.dumps(dict(
    scope="SND08-SND10 collision, grass and sand audio; presentation only",
    baseline="Exact task-start source copies; current shared documentation with only this task's addition removed",
    git="Review patch/hash inventory only; no shared Git index or commit mutation",
    binary_assets="Local WAV artifacts are SHA-256 pinned; bytes are not embedded in the textual patch",
    files=inventory, captured_logs=captured,
    original_clip_hashes=old_map,
),indent=2)+"\n",encoding="utf-8")
result = subprocess.run(["git", "apply", "--reverse", "--check", "--ignore-whitespace", str(OUT / "scoped-change.patch")], cwd=ROOT, capture_output=True, text=True)
print("SCOPED_CHECKPOINT:", len(inventory), "files;", len(captured), "logs; reverse-check", result.returncode)
if result.returncode:
    print(result.stdout, result.stderr)
    raise SystemExit(result.returncode)
