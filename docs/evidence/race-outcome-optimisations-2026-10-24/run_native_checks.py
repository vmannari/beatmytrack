"""Bounded isolated native regressions; never touch an existing game process."""
import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BIN = r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe"
expected = (ROOT / "godot-version.txt").read_text().strip()
assert subprocess.check_output([BIN, "--version"], text=True).strip() == expected
results = []
for name in ("run_confirmation", "backend_second_pass", "earned_coins", "challenges", "challenge_series", "app", "script_parse"):
    environment = {**os.environ, "BMT_API_URL": ""}
    profile = ROOT / ".tools/outcome-native-profiles" / name
    profile.mkdir(parents=True, exist_ok=True)
    environment["APPDATA"] = str(profile)
    command = [BIN, "--headless", "--path", str(ROOT / "game"), "--log-file", str(OUT / (name + "-engine.log")),
               "--script", "res://tests/test_" + name + ".gd"]
    try:
        run = subprocess.run(command, capture_output=True, text=True, timeout=60, env=environment, check=False)
        output = run.stdout + run.stderr
        errors = [line for line in output.splitlines() if re.search(r"SCRIPT ERROR:|Parse Error:|^FAIL:|^ERROR:", line)
                  and "Failed to read the root certificate store" not in line]
        value = {"name": name, "command": command, "exit_code": run.returncode,
                 "passed": run.returncode == 0 and not errors,
                 "sandbox_certificate_diagnostic": "Failed to read the root certificate store" in output,
                 "errors": errors, "output": output}
    except subprocess.TimeoutExpired as error:
        output = str(error)
        value = {"name": name, "command": command, "passed": False, "timeout": True, "output": output}
    (OUT / (name + "-native.log")).write_text(output, encoding="utf-8")
    results.append(value)
    print(json.dumps({key: value[key] for key in ("name", "passed")}), flush=True)
    print("\n".join(line for line in output.splitlines() if "checks" in line or "SCRIPT_PARSE" in line or "FAIL:" in line), flush=True)
(OUT / "native-checks.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
raise SystemExit(0 if all(value["passed"] for value in results) else 1)
