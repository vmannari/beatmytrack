"""Record actual preview transitions and a reverse-checkable task patch."""
from pathlib import Path
import difflib
import hashlib
import json
import math
import re
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
EXISTING = ["game/ui/garage_page.gd", "game/ui/garage_customisation_camera.gd",
            "game/tests/test_customisation_carousel.gd", "AGENTS.md", "DEVELOPMENT_STATUS.md"]
NEW = ["game/tests/test_garage_preview_stability.gd", "game/tests/test_garage_preview_stability.gd.uid",
       "docs/GARAGE_PREVIEW_STABILITY_2026_10_26.md"]
NEW += ["docs/evidence/garage-preview-stability-2026-10-26/"+name
        for name in ("run.ps1", "record.py", "review.html")]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def log_text(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith(b"\xff\xfe") else "utf-8-sig", errors="replace")


patch, sources = [], []
for name in EXISTING + NEW:
    target, before = ROOT / name, EVIDENCE / "before" / name
    original = before.read_text(encoding="utf-8") if before.exists() else ""
    current = target.read_text(encoding="utf-8")
    if original != current:
        patch.append(f"diff --git a/{name} b/{name}\n")
        patch.extend(difflib.unified_diff(original.splitlines(True), current.splitlines(True),
                     fromfile=f"a/{name}" if before.exists() else "/dev/null", tofile=f"b/{name}"))
    sources.append({"path": name, "sha256": sha(target),
                    "before_sha256": sha(before) if before.exists() else None})
checkpoint = EVIDENCE / "task-only.patch"
checkpoint.write_text("".join(patch), encoding="utf-8", newline="\n")
reverse = subprocess.run(["git", "apply", "--check", "--reverse", str(checkpoint)],
                         cwd=ROOT, capture_output=True, text=True)
runs = []
for path in sorted(EVIDENCE.rglob("command.json")):
    log = path.with_name("console.log")
    content = log_text(log)
    runs.append({"directory": path.parent.relative_to(EVIDENCE).as_posix(),
                 **json.loads(path.read_text(encoding="utf-8-sig")),
                 "summary": re.findall(r"(?:GARAGE_PREVIEW_STABILITY|CUSTOMISATION_CAROUSEL|SCRIPT_PARSE):[^\r\n]+", content),
                 "failures": re.findall(r"^FAIL:[^\r\n]+", content, re.M), "log_sha256": sha(log)})
transitions = []
for path in sorted(EVIDENCE.rglob("transitions.json")):
    rows = json.loads(path.read_text(encoding="utf-8"))
    vector = lambda value: [float(part) for part in value.strip("()").split(",")]
    distances = [math.dist(vector(row["camera_origin"]),vector(row["expected_origin"])) for row in rows]
    transitions.append({"path": path.relative_to(EVIDENCE).as_posix(), "sha256": sha(path),
                        "rows": len(rows), "selection_resets": sum(row["actual"]!=row["option"] for row in rows),
                        "max_reported_origin_delta_world_units": max(distances,default=0.0)})
report = {
    "date": "2026-10-26", "requirements": ["GPS01", "GPS02", "GPS03", "R01", "Q01"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(), "sources": sources,
    "runs": runs, "transitions": transitions,
    "behavior": {"same_category": "Retain focus, player orbit/zoom and current category-entry animation",
                 "resize": "Refit distance while retaining direction, orbit values and selected preview",
                 "cleanliness": "Check equipped geometry with unchanged masks and thresholds; genuinely newer dirt still locks",
                 "active_navigation": "Active Parts/category/Workshop input does not clear the preview; internal refresh remains"},
    "initial_fixture_correction": "Retained actual-App test waits for covered Garage preparation, asserts readiness and preserves every original check",
    "initial_logs": [{"path": path.relative_to(EVIDENCE).as_posix(), "sha256": sha(path)}
                     for path in sorted((EVIDENCE / "initial").glob("*.log"))],
    "captures": [{"path": path.relative_to(EVIDENCE).as_posix(), "sha256": sha(path)}
                 for path in sorted(EVIDENCE.rglob("*.png"))],
    "cleanliness_script_audit_sha256": sha(ROOT / "game/ui/garage_cleanliness.gd"),
    "checkpoint": {"path": "task-only.patch", "sha256": sha(checkpoint),
                   "reverse_check_exit": reverse.returncode, "stderr": reverse.stderr},
    "remaining_acceptance": ["client reload", "owner camera/selection feel", "physical-device input review"],
    "limits": ["Windows Compatibility and Vulkan Mobile; injected mouse/touch", "no attachment check or physical-device test",
               "no APK", "no real purchase or live mutation", "no deployment, merge or owner-process restart",
               "concurrent work preserved; no staging or commit"],
}
(EVIDENCE / "report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"runs": [{"name":run["directory"],"exit":run["exit_code"],"summary":run["summary"]} for run in runs],
                  "transition_stats":transitions,"checkpoint_reverse_exit":reverse.returncode,"checkpoint_error":reverse.stderr},indent=2))
failed_final = any(run["exit_code"]!=0 for run in runs if not run["directory"].startswith("before/"))
raise SystemExit(reverse.returncode or int(failed_final))
