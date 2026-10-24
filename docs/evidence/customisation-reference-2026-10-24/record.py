"""Record the task's actual native commands, source hashes and scoped checkpoint."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
RUNTIME = [f"game/ui/{name}.gd" for name in (
    "garage_page", "garage_cosmetic_shelf", "garage_studio_style",
    "garage_livery_menu", "compact_kit_thumbnail",
)]
TESTS = ["game/tests/test_customisation_carousel.gd", "game/tests/test_garage_sidebar.gd"]
DOCS = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
NEW = ["docs/GARAGE_CUSTOMISATION_REFERENCE_2026_10_24.md",
       "docs/evidence/customisation-reference-2026-10-24/run.ps1",
       "docs/evidence/customisation-reference-2026-10-24/record.py",
       "docs/evidence/customisation-reference-2026-10-24/review.html"]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def before_path(name):
    if name == "docs/PHASE_0_PLAN.md":
        return EVIDENCE / "before/PHASE_0_PLAN.md"
    return EVIDENCE / "before" / name

patch = []
sources = []
for name in RUNTIME + TESTS + DOCS + NEW:
    target = ROOT / name
    baseline = before_path(name)
    before = baseline.read_text(encoding="utf-8") if baseline.exists() else ""
    after = target.read_text(encoding="utf-8")
    if before == after:
        continue
    patch.append(f"diff --git a/{name} b/{name}\n")
    patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
        fromfile=f"a/{name}" if baseline.exists() else "/dev/null", tofile=f"b/{name}"))
    sources.append({"path": name, "sha256": digest(target),
                    "before_sha256": digest(baseline) if baseline.exists() else None})
checkpoint = EVIDENCE / "task-only.patch"
checkpoint.write_text("".join(patch), encoding="utf-8", newline="\n")
check = subprocess.run(["git", "apply", "--check", "--reverse", str(checkpoint)],
                       cwd=ROOT, text=True, capture_output=True)
runs = []
for command_file in sorted(EVIDENCE.glob("*/command.json")):
    command = json.loads(command_file.read_text(encoding="utf-8-sig"))
    log = command_file.with_name("console.log")
    content = log.read_text(encoding="utf-16" if log.read_bytes().startswith(b"\xff\xfe") else "utf-8-sig", errors="replace")
    summary = re.findall(r"(?:CUSTOMISATION_CAROUSEL|GARAGE_SIDEBAR|Garage clean customisation|GARAGE_CUSTOMISATION_SPEED|APP_TESTS|SCRIPT_PARSE):[^\r\n]+", content)
    runs.append({"directory": command_file.parent.name, **command,
                 "summary": summary, "console_sha256": digest(log)})
report = {
    "date": "2026-10-24", "requirements": ["GCR01", "GCR02", "GCR03", "R01", "Q01"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(),
    "runs": runs, "sources": sources,
    "captures": [{"path": str(p.relative_to(EVIDENCE)).replace("\\", "/"), "sha256": digest(p)}
                 for p in sorted(EVIDENCE.rglob("*.png"))],
    "checkpoint": {"path": "task-only.patch", "sha256": digest(checkpoint),
                   "reverse_check_exit": check.returncode,
                   "reverse_check_stdout": check.stdout, "reverse_check_stderr": check.stderr},
    "initial_failures": [
        "before/console.log: default user log path denied; isolated APPDATA used thereafter",
        "before/isolated-console.log: Windows certificate store access denied; reviewed execution used thereafter",
        "attempts/first-headless.log: 3 obsolete hidden-footer bounds failures; replaced with explicit absent-footer and visible-workbench assertions",
        "attempts/first-compatibility.log: actual 960x540 workbench clipping; compact heights/spacing corrected without lowering bounds",
    ],
    "baseline": {"summary": "CUSTOMISATION_CAROUSEL: 248 checks, 0 failures",
                 "log": "before/approved-console.log"},
    "remaining_acceptance": ["client reload", "owner appearance and interaction", "physical-device appearance and sampling cost"],
    "limits": ["Windows desktop renderers only", "no phone/tablet attachment check or physical-device test",
               "no APK/export/install", "no real purchase", "no live mutation or deployment", "no owner-process restart",
               "existing actual car geometry, materials and camera retained", "concurrent work preserved"],
}
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"runs": [{"name": r["directory"], "exit": r["exit_code"], "summary": r["summary"]} for r in runs],
                  "reverse_check_exit": check.returncode, "reverse_check_stderr": check.stderr}, indent=2))
raise SystemExit(check.returncode)
