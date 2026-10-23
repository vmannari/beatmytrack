"""Package this task's saved sources, actual logs, and reviewable Git patch."""
from pathlib import Path
import difflib
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
runtime = [
    "game/core/app.gd", "game/editor/editor_world.gd",
    "game/editor/preview_ground.gd", "game/editor/prepared_track_cache.gd",
    "game/track/native_track.gd", "game/track/native_track_visual.gd",
    "game/track/desert_road_relief.gd", "game/track/winter_scenery.gd",
]
paths = runtime + [
    "game/tests/test_editor_placement_latency.gd",
    "game/tests/fixtures/desert_relief_before_editor_latency.gd",
    "game/tests/test_editor_workflow.gd", "game/tests/profile_road_approval.gd",
    "docs/EDITOR_PLACEMENT_LATENCY_2026_10_18.md",
    "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md",
]
hashes = {}
patch = []
for relative in paths:
    current = (ROOT / relative).read_bytes()
    name = relative.replace("/", "__")
    if relative in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
        name = "pre-entry__" + name
    before = OUT / "before" / name
    original = before.read_bytes() if before.exists() else b""
    hashes[relative] = {
        "before_sha256": hashlib.sha256(original).hexdigest() if before.exists() else None,
        "after_sha256": hashlib.sha256(current).hexdigest(),
    }
    # Normalize CRLF like the repository text filters; preserve content verbatim.
    old = original.decode("utf-8-sig").replace("\r\n", "\n")
    new = current.decode("utf-8-sig").replace("\r\n", "\n")
    if old == new:
        continue
    patch.append(f"diff --git a/{relative} b/{relative}\n")
    if not before.exists():
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(
        old.splitlines(keepends=True), new.splitlines(keepends=True),
        fromfile="a/" + relative if before.exists() else "/dev/null",
        tofile="b/" + relative,
    ))
(OUT / "task-only.patch").write_text("".join(patch), encoding="utf-8", newline="")

prefix = "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 "
checks = [
    ("placement_headless", "-Action TestScript -ScriptPath res://tests/test_editor_placement_latency.gd -CommandTimeoutSeconds 300", "build/logs/TestScript-23744/test-script.log", 0, 179, 0),
    ("placement_mobile", "-Action TestScript -ScriptPath res://tests/test_editor_placement_latency.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -CommandTimeoutSeconds 300", "build/logs/TestScript-19744/test-script.log", 0, 184, 0),
    ("placement_compatibility", "-Action TestScript -ScriptPath res://tests/test_editor_placement_latency.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 300", "build/logs/TestScript-25584/test-script.log", 0, 191, 0),
    ("existing_retained_objects_and_saves", "-Action TestScript -ScriptPath res://tests/test_editor_incremental_objects.gd -CommandTimeoutSeconds 300", "build/logs/TestScript-23136/test-script.log", 0, 47, 0),
    ("workflow", "-Action TestWorkflow -CommandTimeoutSeconds 300", "build/logs/TestWorkflow-22692/editor-workflow-tests.log", 0, 252, 0),
    ("app", "-Action TestApp -CommandTimeoutSeconds 180", "build/logs/TestApp-24344/app-tests.log", 0, 101, 0),
    ("parser", "-Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 120", "build/logs/TestScript-25244/test-script.log", 0, 857, 0),
    ("older_road_approval_final", "-Action TestRoadApproval -CommandTimeoutSeconds 300", "build/logs/TestRoadApproval-9560/road-approval-tests.log", 1, 40, 4),
    ("older_road_approval_original", "-Action TestRoadApproval -CommandTimeoutSeconds 300", "build/editor-placement-original/build/logs/TestRoadApproval-27360/road-approval-tests.log", 1, 40, 4),
]
commands = []
(OUT / "logs").mkdir(exist_ok=True)
for name, arguments, log, code, count, failures in checks:
    destination = OUT / "logs" / (name + ".log")
    shutil.copy2(ROOT / log, destination)
    command = prefix + arguments
    if name.endswith("_original"):
        command = command.replace("-File scripts/", "-File build/editor-placement-original/scripts/")
    commands.append({"check": name, "command": command, "exit_code": code,
                     "checks": count, "failures": failures,
                     "log": str(destination.relative_to(OUT)).replace("\\", "/")})

