"""Record real checks and a scoped checkpoint without staging workspace changes."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
EXISTING = [f"game/ui/{name}.gd" for name in (
    "garage_page", "garage_cosmetic_shelf", "garage_studio_style", "compact_kit_thumbnail")]
EXISTING += ["game/tests/test_customisation_carousel.gd", "AGENTS.md", "DEVELOPMENT_STATUS.md"]
NEW = ["game/ui/garage_part_photos.gd", "game/ui/garage_part_photos.gd.uid",
       "docs/GARAGE_CUSTOMISATION_POLISH_2026_10_25.md"]
NEW += ["docs/evidence/customisation-polish-2026-10-25/" + name
        for name in ("run.ps1", "record.py", "review.html")]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read_log(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith(b"\xff\xfe") else "utf-8-sig", errors="replace")

patch, sources = [], []
for name in EXISTING + NEW:
    target = ROOT / name
    before = EVIDENCE / "checkpoint-base" / name
    if not before.exists():
        before = EVIDENCE / "before" / name
    baseline = before.read_text(encoding="utf-8") if before.exists() else ""
    current = target.read_text(encoding="utf-8")
    if baseline == current:
        continue
    patch.append(f"diff --git a/{name} b/{name}\n")
    patch.extend(difflib.unified_diff(baseline.splitlines(True), current.splitlines(True),
        fromfile=f"a/{name}" if before.exists() else "/dev/null", tofile=f"b/{name}"))
    sources.append({"path": name, "sha256": sha(target),
                    "baseline": str(before.relative_to(EVIDENCE)) if before.exists() else None,
                    "baseline_sha256": sha(before) if before.exists() else None})
checkpoint = EVIDENCE / "task-only.patch"
checkpoint.write_text("".join(patch), encoding="utf-8", newline="\n")
check = subprocess.run(["git", "apply", "--check", "--reverse", str(checkpoint)],
                       cwd=ROOT, text=True, capture_output=True)
runs = []
for command_path in sorted(EVIDENCE.glob("*/command.json")):
    command = json.loads(command_path.read_text(encoding="utf-8-sig"))
    log = command_path.with_name("console.log")
    summaries = re.findall(r"(?:CUSTOMISATION_CAROUSEL|GARAGE_SIDEBAR|Garage clean customisation|GARAGE_CUSTOMISATION_SPEED|APP_TESTS|SCRIPT_PARSE):[^\r\n]+", read_log(log))
    runs.append({"directory": command_path.parent.name, **command,
                 "summary": summaries, "console_sha256": sha(log)})
report = {
    "date": "2026-10-25", "requirements": ["GCU01", "GCU02", "GCU03", "R01", "Q01"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(),
    "runs": runs, "sources": sources,
    "baseline": {"log": "before/console.log", "summary": "CUSTOMISATION_CAROUSEL: 267 checks, 0 failures"},
    "import": {"command": "scripts/dev.ps1 -Action Import", "exit_code": 0, "log": "import.log", "sha256": sha(EVIDENCE / "import.log")},
    "captures": [{"path": str(p.relative_to(EVIDENCE)).replace("\\", "/"), "sha256": sha(p)}
                 for p in sorted(EVIDENCE.rglob("*.png"))],
    "checkpoint": {"path": "task-only.patch", "sha256": sha(checkpoint),
                   "reverse_check_exit": check.returncode, "stderr": check.stderr,
                   "concurrent_exclusion": "Workshop navigation restoration retained in checkpoint-base; original copies remain in before"},
    "initial_findings": [
        "First headless and Compatibility runs: 1280x720 panel clipping and stale gap-specific card assertion; failed logs retained in attempts",
        "Four narrow medium-width cards truncate labels despite passing bounds; native image retained in attempts/passed-design/small-labels.png; three readable medium cards restored",
    ],
    "photo_work": {"size": [320,208], "image_cache_limit": 16, "temporary_studios": 1,
                   "idle_studios": 0, "paint_refresh_pixels_checked": ["red", "green"],
                   "cold_appearance_cost": "Sequential native photographs; extra preparation and texture memory require physical-device acceptance",
                   "legacy_prepared_photos": "Default API exact-pixel checks retained"},
    "remaining_acceptance": ["client reload", "owner appearance and interaction", "physical-device uncached-photo cost and appearance"],
    "limits": ["Windows desktop renderers only", "no phone/tablet attachment check or physical-device test",
               "no APK", "no real purchase or live player mutation", "no deployment or owner-process restart",
               "concurrent Workshop/tutorial/backend work preserved"],
}
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"runs": [{"name": r["directory"], "exit": r["exit_code"], "summary": r["summary"]} for r in runs],
                  "checkpoint_reverse_exit": check.returncode, "checkpoint_error": check.stderr}, indent=2))
raise SystemExit(check.returncode)
