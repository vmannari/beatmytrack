"""Run only nonvisual, local client regression scripts with the pinned engine."""
import json
import os
import subprocess
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BINARY = r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe"
SCRIPTS = ["cost_downloads", "backend_scalability", "backend_second_pass", "network_health",
           "product_telemetry", "discovery_pages", "free_race_preload", "challenge_series", "weekly_rivalry"]


def main():
    profile = ROOT / ".tools/cost-optimisation-tests/appdata"
    profile.mkdir(parents=True, exist_ok=True)
    env = {**os.environ, "BMT_API_URL": "", "BMT_COST_TEST_DIR": str(ROOT / ".tools/cost-optimisation-tests"),
           "APPDATA": str(profile),
           "BMT_GHOST_WIRE_FIXTURE": str(HERE / "ghost-wire-fixture.json")}
    results = []
    for name in SCRIPTS:
        started = time.monotonic()
        command = [BINARY, "--headless", "--path", str(ROOT / "game"), "--log-file", str(HERE / (name+"-native.log")),
                   "--script", "res://tests/test_"+name+".gd"]
        result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=240, check=False)
        (HERE / (name+"-console.log")).write_text(result.stdout+result.stderr, encoding="utf-8")
        passed = result.returncode == 0 and "SCRIPT ERROR" not in result.stdout+result.stderr
        results.append({"name": name, "command": command, "exit_code": result.returncode, "passed": passed,
                        "seconds": round(time.monotonic()-started, 3), "output": result.stdout+result.stderr})
        print(json.dumps({k: v for k, v in results[-1].items() if k not in ("command", "output")}), flush=True)
        (HERE / "native-checks.json").write_text(json.dumps(results, indent=2)+"\n", encoding="utf-8")
    raise SystemExit(0 if all(row["passed"] for row in results) else 1)


if __name__ == "__main__":
    main()
