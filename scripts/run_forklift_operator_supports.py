"""Pinned dev entry point with private disposable profiles and concise receipts."""
import os
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/forklift-operator-supports-2026-11-13"
WORK = ROOT / "build/forklift-operator-supports-2026-11-13"


def run(label, script, *options):
    env = os.environ.copy()
    profile = WORK / "profiles" / label
    profile.mkdir(parents=True, exist_ok=True)
    (profile / "local").mkdir(exist_ok=True)
    env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile / "local"),
               BMT_API_URL="", BMT_DEV_AUTH_KEY="", PYTHONIOENCODING="utf-8")
    def quote(value):
        return "'"+str(value).replace("'", "''")+"'"

    invocation = "& "+quote(ROOT / "scripts/dev.ps1")
    invocation += " -Action Import" if script == "IMPORT" else " -Action TestScript -ScriptPath "+quote(script)
    invocation += " -CommandTimeoutSeconds 600"
    index = 0
    while index < len(options):
        option = options[index]
        if option == "-TestArgument":
            invocation += " -TestArgument @("+",".join(quote(x) for x in options[index+1:])+")"
            break
        assert option in ("-Graphical", "-RenderingMethod"), option
        invocation += " "+option
        if option == "-RenderingMethod":
            index += 1
            invocation += " "+quote(options[index])
        index += 1
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", invocation]
    OUT.mkdir(parents=True, exist_ok=True)
    with (OUT / f"{label}.log").open("w", encoding="utf-8") as log:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    lines = (OUT / f"{label}.log").read_text(encoding="utf-8").splitlines()
    (OUT / f"{label}-command.json").write_text(
        json.dumps({"command": command, "exit_code": result.returncode}, indent=2), encoding="utf-8")
    print("\n".join(lines[-14:]), flush=True)
    if result.returncode:
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    run(*sys.argv[1:])
