"""Record UI checks, the unchanged baseline failure and a scoped task patch."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
EXISTING = ["game/ui/garage_page.gd", "AGENTS.md", "DEVELOPMENT_STATUS.md"]
EXISTING += ["game/tests/"+name+".gd" for name in (
    "test_garage_clean_customisation", "test_garage_sidebar", "test_garage_view_controls",
    "test_garage_tuning_layout", "test_livery_patterns")]
NEW = ["docs/GARAGE_WASH_OVERLAY_2026_10_25.md",
       "game/tests/fixtures/garage_wash_overlay_before/test_clean_before.gd",
       "game/tests/fixtures/garage_wash_overlay_before/.gdignore"]
NEW += ["docs/evidence/garage-wash-overlay-2026-10-25/"+name
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
    if not before.exists() and not current:
        patch.append("new file mode 100644\nindex 0000000..e69de29\n")
    else:
        patch.extend(difflib.unified_diff(original.splitlines(True), current.splitlines(True),
            fromfile=f"a/{name}" if before.exists() else "/dev/null", tofile=f"b/{name}"))
    sources.append({"path": name, "sha256": sha(target), "before_sha256": sha(before) if before.exists() else None})
checkpoint = EVIDENCE / "task-only.patch"
checkpoint.write_text("".join(patch), encoding="utf-8", newline="\n")
result = subprocess.run(["git", "apply", "--check", "--reverse", str(checkpoint)],
                        cwd=ROOT, capture_output=True, text=True)
runs = []
for path in sorted(EVIDENCE.rglob("command.json")):
    command = json.loads(path.read_text(encoding="utf-8-sig"))
    log = path.with_name("console.log")
    content = log_text(log)
    summaries = re.findall(r"(?:CUSTOMISATION_CAROUSEL|GARAGE_SIDEBAR|GARAGE_VIEW_CONTROLS|Garage clean customisation|APP_TESTS|SCRIPT_PARSE):[^\r\n]+",content)
    failures = re.findall(r"^FAIL: ([^\r\n]+)",content,re.M)
    known = command["exit_code"] != 0 and failures == ["forklift heavy slow film still blocks"]
    runs.append({"directory": str(path.parent.relative_to(EVIDENCE)).replace("\\", "/"), **command,
                 "summary": summaries, "failures": failures, "known_preexisting_failure": known,
                 "log_sha256": sha(log)})
report = {
    "date": "2026-10-25", "requirements": ["GWO04", "GWO05", "GWO06", "R01", "Q01"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(), "runs": runs, "sources": sources,
    "baseline": {"runtime": "before/game/ui/garage_page.gd",
                 "test": "before/game/tests/test_garage_clean_customisation.gd",
                 "isolation": "Exact source reloaded only into the disposable process memory; no runtime file restoration",
                 "failure": "forklift heavy slow film still blocks"},
    "initial_fixture_issue": {"log": "before/console.log", "issue": "res:// evidence-root argument was not normalized after parsing; fixture corrected"},
    "captures": [{"path": str(path.relative_to(EVIDENCE)).replace("\\", "/"), "sha256": sha(path)}
                 for path in sorted(EVIDENCE.rglob("*.png"))],
    "checkpoint": {"path": "task-only.patch", "sha256": sha(checkpoint),
                   "reverse_check_exit": result.returncode, "stderr": result.stderr},
    "not_run": ["Full legacy livery-pattern and tuning-layout suites; their removed-button fixture references were updated, and full parser checks pass"],
    "remaining_acceptance": ["client reload", "owner appearance and touch", "physical-device acceptance",
                             "separate pre-existing Forklift heavy-slow-film cleanliness assertion"],
    "limits": ["Windows desktop renderers only", "no phone/tablet attachment check or physical-device test",
               "no APK", "no real purchase or live mutation", "no deployment or owner-process restart",
               "no cleanliness threshold changed", "concurrent work preserved"],
}
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
unexpected = [run["directory"] for run in runs if not run["summary"] or (run["exit_code"] and not run["known_preexisting_failure"])]
print(json.dumps({"runs": [{"name": run["directory"], "exit": run["exit_code"], "summary": run["summary"],
                            "known_failure": run["known_preexisting_failure"]} for run in runs],
                  "unexpected_failures": unexpected, "checkpoint_reverse_exit": result.returncode,
                  "checkpoint_error": result.stderr}, indent=2))
raise SystemExit(result.returncode or bool(unexpected))
