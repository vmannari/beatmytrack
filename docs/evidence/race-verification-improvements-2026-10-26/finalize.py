"""Record the task-only review patch and exact validation inputs/outputs."""
import difflib
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
FILES = ["backend/bmt_backend/trajectory_verifier.py", "backend/tests/test_trajectory_integrity.py",
         "backend/tools/benchmark_trajectory_comparison.py", "docs/RACE_VERIFICATION_IMPROVEMENTS_2026_10_26.md"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_log(name):
    data = (HERE / name).read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8")


benchmark = json.loads((HERE / "benchmark-final.json").read_text())
assert benchmark["baseline_sha256"] == sha(HERE / "trajectory_verifier.before.py.txt")
assert benchmark["current_sha256"] == sha(ROOT / FILES[0])
assert benchmark["engine_calls_during_acceptance"] == 0
assert all(case["cpu_ratio"] <= 1 and case["wall_ratio"] <= 1 for case in benchmark["cases"].values())
assert "14 failed, 17 passed" in read_log("regression-before-corrected.log")
assert "68 passed" in read_log("regression-native.log")

chunks = []
for index, name in enumerate(FILES):
    old = (HERE / "trajectory_verifier.before.py.txt").read_text(encoding="utf-8") if index == 0 else ""
    new = (ROOT / name).read_text(encoding="utf-8")
    chunks.append(f"diff --git a/{name} b/{name}\n")
    if index:
        chunks.append("new file mode 100644\n")
    chunks.extend(difflib.unified_diff(old.splitlines(keepends=True), new.splitlines(keepends=True),
        fromfile=f"a/{name}" if index == 0 else "/dev/null", tofile=f"b/{name}"))
(HERE / "checkpoint.patch").write_text("".join(chunks), encoding="utf-8", newline="\n")
checked = subprocess.run(["git", "apply", "--reverse", "--check", str(HERE / "checkpoint.patch")],
                         cwd=ROOT, capture_output=True, text=True, check=False)
assert checked.returncode == 0, checked.stdout+checked.stderr

report = {
    "date": "2026-10-26", "requirements": ["VRI01", "VRI02", "VRI03", "Q01", "R01"],
    "request": "Improve race-result verification without increasing computation",
    "changes": {"VRI01": "Uniform elapsed-time movement tolerance for all one-to-six tick intervals",
                "VRI02": "Project the validated first recorded position for first-gate crossing",
                "VRI03": "Cache six squared speed bounds and numeric types; preserve single pass"},
    "production_files": FILES[:1], "changed_sources": {name:sha(ROOT/name) for name in FILES},
    "baseline_sha256": benchmark["baseline_sha256"],
    "fixtures": {name:sha(HERE/name) for name in ("recorded-proof.json", "verified-oval.json")},
    "validation": {
        "original_new_regressions": {"failed":14, "passed":17, "log":"regression-before-corrected.log"},
        "fixed_unit_and_hairpin": {"passed":32, "log":"regression-unit.log"},
        "focused_final": {"passed":68, "log":"regression-native.log"},
        "ruff": "All checks passed", "git_diff_check": "passed",
        "checkpoint_reverse_apply_check": "passed",
        "native_engine": "4.7.2.stable.official.ed1daf0bf",
        "original_lap_ticks": [2634,2532,2531,2530,2530],
    },
    "benchmark": benchmark,
    "commands_and_setup_details": "../../../RACE_VERIFICATION_IMPROVEMENTS_2026_10_26.md",
    "preserved_setup_failures": ["regression-before.log", "regression-integration.log",
        "regression-integration-imported.log", "regression-final.log", "native-geometry.log",
        "benchmark.log", "benchmark-native.log"],
    "limitations": ["Measured locally on one actual circuit and a synthetic stationary expansion",
        "Broad trajectory plausibility remains the policy; exact control/physics authenticity is not proved",
        "Windows process CPU timer granularity appears in CPU measurements",
        "No PostgreSQL, live-server load or physical-device validation was performed"],
    "remaining_acceptance": ["Separately authorized backend rollout", "Representative live track/car acceptance"],
    "device_attachment_check_performed": False, "device_test_performed": False,
    "apk_built": False, "live_mutation": False, "deployment": False,
    "owner_process_restarted": False, "commit_or_merge": False,
    "checkpoint": {"path":"checkpoint.patch", "sha256":sha(HERE/"checkpoint.patch"), "scope":FILES},
}
(HERE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"focused_passed":68, "original_regression_failures":14,
                  "checkpoint_reverse_apply_check":"passed", "production_files":FILES[:1]}))
