"""Produce scoped source evidence without changing the Git index or live data."""
import hashlib
import json
from pathlib import Path
import shutil
import statistics
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
TASK = Path(__file__).resolve().parent
EVIDENCE = ROOT / "docs/evidence/local-name-filter-2026-10-24"
EVIDENCE.mkdir(parents=True, exist_ok=True)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def xml_result(path):
    suites = list(ET.parse(path).getroot().iter("testsuite"))
    counts = {key: sum(int(suite.get(key, 0)) for suite in suites)
              for key in ("tests", "failures", "errors", "skipped")}
    counts["passed"] = counts["tests"] - counts["failures"] - counts["errors"] - counts["skipped"]
    return counts


checks = {}
for filename in ("baseline.xml", "dictionary-first.xml", "verified.xml", "regression.xml",
                 "control.xml", "regression-final.xml"):
    checks[filename] = xml_result(TASK / filename)
assert checks["verified.xml"]["passed"] == 183 and checks["verified.xml"]["failures"] == 0
assert checks["regression-final.xml"]["passed"] == 193 and checks["regression-final.xml"]["failures"] == 0
assert checks["regression-final.xml"]["errors"] == 0

sys.path.insert(0, str(ROOT / "backend"))
from bmt_backend.name_moderation import POLICY_VERSION, _TERMS, _UNSEGMENTED, contains_profanity

benchmark = {}
for label, value in [("ordinary", "Mäkelä Speedway 2026"), ("max_profile", "A" * 40),
                     ("max_track", "f" * 80), ("max_comparison", "f" * 512), ("separated", "a " * 256)]:
    samples = []
    for _ in range(200):
        start = time.perf_counter_ns()
        assert not contains_profanity(value)
        samples.append((time.perf_counter_ns() - start) / 1e6)
    benchmark[label] = {"median_ms": round(statistics.median(samples), 4),
                        "p95_ms": round(sorted(samples)[189], 4), "max_ms": round(max(samples), 4)}
(EVIDENCE / "performance.json").write_text(json.dumps({"scope": "Local Windows process; 200 calls per case, not production load",
    "results": benchmark}, indent=2) + "\n", encoding="utf-8")

paths = ["backend/bmt_backend/auth.py", "backend/bmt_backend/tracks.py", "backend/bmt_backend/publications.py",
         "backend/bmt_backend/challenges.py", "backend/bmt_backend/app.py", "backend/pyproject.toml",
         "backend/bmt_backend/name_moderation.py", "backend/tests/test_name_moderation.py",
         "docs/LOCAL_NAME_FILTER_2026_10_24.md", "backend/README.md", "AGENTS.md", "DEVELOPMENT_STATUS.md"]
paths += [str(path.relative_to(ROOT)).replace("\\", "/")
          for path in sorted((ROOT / "backend/bmt_backend/name_filter_data").iterdir()) if path.is_file()]
before, after = TASK / "before", TASK / "after"
shutil.copytree(TASK / "original", before, dirs_exist_ok=True)
for name in paths:
    destination = after / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / name, destination)
delta = subprocess.run(["git", "diff", "--no-index", "--binary", "--no-ext-diff", "--src-prefix=a/",
                        "--dst-prefix=b/", "before", "after"], cwd=TASK, capture_output=True)
assert delta.returncode == 1
patch = []
for line in delta.stdout.splitlines(keepends=True):
    if line.startswith((b"diff --git ", b"--- ", b"+++ ")):
        for prefix in (b"before/", b"after/"):
            line = line.replace(b"a/" + prefix, b"a/").replace(b"b/" + prefix, b"b/")
    patch.append(line)
patch_path = EVIDENCE / "task-only.patch"
patch_path.write_bytes(b"".join(patch))
validation = subprocess.run(["git", "apply", "--check", "--reverse", str(patch_path)], cwd=ROOT, capture_output=True)
(EVIDENCE / "patch-check.log").write_bytes(validation.stdout + validation.stderr)
assert validation.returncode == 0, validation.stderr.decode("utf-8", "replace")

artifacts = ["baseline.xml", "first.xml", "dictionary-first.xml", "dictionary-final.xml", "focused.xml",
             "focused-final.xml", "focused-final.log", "verified.xml", "verified.log", "regression.xml",
             "regression.log", "latency-check.xml", "latency-check.log", "control.xml", "control.log",
             "control-command.json", "regression-final.xml", "regression-final.log", "regression-final-command.json",
             "packaging.json", "wheel-build.log", "original-hashes.json", "fetch_wordlists.py",
             "check_package.py", "run_regression.py", "finalize.py"]
for name in artifacts:
    shutil.copyfile(TASK / name, EVIDENCE / name)
shutil.copytree(TASK / "original", EVIDENCE / "source-before", dirs_exist_ok=True)
lint_args = [sys.executable, "-m", "ruff", "check", *[name for name in paths if name.endswith(".py")]]
lint = subprocess.run(lint_args, cwd=ROOT, capture_output=True, text=True)
(EVIDENCE / "ruff.log").write_text(lint.stdout + lint.stderr, encoding="utf-8")
assert lint.returncode == 0

