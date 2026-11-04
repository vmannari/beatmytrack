"""Run ordered native checks without overlapping GPU loads or owner data."""
import json
from pathlib import Path
import subprocess
import sys

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
cache = root/"build/thumbnail-studio-polish-20261104/persistent-final-cache"
cases = [
    ("pipeline", "test_garage_preview_pipeline.gd", []),
    ("persistent-final-seed", "test_garage_persistent_pictures.gd", ["--phase=seed", "--cache="+str(cache)]),
    ("persistent-final-reuse", "test_garage_persistent_pictures.gd", ["--phase=reuse", "--cache="+str(cache)]),
    ("deferred-app", "test_garage_deferred_views.gd", []),
    ("gallery-accepted", "capture_thumbnail_studio_polish.gd", []),
]
results = []
for label, script, extra in cases:
    result = subprocess.run([sys.executable, str(evidence/"run_check.py"), label,
                             "--script", "res://tests/"+script, *extra], cwd=root)
    results.append({"label": label, "exit_code": result.returncode})
    (evidence/"verification.json").write_text(json.dumps(results, indent=2)+"\n")
    print(label, result.returncode, flush=True)
    if result.returncode:
        sys.exit(result.returncode)
