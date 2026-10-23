"""Snapshot only this task's hunks without changing the shared Git index."""
from datetime import datetime, timezone
from hashlib import sha256
import json
from pathlib import Path
import shutil
import subprocess
from uuid import uuid4
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BEFORE = ROOT / "build/news-friend-publication-before"
existing = ["AGENTS.md", "backend/README.md", "backend/bmt_backend/news.py", "backend/bmt_backend/news_models.py",
    "backend/bmt_backend/publications.py", "backend/bmt_backend/tracks.py", "backend/tests/test_news.py",
    "backend/tests/test_publication_intents.py", "backend/tests/test_news_http.py", "game/backend/news_client.gd",
    "game/ui/garage_news_menu.gd", "game/tests/test_garage_news.gd", "game/tests/test_garage_news_native.gd",
    "game/tests/test_garage_news_http.gd"]
added = ["backend/bmt_backend/migrations/versions/0039_friend_publications.py", "docs/GARAGE_FRIEND_PUBLICATIONS_2026_10_16.md"]
stage = ROOT / "build" / ("news-friend-checkpoint-" + uuid4().hex)
for side in ("before", "after"):
    (stage / side).mkdir(parents=True)
for relative in existing + added:
    target = stage / "after" / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / relative, target)
    if relative in existing:
        original = stage / "before" / relative
        original.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(BEFORE / relative.replace("/", "__"), original)
result = subprocess.run(["git", "diff", "--no-index", "--binary", "--", "before", "after"], cwd=stage, capture_output=True)
assert result.returncode == 1, result.stderr.decode()
patch = result.stdout
for source, replacement in ((b"a/before/", b"a/"), (b"a/after/", b"a/"), (b"b/before/", b"b/"), (b"b/after/", b"b/")):
    patch = patch.replace(source, replacement)
(OUT / "task-only.patch").write_bytes(patch)
reverse = subprocess.run(["git", "apply", "--reverse", "--check", str(OUT / "task-only.patch")], cwd=ROOT, capture_output=True)
assert reverse.returncode == 0, reverse.stderr.decode()
(OUT / "checkpoint.json").write_text(json.dumps({
    "scope": "Friend publication feature only. Shared files compare against their pre-edit snapshots; AGENTS snapshot taken immediately before this task's own insertion to preserve concurrent instructions. No index or HEAD mutation.",
    "sha256": {name: sha256((ROOT / name).read_bytes()).hexdigest() for name in existing + added},
    "task_patch": "task-only.patch", "reverse_apply_check": "passed"}, indent=2) + "\n")

def summary(name, domain_only=False):
    counts = {"passed": 0, "failed": 0, "skipped": 0}
    for case in ET.parse(OUT / name).iter("testcase"):
        if domain_only and "test_news_http" in case.get("classname", ""):
            continue
        key = "failed" if case.find("failure") is not None or case.find("error") is not None else "skipped" if case.find("skipped") is not None else "passed"
        counts[key] += 1
    return counts

domains = summary("backend-all.xml", domain_only=True)
wire = summary("wire-final.xml")
final_publication = summary("publication-final.xml")
assert domains == {"passed": 78, "failed": 0, "skipped": 4}, domains
assert wire == {"passed": 2, "failed": 0, "skipped": 0}, wire
assert final_publication == {"passed": 37, "failed": 0, "skipped": 2}, final_publication
report = {
    "created_utc": datetime.now(timezone.utc).isoformat(),
    "request": "Also include when a friend publishes a new track in Garage News",
    "implementation": {"kind": "friend_track", "presentation": "NEW CIRCUIT / named friend, track and actual stored circuit outline",
        "schema": "0039_friend_publications after 0038_garage_news", "backfill": False,
        "publication": "One conditional shared fact insert in actual successful publication transaction; first physical track only, no revision/retry/friend fan-out",
        "reads": "Existing inbox/status plus one <=100-friend roster read and one indexed batched publication statement only when friends exist; no per-friend roundtrips",
        "bounds": {"friends": 100, "eligible_candidates_per_friend": 31, "publication_metadata_rows": 31, "merged_page": 30, "client_cache_items": 100, "outline_points": 96, "retention_days": 90, "shared_expiry_rows_per_minute": 100},
        "new_worker_jobs": 0, "inactive_recipient_writes": 0, "track_document_reads": 0,
        "privacy": "Post-acceptance publications of current friends only; block/account/visibility checks; immediate local unfriend removal; scope fences retained"},
    "validation": [
        {"command": "python -m pytest backend/tests/test_news.py backend/tests/test_publication_intents.py backend/tests/test_news_http.py -q", "domain_result": domains,
         "log": "backend-all.log", "junit": "backend-all.xml", "initial_wire_failure": "Fixture used seed()'s now()-1 publication time, putting it before friendship acceptance; product correctly excluded it"},
        {"command": "python -m pytest backend/tests/test_news_http.py -q", "result": wire, "native_checks": [11, 14], "log": "wire-final.log", "junit": "wire-final.xml"},
        {"command": "python -m pytest backend/tests/test_news.py backend/tests/test_publication_intents.py -k 'publication and not upgrade' -q", "result": final_publication,
         "reason": "Both databases rerun after consolidating capture into one conditional SQL insert", "log": "publication-final.log", "junit": "publication-final.xml"},
        {"command": "Godot --headless --path game --script res://tests/test_garage_news.gd", "result": "23 checks, 0 failures", "log": "client.log"},
        {"command": "Godot --path game --rendering-method gl_compatibility --script res://tests/test_garage_news_native.gd", "result": "79 checks, 0 failures", "log": "native-gl.log"},
        {"command": "Godot --path game --rendering-method mobile --script res://tests/test_garage_news_native.gd", "result": "79 checks, 0 failures", "log": "native-mobile.log"},
        {"command": "Godot --headless --path game --script res://tests/test_script_parse.gd", "result": "820 scripts, 0 failures", "log": "parse.log"},
        {"command": "python -m ruff check changed Python source/tests", "result": "passed", "log": "ruff.log"},
        {"command": "git apply --reverse --check task-only.patch", "result": "passed"}],
    "proof": ["Verified and legacy publication hooks", "No facts until successful publication; rollback, retries and revisions", "No worker demand or recipient inbox writes from publication", "Pending/old/nonfriend/self/hidden/archived/disabled/removed/blocked filtering", "75 mixed records paginate exactly with equal timestamps", "100-friend read still uses two statements, author/time index checked on SQLite and PostgreSQL", "Cached unfriend removal and actual Bearer/JSON wire", "Actual native three-size newspaper capture with real Dust cloud outline and retained Garage resources"],
    "initial_fixtures": ["Second publication needs an extra test publishing slot; pending requester direction corrected (fixtures-initial.log)", "HTTP seed dated publication before acceptance; corrected to intended post-acceptance time (backend-all.log, wire-final.log)"],
    "environment": {"godot": "4.7.2 stable Windows / RTX 3090", "postgres": "Disposable bmt-backend-test started from stopped; left running because another database connection was present after task tests", "root_certificate_warning": "Sandbox engine warning, no final News script errors"},
    "limits": ["Source and disposable local fixtures only; matching API/worker/client plus migration 0039 release still required", "No retained backend migration, deployment, catalog mutation, phone run or APK", "No measured production load/capacity/phone latency claim; owner/physical-phone acceptance remains"]}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"files": len(existing) + len(added), "patch_bytes": len(patch), "reverse_check": "passed", "domain": domains, "wire": wire, "final_publication": final_publication}))
