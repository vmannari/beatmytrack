"""Build the task-only review patch and index actual offline verification receipts."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
OWNED = ["game/core/app.gd", "game/ui/weekly_rivalry_page.gd", "game/tests/test_rivalry_ready_entry.gd"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_log(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig", errors="replace")


def app_base(current, task_start):
    """Undo only this task's exact edits, carrying all concurrent work into base."""
    value = current
    changes = [
        ('var _preparing_rivalry_motion: Tween\n', ''),
        ('\tif next == "rivalry" and rivalry_section == "overview" and not is_instance_valid(game) and _rivalry_needs_entry_data():\n\t\t_open_rivalry()\n\t\treturn\n', ''),
        ('\t_preparing_rivalry_motion = null\n\t_stop_menu_edge_motion()', '\t_stop_menu_edge_motion()'),
        ('\t# A neighbor is also an entry route. Do not expose its unresolved cards under\n\t# the finger while the initial membership request is still in flight.\n\tif menu_neighbors.has(direction) and menu_neighbors[direction].screen == "rivalry" and _rivalry_needs_entry_data():\n\t\t_prefetch_rivalry()\n\t\tfor neighbor: Dictionary in menu_neighbors.values(): neighbor.body.hide()\n\t\tmenu_body.position.x = signf(distance)*64.0*(1.0-exp(-absf(distance)/160.0))\n\t\tmenu_drag_offset = 0.0\n\t\treturn\n', ''),
        ('\tif menu_neighbors[direction].screen == "rivalry" and _rivalry_needs_entry_data():\n\t\t_stop_menu_edge_motion()\n\t\t_open_rivalry()\n\t\treturn\n', ''),
        ('\tmenu_neighbors = remaining\n\t_navigation_generation += 1\n\t_cancel_rivalry_entry()', '\tmenu_neighbors = remaining\n\t_navigation_generation += 1'),
        ('\tif next == "rivalry":\n\t\tif _rivalry_needs_entry_data():\n\t\t\t_open_rivalry()\n\t\t\treturn\n\t\t_reset_rivalry_entry_view()', '\tif next == "rivalry": _reset_rivalry_entry_view()'),
        ('\tif menu_page_motion != null and _preparing_rivalry_motion == null: _finish_menu_page_slide()', '\tif menu_page_motion != null: _finish_menu_page_slide()'),
        ('func _rivalry_needs_entry_data() -> bool:\n\treturn rivalry != null and not rivalry.model.sample and online.client.signed_in() and not rivalry.has_snapshot() and (rivalry.busy or rivalry.error.is_empty())\n\n', ''),
    ]
    for new, old in changes:
        assert value.count(new) == 1, new
        value = value.replace(new, old, 1)
    start = value.index('func _prepare_rivalry_page_motion()')
    end = value.index('func _request_race_mode(', start)
    original_start = task_start.index('func _start_prepared_race_mode(')
    original_end = task_start.index('func _request_race_mode(', original_start)
    value = value[:start] + task_start[original_start:original_end] + value[end:]
    assert value.count('\t_prepare_rivalry_page_motion()\n') == 2
    # Restore the original vertical readiness block; horizontal had no gate.
    vertical = value.index('func _slide_race_mode_page(')
    tail = value.index('func _start_prepared_race_mode(', vertical)
    original_vertical = task_start.index('func _slide_race_mode_page(')
    original_gate = task_start.index('\tvar page: WeeklyRivalryPage = content.find_child', original_vertical)
    original_tail = task_start.index('func _start_prepared_race_mode(', original_gate)
    region = value[vertical:tail].replace('\t_prepare_rivalry_page_motion()\n\n', task_start[original_gate:original_tail])
    value = value[:vertical] + region + value[tail:]
    assert value.count('\t_prepare_rivalry_page_motion()\n') == 1
    return value.replace('\t_prepare_rivalry_page_motion()\n', '', 1)


