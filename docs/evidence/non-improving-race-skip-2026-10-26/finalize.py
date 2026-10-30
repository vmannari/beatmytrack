"""Create an isolated review patch without including concurrent source edits."""
import difflib
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
EXISTING = [
    "backend/bmt_backend/admin.py", "backend/bmt_backend/app.py", "backend/bmt_backend/challenge_series.py",
    "backend/bmt_backend/challenges.py", "backend/bmt_backend/completion_reads.py", "backend/bmt_backend/economy.py",
    "backend/bmt_backend/maintenance.py", "backend/bmt_backend/rivalry.py", "backend/bmt_backend/run_signals.py",
    "backend/bmt_backend/runs.py", "backend/bmt_backend/studio.py", "backend/bmt_backend/trajectory_verifier.py",
    "backend/bmt_backend/worker.py", "backend/schemas/trajectory-v1.schema.json",
    "game/backend/backend_client.gd", "game/backend/challenges_client.gd", "game/backend/cloud_tracks.gd",
    "game/backend/finish_rating.gd", "game/backend/weekly_rivalry_client.gd", "game/core/app.gd",
    "game/ui/challenge_result_view.gd",
]
NEW = ["backend/bmt_backend/non_improving_runs.py", "backend/tests/test_non_improving_runs.py",
       "backend/tests/test_non_improving_http.py", "game/tests/test_non_improving_runs.gd",
       "game/tests/test_non_improving_runs.gd.uid", "game/tests/test_non_improving_http.gd",
       "game/tests/test_non_improving_http.gd.uid", "game/tests/fixtures/non_improving_run_v1.json",
       "docs/NON_IMPROVING_RACE_SKIP_2026_10_26.md"]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_log(name):
    data = (HERE/name).read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8")


def replace(text, new, old, count=1):
    assert text.count(new) == count, (new, text.count(new), count)
    return text.replace(new, old)


def shared_base(name, text):
    """Undo only this task in memory; never write an undo into the worktree."""
    if name == "backend/bmt_backend/admin.py":
        return replace(text, 'Run.status.in_(("verified", "skipped", "failed", "rejected"))',
                       'Run.status.in_(("verified", "failed", "rejected"))')
    if name == "backend/bmt_backend/app.py":
        return replace(text, '            "non_improving_runs_version": 1,\n', "")
    if name == "backend/bmt_backend/trajectory_verifier.py":
        text = replace(text, '"ghost", "claimed_lap_ticks"}', '"ghost"}')
        return replace(text, '''    if "claimed_lap_ticks" in replay:
        laps = replay["claimed_lap_ticks"]
        if (type(laps) is not list or len(laps) != 5
                or any(type(value) is not int or not 0 < value <= MAX_FRAMES for value in laps)
                or sum(laps) != duration(replay)):
            raise VerificationError("Invalid claimed lap timing")
''', "")
    if name == "game/core/app.gd":
        text = replace(text, '["verified","skipped","failed","rejected","expired"]',
                       '["verified","failed","rejected","expired"]')
        return replace(text, '\t\t\tticket_data["_claimed_lap_ticks"] = completed_game.track_session.lap_times.map(func(seconds: float) -> int: return roundi(seconds*120.0))\n', "")
    if name == "game/backend/backend_client.gd":
        text = replace(text, '"skipped",', "", 4)
        text = replace(text, ' and (data.status != "skipped" or data.get("skip_reason") == "no_improvement")', "")
        text = replace(text, '\tvar result: Dictionary = {"path":', '\treturn {"path":')
        text = replace(text, '\tif int(_capabilities.get("non_improving_runs_version",0)) == 1: result.result = 1\n\treturn result\n', "")
        text = replace(text, ', claimed_lap_ticks: Array = []', "")
        start = text.index('\tif not claimed_lap_ticks.is_empty():\n')
        end = text.index('\tif packed_path:', start)
        return text[:start]+text[end:]
    if name == "game/backend/cloud_tracks.gd":
        text = replace(text, '''\tif int(ticket_data.get("_wire_options",{}).get("result",0)) == 1 and ticket_data.get("_claimed_lap_ticks") is Array:
\t\trecording.claimed_lap_ticks = ticket_data._claimed_lap_ticks
''', "")
        text = replace(text, '''\t\tif not options is Dictionary or options.size() not in [2,3] or not Client._whole(options.get("path"),0,1) or not options.get("incidents") is bool or (options.size() == 3 and not options.has("result")) or (options.has("result") and not Client._whole(options.result,1,1)):
''', '''\t\tif not options is Dictionary or options.size() != 2 or not Client._whole(options.get("path"),0,1) or not options.get("incidents") is bool:
''')
        text = replace(text, '''\t\tif int(options.get("result",0)) == 1 and int(client._capabilities.get("non_improving_runs_version",0)) != 1:
\t\t\treturn {"ok":false,"status":503,"error":"SUBMISSION_SERVER_UPDATE_REQUIRED","data":{}}
\t\tvar claims: Array = loaded.get("claimed_lap_ticks",[]) if int(options.get("result",0)) == 1 else []
''', "")
        text = replace(text, 'options.incidents,int(options.path) == 1,claims))', 'options.incidents,int(options.path) == 1))')
        text = replace(text, '"skipped",', "", 2)
        text = replace(text, 'if response.data.status in ["verified","skipped"]:', 'if response.data.status == "verified":')
        return replace(text, 'status = "Race completed" if response.data.status == "skipped" else "Race verified"',
                       'status = "Race verified"')
    return None


