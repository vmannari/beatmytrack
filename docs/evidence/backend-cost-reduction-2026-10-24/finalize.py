"""Validate the corrected review and proposed cost ceiling without changing runtime."""
import difflib
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def main():
    budget = json.loads((HERE / "budget.json").read_text(encoding="utf-8"))
    benchmark = json.loads((HERE / "trajectory-current.json").read_text(encoding="utf-8"))
    assert budget["total_budget_eur_month"] == 1753.96
    assert budget["total_budget_eur_month"] < .05 * min(budget["original_cost_range_eur_month"])
    assert benchmark["iterations"] == 500 and benchmark["engine_calls_during_verification"] == 0
    assert benchmark["five_laps"] and benchmark["adapter"]["p95_ms"] < 5
    checked_links = 0
    for name in ("BACKEND_PERFORMANCE_REVIEW_2026_10_24.md", "BACKEND_COST_REDUCTION_PLAN_2026_10_24.md"):
        path = ROOT / "docs" / name
        for link in re.findall(r"\[[^\]]*\]\(([^)]+)\)", path.read_text(encoding="utf-8")):
            if link.startswith(("https://", "http://", "#")):
                continue
            assert (path.parent / link.split("#")[0]).exists(), link
            checked_links += 1
    sources = ["backend/bmt_backend/verifier.py", "backend/bmt_backend/trajectory_verifier.py",
               "backend/bmt_backend/worker.py", "backend/bmt_backend/runs.py",
               "backend/bmt_backend/economy_models.py", "backend/bmt_backend/studio_finance.py",
               "backend/bmt_backend/telemetry_processing.py", "backend/bmt_backend/gcs_storage.py",
               "backend/bmt_backend/s3_storage.py", "backend/tools/benchmark_trajectory.py",
               "backend/tests/fixtures/verified_oval.json", ".tools/trajectory-approved-20261009/proof.json"]
    report = {
        "date": "2026-10-24", "requirements": budget["requirements"],
        "status": "Concrete cost target and design prepared; no cost-reduction implementation or production capacity claim",
        "review_correction": "The prior native proof/full-replay cost basis was superseded. Current acceptance uses a Python trajectory check without a replay fallback.",
        "source_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sources},
        "new_measurement": {"fixture": "five laps,2130samples", "iterations_each_kernel_and_adapter": 500,
            "adapter_median_ms": benchmark["adapter"]["median_ms"], "adapter_p95_ms": benchmark["adapter"]["p95_ms"],
            "engine_calls_during_acceptance": 0, "exact_lap_times_retained": True,
            "first_attempt": "Restricted execution failed during engine preparation; normal native-access run passed"},
        "target_eur_month": 1800, "candidate_budget_eur_month": budget["total_budget_eur_month"],
        "capacity_status": "One-millionDAU allocation is unproven; complete mixed load,failover,storage and recovery gates remain",
        "local_relative_links_checked": checked_links,
        "validation": {"budget_totals": "passed", "95percent_comparison": "passed", "JSON_readback": "passed",
            "runtime_tests": "No runtime modifications; fresh check/adapter benchmark only. Earlier focused review tests retain39pass,1failure,15skips.",
            "lint_and_compilation": "Run separately and recorded in conversation"},
        "preservation": {"original_review": "review-before-correction.md", "original_model": "model-before-correction.json",
            "cloud_mutation": False, "runtime_implementation": False, "data_deletion": False,
            "purchases": False, "device_test": False, "phone_or_tablet_attachment_check": False},
    }
    (HERE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    changed = [ROOT / "docs/BACKEND_COST_REDUCTION_PLAN_2026_10_24.md", *sorted(
        path for path in HERE.iterdir() if path.is_file() and path.name != "scoped-change.patch")]
    # These new files accompany the separately regenerated corrected-review patch.
    patch = []
    for path in changed:
        if path.suffix == ".json":
            json.loads(path.read_text(encoding="utf-8"))
        name = path.relative_to(ROOT).as_posix()
        patch.extend([f"diff --git a/{name} b/{name}\n", "new file mode 100644\n"])
        for line in difflib.unified_diff([], path.read_text(encoding="utf-8").splitlines(keepends=True),
                                         fromfile="/dev/null", tofile="b/" + name):
            patch.append(line)
            if not line.endswith("\n"):
                patch.append("\n\\ No newline at end of file\n")
    (HERE / "scoped-change.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
    print(json.dumps({"budget_eur_month": budget["total_budget_eur_month"], "relative_links": checked_links,
                      "new_files_in_checkpoint": len(changed), "engine_calls_in_check": 0}))


if __name__ == "__main__":
    main()
