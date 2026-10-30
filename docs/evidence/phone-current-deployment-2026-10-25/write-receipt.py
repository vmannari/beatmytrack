from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re
import shutil

work = Path(__file__).resolve().parent
root = work.parents[1]
evidence = root / "docs/evidence/phone-current-deployment-2026-10-25"
device = json.loads((evidence / "device-verification.json").read_text())
assert device["app_ready"] and device["matched_startup_errors"] == 0
assert device["installed_apk_sha256_matches"] and device["first_install_time_unchanged"]
logs = max((work / "source/build/logs").glob("ExportAndroid-*"), key=lambda path: path.stat().st_mtime)
validation = {}
for filename, label in (("driving-tests.log", "DRIVING_TESTS"), ("catalog-tests.log", "CATALOG_TESTS"), ("menu-presentation-tests.log", "MENU_PRESENTATION_TESTS")):
    text = (logs / filename).read_text(encoding="utf-8-sig")
    match = re.search(label + r": (\d+) checks, (\d+) failures", text)
    assert match and int(match.group(2)) == 0
    validation[label] = {"checks": int(match.group(1)), "failures": 0, "log": filename}
    shutil.copy2(logs / filename, evidence / filename)
assert "APP_READY" in (logs / "startup.log").read_text(encoding="utf-8-sig")
for filename in ("import.log", "startup.log", "android-export.log", "client-build-identity.json"):
    shutil.copy2(logs / filename, evidence / filename)
for filename in ("verified-build.json", "apk-audit.json", "freeze.py", "run-build.ps1", "verify-build.ps1", "audit-apk.py", "deploy.py", "write-receipt.py"):
    shutil.copy2(work / filename, evidence / filename)
report = {
    "date": "2026-10-25",
    "completed_utc": datetime.now(timezone.utc).isoformat(),
    "authorization": "Owner: deploy the current game to the phone; USB debugging explicitly allowed.",
    "requirements": ["PD01: current source Android export", "PD02: preserve app data and verify install/startup", "V05", "R01", "Q01"],
    "outcome": "Current workspace snapshot installed and launched on OnePlus DN2103, Android 13.",
    "device": device,
    "validation": validation,
    "import_startup_export": "passed",
    "full_regression_run": False,
    "apk_audit": json.loads((work / "apk-audit.json").read_text()),
    "source_snapshot": {"path": str(work / "source"), "manifest": str(work / "source-manifest.json"), "manifest_sha256": hashlib.sha256((work / "source-manifest.json").read_bytes()).hexdigest()},
    "commands": [
        "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor (sandboxed ADB denied; escalated retry enumerated phone)",
        "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ExportAndroid -QuickValidation -CommandTimeoutSeconds 1800 (passed, rejected for install after source drift)",
        "python build/phone-current-deployment-2026-10-25/freeze.py",
        "powershell -NoProfile -ExecutionPolicy Bypass -File build/phone-current-deployment-2026-10-25/run-build.ps1",
        "powershell -NoProfile -ExecutionPolicy Bypass -File build/phone-current-deployment-2026-10-25/verify-build.ps1",
        "python build/phone-current-deployment-2026-10-25/audit-apk.py",
        "python build/phone-current-deployment-2026-10-25/deploy.py (ADB install -r; installed version and APK SHA256; launch APP_READY; screenshot)",
        "python build/phone-current-deployment-2026-10-25/write-receipt.py",
    ],
    "initial_notes": [
        "Sandboxed ADB could not create its Android directory; authorized execution succeeded.",
        "USB debugging initially unauthorized; owner accepted the phone prompt.",
        "First direct export passed focused validation/export but final shipping-source hash changed; it was not installed.",
        "Concurrent localization/en.po and messages.pot changes were detected during first freeze; a subsequent copy matched all source bytes.",
        "Frozen export initially lacked the ignored Android source template; copied the pinned SHA256-verified existing template and reran successfully.",
        "Catalogue check retains its existing anchor-sizing warning.",
    ],
    "changed_files": ["docs/ANDROID.md", "docs/evidence/phone-current-deployment-2026-10-25/*", "build/phone-current-deployment-2026-10-25/* (ignored)", "game/core/build_identity.gd and game/project.godot generated identity during the initial root export/recheck"],
    "scope": {"gameplay_source_edits": False, "backend_deployment": False, "purchase": False, "track_sync": False, "uninstall": False, "clear_data": False, "owner_desktop_process_restart": False, "concurrent_work_preserved": True},
    "remaining_acceptance": ["Owner physical-touch driving and visual review", "Sustained performance/thermal, background/resume and sign-in checks", "Matching online service contracts for current gameplay changes remain separate from this phone-only deployment"],
    "private_startup_log": str(work / "device-startup-private.log"),
}
report["artifact_sha256"] = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(evidence.iterdir()) if path.is_file() and path.name not in {"report.json", "task-only.patch"}}
(evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"report": str(evidence / "report.json"), "checks": sum(entry["checks"] for entry in validation.values()), "app_ready": True, "build_id": device["build"]["build_id"]}))
