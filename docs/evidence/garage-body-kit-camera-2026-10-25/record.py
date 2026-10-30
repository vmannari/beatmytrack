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
    "game/ui/garage_page.gd", "game/ui/garage_customisation_camera.gd",
    "game/tests/test_customisation_carousel.gd", "AGENTS.md", "DEVELOPMENT_STATUS.md",
]
NEW = ["docs/GARAGE_BODY_KIT_CAMERA_2026_10_25.md"]
NEW += ["docs/evidence/garage-body-kit-camera-2026-10-25/" + name
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
for path in sorted(EVIDENCE.rglob("command.json")):
    command = json.loads(path.read_text(encoding="utf-8-sig"))
    log = path.with_name("console.log")
    content = log_text(log)
    summaries = re.findall(r"(?:CUSTOMISATION_CAROUSEL|GARAGE_SIDEBAR|GARAGE_VIEW_CONTROLS|"
                           r"GARAGE_CUSTOMISATION_SPEED|APP_TESTS|SCRIPT_PARSE):[^\r\n]+", content)
    runs.append({"directory": path.parent.relative_to(EVIDENCE).as_posix(), **command, "summary": summaries,
                 "failures": re.findall(r"^FAIL:[^\r\n]+", content, re.M), "log_sha256": sha(log)})
baseline = EVIDENCE / "before/native/console.log"
report = {
    "date": "2026-10-25", "requirements": ["GBK01", "GBK02", "R01", "Q01"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(),
    "behavior": {
        "body_kits": "Separate low front three-quarter preset, fitted to actual selected model bounds",
        "entry": "Kit-category selection, option selection and layout resize use body_kit focus",
        "unchanged": "Pattern/colour framing, options panel, exact return-camera and cosmetic rules",
    },
    "runs": runs, "sources": sources,
    "baseline": {"log": "before/native/console.log", "sha256": sha(baseline),
                 "summary": re.findall(r"CUSTOMISATION_CAROUSEL:[^\r\n]+", log_text(baseline)),
                 "regression_source": "before/regression_test_customisation_carousel.gd.txt",
                 "regression_sha256": sha(EVIDENCE / "before/regression_test_customisation_carousel.gd.txt"),
                 "finding": "Original runtime inherits 62-degree Garage view for every body kit"},
    "captures": [{"path": path.relative_to(EVIDENCE).as_posix(), "sha256": sha(path)}
                 for path in sorted(EVIDENCE.rglob("*.png"))],
    "checkpoint": {"path": "task-only.patch", "sha256": sha(checkpoint),
                   "reverse_check_exit": result.returncode, "stderr": result.stderr},
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
