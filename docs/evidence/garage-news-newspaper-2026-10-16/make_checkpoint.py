"""Reproducible task-only checkpoint, without touching the shared Git index."""
from datetime import datetime, timezone
from hashlib import sha256
import json
from pathlib import Path
import shutil
import subprocess
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
SNAPSHOT = ROOT / "build/news-newspaper-before"
old_checkpoint = json.loads((ROOT / "docs/evidence/garage-news-2026-10-16/checkpoint.json").read_text())
old_patch = (ROOT / "docs/evidence/garage-news-2026-10-16/task-only.patch").read_text()
client_hunk = old_patch.split("+++ b/game/backend/news_client.gd\n", 1)[1].split("diff --git", 1)[0]
client_before = "".join(line[1:] for line in client_hunk.splitlines(keepends=True) if line.startswith("+"))
assert sha256(client_before.encode()).hexdigest() == old_checkpoint["sha256"]["game/backend/news_client.gd"]

existing = ["AGENTS.md", "licenses/ASSETS.md", "game/export_presets.cfg", "game/ui/garage_page.gd", "game/ui/garage_news_menu.gd",
    "backend/bmt_backend/news.py", "backend/tests/test_news.py", "backend/tests/test_news_http.py",
    "game/tests/test_garage_news.gd", "game/tests/test_garage_news_native.gd", "game/tests/test_garage_news_http.gd"]
new = ["game/ui/garage_news_art.gd", "game/ui/garage_news_art.gd.uid",
    "game/assets/fonts/libre_baskerville/LibreBaskerville.ttf",
    "game/assets/fonts/libre_baskerville/LibreBaskerville.ttf.import",
    "game/assets/fonts/libre_baskerville/OFL.txt", "docs/GARAGE_NEWS_NEWSPAPER_2026_10_16.md"]
stage = ROOT / "build" / ("news-newspaper-checkpoint-" + uuid4().hex)
before, after = stage / "before", stage / "after"
before.mkdir(parents=True)
after.mkdir()
for relative in existing + new + ["game/backend/news_client.gd"]:
    target = after / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / relative, target)
    if relative in existing or relative == "game/backend/news_client.gd":
        original = before / relative
        original.parent.mkdir(parents=True, exist_ok=True)
        original.write_bytes(client_before.encode() if relative == "game/backend/news_client.gd"
            else (SNAPSHOT / relative.replace("/", "__")).read_bytes())
result = subprocess.run(["git", "diff", "--no-index", "--binary", "--", "before", "after"],
    cwd=stage, capture_output=True, check=False)
assert result.returncode == 1, result.stderr.decode()
patch = result.stdout
for source, target in [(b"a/before/", b"a/"), (b"a/after/", b"a/"), (b"b/before/", b"b/"), (b"b/after/", b"b/")]:
    patch = patch.replace(source, target)
patch_path = OUT / "task-only.patch"
patch_path.write_bytes(patch)
check = subprocess.run(["git", "apply", "--reverse", "--check", str(patch_path)],
    cwd=ROOT, capture_output=True, check=False)
assert check.returncode == 0, check.stderr.decode()
files = existing + new + ["game/backend/news_client.gd"]
checkpoint = {"scope": "Newspaper redesign only; shared files compared against this turn's snapshots. News client baseline recovered verbatim from its prior checkpoint and hash-verified. No index or HEAD mutation.",
    "sha256": {name: sha256((ROOT / name).read_bytes()).hexdigest() for name in files},
    "task_patch": "task-only.patch", "reverse_apply_check": "passed"}
