"""Record completed local checks and a scoped regression-test checkpoint."""
import difflib
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent


def read_log(name):
    data = (OUT / "logs" / name).read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")


runs = [
    {"log":"backend.log", "expected":"43 passed, 2 skipped, 53 deselected", "passed":43, "skipped":2, "deselected":53, "command":"$env:PYTHONPATH = Join-Path (Get-Location) 'backend'; & .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_challenges.py backend/tests/test_challenge_discovery.py backend/tests/test_custom_challenge_tracks.py backend/tests/test_challenge_series.py -q -k 'sqlite and not migration' --basetemp=build/challenge-check-unit-2026-10-25"},
    {"log":"http-baseline.log", "expected":"2 passed", "passed":2, "native_checks":[54,52], "command":"$env:PYTHONPATH = Join-Path (Get-Location) 'backend'; & .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_challenges_http.py -q -s --basetemp=build/challenge-check-http-baseline-2026-10-25"},
    {"log":"group-http-final.log", "expected":"CHALLENGE_GROUP_HTTP: 58 checks, 0 failures", "passed":1, "native_checks":58, "command":"$env:PYTHONPATH = Join-Path (Get-Location) 'backend'; & .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_challenge_group_http.py -q -s --basetemp=build/challenge-group-http-final-2026-10-25"},
    {"log":"multi-http.log", "expected":"CHALLENGE_MULTI_HTTP: 26 checks, 0 failures", "passed":1, "native_checks":26, "command":"$env:PYTHONPATH = Join-Path (Get-Location) 'backend'; & .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_challenge_multi_http.py -q -s --basetemp=build/challenge-check-multi-http-2026-10-25"},
]
for script, log, count, timeout, graphical in [
    ("test_challenge_race_flows", "race-flows.log", 34, 150, False),
    ("test_challenges", "native-challenges.log", 216, 150, False),
    ("test_challenge_result_view", "result-view.log", 293, 120, False),
    ("test_results_challenge_setup", "results-setup-compatibility.log", 82, 120, True),
    ("test_script_parse", "parser.log", 1120, 150, False),
]:
    command = f"powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/{script}.gd -CommandTimeoutSeconds {timeout}"
    if graphical:
        command += " -Graphical -RenderingMethod gl_compatibility"
    runs.append({"log":log, "expected":f"{count} ", "checks":count, "failures":0, "command":command})
runs.append({"log":"ruff.log", "expected":"All checks passed!", "command":"& .tools/backend-secure-venv/Scripts/python.exe -m ruff check backend/tests/test_challenge_group_http.py"})
for run in runs:
    content = read_log(run["log"])
    assert run["expected"] in content, run["log"]
    assert "FAIL:" not in content and "SCRIPT ERROR" not in content, run["log"]

modified = ["docs/CHALLENGES.md"]
added = ["backend/tests/test_challenge_group_http.py", "game/tests/test_challenge_group_http.gd", "docs/CHALLENGE_CHECK_2026_10_25.md"]
patch = []
changed = {}
for relative in modified + added:
    old = (OUT / "before" / relative).read_bytes() if relative in modified else b""
    new = (ROOT / relative).read_bytes()
    patch.append(f"diff --git a/{relative} b/{relative}\n")
    if relative in added:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(old.decode("utf-8-sig").splitlines(keepends=True), new.decode("utf-8-sig").splitlines(keepends=True), fromfile=f"a/{relative}" if relative in modified else "/dev/null", tofile=f"b/{relative}"))
    changed[relative] = {"before_sha256":hashlib.sha256(old).hexdigest() if old else None, "after_sha256":hashlib.sha256(new).hexdigest()}
(OUT / "task.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
sources = ["game/core/app.gd", "game/ui/challenge_create.gd", "game/backend/challenges_client.gd", "backend/bmt_backend/challenges.py", "backend/bmt_backend/challenge_series.py", "backend/bmt_backend/challenge_models.py", "backend/tests/test_challenges.py", "backend/tests/test_challenges_http.py", "game/tests/test_challenges_http.gd"]
source_hashes = {name:hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sources}
artifacts = {path.relative_to(OUT).as_posix():{"bytes":path.stat().st_size,"sha256":hashlib.sha256(path.read_bytes()).hexdigest()} for path in sorted(OUT.rglob("*")) if path.is_file() and "before" not in path.relative_to(OUT).parts and path.name != "report.json"}
report = {
    "date":"2026-10-25", "requirements":["CHK01-individual", "CHK02-group", "CHK03-retries-and-account-fences"],
    "conclusion":"All final local checks passed. No challenge runtime fix needed. Added a real three-account group regression.",
    "engine":"4.7.2.stable.official.ed1daf0bf", "task_start_commit":"3597d01eb", "runs":runs,
    "environment":"Windows; isolated workspace APPDATA under build/challenge-check-2026-10-25; disposable loopback SQLite services and fixture accounts. One native Compatibility UI run; other native runs headless. No physical-device or production-service checks.",
    "source_hashes_at_report":source_hashes, "changed_files":changed, "artifacts":artifacts,
    "initial_group_run":{"log":"logs/group-http-initial.log", "checks":58, "failures":2, "cause":"New fixture incorrectly required an empty selected invitation after logout. Guest discovery can repopulate public invitations. Corrected the test to wait for guest refresh and verify empty private result/polling/outcome identity and no joined/self membership; runtime unchanged. All racing/ranking/try checks already passed.", "other_fixture_corrections":"Observe completed source lookup before starting another; Python import formatting."},
    "excluded":"PostgreSQL and migrations excluded from the selected backend run; two SQLite row-concurrency skips retained. No load certification.",
    "warnings":"Existing Starlette/index-reflection warnings and temporary comparison-unavailable responses remain in passing logs.",
    "not_performed":["physical-device test", "device attachment check", "APK", "production check/mutation", "deployment", "purchase", "social send", "owner-process restart"],
    "concurrency":"Concurrent tutorial and Studio changes preserved. Runtime challenge files and existing tests were not edited by this task. Generated build identity changes are outside the scoped patch.",
}
(OUT / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(f"Recorded {len(runs)} passing checks; checkpoint contains {len(changed)} files")