patches = []
sources = []
base_root = EVIDENCE / "checkpoint-base"
for name in OWNED:
    current = (ROOT / name).read_text(encoding="utf-8")
    before_path = EVIDENCE / "before" / name
    before = before_path.read_text(encoding="utf-8") if before_path.exists() else ""
    if name == "game/core/app.gd":
        before = app_base(current, before)
    if before_path.exists():
        base = base_root / name
        base.parent.mkdir(parents=True, exist_ok=True)
        base.write_text(before, encoding="utf-8", newline="\n")
    header = f"diff --git a/{name} b/{name}\n"
    if not before_path.exists():
        header += "new file mode 100644\n"
    patches.append(header + "".join(difflib.unified_diff(
        before.splitlines(keepends=True), current.splitlines(keepends=True),
        fromfile=f"a/{name}" if before_path.exists() else "/dev/null", tofile=f"b/{name}")))
    sources.append({"path": name, "sha256": sha(ROOT / name),
                    "task_start_sha256": sha(before_path) if before_path.exists() else None})

patch = EVIDENCE / "task.patch"
patch.write_text("".join(patches), encoding="utf-8", newline="\n")
checks = []
for args in [
    ["git", "apply", "--reverse", "--check", str(patch)],
    ["git", "apply", "--check", "--unsafe-paths", "--directory=" + str(base_root), str(patch)],
]:
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True)
    checks.append({"command": args, "exit_code": result.returncode, "output": result.stdout + result.stderr})
    assert result.returncode == 0, checks[-1]

logs = []
for path in sorted(EVIDENCE.glob("*.log")):
    value = read_log(path)
    logs.append({"path": path.name, "sha256": sha(path),
                 "results": re.findall(r"([A-Z_]+): (\d+) (checks|scripts), (\d+) failures", value),
                 "client_builds": re.findall(r"Client build: (\S+)", value),
                 "diagnostics": [line for line in value.splitlines() if "FAIL:" in line or "ERROR:" in line or "Command failed" in line]})

report = {
    "date": "2026-10-28", "requirements": ["RRE01", "RRE02", "RRE03"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(),
    "sources": sources, "verification": logs, "patch_checks": checks,
    "documentation": ["docs/RIVALRY_READY_ENTRY_2026_10_28.md", "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"],
    "app_control": json.loads((EVIDENCE / "app-control-provenance.json").read_text(encoding="utf-8")) if (EVIDENCE / "app-control-provenance.json").exists() else None,
    "captures": [{"path": str(p.relative_to(EVIDENCE)).replace("\\", "/"), "sha256": sha(p)} for p in sorted(EVIDENCE.glob("*/*.png"))],
    "commands": [
        "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_ready_entry.gd -CommandTimeoutSeconds 120",
        "Native Compatibility: add -Graphical -RenderingMethod gl_compatibility; desktop Mobile: add -Graphical -RenderingMethod mobile -TestArgument --compact",
        "APPDATA/LOCALAPPDATA=build/rivalry-ready-entry/<run>/{appdata,localappdata}; BMT_RIVALRY_READY_CAPTURE_DIR=docs/evidence/rivalry-ready-entry-2026-10-28/<renderer>",
        "powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/rivalry-ready-entry-2026-10-28/run_checks.ps1",
        "Final App/parser reruns: same TestScript command with res://tests/test_app.gd and res://tests/test_script_parse.gd, offline profile build/rivalry-ready-entry/final-controls",
        "python docs/evidence/rivalry-ready-entry-2026-10-28/prepare_app_control.py; TestScript res://tests/_rivalry_ready_app_control.gd with offline profile build/rivalry-ready-entry/app-control; remove only the two owned temporary scripts after archiving",
        "python docs/evidence/rivalry-ready-entry-2026-10-28/build_evidence.py",
    ],
    "limits": [
        "Synthetic responses and isolated offline App profiles; no live service or owner saves used.",
        "Network wait and first desktop construction costs remain; no phone/FPS or latency improvement claim.",
        "Initial sandbox certificate-store failure is retained; local isolated execution passed the engine access restriction.",
        "Two transient concurrent editor parse failures are retained. Final App and no-Rivalry-patch control both retain the same editor touch-cancellation failure (141 checks, one failure).",
        "Concurrent Garage account-restoration and editor jump/dialog edits in App are preserved and excluded from the task patch.",
        "Generated build identity/project metadata are excluded; no main-index staging, commit or merge.",
        "No device attachment query/test, APK, deployment or owner-process restart; reload/rebuild and owner/device acceptance remain.",
    ],
}
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"sources": len(sources), "logs": len(logs), "captures": len(report["captures"]), "patch_checks": [c["exit_code"] for c in checks]}))
