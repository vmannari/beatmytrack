"""Run ordered native checks without overlapping GPU loads or owner data."""
import json
from pathlib import Path
import subprocess
import sys

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
cache = root/"build/thumbnail-studio-enabled-20261103/persistent-cache"
cases = [
    ("pipeline", "test_garage_preview_pipeline.gd", []),
    ("persistent-seed", "test_garage_persistent_pictures.gd", ["--phase=seed", "--cache="+str(cache)]),
    ("persistent-reuse", "test_garage_persistent_pictures.gd", ["--phase=reuse", "--cache="+str(cache)]),
    ("warm-scheduling", "test_garage_warm_scheduling.gd", []),
    ("deferred-app", "test_garage_deferred_views.gd", []),
    ("first-entry", "test_garage_first_entry.gd", []),
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
