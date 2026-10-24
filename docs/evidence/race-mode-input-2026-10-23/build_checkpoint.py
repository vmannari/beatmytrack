"""Build a review patch containing this task's hunks, preserving concurrent work."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent


def read(path):
    return path.read_text(encoding="utf-8").splitlines(keepends=True)


def app_baseline():
    """Undo only our disjoint hunks in a copy of the current App."""
    current = read(ROOT / "game/core/app.gd")
    original = read(OUT / "before-source/app.gd")
    diff = list(difflib.unified_diff(original, current, n=3))
    hunks = []
    for line in diff[2:]:
        if line.startswith("@@"):
            hunks.append([line])
        else:
            hunks[-1].append(line)
    selected = []
    for hunk in hunks:
        added = "".join(line[1:] for line in hunk if line.startswith("+"))
        if any(key in added for key in ["_park_rivalry_page", "_retained_rivalry", "_rivalry_parking", "if parked:"]):
            selected.append(hunk)
    assert len(selected) == 8, f"Review changed hunk boundaries: {len(selected)}"
    for hunk in reversed(selected):
        match = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", hunk[0])
        start, count = int(match[1]) - 1, int(match[2] or 1)
        before = [line[1:] for line in hunk[1:] if line[0] in " -"]
        current[start : start + count] = before
    return current


def status_baseline(name):
    # Concurrent tasks may edit these shared reports after our initial copy.
    # Remove only our appended receipt from the current text.
    text = (ROOT / name).read_text(encoding="utf-8")
    before, count = re.subn(r"\n\n2026-10-23 RMI01-RMI03/R01/Q01:[^\n]*\n", "", text)
    assert count == 1, name
    return before.splitlines(keepends=True)


baselines = {
    "game/core/app.gd": app_baseline(),
    "game/ui/race_mode_rail.gd": read(OUT / "before-source/race_mode_rail.gd"),
    "DEVELOPMENT_STATUS.md": status_baseline("DEVELOPMENT_STATUS.md"),
    "docs/PHASE_0_PLAN.md": status_baseline("docs/PHASE_0_PLAN.md"),
}
for name in [
    "game/tests/test_race_mode_input.gd",
    "game/tests/test_race_mode_input.gd.uid",
    "game/tests/fixtures/race_mode_input_before/test_menu_page_swipe_before.gd",
    "game/tests/fixtures/race_mode_input_before/test_menu_medium_before.gd",
    "docs/RACE_MODE_INPUT_2026_10_23.md",
]:
    baselines[name] = []

patch = []
hashes = {}
for name, before in baselines.items():
    path = ROOT / name
    after = read(path)
    patch.extend(difflib.unified_diff(before, after, fromfile="a/" + name if before else "/dev/null", tofile="b/" + name))
    hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
(OUT / "scoped-change.patch").write_text("".join(patch), encoding="utf-8", newline="\n")

logs = {
    "before-input": 27344, "press-only-input": 34296,
    "initial-retention-input": 8436, "retention-headless": 1708,
    "final-headless": 23220, "final-compatibility": 6352, "final-mobile": 36396,
    "carousel": 15008, "delayed-entry": 16876, "standings": 9180,
    "weekly-rivalry": 35568, "parser": 7132, "app": 28764,
    "broad-swipe-current": 20224, "broad-swipe-original-app": 15228,
    "menu-medium-current": 13408, "menu-medium-original-app": 18496,
}
(OUT / "logs").mkdir(exist_ok=True)
for label, pid in logs.items():
    shutil.copyfile(ROOT / f"build/logs/TestScript-{pid}/test-script.log", OUT / f"logs/{label}.log")

report = {
    "date": "2026-10-23", "requirements": ["RMI01", "RMI02", "RMI03", "R01", "Q01"],
    "engine": "4.7.2.stable.official.ed1daf0bf",
    "changes": {
        "RMI01": "Race rail uses native ACTION_MODE_BUTTON_PRESS; release cannot lose a replaced temporary button.",
        "RMI02": "One actual Rivalry page is retained with hidden/inactive parking and disabled subviewports; updated before promotion and discarded across scope changes.",
        "RMI03": "Original vertical animation, fixed rail/header, populated first entry, status and standings, primary navigation and result owners retained.",
    },
    "final_checks": {"input_headless": [57, 0], "input_compatibility": [62, 0], "input_desktop_mobile": [62, 0], "carousel": [42, 0], "delayed_entry": [66, 0], "standings": [44, 0], "weekly_rivalry": [1115, 0], "app": [141, 0], "parser": [979, 0]},
    "retained_initial_results": {
        "original_input": [34, 16], "press_only": [34, 0], "first_retention": [47, 2],
        "correction": "Explicitly disable parked SubViewports; retained both failed assertions.",
        "bootstrap": "Initial execution-policy/user-directory/certificate-store errors; documented launcher, isolated APPDATA and approved Windows certificate-store access used thereafter.",
    },
    "known_broad_suite_failures": {
        "swipe": "Three live-drag assertions, followed by nil Tween.pause; same failures with task-original App. Original assertion source preserved.",
        "menu_medium": "313 checks, 30 washing failures with current App and task-original App. Retained Rivalry portion passes in both. Washing executes before App construction. No washing code changed.",
    },
    "commands": [
        "$env:APPDATA='<workspace>/build/race-mode-input-<run>'; New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null",
        "$env:BMT_RACE_MODE_INPUT_OUTPUT='<workspace>/docs/evidence/race-mode-input-2026-10-23/<run>'; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_mode_input.gd -CommandTimeoutSeconds 120",
        "Same input command with -Graphical -RenderingMethod gl_compatibility or mobile; final runs use final-<renderer> evidence directories.",
        "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/<test_race_mode_carousel.gd|test_rivalry_entry.gd|test_standings_stability.gd|test_menu_page_swipe.gd|test_weekly_rivalry.gd|test_script_parse.gd|test_app.gd|test_menu_medium_priority.gd> -CommandTimeoutSeconds 180",
        "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/fixtures/race_mode_input_before/test_menu_page_swipe_before.gd -CommandTimeoutSeconds 45",
        "$env:BMT_MENU_MEDIUM_OUTPUT='<workspace>/docs/evidence/race-mode-input-2026-10-23/menu-medium-before'; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/fixtures/race_mode_input_before/test_menu_medium_before.gd -CommandTimeoutSeconds 120",
        "python docs/evidence/race-mode-input-2026-10-23/build_checkpoint.py",
        "git apply --reverse --check --whitespace=error-all docs/evidence/race-mode-input-2026-10-23/scoped-change.patch",
        "git diff --check -- game/core/app.gd game/ui/race_mode_rail.gd DEVELOPMENT_STATUS.md docs/PHASE_0_PLAN.md",
    ],
    "paired_local_rivalry_dispatch_ms": {
        "before_retention_press_only": [426.752, 404.026, 435.274, 486.345],
        "after_retention": [34.562, 21.417, 28.477, 30.949],
        "scope": "Same offline sample model/two viewport sizes, synchronous touch dispatch. Not first rendered frame, phone/FPS/network or memory certification.",
    },
    "native_evidence": [str(path.relative_to(OUT)).replace("\\", "/") for path in sorted(OUT.glob("final-*/*.png"))],
    "source_sha256": hashes,
    "remaining_acceptance": ["Owner feel", "Physical-device touch and latency", "Long-session retained memory", "Cold first construction and real network waits remain"],
    "scope": "No phone attachment check/device test, APK, live backend/account mutation, social send or deployment. Concurrent editor/challenge/backend source changes excluded from review patch.",
    "review_checkpoint": "scoped-change.patch; reverse applicability/whitespace receipts recorded in checkpoint-check.txt",
}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"files": len(baselines), "patch_bytes": (OUT / "scoped-change.patch").stat().st_size, "logs": len(logs)}))
