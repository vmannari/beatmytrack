"""Collect this task's existing receipts and build a source-only review patch."""
from pathlib import Path
import difflib
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
logs = sorted((ROOT / "build/logs").glob("TestScript-*/test-script.log"),
              key=lambda p: p.stat().st_mtime, reverse=True)


def receipt(name, marker, script, extra="", timeout=180, contains=""):
    for path in logs:
        data = path.read_text(errors="replace")
        if marker not in data or (contains and contains not in data):
            continue
        if "SCRIPT ERROR:" in data or "FAIL:" in data:
            continue
        target = OUT / "logs" / (name + ".log")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        identity = path.parent / "client-build-identity.json"
        shutil.copyfile(identity, target.with_suffix(".identity.json"))
        return {
            "command": ("powershell -NoProfile -ExecutionPolicy Bypass -File "
                        "scripts/dev.ps1 TestScript -ScriptPath res://tests/"
                        f"{script} {extra} -CommandTimeoutSeconds {timeout}").strip(),
            "result": marker, "log": str(target.relative_to(ROOT)),
            "original_log": str(path.relative_to(ROOT)),
            "identity": json.loads(identity.read_text(encoding="utf-8-sig"))["build_id"],
        }
    raise RuntimeError("Missing completed receipt: " + name)


checks = [
    receipt("latency-catalog", "CHECKPOINT_NOTICE_LATENCY: 2154 checks, 0 failures",
            "test_checkpoint_notice_latency.gd", "-TestArgument '--catalog'", 240),
    receipt("notices", "CHECKPOINT_NOTICE_TESTS: 537 checks, 0 failures", "test_checkpoint_notices.gd"),
    receipt("star-consistency", "STAR_CONSISTENCY_TESTS: 58 checks, 0 failures", "test_star_checkpoint_consistency.gd"),
    receipt("star-edge", "STAR_GATE_TOLERANCE_TESTS: 201 checks, 0 failures", "test_star_gate_tolerance.gd", timeout=240),
    receipt("dust-cloud", "BRIDGE_CHECKPOINT_TESTS: 259 checks, 0 failures", "test_checkpoint_bridge_layers.gd", timeout=240),
    receipt("forgiveness", "CHECKPOINT_FORGIVENESS: 48 checks, 0 failures", "test_checkpoint_forgiveness.gd"),
    receipt("gates", "CHECKPOINT_TESTS: 266 checks, 0 failures", "test_checkpoint_rules.gd"),
    receipt("rewind", "Rewind: 61 checks, 0 failures", "test_rewind.gd"),
    receipt("parse", "SCRIPT_PARSE: 847 scripts, 0 failures", "test_script_parse.gd"),
    receipt("capture-compatibility", "CHECKPOINT_NOTICE_CAPTURE before_missed=18 after_missed=-1 gate_ahead=0.86936104297638 saved=true",
            "capture_checkpoint_notice_recovery.gd", "-Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3", contains="OpenGL API"),
    receipt("capture-mobile", "CHECKPOINT_NOTICE_CAPTURE before_missed=18 after_missed=-1 gate_ahead=0.86936104297638 saved=true",
            "capture_checkpoint_notice_recovery.gd", "-Graphical -RenderingMethod mobile -RenderingDriver vulkan", contains="Vulkan"),
]
baseline = receipt("frozen-baseline", "CHECKPOINT_NOTICE_LATENCY: 1175 checks, 0 failures",
                   "test_checkpoint_notice_latency.gd")
baseline["command"] = ("powershell -NoProfile -ExecutionPolicy Bypass -Command "
                       '"& ./scripts/dev.ps1 -Action TestScript -ScriptPath '
                       "'res://tests/test_checkpoint_notice_latency.gd' "
                       "-TestArgument @('--baseline','--catalog') -CommandTimeoutSeconds 180\"")

