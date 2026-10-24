"""Record this UI task and build a patch against its retained working sources."""
from hashlib import sha256
import json
from pathlib import Path
import subprocess

evidence = Path(__file__).resolve().parent
repo = evidence.parents[2]
changed = [
    "game/ui/menu_style.gd",
    "game/ui/race_hud_style.gd",
    "game/ui/achievements_menu.gd",
    "game/ui/weekly_rivalry_page.gd",
    "docs/STORE_REFERENCE_2026_10_24.md",
]
added = ["game/tests/test_scrollbar_style.gd"]
patches = []
for relative in changed:
    before = evidence / "before" / (relative.replace("/", "__") + ".txt")
    before_relative = before.relative_to(repo).as_posix()
    result = subprocess.run(
        ["git", "diff", "--no-index", "--binary", "--", before_relative, relative],
        cwd=repo, capture_output=True, check=False,
    )
    if result.returncode not in (0, 1):
        raise RuntimeError(result.stderr.decode())
    patches.append(result.stdout.replace(("a/" + before_relative).encode(), ("a/" + relative).encode()))
for relative in added:
    result = subprocess.run(
        ["git", "diff", "--no-index", "--binary", "--", "/dev/null", relative],
        cwd=repo, capture_output=True, check=False,
    )
    if result.returncode != 1:
        raise RuntimeError(result.stderr.decode())
    patches.append(result.stdout)
checkpoint = evidence / "checkpoint.patch"
checkpoint.write_bytes(b"".join(patches))
subprocess.run(["git", "apply", "--check", "--reverse", str(checkpoint)], cwd=repo, check=True)
subprocess.run(["git", "diff", "--check", "--", *changed, *added], cwd=repo, check=True)

report = {
    "date": "2026-10-24",
    "requirements": {
        "SSP01": "One subtle vertical/horizontal scrollbar style across shared menu and race HUD themes, including native nested controls.",
        "SSP02": "4-unit rounded thumb, 24-unit native drag lane, 10-unit clearance to either side, inset ends and transparent rail; clearer hover/pressed states.",
        "R01": "Retain gestures, native thumb dragging, automatic hiding, focused item reveal, list layout, purchase guards and existing modal gutters.",
        "G01": "Inspect actual Store, Settings, Rivalry and short achievement-sheet captures plus native pixel clearance on both axes.",
        "Q01": "Use the pinned engine, isolated fixture service and userdata; preserve concurrent changes and check a task-only patch.",
    },
    "changed_files": changed + added,
    "engine": (repo / "godot-version.txt").read_text().strip(),
    "command_template": "powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/scrollbar-style-2026-10-24/run_validation.ps1",
    "runs": [
        {"arguments": "-Mode gl_compatibility", "checks": 22, "failures": 0, "exit": 0},
        {"arguments": "-Mode mobile", "checks": 22, "failures": 0, "exit": 1, "limitation": "Assertions and native captures completed; engine stalled during shutdown and this owned tool session was interrupted with Ctrl-C."},
        {"arguments": "-Test test_store_reference", "checks": 131, "failures": 0, "exit": 0},
        {"arguments": "-Test test_store_reference -Mode gl_compatibility", "checks": 144, "failures": 0, "exit": 0},
        {"arguments": "-Test test_store_reference -Mode mobile", "checks": 144, "failures": 0, "exit": 0, "note": "Separate Mobile run completed; shutdown reported four ObjectDB instances and one resource."},
        {"arguments": "-Test test_achievement_detail_layout", "checks": 1220, "failures": 0, "exit": 0},
        {"arguments": "-Test test_achievement_detail_layout -Mode gl_compatibility", "checks": 1229, "failures": 0, "exit": 0},
    ],
    "retained_diagnostics": [
        "Sandbox certificate-store diagnostic remains in native logs; no TLS settings were changed.",
        "Read-only CIM lookup of the owned test process was denied by the sandbox. The known running tool session was interrupted directly; no process-name kill or owner-process restart was used.",
        "Mobile focused fixture passed all assertions but stalled at shutdown; the separate actual Store Mobile run completed with the shutdown resource diagnostics listed above. No universal clean-shutdown claim.",
    ],
    "source_sha256": {p: sha256((repo / p).read_bytes()).hexdigest() for p in changed + added},
    "captures": [p.relative_to(evidence).as_posix() for p in sorted(evidence.glob("final/**/*.png"))],
    "checkpoint": {"file": "checkpoint.patch", "reverse_check_exit": 0, "scope": "Task-start sources retain concurrent tab and Rivalry presentation edits; those edits and the preceding Store scrolling task are excluded."},
    "remaining_acceptance": ["Reload the client.", "Owner appearance acceptance and physical-device appearance/interaction review."],
    "phone_or_tablet_attachment_checked": False,
    "physical_device_test_performed": False,
    "apk_built": False,
    "real_purchase_or_live_mutation": False,
    "deployment_or_owner_process_restart": False,
}
(evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("Task-only patch validates; report and source hashes saved.")
