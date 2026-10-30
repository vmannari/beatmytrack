"""Record native outcomes and an exact, task-scoped review checkpoint."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
EXISTING = ["game/ui/garage_page.gd", "game/ui/garage_customisation_camera.gd",
            "game/ui/garage_environment.gd", "game/vehicle/vehicle_customisation.gd",
            "game/tests/test_customisation_carousel.gd", "AGENTS.md", "DEVELOPMENT_STATUS.md"]
NEW = ["game/ui/"+name+suffix
       for name in ("garage_parts_list", "garage_part_option", "garage_compare_button", "garage_part_indicator")
       for suffix in (".gd", ".gd.uid")]
NEW += ["game/tests/capture_garage_configurator.gd", "game/tests/capture_garage_configurator.gd.uid",
        "docs/GARAGE_LIVE_CONFIGURATOR_2026_10_26.md"]
NEW += ["docs/evidence/garage-live-configurator-2026-10-26/"+name
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
result = subprocess.run(["git", "apply", "--check", "--reverse", str(checkpoint)],
                        cwd=ROOT, capture_output=True, text=True)
runs = []
for path in sorted(EVIDENCE.glob("*/command.json")):
    if path.parent.name == "initial": continue
    command = json.loads(path.read_text(encoding="utf-8-sig"))
    log = path.with_name("console.log")
    content = log_text(log)
    runs.append({"directory": path.parent.name, **command,
                 "summary": re.findall(r"(?:CUSTOMISATION_CAROUSEL|GARAGE_SIDEBAR|GARAGE_VIEW_CONTROLS|"
                                       r"GARAGE_CUSTOMISATION_SPEED|GARAGE_CONFIGURATOR_CAPTURE|SCRIPT_PARSE):[^\r\n]+", content),
                 "failures": re.findall(r"^FAIL:[^\r\n]+", content, re.M), "log_sha256": sha(log)})
report = {
    "date": "2026-10-26", "requirements": ["GLF01", "GLF02", "GLF03", "GLF04", "GLF05", "R01", "Q01"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(),
    "behavior": {"parts": "Full-width numbered text rows, descriptions, aligned prices and actual category counts",
                 "states": "Thin selected outline, green equipped check and independent preview state",
                 "preview": "Actual Garage car only; no Parts photos, detail world or redundant selected summary/cancel action",
                 "purchase": "Existing explicit confirmation, ownership, account, serial, save and affordability guards",
                 "compare": "Momentary mouse/touch/keyboard hold; outside release, cancel, focus, selection/account/navigation cleanup",
                 "presentation": "Flat UI, projected callout, actual untinted finish, revised Hood framing and Garage key/fill"},
    "sources": sources, "runs": runs,
    "retained_assets_test_sha256": sha(ROOT / "game/tests/test_garage_customisation_speed.gd"),
    "initial_findings": ["No-photo assertion initially included the required equipped-check icon",
                         "Native resize callback needed a detached-tree guard",
                         "Selected row could be clipped until scrollbar bounds settled; original enclosure assertion retained"],
    "initial_logs": [{"path": path.relative_to(EVIDENCE).as_posix(), "sha256": sha(path)}
                     for path in sorted((EVIDENCE / "initial").glob("*.log"))],
    "captures": [{"path": path.relative_to(EVIDENCE).as_posix(), "sha256": sha(path)}
                 for path in sorted(EVIDENCE.rglob("*.png"))],
    "checkpoint": {"path": "task-only.patch", "sha256": sha(checkpoint),
                   "reverse_check_exit": result.returncode, "stderr": result.stderr},
    "review_fixture": "Actual App with isolated red paint and 3000-coin local Shop fixture; no live account, balance or purchase",
    "remaining_acceptance": ["client reload", "owner appearance/touch", "translated descriptive copy", "physical-device review"],
    "limits": ["Windows desktop renderers and injected touch only", "no device attachment check or physical-device test",
               "no APK", "no real authentication/purchase or live mutation", "no deployment or owner-process restart",
               "concurrent work preserved; no staging or commit"],
}
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"runs": [{"name": run["directory"], "exit": run["exit_code"], "summary": run["summary"]}
                           for run in runs], "checkpoint_reverse_exit": result.returncode,
                  "checkpoint_error": result.stderr}, indent=2))
raise SystemExit(result.returncode)
