"""Record only this menu-loop task without staging the shared worktree."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
summary = (
    "2026-10-11 MUS36-MUS37/SND05/MUS35/SND33/G01/R01/Q01: owner selects "
    "Exploration 3_take-3.mp3 as looping menu background. Original preserved; "
    "110.852404s stereo PCM/fade-out trim/1.995125s cosine overlap/quiet cut/"
    "-3dBFS peak/existing cyclic guard. Menu-results only; races remain silent. "
    "Final Import0/soundtrack1158/biome42/nativecapture9/PCM review pass; "
    "two actual wraps/no silent gap/clipping/exact delivered mute. Initial "
    "sandbox/QOA/seam/focus/fixture issues corrected and documented. Doctor "
    "no phone attached/no device listening/export-install/fullValidate/"
    "physics/backend/deploy. Source-license and owner listening acceptance "
    "pending. Files/commands/audio/task-only patch: docs/MENU_EXPLORATION.md.\n\n"
)
patches = []
for filename in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    path = ROOT / filename
    before = path.read_text(encoding="utf-8-sig")
    if not before.startswith(summary):
        after = summary+before
        path.write_text(after, encoding="utf-8")
        patches.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                          fromfile="a/"+filename, tofile="b/"+filename))
for filename, saved in [("game/soundtrack/audio_world.gd", "audio_world.gd"),
                        ("docs/music/STATE.md", "STATE.md")]:
    before = (OUT / "before" / saved).read_text(encoding="utf-8-sig")
    after = (ROOT / filename).read_text(encoding="utf-8-sig")
    patches.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                      fromfile="a/"+filename, tofile="b/"+filename))
testfile = "game/tests/test_soundtrack.gd"
after = (ROOT / testfile).read_text(encoding="utf-8-sig")
before = after
start = before.index("\tvar menu_manifest:")
end = before.index("\tcheck(menu.format", start)
before = before[:start]+before[end:]
before = before.replace("menu.loop_end == menu_frames", "menu.loop_end == 1512000")
before = before.replace("complete exact menu loop without", "complete exact musical menu loop without")
before = before.replace("(menu_frames + 1) * 4", "1512001 * 4")
patches.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                  fromfile="a/"+testfile, tofile="b/"+testfile))
(OUT / "task-only.patch").write_text("".join(patches), encoding="utf-8")
files = [ROOT / "scripts/prepare_menu_exploration.py", ROOT / "game/tests/capture_menu_exploration.gd",
         ROOT / "game/soundtrack/audio_world.gd", ROOT / testfile, ROOT / "docs/MENU_EXPLORATION.md",
         ROOT / "archive/music/menu-exploration-2026-10-11/Exploration 3_take-3.mp3"]
files += list((ROOT / "game/assets/audio/menu_exploration_v1").iterdir())
files += [OUT / "task-only.patch", OUT / "audio-analysis.json", OUT / "native-audio-review.json"]
record = {"base_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
          "checkpoint": "task-only patch and exact file hashes; no Git commit/staging",
          "files": [{"path": str(path.relative_to(ROOT)), "bytes": path.stat().st_size,
                     "sha256": hashlib.sha256(path.read_bytes()).hexdigest()} for path in files if path.is_file()]}
(OUT / "checkpoint.json").write_text(json.dumps(record, indent=2)+"\n", encoding="utf-8")
print("MENU_CHECKPOINT:", len(record["files"]), "files; existing worktree/index preserved")
