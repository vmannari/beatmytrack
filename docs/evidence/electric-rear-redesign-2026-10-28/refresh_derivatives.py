"""Refresh only this electric car's derived assets with existing pinned helpers."""
from pathlib import Path
import argparse
import json
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = "res://../docs/evidence/electric-rear-redesign-2026-10-28/"
JOBS = [
    ("shadows", "bake_electric_design_shadows", False, []),
    ("garage", "bake_garage_cars", False, ["--vehicle=electric"]),
    ("liveries", "bake_livery_previews", True, ["--vehicle=electric"]),
    ("news", "bake_news_car_photos", True, ["--vehicle=electric", "--evidence-root=" + BASE + "news"]),
    ("cached-pictures", "bake_electric_design_art", True, []),
    ("menu", "test_electric_car_ui", True, ["--bake-art"]),
    ("import", "", False, []),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--start-at", choices=[j[0] for j in JOBS], default="shadows")
    args = parser.parse_args()
    receipt = HERE / "derivative-commands.json"
    history = json.loads(receipt.read_text(encoding="utf-8")) if receipt.exists() else []
    start = next(i for i, j in enumerate(JOBS) if j[0] == args.start_at)
    for label, script, graphical, arguments in JOBS[start:]:
        command = "& './scripts/dev.ps1' -Action " + ("TestScript" if script else "Import")
        if script:
            command += " -ScriptPath 'res://tests/" + script + ".gd'"
        if graphical:
            command += " -Graphical -RenderingMethod gl_compatibility"
        if arguments:
            command += " -TestArgument @(" + ",".join("'" + a.replace("'", "''") + "'" for a in arguments) + ")"
        command += " -CommandTimeoutSeconds 300"
        argv = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command]
        result = subprocess.run(argv, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        text = result.stdout.decode("utf-8", errors="replace")
        record = {"job": label, "argv": argv, "exit_code": result.returncode, "output": text}
        history.append(record)
        receipt.write_text(json.dumps(history, indent=2) + "\n", encoding="utf-8")
        print(label + ": exit " + str(result.returncode), flush=True)
        if result.returncode:
            print(text[-3000:], flush=True)
            raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
