"""Calculate planning quantities and capture this assessment's provenance."""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
probe = json.loads((OUT / "probe.json").read_text())
assert probe["cleanup"] is True
assert hashlib.sha256((OUT / "probe.py").read_bytes()).hexdigest() == probe["source_sha256"]
assert [c["population"] for c in probe["cases"]] == [10000, 100000, 1000000]
fact_bytes = probe["fact_storage_sample"]["total_heap_and_index_bytes"] / probe["fact_storage_sample"]["rows"]
rows = []
for case in probe["cases"]:
    n = case["population"]
    bounds = case["bounds"]
    assert bounds["history"] == 26*n and bounds["entries"] == n
    assert bounds["counted"] == 12 and bounds["max_total"] <= 12000 and bounds["season_max"] <= 6000
    assert all(s["execution_ms"] >= 0 for s in case["stages"])
    rows.append({
        "weekly_finishers": n,
        "core_stage_seconds": case["all_measured_stages_execution_seconds"],
        "weekly_classification_seconds": case["classification_execution_seconds"],
        "audited_fact_26_week_gib": 26*n*fact_bytes/(1024**3),
        "audited_fact_annual_gib": 52*n*fact_bytes/(1024**3),
        "compact_hot_projection_gib": case["relation_bytes"]["history"]/(1024**3),
        "snapshot_prototype_gib": case["relation_bytes"]["entries"]/(1024**3),
        "cumulative_temp_writes_mib": sum(s["temp_written_blocks"] for s in case["stages"])*8192/(1024**2),
        "stages_over_current_10s_timeout": [s["stage"] for s in case["stages"] if s["execution_ms"] > 10000],
        "average_race_rate_minimum": 5*n/604800,
        "average_race_rate_20_per_finisher": 20*n/604800,
    })
sources = ["docs/WORLD_RANKING_SPEC_2026_10_22.md", "backend/bmt_backend/rivalry.py",
           "backend/bmt_backend/rivalry_models.py", "backend/bmt_backend/service_worker.py",
           "backend/bmt_backend/worker.py", "backend/bmt_backend/config.py", "backend/bmt_backend/db.py",
           "backend/bmt_backend/maintenance.py", "backend/deploy/gcp/staging.py", "backend/deploy/compose.yaml"]
report = {
    "requirements": {"WRB01": "Separate weekly complete, entered and rolling populations.",
                     "WRB02": "Measure SQL classification, best-result selection and stored reads at three scales.",
                     "WRB03": "Quantify score history, index, snapshot and race-rate growth.",
                     "WRB04": "Identify changes to locking, deadlines, supervision, pool budgeting and retention.",
                     "R01": "Existing runtime and services remain unchanged.",
                     "Q01": "Retain actual SQL plans, numerical checks, limits and initial fixture correction."},
    "date": "2026-10-23", "rows": rows, "fact_sample_bytes_per_row": fact_bytes,
    "source_sha256": {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sources},
    "git_head": subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True,
                               capture_output=True, check=True).stdout.strip(),
    "external_references": ["https://www.postgresql.org/docs/17/runtime-config-resource.html#GUC-WORK-MEM",
                            "https://www.postgresql.org/docs/17/indexes-ordering.html"],
    "commands": [
        {"command": "python docs/evidence/world-ranking-backend-2026-10-23/probe.py --populations 10000 100000 1000000 --history-limit 100000",
         "outcome": "Initial probe passed 10k/100k, then synthetic p*7919 overflowed at 1M; owned container removed. initial-probe.py/json retain this attempt."},
        {"command": "python docs/evidence/world-ranking-backend-2026-10-23/probe.py --populations 10000 100000 1000000 --history-limit 1000000",
         "outcome": "All three full-history SQL probes and cardinality/score bounds passed; owned container removed."},
        {"command": ".tools/backend-venv/Scripts/python.exe -m ruff check docs/evidence/world-ranking-backend-2026-10-23/probe.py docs/evidence/world-ranking-backend-2026-10-23/assess.py",
         "outcome": "Recorded in lint.log after final assessment."},
        {"command": "python docs/evidence/world-ranking-backend-2026-10-23/assess.py", "outcome": "Passed"}],
    "initial_correction": "Use bigint multiplication in the synthetic generator. No ranking rule, SQL window or assertion was weakened.",
    "limits": probe["limits"] + [
        "One final observation per population, not a throughput distribution or production SLO.",
        "The 26-week and annual fact sizes extrapolate the measured 100k-row sample with stable weekly participation.",
        "Snapshot prototype and hot projection use compact work IDs; the shipping schema needs another size measurement.",
        "No live database/allocation inspection, API/worker rollout, backend mutation, device test or phone attachment check.",
        "Eligibility extraction, career rebuilding, atomic publication, foreground contention and correction recovery remain implementation acceptance work."],
}
(OUT / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({"cases_checked": len(rows), "fact_bytes_per_row": fact_bytes,
                  "core_seconds": [r["core_stage_seconds"] for r in rows], "cleanup": probe["cleanup"]}))
