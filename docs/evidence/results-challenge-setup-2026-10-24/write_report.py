"""Capture the results-setup task delta without including earlier workspace edits."""
from pathlib import Path
import difflib
import hashlib
import json

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
SUMMARY = (
    "2026-10-24 RCS01-RCS03/R01/G01/Q01: Race-results Create challenge opens a "
    "dedicated single-race setup with only One-to-one/Group, duration and tries. "
    "The exact finished ticket/track/car/time, verification/account fences and "
    "explicit Create & share remain; Back restores the retained results. Menu "
    "creation and setup-drive continuation retain their original rules. Focused "
    "74headless/82Compatibility/82desktopMobile, actual actions27/34, existing "
    "cards223/App141/parser1105 and real HTTP2 (native54/52) pass. Native views, "
    "commands, retained launch corrections, hashes and scoped checkpoint: "
    "docs/RESULTS_CHALLENGE_SETUP_2026_10_24.md and "
    "docs/evidence/results-challenge-setup-2026-10-24/report.json. Client reload "
    "and owner/device acceptance remain. No device attachment check/test, APK, "
    "live mutation, social send, deployment or owner-process restart; concurrent "
    "work preserved."
)

for relative in ("AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"):
    path = ROOT / relative
    data = path.read_bytes()
    marker = b"<!-- RESULTS-CHALLENGE-SETUP-20261024 -->"
    if not data.startswith(marker):
        title = "## Results-only challenge setup override (2026-10-24)\n" if relative == "AGENTS.md" else ""
        block = f"{marker.decode()}\n{title}{SUMMARY}\n<!-- /RESULTS-CHALLENGE-SETUP-20261024 -->\n\n"
        path.write_bytes(block.encode("utf-8") + data)

modified = [
    "game/core/app.gd", "game/ui/challenge_create.gd",
    "game/tests/test_challenge_result_action.gd", "game/tests/test_challenges_http.gd",
    "docs/CHALLENGES.md", "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md",
]
added = [
    "game/tests/test_results_challenge_setup.gd",
    "game/tests/test_results_challenge_setup.gd.uid",
    "docs/RESULTS_CHALLENGE_SETUP_2026_10_24.md",
]
patch = []
fingerprints = {}
for relative in modified + added:
    path = ROOT / relative
    old_path = EVIDENCE / "before" / relative
    old = old_path.read_bytes() if relative in modified else b""
    new = path.read_bytes()
    patch.append(f"diff --git a/{relative} b/{relative}\n")
    if relative in added:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(
        old.decode("utf-8-sig").splitlines(keepends=True),
        new.decode("utf-8-sig").splitlines(keepends=True),
        fromfile=f"a/{relative}" if relative in modified else "/dev/null",
        tofile=f"b/{relative}",
    ))
    fingerprints[relative] = {
        "before_sha256": hashlib.sha256(old).hexdigest() if relative in modified else None,
        "after_sha256": hashlib.sha256(new).hexdigest(),
    }
(EVIDENCE / "task.patch").write_text("".join(patch), encoding="utf-8", newline="\n")

runs = [
    ("focused-headless-final.log", "test_results_challenge_setup", "headless", 74),
    ("focused-compatibility-complete.log", "test_results_challenge_setup", "Compatibility", 82),
    ("focused-mobile-final.log", "test_results_challenge_setup", "desktop Mobile", 82),
    ("actions-headless.log", "test_challenge_result_action", "headless", 27),
    ("actions-compatibility.log", "test_challenge_result_action", "Compatibility", 34),
    ("cards-headless.log", "test_challenge_cards", "headless", 223),
    ("app.log", "test_app", "headless", 141),
    ("parser.log", "test_script_parse", "headless", 1105),
]
report_runs = []
def read_log(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")

for log, test, renderer, count in runs:
    content = read_log(EVIDENCE / "logs" / log)
    assert f"{count} " in content and "0 failures" in content, log
    assert "SCRIPT ERROR" not in content and "FAIL:" not in content, log
    timeout = 180 if test == "test_challenge_cards" else 150 if test in ("test_app", "test_script_parse") or log == "actions-compatibility.log" else 120
    command = f"powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/{test}.gd -CommandTimeoutSeconds {timeout}"
    if renderer != "headless":
        command += " -Graphical -RenderingMethod " + ("mobile" if renderer == "desktop Mobile" else "gl_compatibility")
    report_runs.append({"test":test,"renderer":renderer,"checks":count,"failures":0,"log":"logs/"+log,"command":command})
http = read_log(EVIDENCE / "logs/http-with-path.log")
assert "2 passed" in http and "CHALLENGES_HTTP: 54 checks, 0 failures" in http and "CHALLENGES_HTTP: 52 checks, 0 failures" in http
report_runs.append({"test":"backend/tests/test_challenges_http.py","passed":2,"native_checks":[54,52],"failures":0,"warnings":11,"log":"logs/http-with-path.log","command":"$env:PYTHONPATH = Join-Path (Get-Location) 'backend'; & .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_challenges_http.py -q -s --basetemp=build/results-challenge-http-pytest"})

artifacts = {}
for path in sorted(EVIDENCE.rglob("*")):
    if path.is_file() and "before" not in path.relative_to(EVIDENCE).parts and path.name != "report.json":
        artifacts[path.relative_to(EVIDENCE).as_posix()] = {"bytes":path.stat().st_size,"sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
report = {
    "date":"2026-10-24", "requirements":["RCS01","RCS02","RCS03","R01","G01","Q01"],
    "engine":"4.7.2.stable.official.ed1daf0bf",
    "environment":"Windows, isolated workspace APPDATA; disposable loopback SQLite services and fixture accounts. RTX 3090 desktop Compatibility and desktop Mobile; no physical-device test.",
    "changed_files":fingerprints, "runs":report_runs, "artifacts":artifacts,
    "checkpoint":"task.patch is a task-only delta against captured starting files, preserving pre-existing edits. No commit, deployment or owner-process restart.",
    "retained_corrections":[
        "Sandbox Godot startup could not read the Windows certificate store; successful runs used approved host access and workspace-only saves, with no TLS setting change.",
        "Initial pytest invocation lacked backend PYTHONPATH; corrected invocation passed both HTTP tests.",
        "Native inspection prompted compact horizontal options in landscape. Short windows scroll the choices and retain the visible final action; final tests verify last-choice reachability.",
        "Passing HTTP tests retain 11 dependency/index reflection warnings and temporary results-comparison 503 responses during fixture preparation."
    ],
    "remaining_acceptance":["Reload or rebuild the client.","Owner appearance/interaction acceptance.","Physical-device touch/readability acceptance; no attachment check or device test performed."],
    "not_performed":["APK export/install","production/account mutation","deployment","purchase","social send","owner-process restart"],
}
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(f"Recorded {len(fingerprints)} source/doc files, {len(report_runs)} passing runs and {len(artifacts)} artifacts")
