"""Compare early shared PNG restoration with the former startup gate."""
import json
from pathlib import Path
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
renderer = sys.argv[1]
assert renderer in ("gl_compatibility", "mobile")
out = ROOT / "docs/evidence/profile-picture-startup-2026-11-16" / renderer / uuid.uuid4().hex[:10]
out.mkdir(parents=True)
results = {}
for phase in ("fixed", "former-gate"):
    name = f"{renderer}-startup-pictures-{phase}-{out.name}"
    command = [sys.executable, str(ROOT / "scripts/run_shared_car_pictures.py"), name,
               "res://tests/test_profile_picture_startup.gd", "--direct"]
    if phase == "former-gate":
        command.append("--legacy-read-gate")
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    (out / f"{phase}.log").write_text(result.stdout + result.stderr, encoding="utf-8")
    evidence = ROOT / "docs/evidence/shared-car-pictures-2026-11-15" / name
    report = json.loads((evidence / "report.json").read_text(encoding="utf-8"))
    expected_failures = 1 if phase == "former-gate" else 0
    assert result.returncode == expected_failures and report["failures"] == expected_failures
    if phase == "former-gate":
        assert "FAIL: cached pictures restore while startup and menu data remain blocked" in result.stdout
    results[phase] = {"evidence": str(evidence), **report}
    print(json.dumps({"phase": phase, **report}), flush=True)
(out / "report.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"evidence": str(out), "result": "passed"}))