attempts = {
    "initial-certificate-store.log": "build/logs/TestScript-25000/test-script.log",
    "original-completed-observations.log": "build/editor-placement-appdata/Circuit01Lab/logs/godot.log",
    "overly-strict-ground-identity.log": "build/editor-placement-appdata-final/Circuit01Lab/logs/godot.log",
    "fixture-startup-recursion.log": "build/logs/TestScript-20052/test-script.log",
    "workflow-before-startup-wait.log": "build/logs/TestWorkflow-26564/editor-workflow-tests.log",
    "road-approval-before-startup-wait.log": "build/logs/TestRoadApproval-28552/road-approval-tests.log",
    "intermediate-compatibility.log": "build/editor-placement-native/Circuit01Lab/logs/godot.log",
}
for name, source in attempts.items():
    shutil.copy2(ROOT / source, OUT / "attempts" / name)

baseline = json.loads((OUT / "baseline-headless-gl_compatibility/report.json").read_text())
final = json.loads((OUT / "final-headless-gl_compatibility/report.json").read_text())
baseline_by_name = {row["operation"]: row for row in baseline["observations"]}
comparisons = []
for row in final["observations"]:
    if row["operation"] in baseline_by_name:
        comparisons.append({"operation": row["operation"], "before": baseline_by_name[row["operation"]], "after": row})
report = {
    "date": "2026-10-18", "requirements": ["EPL01", "EPL02", "EPL03", "G01", "R01", "Q01"],
    "engine": "4.7.2.stable.official.ed1daf0bf", "gpu_for_render_checks": "NVIDIA GeForce RTX 3090",
    "source_hashes": hashes, "commands": commands,
    "environment": "Each test uses a separate build/editor-placement-* APPDATA directory and disposable fixture saves. Native execution permits the Windows certificate-store read blocked in restricted attempts.",
    "comparison_scope": "Single observed samples on the same synthetic 24-piece circuit. Process frame intervals, not device FPS. Headless samples collected before concurrent broader regressions; renderer observations are used for correctness only.",
    "comparisons": comparisons,
    "baseline_command": "powershell -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_placement_latency.gd -TestArgument '--baseline' -CommandTimeoutSeconds 300",
    "baseline_command_status": "Wrapper failed on certificate-store access, but the child completed 145 checks with zero failures and wrote the preserved baseline report/log. It is observation evidence, not a passed wrapper command.",
    "initial_attempts": [
        "Direct ./scripts/dev.ps1 blocked by PowerShell execution policy.",
        "Restricted Godot log/root-certificate access failures; later native tests use disposable workspace APPDATA.",
        "Ground identity initially included the full overlay image, preventing valid scene reuse. Corrected by private material rebinding.",
        "Multiple -TestArgument values passed through -File were received as one comma-separated string; focused rerun used the single --pine switch.",
        "New test-only Garage shortcut initially triggered startup profile rebuilding recursively; fixture corrected without changing the game guard.",
        "Workflow and old road-approval fixtures opened editing during asynchronous startup; changed only to await startup_complete, preserving all assertions.",
    ],
    "validation_scope": "Headless/Mobile runs precede the additional solid-on-road case and final finish-stripe identity guard; final Compatibility includes them. Scoped source snapshots and command logs are retained; generated build IDs also changed with concurrent unrelated Garage work.",
    "known_limits": [
        "Detailed new Desert road preparation still takes roughly 13 seconds in the background; existing immediate road overlay/input remain usable.",
        "Cold shader/driver preparation can still stall first biome/surface use in native rendered runs.",
        "First detailed prop model generation can still take roughly 0.1-0.2 seconds in the placement callback.",
        "Older road-approval suite has four exact saved-original-runtime failures and is not counted as passing.",
        "No physical phone attachment check/test, export/APK/install, backend mutation or deployment. Owner/device flow acceptance remains.",
    ],
    "checkpoint": "task-only.patch, against saved task-start runtime sources and immediate pre-entry documentation snapshots; unrelated dirty-tree work and the normal Git index are preserved.",
}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(f"Packaged {len(paths)} scoped files and {len(commands)} actual validation commands.")
