"""Collect actual outcomes and make a task-only patch from concurrent sources."""
import difflib
import hashlib
import json
from pathlib import Path
import re

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
AFTER = OUT / "after"
AFTER.mkdir(exist_ok=True)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def diff(path, before, after):
    return "".join(difflib.unified_diff(
        before.decode("utf-8").splitlines(keepends=True),
        after.decode("utf-8").splitlines(keepends=True),
        fromfile="a/" + path if before else "/dev/null", tofile="b/" + path))

app_path = "game/core/app.gd"
app = (ROOT / app_path).read_bytes()
text = app.decode("utf-8")
start = text.index("\tif is_instance_valid(prepared_game.world_render_preparation):",
                   text.index("func _start_garage_free_drive()"))
end = text.index("\tvar touch: TouchControls", start)
block = text[start:end]
assert len(block.splitlines()) == 9
scoped_before = (text[:start] + text[end:]).encode("utf-8")
(OUT / "scoped-before-app.gd").write_bytes(scoped_before)
(AFTER / "app.gd").write_bytes(app)
runtime_patch = diff(app_path, scoped_before, app)
(OUT / "runtime.patch").write_bytes(runtime_patch.encode("utf-8"))
patches = [runtime_patch]
hashes = {app_path: sha(app)}

new_files = ["game/tests/test_garage_test_drive.gd",
             "game/tests/test_garage_test_drive.gd.uid",
             "game/tests/test_garage_test_drive_cancellation.gd",
             "game/tests/test_garage_test_drive_cancellation.gd.uid",
             "docs/GARAGE_TEST_DRIVE_FIX_2026_10_26.md"]
for path in new_files:
    data = (ROOT / path).read_bytes()
    hashes[path] = sha(data)
    patches.append(diff(path, b"", data))

for path in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    data = (ROOT / path).read_bytes()
    content = data.decode("utf-8")
    start = content.index("<!-- GARAGE-TEST-DRIVE-FIX-20261026 -->")
    end = content.index("<!-- /GARAGE-TEST-DRIVE-FIX-20261026 -->", start)
    end += len("<!-- /GARAGE-TEST-DRIVE-FIX-20261026 -->")
    while end < len(content) and content[end] in "\r\n":
        end += 1
    before = (content[:start] + content[end:]).encode("utf-8")
    patches.append(diff(path, before, data))
    hashes[path] = sha(data)
(OUT / "checkpoint.patch").write_bytes("".join(patches).encode("utf-8"))

commands = {}
for path in sorted(OUT.glob("*.json")):
    if path.name == "report.json": continue
    result = json.loads(path.read_text(encoding="utf-8"))
    log_path = path.with_suffix(".log")
    log = log_path.read_text(encoding="utf-8") if log_path.exists() else ""
    result["summaries"] = re.findall(r"^.*(?:checks, .*failures|scripts, .*failures).*$", log, re.M)
    result["script_errors"] = log.count("SCRIPT ERROR:")
    result["engine_errors"] = len(re.findall(r"^ERROR:", log, re.M))
    commands[path.stem] = result

for path in ["game/core/game.gd", "game/garage/parking_hall_drive.gd",
             "game/tests/test_parking_hall.gd", "game/race/world_render_preparation.gd"]:
    data = (ROOT / path).read_bytes()
    hashes[path] = sha(data)

report = {
    "date": "2026-10-26",
    "requirements": ["GTF01", "GTF02", "GTF03", "R01", "Q01"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(),
    "cause": "Cooperative Game holds new geometry hidden; Garage omitted staged prepare before removing its cover.",
    "runtime_changes": {app_path: "Nine added Garage graphics-preparation lines with existing cancellation guards."},
    "commands": commands,
    "import": {"command": "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import -CommandTimeoutSeconds 120", "exit_code": 0, "log": "import.log", "warning": "Android build-tools unavailable; no Android build requested."},
    "source_sha256": hashes,
    "task_start_app_sha256": sha((OUT / "before/app.gd").read_bytes()),
    "scoped_before_app_sha256": sha(scoped_before),
    "unchanged_from_task_start": {
        path: (ROOT / path).read_bytes() == (OUT / "before" / Path(path).name).read_bytes()
        for path in ["game/core/game.gd", "game/garage/parking_hall_drive.gd", "game/tests/test_parking_hall.gd"]},
    "retained_findings": [
        "Original parking suite stops at outdated GarageBack lookup before driving; original-parking-suite.log retained.",
        "First smoke test passed parent visibility but blank native capture required stronger descendant/pending checks; baseline-geometry then had 21 failures.",
        "First fixed electric movement check was paused by offscreen focus loss; fixture resumes via existing pause method and separately checks background pausing.",
        "Concurrent header assets lacked imports in intermediate native runs; pinned import refreshed seven images; clean final logs retained.",
        "Initial Mobile 15-second fixture allowance expired before HUD creation; final allowance matches the existing suite/App watchdog at 45 seconds.",
        "Initial wide App diff included five concurrent comparison lines; runtime.patch regenerated by removing only the nine task lines from current source."],
    "captures": ["blank-electric.png",
                 "verified-compatibility/gl_compatibility-ready-electric.png",
                 "verified-compatibility/gl_compatibility-driving-electric.png",
                 "electric-mobile/mobile-ready-electric.png",
                 "electric-mobile/mobile-driving-electric.png"],
    "remaining_acceptance": ["Reload/rebuild running or exported game.", "Owner electric/all-car driving acceptance.", "Physical-device touch, appearance and loading performance."],
    "device_attachment_checked": False,
    "physical_device_test": False,
    "apk_or_deployment": False,
    "owner_process_restarted": False,
    "git_staging_commit_merge": False,
    "patches": ["runtime.patch", "checkpoint.patch"]}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"commands": {key: value["summaries"] for key, value in commands.items()},
                  "unchanged": report["unchanged_from_task_start"],
                  "runtime_added_lines": len(block.splitlines())}, indent=2))
