"""Keep subprocess source paths explicit and preserve unrelated control failures."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
TASK = Path(__file__).resolve().parent
SUITES = ["test_auth.py", "test_browser_auth.py", "test_publication_intents.py", "test_publication_latency.py",
          "test_challenges.py", "test_challenge_series.py", "test_custom_challenge_tracks.py",
          "test_challenge_discovery.py", "test_community_safety.py", "test_privacy.py",
          "test_retired_authoring.py", "test_robustness_fixes.py", "test_robustness_second_pass.py"]
control = "--control" in sys.argv
if control:
    source = TASK / "control"
    source.mkdir(exist_ok=True)
    shutil.copytree(ROOT / "backend/bmt_backend", source / "bmt_backend",
                    ignore=shutil.ignore_patterns("__pycache__", "*.pyc"), dirs_exist_ok=True)
    for path in (TASK / "original/backend/bmt_backend").glob("*.py"):
        shutil.copyfile(path, source / "bmt_backend" / path.name)
    app = (ROOT / "backend/bmt_backend/app.py").read_text(encoding="utf-8")
    changed = ('        from .name_moderation import REJECTION\n'
               '        detail = REJECTION if any(error["type"] == "inappropriate_name" for error in _error.errors()) else "INVALID_INPUT"\n')
    assert app.count(changed) == 1
    original = app.replace(changed, "").replace('{"detail": detail, "request_id": request.state.request_id}',
                                               '{"detail": "INVALID_INPUT", "request_id": request.state.request_id}')
    (source / "bmt_backend/app.py").write_text(original, encoding="utf-8")
    # This file's original is reconstructed by reversing only our additive handler edit.
    (TASK / "original/backend/bmt_backend/app.py").write_text(original, encoding="utf-8")
    suites = ["test_publication_latency.py", "test_challenges.py"]
    selection = "not postgres and (supervisor_starts or additive_attempt_migration)"
    name = "control"
else:
    source = ROOT / "backend"
    suites = SUITES
    selection = "not postgres and not supervisor_starts and not additive_attempt_migration"
    name = "regression-final"
environment = os.environ.copy()
environment["PYTHONPATH"] = str(source)
args = [sys.executable, "-X", "utf8", "-m", "pytest", *[str(ROOT / "backend/tests" / name) for name in suites],
        "-q", "-m", "not godot", "-k", selection, "--tb=short", "--basetemp=" + str(TASK / (name + "-tmp")),
        "-p", "no:cacheprovider", "--junitxml=" + str(TASK / (name + ".xml")), "--disable-warnings"]
(TASK / (name + "-command.json")).write_text(json.dumps({"argv": args, "cwd": str(source),
    "PYTHONPATH": str(source)}, indent=2) + "\n", encoding="utf-8")
with (TASK / (name + ".log")).open("w", encoding="utf-8") as output:
    result = subprocess.run(args, cwd=source, env=environment, stdout=output, stderr=subprocess.STDOUT)
print(json.dumps({"suite": name, "exit_code": result.returncode}))
raise SystemExit(result.returncode)
