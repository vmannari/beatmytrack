"""Record the isolated native paint-list checks and a scoped review patch."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
EXISTING = ["game/ui/garage_livery_menu.gd", "game/ui/garage_page.gd",
            "game/ui/garage_part_option.gd", "game/ui/garage_parts_list.gd",
            "game/ui/profile_car.gd", "game/tests/test_customisation_carousel.gd",
            "game/tests/test_livery_patterns.gd", "game/tests/test_earned_coins.gd",
            "AGENTS.md", "DEVELOPMENT_STATUS.md"]
NEW = ["game/ui/garage_paint_icons.gd", "game/ui/garage_paint_icons.gd.uid",
       "game/tests/test_garage_paint_list.gd", "game/tests/test_garage_paint_list.gd.uid",
       "docs/GARAGE_PAINT_LIST_2026_10_26.md"]
NEW += ["docs/evidence/garage-paint-list-2026-10-26/"+name
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
for path in sorted(EVIDENCE.glob("*/command.json")):
    log = path.with_name("console.log")
    content = log_text(log)
    runs.append({"directory": path.parent.relative_to(EVIDENCE).as_posix(),
                 **json.loads(path.read_text(encoding="utf-8-sig")),
                 "summary": re.findall(r"(?:GARAGE_PAINT_LIST|CUSTOMISATION_CAROUSEL|GARAGE_CUSTOMISATION_SPEED|EARNED_COINS|SCRIPT_PARSE):[^\r\n]+", content),
                 "failures": re.findall(r"^FAIL:[^\r\n]+", content, re.M),
                 "log_sha256": sha(log)})
initial_command = EVIDENCE / "initial/world-lifetime-command.json"
report = {
    "date": "2026-10-26", "requirements": ["GPL01", "GPL02", "GPL03", "GPL04", "R01", "Q01"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(), "sources": sources,
    "runs": runs,
    "behavior": {"paint_options": 49, "vehicles": 7, "layout": "shared numbered full-width Parts list",
                 "icons": "shared actual profile camera, simple model, lights and compositor",
                 "equipped_icon": "actual saved palette and stickers; selecting restores saved paint",
                 "preview": "main Garage, stable angle/zoom, momentary equipped comparison",
                 "purchases": "explicit Buy & Equip with original confirmation, account and save fences"},
    "resources": {"icon_pixels": [176,112], "display_pixels": [[64,40],[56,36]],
                  "cache_limit": 24, "active_icon_studio_limit": 1, "per_row_worlds": 0,
                  "hidden": "pending jobs cancelled and studio released", "in_flight_teardown": "native stress check passes"},
    "initial_findings": [
        {"issue": "five one-world lifecycle assertion failures from queued-free studios remaining attached",
         "command": json.loads(initial_command.read_text(encoding="utf-8-sig")),
         "log_sha256": sha(EVIDENCE / "initial/world-lifetime-console.log"),
         "correction": "frame-driven worker, detach then queue_free; original world bound retained"},
        {"issue": "compact description wrapped below the original 82-unit row",
         "capture": "initial/compact-description-before.png",
         "correction": "100-unit paint rows with explicit containment checks at all three sizes"},
        {"issue": "project parse observed an in-progress concurrent challenge-test override signature change",
         "command": json.loads((EVIDENCE / "initial/concurrent-challenge-signature-command.json").read_text(encoding="utf-8-sig")),
         "log_sha256": sha(EVIDENCE / "initial/concurrent-challenge-signature-console.log"),
         "correction": "subsequent check after the matching concurrent override was present; no challenge source edits by this task"}],
    "captures": [{"path": path.relative_to(EVIDENCE).as_posix(), "sha256": sha(path)}
                 for path in sorted(EVIDENCE.rglob("*.png"))],
    "checkpoint": {"path": "task-only.patch", "sha256": sha(checkpoint),
                   "reverse_check_exit": reverse.returncode, "stderr": reverse.stderr},
    "remaining_acceptance": ["client reload", "owner appearance, scrolling and compare review",
                             "translated descriptive copy", "physical-device touch and performance"],
    "limits": ["Windows Compatibility and Vulkan Mobile; injected mouse/touch",
               "no attachment check or physical-device test", "no APK", "no real authentication or purchase",
               "no live-account mutation, deployment, merge or owner-process restart", "no staging or commit",
               "historical automatic-commit livery suite not run; one obsolete row type adapted only",
               "concurrent changes preserved and excluded from the patch"]}
(EVIDENCE / "report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"runs": [{"name":run["directory"],"exit":run["exit_code"],"summary":run["summary"]} for run in runs],
                  "checkpoint_reverse_exit":reverse.returncode,"checkpoint_error":reverse.stderr},indent=2))
raise SystemExit(reverse.returncode or int(any(run["exit_code"]!=0 for run in runs)))
