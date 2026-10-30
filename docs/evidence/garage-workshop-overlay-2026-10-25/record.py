"""Record actual native checks and a scoped, reverse-checkable task patch."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
EXISTING = ["game/ui/garage_page.gd", "game/tests/test_garage_sidebar.gd",
            "game/tests/test_customisation_carousel.gd", "AGENTS.md", "DEVELOPMENT_STATUS.md"]
NEW = ["docs/GARAGE_WORKSHOP_OVERLAY_2026_10_25.md"]
NEW += ["docs/evidence/garage-workshop-overlay-2026-10-25/"+name
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
    patch.append(f"diff --git a/{name} b/{name}\n")
    patch.extend(difflib.unified_diff(original.splitlines(True), current.splitlines(True),
        fromfile=f"a/{name}" if before.exists() else "/dev/null", tofile=f"b/{name}"))
    sources.append({"path": name, "sha256": sha(target), "before_sha256": sha(before) if before.exists() else None})
checkpoint = EVIDENCE / "task-only.patch"
checkpoint.write_text("".join(patch), encoding="utf-8", newline="\n")
result = subprocess.run(["git", "apply", "--check", "--reverse", str(checkpoint)],
                        cwd=ROOT, capture_output=True, text=True)
runs = []
for path in sorted(EVIDENCE.glob("*/command.json")):
    command = json.loads(path.read_text(encoding="utf-8-sig"))
    log = path.with_name("console.log")
    summaries = re.findall(r"(?:CUSTOMISATION_CAROUSEL|GARAGE_SIDEBAR|APP_TESTS|SCRIPT_PARSE):[^\r\n]+",log_text(log))
    runs.append({"directory": path.parent.name, **command, "summary": summaries, "log_sha256": sha(log)})
report = {
    "date": "2026-10-25", "requirements": ["GWO01", "GWO02", "GWO03", "R01", "Q01"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(),
    "runs": runs, "sources": sources,
    "baseline": {"log": "before/console.log", "summary": "GARAGE_SIDEBAR: 484 checks, 0 failures"},
    "initial_visual_correction": {"image": "initial/caption-icon-space.png",
        "finding": "Native expanded icons need explicit width beside captions; corrected without changing touch targets"},
    "captures": [{"path": str(path.relative_to(EVIDENCE)).replace("\\", "/"), "sha256": sha(path)}
                 for path in sorted(EVIDENCE.rglob("*.png"))],
    "checkpoint": {"path": "task-only.patch", "sha256": sha(checkpoint),
                   "reverse_check_exit": result.returncode, "stderr": result.stderr},
    "remaining_acceptance": ["client reload", "owner appearance and touch", "physical-device acceptance"],
    "limits": ["Windows desktop renderers only", "no phone/tablet attachment check or physical-device test",
               "no APK", "no real purchase or live mutation", "no deployment or owner-process restart",
               "concurrent work preserved"],
}
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"runs": [{"name": run["directory"], "exit": run["exit_code"], "summary": run["summary"]}
                           for run in runs], "checkpoint_reverse_exit": result.returncode,
                  "checkpoint_error": result.stderr}, indent=2))
raise SystemExit(result.returncode)
