"""Retain actual receipts and a Git-checkable patch containing this task only."""
from pathlib import Path
import difflib
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
originals = [
    "game/platform/race_ad_breaks.gd", "game/core/app.gd",
    "game/tests/test_race_ad_breaks.gd", "game/tests/test_game_configuration.gd",
    "backend/bmt_backend/game_config.py", "backend/bmt_backend/admin_ui/game_config.js",
    "backend/tests/test_game_config.py", "scripts/test_game_configuration_console.py",
]
added = ["game/tests/test_cumulative_ad_cadence.gd", "game/tests/test_cumulative_ad_cadence.gd.uid",
         "docs/CUMULATIVE_AD_CADENCE_2026_10_24.md"]
patch, scoped_after = [], {}
for name in originals + added:
    before_file = OUT / "before" / name.replace("/", "__")
    before = before_file.read_text(encoding="utf-8") if name in originals else ""
    after = (ROOT / name).read_text(encoding="utf-8")
    if name == "game/core/app.gd":
        # Concurrent Challenge changes after our snapshot are not this task.
        after = before.replace(
            '\t\tif race_ad_breaks != null: race_ad_breaks.observe_time(false)\n',
            '\t\tif race_ad_breaks != null:\n\t\t\trace_ad_breaks.observe_time(false)\n\t\t\trace_ad_breaks.flush_progress()\n', 1)
        after = after.replace('\trace_ad_breaks.client = online.client\n',
            '\trace_ad_breaks.client = online.client\n\trace_ad_breaks.storage_path = profile_root.path_join("ad_cadence.json")\n', 1)
        assert '\trace_ad_breaks.storage_path = profile_root.path_join("ad_cadence.json")\n' in (ROOT / name).read_text(encoding="utf-8")
    scoped_after[name] = hashlib.sha256(after.encode()).hexdigest()
    patch.append(f"diff --git a/{name} b/{name}\n")
    if name in added:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True),
        fromfile=f"a/{name}" if name in originals else "/dev/null", tofile=f"b/{name}"))
(OUT / "task-only.patch").write_text("".join(patch), encoding="utf-8", newline="")

def receipt(marker, pattern, target):
    candidates = []
    start = min(file.stat().st_mtime for file in (OUT / "before").iterdir()) - 5
    for path in (ROOT / "build/logs").glob(pattern):
        if path.stat().st_mtime >= start and marker in path.read_text(encoding="utf-8", errors="replace"):
            candidates.append(path)
    selected = max(candidates, key=lambda item: item.stat().st_mtime)
    shutil.copyfile(selected, OUT / target)
    return str(selected.relative_to(ROOT))

logs = {
    "cumulative.log": receipt("CUMULATIVE_AD_CADENCE: 28 checks, 0 failures", "TestScript-*/test-script.log", "cumulative.log"),
    "race-ads.log": receipt("RACE_AD_BREAKS: 63 checks, 0 failures", "TestScript-*/test-script.log", "race-ads.log"),
    "configuration.log": receipt("GAME_CONFIGURATION: 40 checks, 0 failures", "TestScript-*/test-script.log", "configuration.log"),
    "app.log": receipt("APP_TESTS: 141 checks, 0 failures", "TestApp-*/app-tests.log", "app.log"),
    "parse.log": receipt("SCRIPT_PARSE: 1064 scripts, 0 failures", "TestScript-*/test-script.log", "parse.log"),
    "import.log": receipt("DONE", "Import-*/import.log", "import.log"),
}
initial = ROOT / "build/logs/TestScript-32204/test-script.log"
shutil.copyfile(initial, OUT / "initial-concurrent-desert-parse.log")
commands = {
    "reverse_patch": ["git", "apply", "--check", "--reverse", str(OUT / "task-only.patch")],
    "whitespace": ["git", "diff", "--check", "--", *originals, "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"],
}
checks = {}
for name, command in commands.items():
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    checks[name] = {"command": command, "exit_code": result.returncode, "stdout": result.stdout, "stderr": result.stderr}
report = {
    "date": "2026-10-24", "requirements": ["CAD01", "CAD02", "CAD03", "R01", "Q01"],
    "behavior": {"cadence": "configured N races OR X active minutes, accumulated across launches",
                 "first_race": "at least one completed ordinary race in this app launch",
                 "persistence": "install-local ad_cadence.json; no cross-device synchronization",
                 "reset": "both cumulative counters after an actual interstitial show; no-fill retains them",
                 "session_fields": "first-race guard, delay, cap and rewarded cooldown remain session-local"},
    "results": {"cumulative": [28, 0], "real_app_race_ads": [63, 0], "configuration": [40, 0],
                "app": [141, 0], "backend": {"passed": 14, "warnings": 56}, "browser": {"workflows": 13, "page_errors": 0},
                "parse": [1064, 0], "import_exit": 0, "ruff_exit": 0, "python_compile_exit": 0},
    "commands": ["scripts/dev.ps1 TestScript -ScriptPath res://tests/test_cumulative_ad_cadence.gd -CommandTimeoutSeconds 180",
                 "scripts/dev.ps1 TestScript -ScriptPath res://tests/test_race_ad_breaks.gd -CommandTimeoutSeconds 240",
                 "scripts/dev.ps1 TestScript -ScriptPath res://tests/test_game_configuration.gd -CommandTimeoutSeconds 180",
                 "scripts/dev.ps1 TestApp -CommandTimeoutSeconds 240",
                 "scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180",
                 "scripts/dev.ps1 Import -CommandTimeoutSeconds 180",
                 ".tools/backend-venv/Scripts/python.exe -m pytest tests/test_game_config.py -k 'not postgres' -q (cwd backend)",
                 ".tools/backend-venv/Scripts/python.exe scripts/test_game_configuration_console.py --output docs/evidence/cumulative-ad-cadence-2026-10-24/browser",
                 ".tools/backend-venv/Scripts/python.exe -m ruff check backend/bmt_backend/game_config.py backend/tests/test_game_config.py scripts/test_game_configuration_console.py",
                 "python -m py_compile scripts/test_game_configuration_console.py"],
    "logs": logs, "checks": checks,
    "current_source_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in originals + added},
    "task_only_after_normalized_sha256": scoped_after,
    "checkpoint": "task-only.patch excludes concurrent App Challenge edits and independent Desert sources; status prefixes are recorded separately",
    "initial_limitations": ["full scan initially stopped on concurrent Desert ROOTS constant expression; independent correction allowed final 1064/0",
                            "standalone node was unavailable; actual browser loaded JavaScript with zero page errors"],
    "durability_limit": "background/clean shutdown flush; foreground crash may lose active time since the most recent 15-second checkpoint; disk failure cannot guarantee persistence",
    "not_performed": ["phone/tablet attachment check", "physical-device test", "APK/export/install", "live mutation", "deployment", "provider-console changes"],
    "remaining": ["matching client/API/Studio rollout", "owner/device acceptance", "existing production provider and consent prerequisites"],
}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"results": report["results"], "checks": checks}, indent=2))
if any(item["exit_code"] for item in checks.values()):
    raise SystemExit(1)
