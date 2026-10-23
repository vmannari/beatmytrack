"""Keep this UI-only task separate from concurrent workspace changes."""
from datetime import datetime, timezone
from hashlib import sha256
import json
from pathlib import Path
import shutil
import subprocess
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BASE = ROOT / "build/news-examples-before"
existing = ["AGENTS.md", "game/ui/garage_news_menu.gd", "game/tests/test_garage_news.gd", "game/tests/test_garage_news_native.gd"]
new = ["game/ui/garage_news_examples.gd", "game/ui/garage_news_examples.gd.uid", "docs/GARAGE_NEWS_LOCAL_STORIES_2026_10_16.md"]
stage = ROOT / "build" / ("news-examples-checkpoint-" + uuid4().hex)
for side in ("before", "after"):
    (stage / side).mkdir(parents=True)
for name in existing + new:
    target = stage / "after" / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / name, target)
    if name in existing:
        before = stage / "before" / name
        before.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(BASE / name.replace("/", "__"), before)
result = subprocess.run(["git", "diff", "--no-index", "--binary", "--", "before", "after"], cwd=stage, capture_output=True)
assert result.returncode == 1
patch = result.stdout
for old, replacement in ((b"a/before/", b"a/"), (b"a/after/", b"a/"), (b"b/before/", b"b/"), (b"b/after/", b"b/")):
    patch = patch.replace(old, replacement)
(OUT / "task-only.patch").write_bytes(patch)
check = subprocess.run(["git", "apply", "--reverse", "--check", str(OUT / "task-only.patch")], cwd=ROOT, capture_output=True)
assert check.returncode == 0, check.stderr.decode()
(OUT / "checkpoint.json").write_text(json.dumps({
    "scope": "Local newspaper stories and renderer selection only; no backend source/data changes. Shared-file snapshots taken before each owned edit. No Git index or HEAD mutation.",
    "sha256": {name: sha256((ROOT / name).read_bytes()).hexdigest() for name in existing + new},
    "task_patch": "task-only.patch", "reverse_apply_check": "passed"}, indent=2) + "\n")
for log, marker in (("client.log", "GARAGE NEWS: 29 checks, 0 failures"), ("native-gl.log", "GARAGE NEWS NATIVE: 112 checks, 0 failures"),
    ("native-mobile.log", "GARAGE NEWS NATIVE: 112 checks, 0 failures"), ("parse.log", "SCRIPT_PARSE: 830 scripts, 0 failures")):
    data = (OUT / log).read_bytes()
    content = data.decode("utf-16") if data.startswith((b"\xff\xfe", b"\xfe\xff")) else data.decode("utf-8", errors="replace")
    assert marker in content, log
report = {"created_utc": datetime.now(timezone.utc).isoformat(),
    "request": "Add example stories; owner clarifies that they should look like normal stories",
    "behavior": "Five local dictionaries use the ordinary newspaper when account news is empty/unavailable. Real available news replaces them automatically. No example tab/badge, no mixing or insertion into account data.",
    "stories": ["Mira publishes Dust cloud", "1,000 racers on Underpass", "Jules sets a Formula lap record", "Noa beats a Compact track time", "Classic lap time drops outside top 5%"],
    "bounds": {"stories": 5, "packaged_outlines": 2, "points_per_outline": 96, "extra_api_reads_for_browsing": 0, "extra_jobs": 0, "extra_live_renderers": 0, "account_or_record_writes": 0},
    "validation": [
        {"command": "Godot --headless --path game --script res://tests/test_garage_news.gd", "result": "29 checks, 0 failures", "log": "client.log"},
        {"command": "Godot --path game --rendering-method gl_compatibility --script res://tests/test_garage_news_native.gd -- --evidence-root=res://../docs/evidence/garage-news-examples-2026-10-16", "result": "112 checks, 0 failures", "log": "native-gl.log"},
        {"command": "Godot --path game --rendering-method mobile --script res://tests/test_garage_news_native.gd -- --evidence-root=res://../docs/evidence/garage-news-examples-2026-10-16", "result": "112 checks, 0 failures", "log": "native-mobile.log"},
        {"command": "Godot --headless --path game --script res://tests/test_script_parse.gd", "result": "830 scripts, 0 failures", "log": "parse.log"},
        {"command": "git apply --reverse --check task-only.patch", "result": "passed"}],
    "evidence": "Guest, unavailable server, empty actual feed, normal folio, all five packaged outlines, API/account isolation, automatic live replacement and retained Garage at 960/1280/1600px",
    "provenance": {str(path): sha256((ROOT / path).read_bytes()).hexdigest() for path in ("game/tests/fixtures/underpass.json", "game/tests/fixtures/dust_cloud.json")},
    "environment": "Godot 4.7.2 stable Windows / RTX 3090; known sandbox root-certificate warning; no final script errors",
    "limits": ["Local UI/data only; no backend code, migration or data changes", "No phone check/test, APK or deployment", "Owner/phone visual acceptance remains"]}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"files": len(existing)+len(new), "patch_bytes": len(patch), "reverse_check": "passed"}))
