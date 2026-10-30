"""Record actual native outcomes and the task-only review checkpoint."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
EXISTING = [
    "game/ui/garage_page.gd", "game/ui/garage_livery_menu.gd",
    "game/ui/garage_cosmetic_shelf.gd", "game/ui/garage_customisation_camera.gd",
    "game/tests/test_customisation_carousel.gd", "game/tests/test_garage_customisation_speed.gd",
    "AGENTS.md", "DEVELOPMENT_STATUS.md",
]
NEW = ["docs/GARAGE_OPTIONS_FOCUS_2026_10_25.md"]
NEW += ["docs/evidence/garage-options-focus-2026-10-25/" + name
        for name in ("run.ps1", "record.py", "review.html")]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def log_text(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith(b"\xff\xfe") else "utf-8-sig", errors="replace")


patch, sources = [], []
for name in EXISTING + NEW:
    target = ROOT / name
    before = EVIDENCE / "before" / name
    original = before.read_text(encoding="utf-8") if before.exists() else ""
    current = target.read_text(encoding="utf-8")
    if current != original:
        patch.append(f"diff --git a/{name} b/{name}\n")
        patch.extend(difflib.unified_diff(original.splitlines(True), current.splitlines(True),
                     fromfile=f"a/{name}" if before.exists() else "/dev/null", tofile=f"b/{name}"))
    sources.append({"path": name, "sha256": sha(target),
                    "before_sha256": sha(before) if before.exists() else None})
checkpoint = EVIDENCE / "task-only.patch"
checkpoint.write_text("".join(patch), encoding="utf-8", newline="\n")
result = subprocess.run(["git", "apply", "--check", "--reverse", str(checkpoint)],
                        cwd=ROOT, capture_output=True, text=True)
runs = []
for path in sorted(EVIDENCE.glob("*/command.json")):
    command = json.loads(path.read_text(encoding="utf-8-sig"))
    log = path.with_name("console.log")
    content = log_text(log)
    summaries = re.findall(r"(?:CUSTOMISATION_CAROUSEL|GARAGE_SIDEBAR|GARAGE_VIEW_CONTROLS|"
                           r"GARAGE_CUSTOMISATION_SPEED|APP_TESTS|SCRIPT_PARSE):[^\r\n]+", content)
    runs.append({"directory": path.parent.name, **command, "summary": summaries,
                 "failures": re.findall(r"^FAIL:[^\r\n]+", content, re.M), "log_sha256": sha(log)})
baseline = EVIDENCE / "before/console.log"
report = {
    "date": "2026-10-25", "requirements": ["GOF01", "GOF02", "GOF03", "R01", "Q01"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(),
    "behavior": {
        "right_panel": "Two-column options, selected item and explicit equip; no large detail photo/viewport",
        "main_view": "Body fit for Patterns/Colours; category/surface focus for Parts/Stickers after layout",
        "cancel": "Restore equipped cosmetics and keep editing focus",
        "leave": "Restore exact previous camera and scalar orbit values",
        "bounds": "All seven model bounds projected into safe viewport area at two landscape sizes",
    },
    "runs": runs, "sources": sources,
    "baseline": {"log": "before/console.log", "sha256": sha(baseline),
                 "summary": re.findall(r"CUSTOMISATION_CAROUSEL:[^\r\n]+", log_text(baseline))},
    "initial_corrections": [
        {"image": "initial/title-and-selection.png", "log": "initial/first-compatibility.log",
         "finding": "Selected title width, selected-option visibility and preserved whole-body viewing direction"},
        {"log": "initial/sidebar-camera-precision.log",
         "finding": "One exact orbit failure: Vector3 storage rounded saved scalar values; preserve scalars separately",
         "assertion": "Original navigation assertion retained unchanged"},
    ],
    "captures": [{"path": path.relative_to(EVIDENCE).as_posix(), "sha256": sha(path)}
                 for path in sorted(EVIDENCE.rglob("*.png"))],
    "checkpoint": {"path": "task-only.patch", "sha256": sha(checkpoint),
                   "reverse_check_exit": result.returncode, "stderr": result.stderr},
    "known_unrelated": ["Prior Forklift heavy-film cleanliness failure not rerun or changed by this task"],
    "remaining_acceptance": ["client reload", "owner appearance and touch", "physical-device acceptance"],
    "limits": ["Windows desktop renderers only", "no device attachment check or physical-device test",
               "no APK", "no real purchase or live mutation", "no deployment or owner-process restart",
               "concurrent work preserved; no staging or commit"],
}
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"runs": [{"name": run["directory"], "exit": run["exit_code"], "summary": run["summary"]}
                           for run in runs], "checkpoint_reverse_exit": result.returncode,
                  "checkpoint_error": result.stderr}, indent=2))
raise SystemExit(result.returncode)
