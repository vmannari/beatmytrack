"""Validate local review artifacts and create a scoped, unapplied checkpoint."""
import difflib
import hashlib
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DOCUMENT = ROOT / "docs/BACKEND_PERFORMANCE_REVIEW_2026_10_24.md"


def main():
    source_paths = [
        "backend/bmt_backend/app.py", "backend/bmt_backend/config.py", "backend/bmt_backend/db.py",
        "backend/bmt_backend/middleware.py", "backend/bmt_backend/worker.py", "backend/bmt_backend/service_worker.py",
        "backend/bmt_backend/publication_worker.py", "backend/bmt_backend/discovery_worker.py",
        "backend/bmt_backend/discovery_v3.py", "backend/bmt_backend/product_worker.py",
        "backend/bmt_backend/queueing.py", "backend/bmt_backend/run_signals.py",
        "backend/bmt_backend/runs.py", "backend/bmt_backend/rivalry.py",
        "backend/bmt_backend/leaderboard_ranks.py", "backend/bmt_backend/reward_ranks.py",
        "backend/bmt_backend/economy_models.py", "backend/bmt_backend/economy.py",
        "backend/bmt_backend/race_acceptance.py", "backend/bmt_backend/studio_finance.py",
        "backend/bmt_backend/trajectory_verifier.py", "backend/bmt_backend/verifier.py",
        "backend/bmt_backend/studio_reporting.py", "backend/bmt_backend/telemetry_processing.py",
        "backend/bmt_backend/telemetry_queue.py", "backend/bmt_backend/maintenance.py",
        "backend/bmt_backend/observability.py", "backend/bmt_backend/gcs_storage.py",
        "backend/bmt_backend/world_ranking_worker.py", "backend/bmt_backend/world_ranking_build.py",
        "backend/bmt_backend/migrations/versions/0013_scalability.py",
        "backend/bmt_backend/migrations/versions/0045_reward_rank_index.py",
        "backend/bmt_backend/migrations/versions/0055_bounded_rank_reads.py",
        "backend/bmt_backend/migrations/versions/0058_challenge_series.py",
        "backend/bmt_backend/migrations/versions/0059_world_ranking.py",
        "backend/deploy/compose.yaml", "backend/deploy/README.md", "backend/deploy/gcp/staging.py",
        "backend/LOAD_TESTING.md", "backend/load_budgets.json",
        "docs/LATEST_BACKEND_DEPLOY_2026_10_23.md", "docs/VERIFICATION_SPEED.md",
        "docs/WORLD_RANKING_IMPLEMENTATION_2026_10_23.md",
    ]
    fingerprints = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in source_paths}
    (HERE / "reviewed-source-sha256.json").write_text(json.dumps(fingerprints, indent=2) + "\n", encoding="utf-8")

    document = DOCUMENT.read_text(encoding="utf-8")
    links = re.findall(r"\[[^\]]*\]\(([^)]+)\)", document)
    relative_links = [link for link in links if not link.startswith(("https://", "http://", "#"))]
    missing = [link for link in relative_links if not (DOCUMENT.parent / link.split("#")[0]).exists()]
    assert not missing, missing
    model = json.loads((HERE / "capacity-cost-model.json").read_text(encoding="utf-8"))
    million = next(row for row in model["scenarios"] if row["dau"] == 1000000)
    assert million["races_per_day"] == 10000000
    assert million["peak_serial_verification_engines"] == 224
    assert abs(million["verification_rps_peak"] - 578.7037037037037) < 1e-8
    assert abs(sum(model["current_fixed_resource_floor_eur"].values()) / 2 - 83.45172457) < 1e-8
    assert 37700 < million["with_25_percent_operational_allowance_eur_month_range"][0] < 37800
    assert 58600 < million["with_25_percent_operational_allowance_eur_month_range"][1] < 58700
    for row in model["scenarios"]:
        components = row["component_costs_eur_month"]
        if "subtotal_eur_month_range" not in row:
            continue
        for index in (0, 1):
            total = sum(value[index] if isinstance(value, list) else value for value in components.values())
            assert abs(total - row["subtotal_eur_month_range"][index]) < 1e-7
    tests = ET.parse(HERE / "focused-tests.xml").getroot()
    suites = tests.findall("testsuite") if tests.tag != "testsuite" else [tests]
    counts = {key: sum(int(suite.attrib.get(key, 0)) for suite in suites) for key in ("tests", "failures", "errors", "skipped")}
    assert counts == {"tests": 55, "failures": 1, "errors": 0, "skipped": 15}, counts
    metrics = json.loads((HERE / "cloud-metrics.json").read_text(encoding="utf-8"))
    assert all(value["http_status"] == 200 and not value["pagination_remaining"] for value in metrics["metrics"].values())
    head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    report = {
        "date": "2026-10-24", "requirements": ["BPR01", "BPR02", "BPR03", "BPR04", "Q01"],
        "source_head": head, "source_snapshot": "reviewed-source-sha256.json",
        "scope": "Read-only cloud inspection, current-source review, prior-evidence analysis and assumption-based cost modelling",
        "document": "../../BACKEND_PERFORMANCE_REVIEW_2026_10_24.md",
        "verdict": "Credible scaling foundations; small retained staging deployment, no demonstrated million-DAU capacity",
        "new_observations": [
            "Worker sampled CPU average57.2percent and sampled memory maximum659MiB of768MiB",
            "Fixed10GiB SQL disk, noPITR, zonal primary and no reporting standby",
            "Independent telemetry/discovery admission allowances can jointly exhaust the API pool",
            "Permanent reward/finance/compacted server receipts grow with accepted attempts despite optional race retention",
        ],
        "validation": {"focused_pytest": {"passed": 39, "failed": 1, "skipped": 15, "deselected": 51,
            "failure": "Previously documented tiny SQLite fixture uses a different covering index; plan-name assertion fails",
            "postgresql_parametrizations": "Excluded; no new PostgreSQL load or concurrency result"},
            "cloud_metric_queries": len(metrics["metrics"]), "all_metric_pages_consumed": True,
            "relative_markdown_links_checked": len(relative_links), "missing_links": missing,
            "model_totals_and_units": "Passed local independent arithmetic assertions",
            "ruff": "Passed after explicit subprocess checks, narrowed exception handlers and removal of one unused import",
            "initial_cloud_attempt": "Restricted-environment failure retained; read-only normal execution succeeded"},
        "withdrawn_original_million_dau_cost_scenario_eur_month": million["with_25_percent_operational_allowance_eur_month_range"],
        "cost_qualification": "WITHDRAWN forecast: used superseded native proof/full-replay acceptance. Current code uses Python trajectory checks without replay fallback. Other costs were scenario assumptions, not minimum capacity requirements.",
        "corrected_plan": "../../BACKEND_COST_REDUCTION_PLAN_2026_10_24.md",
        "mutations": {"cloud": False, "runtime_source": False, "real_player_data": False,
            "deployment": False, "phone_or_tablet_attachment_check": False, "device_test": False},
        "remaining": ["Current-image native and sustained HTTP load calibration", "Real stored-byte deltas",
            "Hot-board/combined-lane/connection pressure tests", "Retention and restore acceptance", "Production topology and capacity SLOs"],
    }
    (HERE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    files = [DOCUMENT, *sorted(path for path in HERE.iterdir() if path.is_file() and path.name != "scoped-change.patch")]
    for path in files:
        if path.suffix == ".json":
            json.loads(path.read_text(encoding="utf-8"))
    patch = []
    for path in files:
        relative = path.relative_to(ROOT).as_posix()
        lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
        patch.extend([f"diff --git a/{relative} b/{relative}\n", "new file mode 100644\n"])
        for line in difflib.unified_diff([], lines, fromfile="/dev/null", tofile="b/" + relative):
            patch.append(line)
            if not line.endswith("\n"):
                patch.append("\n\\ No newline at end of file\n")
    (HERE / "scoped-change.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
    print(json.dumps({"files_in_scoped_patch": len(files), "reviewed_source_files": len(fingerprints),
        "links_checked": len(relative_links), "test_counts": counts,
        "withdrawn_original_million_dau_monthly_eur_range": million["with_25_percent_operational_allowance_eur_month_range"]}))


if __name__ == "__main__":
    main()