(OUT / "checkpoint.json").write_text(json.dumps(checkpoint, indent=2) + "\n")
motion = ROOT / "build/news-newspaper-motion-isolated.gd"
shutil.copyfile(motion, OUT / "motion-isolated.gd.txt")
shutil.copyfile(ROOT / "build/news-newspaper-import.log", OUT / "import-initial.log")
report = {
    "created_utc": datetime.now(timezone.utc).isoformat(),
    "objective": "Creative Garage newspaper on a desk, with relevant car photograph and actual circuit outline; retain demand-only backend work.",
    "implementation": {"page": "Trackside lead story and selectable briefs; paper Friends directory; Garage return on paper",
        "car": "Retained main viewport hidden and UPDATE_DISABLED during News; existing native factory file photo for board vehicle; no remote appearance claim",
        "track": "Same indexed page query selects stored discovery; <=30 distinct outlines/page, <=96 validated points/outline, deduplicated by version ID",
        "extra_jobs": 0, "extra_sql_queries": 0, "extra_object_reads": 0, "extra_3d_worlds": 0,
        "client_browse_requests": 0, "font_bytes": 171900},
    "validation": [
        {"command": "Godot --headless --path game --script res://tests/test_garage_news.gd", "result": "19 checks, 0 failures", "log": "client.log"},
        {"command": "Godot --path game --rendering-method gl_compatibility --script res://tests/test_garage_news_native.gd", "result": "67 checks, 0 failures", "log": "native-gl.log"},
        {"command": "Godot --path game --rendering-method mobile --script res://tests/test_garage_news_native.gd", "result": "67 checks, 0 failures", "log": "native-mobile.log"},
        {"command": "python -m pytest backend/tests/test_news.py backend/tests/test_news_http.py -q", "result": "40 passed, 2 SQLite concurrency skips", "log": "backend-all.log", "junit": "backend-all.xml"},
        {"command": "python -m pytest backend/tests/test_news_http.py -q", "result": "1 passed after adding the 11th native HTTP check for exact circuit coordinates", "log": "wire-final.log", "junit": "wire.xml"},
        {"command": "Godot --headless --path game --script build/news-newspaper-motion-isolated.gd -- --evidence-root=res://../docs/evidence/garage-news-newspaper-2026-10-16/motion-headless", "result": "135 checks, 0 failures", "log": "motion-isolated.log",
         "fixture_only_substitution": ['"user://garage_menu_motion_"+TrackLibrary.unique_id()', 'ProjectSettings.globalize_path("res://../build/newspaper-motion-storage/"+TrackLibrary.unique_id())'],
         "source_sha256": sha256((ROOT / "game/tests/test_garage_menu_motion.gd").read_bytes()).hexdigest(), "executed_sha256": sha256(motion.read_bytes()).hexdigest()},
        {"command": "Godot --headless --path game --script res://tests/test_script_parse.gd", "result": "819 scripts, 0 failures", "log": "parse.log"},
        {"command": "python -m ruff check backend/bmt_backend/news.py backend/tests/test_news.py", "result": "passed"},
        {"command": "git apply --reverse --check task-only.patch", "result": "passed"}],
    "initial_corrections": ["Catalog helper typo during import; corrected to VehicleCatalog.IDS", "Fit full car photograph; move Garage action onto paper to keep result above the fold", "HTTP nested JSON floats need equivalent parsed JSON in assertion (wire-initial.log)", "Wait existing 0.65s room camera tween before comparing return pose (native-gl-camera-settling.log)", "Motion fixture user:// writes sandboxed; use an absolute workspace fixture path (motion.log, motion-relative-path-initial.log)"],
    "environment": {"engine": "Godot 4.7.2 stable Windows", "gpu": "RTX 3090", "postgres_fixture": "bmt-backend-test, originally stopped, started for tests, already stopped when cleanup was checked", "root_certificate_warning": "sandbox engine warning; no final News script errors"},
    "provenance": {"font": "https://github.com/google/fonts/tree/main/ofl/librebaskerville", "license": "game/assets/fonts/libre_baskerville/OFL.txt", "images": "Existing project-native vehicle file photographs; native code draws paper/desk/ink"},
    "limits": ["Desktop seeded-event captures; owner/physical-phone visual acceptance remains", "Existing photos identify vehicle models, not remote driver's paint or fitted parts", "Missing projection shows unavailable, without a track download", "No deployment, catalog change, phone test or APK", "Matching backend rollout remains required"]}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"files": len(files), "patch_bytes": len(patch), "reverse_check": "passed"}))
