"""Build the task-only checkpoint without touching the main Git index."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
FILES = [
    "game/backend/weekly_rivalry_client.gd",
    "game/tests/test_rivalry_car_switch.gd",
    "game/tests/test_rivalry_car_switch.gd.uid",
]


def normalized(path):
    if not path.exists():
        return ""
    data = path.read_bytes()
    encoding = "utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig"
    return data.decode(encoding).replace("\r\n", "\n")


def run(arguments, cwd):
    result = subprocess.run(arguments, cwd=cwd, text=True, capture_output=True)
    assert result.returncode == 0, (arguments, result.stdout, result.stderr)
    return {"argv": arguments, "exit_code": result.returncode, "stdout": result.stdout, "stderr": result.stderr}


patch = ""
for name in FILES:
    before = EVIDENCE / "before" / name
    patch += "".join(difflib.unified_diff(
        normalized(before).splitlines(True), normalized(ROOT / name).splitlines(True),
        fromfile="a/" + name if before.exists() else "/dev/null", tofile="b/" + name,
    ))
patch_path = EVIDENCE / "task.patch"
patch_path.write_text(patch, encoding="utf-8", newline="\n")
checkpoint = ROOT / "build/rivalry-car-switch/checkpoint"
checkpoint.mkdir(parents=True, exist_ok=True)
receipts = [run(["git", "init", "--quiet"], checkpoint)]
for name in FILES:
    destination = checkpoint / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    before = EVIDENCE / "before" / name
    if before.exists():
        destination.write_text(normalized(before), encoding="utf-8", newline="\n")
    elif destination.exists():
        destination.unlink()
receipts.append(run(["git", "apply", "--check", "--whitespace=error-all", str(patch_path)], checkpoint))
receipts.append(run(["git", "apply", "--whitespace=error-all", str(patch_path)], checkpoint))
receipts.append(run(["git", "apply", "--reverse", "--check", "--whitespace=error-all", str(patch_path)], checkpoint))
assert all(normalized(checkpoint / name) == normalized(ROOT / name) for name in FILES)

tests = []
for log in sorted(EVIDENCE.glob("*.log")):
    contents = normalized(log)
    result = re.findall(r"([A-Z_]+): (\d+) (checks|scripts), (\d+) failures", contents)
    timeout = 120 if log.stem.startswith("baseline") or log.stem == "fixed-headless" else 180
    script = log.stem if log.stem.startswith("test_") else "test_rivalry_car_switch"
    command = "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/" + script + ".gd -CommandTimeoutSeconds " + str(timeout)
    if "compatibility" in log.stem:
        command += " -Graphical -RenderingMethod gl_compatibility"
    if log.stem == "final-mobile":
        command += " -Graphical -RenderingMethod mobile -TestArgument '--compact'"
    if log.stem == "import":
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 240"
    tests.append({"log": log.name, "command": command, "results": result,
                  "client_builds": re.findall(r"Client build: ([\w.-]+)", contents),
                  "sha256": hashlib.sha256(log.read_bytes()).hexdigest()})
for name in ["final-headless", "final-compatibility", "final-mobile", "test_automatic_rivalry_flow",
             "test_menu_loading_speed", "test_rivalry_entry", "test_rivalry_join_failure",
             "test_rivalry_week_completion", "test_app", "test_script_parse"]:
    entry = next(item for item in tests if item["log"] == name + ".log")
    assert entry["results"] and all(result[3] == "0" for result in entry["results"]), entry

tracking = """<!-- RIVALRY-CAR-SWITCH-20261028 -->
## Rivalry car switches publish the final standings once (2026-10-28)
RCS01-RCS03/R01/Q01: Owner reports several different standings after changing car. Scope changes show existing loading before appearance sync; saved scores are bypassed during switches/retries and automatic enrollment publishes only its final response. Same-car refresh, startup cache, retry and generation fences remain. Actual-App original36/23fail becomes36/0 headless and42/0 each desktop renderer; six views each cover loading/enrollment/final/failure/recovery. Existing automatic14/cache27/entry66/join-failure38/rollover38/App141/parser1377 pass. Initial sandbox certificate, fixture-path and concurrent missing/unimported Hovercraft art findings remain; final native runs use actual imported art. One runtime source/new regression; original tests and concurrent work preserved. Commands, hashes, views and checked source-only checkpoint: docs/RIVALRY_CAR_SWITCH_2026_10_28.md and docs/evidence/rivalry-car-switch-2026-10-28/report.json. Network wait, reload/rebuild and owner/device acceptance remain. No device query/test, APK, live mutation, deployment, owner-process restart or main-index staging/commit/merge.
<!-- /RIVALRY-CAR-SWITCH-20261028 -->

"""
for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    path = ROOT / name
    original = path.read_bytes()
    if b"<!-- RIVALRY-CAR-SWITCH-20261028 -->" not in original:
        path.write_bytes(tracking.encode("utf-8") + original)

report = {
    "date": "2026-10-28", "requirements": ["RCS01", "RCS02", "RCS03"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(),
    "commands": [
        "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/<test>.gd -CommandTimeoutSeconds 180",
        "Native options: -Graphical -RenderingMethod gl_compatibility; Mobile: -Graphical -RenderingMethod mobile -TestArgument --compact",
        "APPDATA/LOCALAPPDATA: build/rivalry-car-switch/<run>/{appdata,localappdata}; join-failure fixture: build/rivalry-join-feedback/rivalry-car-switch/{appdata,localappdata}",
        "BMT_RIVALRY_CAR_SWITCH_CAPTURE_DIR=docs/evidence/rivalry-car-switch-2026-10-28/<renderer>",
        "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 240",
        "python docs/evidence/rivalry-car-switch-2026-10-28/build_evidence.py",
    ],
    "files": [{"path": name, "sha256": hashlib.sha256((ROOT / name).read_bytes()).hexdigest(),
               "before_sha256": hashlib.sha256((EVIDENCE / "before" / name).read_bytes()).hexdigest()
               if (EVIDENCE / "before" / name).exists() else None} for name in FILES],
    "documentation": ["docs/RIVALRY_CAR_SWITCH_2026_10_28.md", "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"],
    "tests": tests, "checkpoint": receipts,
    "screenshots": [{"path": str(path.relative_to(EVIDENCE)).replace("\\", "/"),
                     "sha256": hashlib.sha256(path.read_bytes()).hexdigest()} for path in sorted(EVIDENCE.glob("*/*.png"))],
    "limitations": ["Synthetic offline services and disposable profiles; no live-results claim.",
                    "Network loading latency and owner/device acceptance remain; reload/rebuild needed.",
                    "No physical-device query/test, APK, live mutation, deployment, process restart or main-index write.",
                    "Initial certificate/path-guard/concurrent-art failures and track-browser warning retained.",
                    "Build metadata and unrelated concurrent sources/assets excluded from source-only patch."],
}
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("CHECKPOINT: forward/reverse checks and exact source reconstruction pass")
print("REPORT: %d logs, %d screenshots, %d scoped files" % (len(tests), len(report["screenshots"]), len(FILES)))
