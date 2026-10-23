"""Build the task-only review patch and retain actual local verification receipts."""
from pathlib import Path
import difflib
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
originals = {
    "game/core/app.gd": "app.gd",
    "native/admob/src/org/beatmytrack/admob/BmtAdMob.java": "BmtAdMob.java",
    "native/admob/PROVENANCE.md": "PROVENANCE.md",
}
added = [
    "game/platform/race_ad_breaks.gd",
    "game/platform/race_ad_breaks.gd.uid",
    "game/platform/admob_interstitial.gd",
    "game/platform/admob_interstitial.gd.uid",
    "game/tests/test_race_ad_breaks.gd",
    "game/tests/test_race_ad_breaks.gd.uid",
    "docs/INTERSTITIAL_CADENCE_2026_10_22.md",
]
patch = []
for name, before in [(name, OUT / "before" / before) for name, before in originals.items()] + [(name, None) for name in added]:
    original = before.read_text(encoding="utf-8").splitlines(keepends=True) if before else []
    current = (ROOT / name).read_text(encoding="utf-8").splitlines(keepends=True)
    patch.append(f"diff --git a/{name} b/{name}\n")
    if before is None:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(original, current, fromfile=f"a/{name}" if before else "/dev/null", tofile=f"b/{name}"))
(OUT / "task-only.patch").write_text("".join(patch), encoding="utf-8", newline="")

logs = {
    "headless.log": "build/logs/TestScript-31812/test-script.log",
    "rewarded.log": "build/logs/TestScript-31204/test-script.log",
    "app.log": "build/logs/TestApp-19688/app-tests.log",
    "import.log": "build/logs/Import-5952/import.log",
    "initial-missing-track.log": "build/logs/TestScript-30260/test-script.log",
    "initial-missing-timestamp.log": "build/logs/TestScript-18708/test-script.log",
    "initial-wasapi.log": "build/logs/TestScript-14148/test-script.log",
}
parse_logs = [ROOT / f"build/logs/TestScript-{pid}/test-script.log" for pid in [21852, 33440]]
logs["parse.log"] = str(max(parse_logs, key=lambda item: item.stat().st_mtime).relative_to(ROOT))
for target, source in logs.items():
    shutil.copyfile(ROOT / source, OUT / target)

checks = {}
commands = {
    "reverse_patch": ["git", "apply", "--check", "--reverse", str(OUT / "task-only.patch")],
    "scoped_whitespace": ["git", "diff", "--check", "--", *originals, "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"],
}
for name, command in commands.items():
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    checks[name] = {"command": command, "exit_code": result.returncode, "stdout": result.stdout, "stderr": result.stderr}

report = {
    "date": "2026-10-22",
    "requirements": ["ADB01", "ADB02", "ADB03", "ADB04", "R01", "Q01"],
    "engine": "4.7.2.stable.official.ed1daf0bf",
    "policy": {"completed_races": 3, "active_milliseconds": 600000, "trigger": "whichever-first; next ordinary finish only", "reset": "both counters after a shown ad is dismissed", "persistence": "session-local"},
    "configuration": {"provider": "AdMob", "placement": "interstitial", "unit": "ca-app-pub-3940256099942544/1033173712", "build": "Android debug", "preference": "development_show_ads", "production_configured": False},
    "results": {"focused_headless": [57, 0], "focused_desktop_compatibility_with_captures": [59, 0], "existing_rewarded": [44, 0], "app": [141, 0], "parse": [930, 0], "import_exit": 0, "native_java_compile_exit": 0},
    "initial_failures": ["Sandbox user-log write denied; workspace APPDATA used", "Sandbox Windows root certificate-store read denied; isolated elevated test used", "Synthetic App fixture omitted published-track marker, then final lap timestamp", "Unflavored Gradle Java task ambiguous; standard debug target selected", "Default graphical run hit WASAPI GetBufferSize error; Dummy audio passed"],
    "logs": logs,
    "checks": checks,
    "source_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in [*originals, *added]},
    "checkpoint": "task-only.patch is relative to the preserved task-original sources; status-file summaries are separate",
    "remaining": ["actual Android interstitial lifecycle/touch test", "owner cadence acceptance", "production app/interstitial IDs", "consent and release configuration"],
    "not_performed": ["phone attachment check", "physical-device/emulator ad test", "APK/export/install", "backend deployment", "live account/race mutation", "provider-console mutation"],
    "captures": "real result page around an injected test ad; not Google ad screenshots",
}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"checks": checks, "source_files": len(report["source_sha256"])}, indent=2))
if any(check["exit_code"] for check in checks.values()):
    raise SystemExit(1)
