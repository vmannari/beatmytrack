"""Stage and test the real verifier with a test-local, trusted CA bundle."""
import copy
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
project = ROOT / "build/creator-capacity/verifier-complete"
engine = Path("C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe")

def run(name, args, **kwargs):
    result = subprocess.run([str(x) for x in args], capture_output=True, check=False, **kwargs)
    (HERE / name).write_bytes(result.stdout + result.stderr)
    print(name, result.returncode, flush=True)
    return result

if not project.exists():
    assert run("stage-final.log", [sys.executable, ROOT / "backend/deploy/stage_verifier.py",
                                  "--destination", project]).returncode == 0
# Only this disposable verifier project uses the bundled certifi roots. No
# production source, verifier diagnostic filter, or machine trust store changes.
bundle = ROOT / ".tools/backend-secure-venv/Lib/site-packages/certifi/cacert.pem"
settings = project / "project.godot"
base = settings.read_text().split("\n[network]\n")[0]
settings.write_text(base + '\n[network]\ntls/certificate_bundle_override=' + json.dumps(bundle.as_posix()) + '\n')
environment = dict(os.environ, BMT_GAME_PROJECT=str(project),
                   APPDATA=str(ROOT / "build/creator-capacity/appdata"))
assert run("canonical-import-final.log", [engine, "--headless", "--editor", "--import", "--path", project],
           env=environment, timeout=90).returncode == 0
base_doc = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())["document"]
cases = []
doc = copy.deepcopy(base_doc)
doc["objects"] = [{"kind": "grass_clump", "position": [i % 100 - 50, i // 100 - 20], "rotation": 0}
                  for i in range(4096)]
cases.append(("4096-props", copy.deepcopy(doc), True))
doc["objects"].append(doc["objects"][0])
cases.append(("4097-props", copy.deepcopy(doc), False))
doc["objects"] = [{"kind": "tyre_wall", "position": [0, 0], "rotation": 0} for _ in range(682)]
doc["objects"] += [{"kind": "tyre_stack", "position": [0, i], "rotation": 0} for i in range(4)]
cases.append(("4096-tyres", copy.deepcopy(doc), True))
doc["objects"].append({"kind": "tyre_stack", "position": [1, 1], "rotation": 0})
cases.append(("4097-tyres", copy.deepcopy(doc), False))
matrix = []
for name, document, accepted in cases:
    input_path, output_path = project.parent / (name+"-input.json"), project.parent / (name+"-output.json")
    input_path.write_text(json.dumps({"operation": "track", "document": document}))
    outcome = run("canonical-"+name+".log", [engine, "--headless", "--path", project,
                  "--script", "res://backend/runner.gd", "--", "--input="+str(input_path),
                  "--output="+str(output_path)], env=environment, timeout=90)
    response = json.loads(output_path.read_text())
    diagnostics = (outcome.stdout+outcome.stderr).decode(errors="replace")
    errors = re.findall(r"^(?:SCRIPT ERROR:|ERROR:|.*Parse Error:).*", diagnostics, re.MULTILINE)
    assert response["ok"] is accepted, (name, response)
    assert outcome.returncode == (0 if accepted else 2), (name, outcome.returncode)
    assert all(line.strip() == "ERROR: Failed to read the root certificate store." for line in errors), errors
    matrix.append({"case": name, "accepted": response["ok"], "exit": outcome.returncode,
                   "error": response.get("error"), "environment_diagnostics": errors})
(HERE / "canonical-matrix.json").write_text(json.dumps(matrix, indent=2)+"\n")
result = run("backend-canonical-final.log", [sys.executable, "-m", "pytest", "-q",
             "tests/test_creator_capacity.py"], cwd=ROOT / "backend", env=environment, timeout=300)
raise SystemExit(result.returncode)