# Retain failed diagnostics as evidence, not as final validation.
attempts = []
for folder in ["TestScript-31828", "TestScript-14224", "TestScript-31852",
               "TestScript-18132", "TestScript-8232", "TestScript-10596",
               "TestScript-30552", "Import-2892"]:
    source = ROOT / "build/logs" / folder
    for path in source.glob("*.log"):
        target = OUT / "attempts" / folder / path.name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        attempts.append(str(target.relative_to(ROOT)))

scope = ["game/race/track_session.gd", "game/race/spline_gate_corridor.gd",
         "game/tests/test_checkpoint_notices.gd", "scripts/dev.ps1",
         "game/tests/test_checkpoint_notice_latency.gd",
         "game/tests/test_checkpoint_notice_latency.gd.uid",
         "game/tests/capture_checkpoint_notice_recovery.gd",
         "game/tests/capture_checkpoint_notice_recovery.gd.uid",
         "docs/CHECKPOINT_NOTICE_TIMING_2026_10_17.md",
         "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
prefix = "docs/evidence/checkpoint-notice-2026-10-17/"
required_before = [prefix + "before/game/race/track_session.gd",
                   prefix + "before/game/race/spline_gate_corridor.gd"]
scope += required_before
patch = []
for name in scope:
    path = ROOT / name
    after = path.read_text(encoding="utf-8-sig")
    before_path = OUT / ("before-docs-final" if name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"] else "before") / name
    before = before_path.read_text(encoding="utf-8-sig") if before_path.exists() else ""
    if name == "scripts/dev.ps1":
        own = ("    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', "
               "'res://tests/test_checkpoint_notice_latency.gd') 'checkpoint-notice-latency-tests.log'\n")
        assert after.count(own) == 1
        before = after.replace(own, "")  # Exclude any concurrent Validate additions.
    patch += difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True),
                                 fromfile="a/" + name if before_path.exists() else "/dev/null",
                                 tofile="b/" + name)
(OUT / "task-only.patch").write_text("".join(patch), encoding="utf-8", newline="\n")

before_rows = json.loads((OUT / "baseline-catalog-latency.json").read_text())
final_rows = json.loads((OUT / "final-catalog-latency.json").read_text())
assert sum(row["blocked_cuts"] for row in final_rows) == 500
assert sum(row["silent_cuts"] for row in final_rows) == 0
assert (ROOT / "game/ui/checkpoint_marker.gd").read_bytes() == (OUT / "before/game/ui/checkpoint_marker.gd").read_bytes()
report = {
    "date": "2026-10-17", "engine": "4.7.2.stable.official.ed1daf0bf",
    "rules": "standing-5-road-gates-v22", "physics": "arcade-planar-0.65", "notice_layout": 3,
    "runtime_scope": scope[:2], "checks": checks, "baseline": baseline,
    "metrics": {"cases": len(final_rows), "retained_catalog_tracks": 27,
                "blocked_cuts": 500, "wrong_layer_rejoins": sum(r["wrong_layer_rejoins"] for r in final_rows),
                "before_silent_cuts": sum(r["silent_cuts"] for r in before_rows), "final_silent_cuts": 0,
                "before_max_correct_layer_reentry_delay_m": max(r["worst"]["delay"] for r in before_rows),
                "final_max_correct_layer_reentry_delay_m": max(r["worst"]["delay"] for r in final_rows),
                "max_serialized_preparation_bytes": max(r["prepared_bytes"] for r in final_rows)},
    "source_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in scope},
    "retained_attempts": attempts,
    "limits": ["Geometric catalog paths are not 27 physical driving tests.",
               "Wrong-layer X/Z rejoins are excluded from correct-layer timing bounds and remain required to warn.",
               "Captures reconstruct paused states; physical laps are separate checks.",
               "No phone action, APK, backend mutation or deployment in this task."],
}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"metrics": report["metrics"], "receipts": len(checks), "patch_bytes": (OUT / "task-only.patch").stat().st_size}))
