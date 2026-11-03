"""Isolated, bounded local Godot regressions; no owner profile or device access."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build/checkpoint-road-coverage-2026-11-03"
GODOT = Path(os.environ.get("GODOT_BIN", "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe"))


def main():
    scripts = sys.argv[1:] or [
        "test_checkpoint_road_coverage", "test_star_checkpoint_shortcuts",
        "test_hairpin_checkpoints", "test_star_checkpoint_consistency",
        "test_checkpoint_forgiveness", "test_checkpoint_rules",
        "test_checkpoint_bridge_layers", "test_bridge_entry_checkpoints",
        "test_bridge_exit_checkpoints", "test_checkpoint_notices",
        "test_knot_checkpoint_notices", "test_checkpoint_notice_latency",
        "test_rewind", "test_checkpoint_catalog_routes",
    ]
    (OUTPUT / "logs").mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA"):
        path = OUTPUT / "profiles" / key
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    results = []
    for script in scripts:
        args = script.split(":")
        name = args[0]
        renderer = args[1] if len(args) > 1 else "headless"
        label = name + "-" + renderer
        command = [sys.executable, "scripts/run_no_crash_dialog.py", "--", str(GODOT),
                   "--path", "game", "--log-file", str(OUTPUT / "logs" / (label + "-engine.log"))]
        command += ["--headless"] if renderer == "headless" else ["--rendering-method", renderer]
        command += ["--script", "res://tests/" + name + ".gd"]
        start = time.monotonic()
        log = OUTPUT / "logs" / (label + ".log")
        with log.open("w", encoding="utf-8") as stream:
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
            try:
                code = process.wait(timeout=240)
            except subprocess.TimeoutExpired:
                # This PID belongs to this invocation and its wrapper only.
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
                code = 124
        output = log.read_text(encoding="utf-8", errors="replace")
        failed = code != 0 or "SCRIPT ERROR:" in output or "FAIL:" in output
        result = {"name": label, "command": command, "exit_code": code, "failed": failed,
                  "seconds": round(time.monotonic() - start, 3), "log": str(log.relative_to(ROOT))}
        results.append(result)
        print(json.dumps(result), flush=True)
        (OUTPUT / ("results-" + str(os.getpid()) + ".json")).write_text(json.dumps(results, indent=2), encoding="utf-8")
    return int(any(row["failed"] for row in results))


if __name__ == "__main__":
    raise SystemExit(main())