assert "26 passed" in read_log("all-focused-final.log")
assert "1 passed" in read_log("native-reuse-http.log")
assert "NON_IMPROVING_HTTP: 17 checks, 0 failures" in read_log("native-reuse-http.log")
for renderer in ("compatibility", "mobile"):
    assert "26 checks, 0 failures" in read_log("native-"+renderer+"-final.log")

chunks, sources, concurrent = [], {}, {}
for name in EXISTING+NEW:
    path = ROOT/name
    text = path.read_text(encoding="utf-8")
    sources[name] = digest(path.read_bytes())
    before = ""
    if name in EXISTING:
        snapshot = (HERE/"before"/(name.replace("/","__")+".txt")).read_text(encoding="utf-8")
        without_task = shared_base(name, text)
        before = snapshot if without_task is None else without_task
        if without_task is not None and without_task != snapshot:
            concurrent[name] = {"task_start_sha256":digest(snapshot.encode()),
                                "current_base_without_task_sha256":digest(without_task.encode())}
    chunks.append(f"diff --git a/{name} b/{name}\n")
    if name in NEW:
        chunks.append("new file mode 100644\n")
    chunks.extend(difflib.unified_diff(before.splitlines(keepends=True), text.splitlines(keepends=True),
                  fromfile="a/"+name if name in EXISTING else "/dev/null", tofile="b/"+name))
(HERE/"checkpoint.patch").write_text("".join(chunks), encoding="utf-8", newline="\n")
checked = subprocess.run(["git","apply","--reverse","--check",str(HERE/"checkpoint.patch")],
                         cwd=ROOT, capture_output=True, text=True, check=False)
assert checked.returncode == 0, checked.stdout+checked.stderr
ruff_files = [name for name in EXISTING+NEW if name.endswith(".py") and not name.endswith("/app.py")]
lint = subprocess.run([sys.executable,"-m","ruff","check",*ruff_files],cwd=ROOT,
                      capture_output=True,text=True,check=False)
assert lint.returncode == 0, lint.stdout+lint.stderr
old_app = (HERE/"before/backend__bmt_backend__app.py.txt").read_bytes()
original_lint = subprocess.run([sys.executable,"-m","ruff","check","--stdin-filename",
    "backend/bmt_backend/app.py","--output-format","json","-"],input=old_app,cwd=ROOT,capture_output=True,check=False)

report = {
    "date":"2026-10-26", "requirements":["NIS01","NIS02","NIS03","NIS04","NIS05","NIS06","R01","Q01"],
    "owner_policy":{"skip_when_no_pb_or_competition_improvement":True,"keep_completion_rewards":True},
    "capability":"non_improving_runs_version=1", "claim":"claimed_lap_ticks", "status":"skipped",
    "skip_reason":"no_improvement", "verification_attempts_when_skipped":0,
    "normal_skip_verifier_calls":0, "explicit_competitive_reuse_verifier_calls":1,
    "new_migration_required":False, "new_privileges_required":False,
    "source_sha256":sources, "concurrent_edits_excluded":concurrent,
    "validation":{
        "focused_backend":{"passed":26,"deselected":25,"log":"all-focused-final.log"},
        "native_real_http":{"passed":1,"native_checks":17,"log":"native-reuse-http.log"},
        "native_compatibility":{"checks":26,"failures":0,"log":"native-compatibility-final.log"},
        "native_desktop_mobile":{"checks":26,"failures":0,"log":"native-mobile-final.log"},
        "parser":{"passed":True,"log":"parser.log"},
        "broad_backend":{"passed":165,"skipped":3,"deselected":114,"failed_existing":2,"log":"backend-regression.log"},
        "queue_archive_maintenance":{"passed":37,"skipped":7,"deselected":35,"failed_existing":1,"log":"related-final.log"},
        "existing_failures_reproduced_with_task_start_modules":["original-regressions.log","original-queue.log"],
        "postgresql":{"passed":False,"reason":"Configured localhost:55439 test service timed out","log":"postgres.log"},
        "ruff_owned_python":"passed", "app_existing_lint_codes":sorted({row["code"] for row in json.loads(original_lint.stdout)}),
        "checkpoint_reverse_apply_check":"passed",
    },
    "limitations":["Old recordings without lap hints conservatively retain verification",
        "Non-scoring completion authenticity is intentionally not established",
        "Skipped runs do not enter verified-only achievement/news capture",
        "PostgreSQL concurrency remains untested because the configured service is unreachable"],
    "remaining_acceptance":["Matching client/backend rollout","Owner workflow acceptance","PostgreSQL concurrency/capacity"],
    "commands":"../../../NON_IMPROVING_RACE_SKIP_2026_10_26.md",
    "checkpoint":{"path":"checkpoint.patch","sha256":digest((HERE/"checkpoint.patch").read_bytes())},
    "phone_attachment_checked":False,"physical_device_tested":False,"apk_built":False,
    "live_backend_contacted":False,"deployment":False,"owner_process_restarted":False,"commit_or_merge":False,
}
(HERE/"report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"focused_backend_passed":26,"native_http_checks":17,"skipped_verifier_calls":0,
    "explicit_reuse_verifier_calls":1,"checkpoint_reverse_check":"passed", "scope_files":len(sources),
    "concurrent_bases_preserved":sorted(concurrent)}))