report = {
    "date": "2026-10-24", "requirements": ["LNF01", "LNF02", "LNF03", "R01", "Q01"],
    "summary": "Local backend policy for every current player naming write and all source names in generated challenge titles",
    "coverage": ["Native/browser/development signup and old browser handoffs", "Profile renames",
                 "Publication/revision envelope and embedded document names", "Authoritative/saved creator names and queued publication commit",
                 "New single/multi-track challenges and rematches, including the fifth track"],
    "policy": {"version": POLICY_VERSION, "source_languages": 26, "upstream_entries": 2656,
               "effective_terms": len(_TERMS), "script_substrings": len(_UNSEGMENTED),
               "runtime_network": False, "new_runtime_dependencies": False,
               "source_manifest": "backend/bmt_backend/name_filter_data/sources.json"},
    "checks": checks, "focused_postgres_deselected": 18, "regression_deselected": 87,
    "packaging": json.loads((TASK / "packaging.json").read_text(encoding="utf-8")),
    "commands": {
        "working_directory": "C:/Codes/Godot/Beat my track",
        "focused_working_directory": "C:/Codes/Godot/Beat my track/backend",
        "focused": "../.tools/backend-secure-venv/Scripts/python.exe -X utf8 -m pytest tests/test_name_moderation.py -q -k 'not postgres' --tb=short --basetemp=../build/name-moderation-2026-10-24/verified -p no:cacheprovider --junitxml=../build/name-moderation-2026-10-24/verified.xml --disable-warnings",
        "baseline": "../.tools/backend-secure-venv/Scripts/python.exe -X utf8 -m pytest tests/test_name_moderation.py -q -k 'not postgres' --tb=short --basetemp=../build/name-moderation-2026-10-24/baseline -p no:cacheprovider --junitxml=../build/name-moderation-2026-10-24/baseline.xml",
        "initial_broad": "../.tools/backend-secure-venv/Scripts/python.exe -X utf8 -m pytest tests/test_auth.py tests/test_browser_auth.py tests/test_publication_intents.py tests/test_publication_latency.py tests/test_challenges.py tests/test_challenge_series.py tests/test_custom_challenge_tracks.py tests/test_challenge_discovery.py tests/test_community_safety.py tests/test_privacy.py tests/test_retired_authoring.py tests/test_robustness_fixes.py tests/test_robustness_second_pass.py -q -k 'not postgres' --tb=short --basetemp=../build/name-moderation-2026-10-24/regression -p no:cacheprovider --junitxml=../build/name-moderation-2026-10-24/regression.xml --disable-warnings",
        "regression": ".tools/backend-secure-venv/Scripts/python.exe -X utf8 build/name-moderation-2026-10-24/run_regression.py",
        "control": ".tools/backend-secure-venv/Scripts/python.exe -X utf8 build/name-moderation-2026-10-24/run_regression.py --control",
        "packaging": ".tools/backend-secure-venv/Scripts/python.exe -X utf8 build/name-moderation-2026-10-24/check_package.py",
        "dictionaries": ".tools/backend-secure-venv/Scripts/python.exe -X utf8 build/name-moderation-2026-10-24/fetch_wordlists.py",
        "lint": lint_args, "patch_check": ["git", "apply", "--check", "--reverse", str(patch_path)],
        "finalization": ".tools/backend-secure-venv/Scripts/python.exe -X utf8 build/name-moderation-2026-10-24/finalize.py",
        "full_regression_and_control_arguments": ["regression-final-command.json", "control-command.json"]},
    "retained_failures": [
        "Five task-start naming API assertions failed; all corrected without changing those assertions",
        "Initial dictionary trial: Russian suka, Japanese kuso and pron spelling missing; terms added",
        "Manual harmless-name probe: Japanese Latin abbreviations matched Jasmine/Smith; substring scanning now requires the corresponding script",
        "Initial root-directory import lacked PYTHONPATH; working directory and child-process source paths corrected",
        "Original broad regression: 190 passed, five failed, two fixture errors, five skipped, 83 deselected",
        "Two supervision assertions omit the existing discovery process and the migration-0054 downgrade guard fails; all three reproduced with task-start source controls",
        "Native publication fixture failed in engine preparation before name admission; native marker excluded from final string-validation regression"],
    "preserved": ["Accepted spelling and immutable document hashes", "Exact queued/completed publication and challenge receipts",
                  "Ownership and terms enforcement", "Publication slot atomicity and verification", "Existing reports/blocks and existing stored records",
                  "Concurrent source changes and owner processes"],
    "remaining": ["Authorized API and publication-worker deployment/restart", "Owner policy calibration using real moderation feedback",
                  "PostgreSQL-specific and physical-device acceptance not performed"],
    "not_performed": ["Deployment", "Existing player/backend database mutation", "Database schema migration",
                      "Owner-process restart", "Phone/tablet attachment check", "Physical-device test", "APK build"],
    "control_note": "app.py original reconstructed by reversing only the task's handler edit; other source baselines captured before edits",
    "source_sha256": {name: digest(ROOT / name) for name in paths},
    "source_before_sha256": {str(path.relative_to(TASK / 'original')).replace('\\', '/'): digest(path)
                             for path in sorted((TASK / 'original').rglob('*')) if path.is_file()},
    "checkpoint": {"path": "task-only.patch", "sha256": digest(patch_path), "files": len(paths),
                   "git_apply_reverse_check": "pass", "git_index_changed": False},
}
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps({"focused": checks["verified.xml"], "regression": checks["regression-final.xml"],
                  "checkpoint_files": len(paths), "patch_check": "pass", "evidence": str(EVIDENCE)}))
