"""Cost ceiling and engineering gates; no claim of production capacity."""
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent


def main():
    original = json.loads((HERE / "model-before-correction.json").read_text(encoding="utf-8"))
    million = next(item for item in original["scenarios"] if item["dau"] == 1000000)
    old_range = million["with_25_percent_operational_allowance_eur_month_range"]
    benchmark = json.loads((HERE / "trajectory-current.json").read_text(encoding="utf-8"))
    # Official Hetzner June 2026 adjustment, EU, excluding VAT and IPv4.
    servers = {"two_api_worker_CCX43": 2 * 275.99, "postgres_primary_standby_two_CCX43": 2 * 275.99}
    allowances = {"packed_objects_and_operations": 200, "database_backups_wal_and_recovery": 150,
                  "edge_load_balancing_ipv4_and_transfer": 100, "monitoring_logs": 50,
                  "extra_storage_and_miscellaneous": 50, "contingency": 100}
    total = sum(servers.values()) + sum(allowances.values())
    races_day, peak_factor = 10000000, 5
    race_peak = races_day / 86400 * peak_factor
    result = {
        "requirements": ["CR95-01", "CR95-02", "CR95-03", "CR95-04", "CR95-05", "CR95-06", "CR95-07"],
        "status": "Engineering budget and test gates only; unproven at target traffic",
        "date": "2026-10-24", "dau": 1000000, "registered_accounts_assumption": 10000000, "receipt_history_years": 1,
        "races_per_dau_day": 10, "races_per_day": races_day, "verification_peak_per_second": race_peak,
        "original_cost_range_eur_month": old_range,
        "original_model_status": "Verification assumptions withdrawn; comparison is with the previous scenario, not an observed bill",
        "strict_95_percent_cost_ceiling_eur_month": .05 * min(old_range),
        "chosen_ceiling_eur_month": 1800, "line_item_budget_eur_month": {**servers, **allowances},
        "total_budget_eur_month": total,
        "reduction_against_original_range_percent": [100 * (1-total/value) for value in old_range],
        "current_verification": {"schema": "bmt-trajectory-v1", "ordinary_replay_fallback": False,
            "iterations": benchmark["iterations"], "samples_per_fixture": benchmark["trajectory_samples"],
            "adapter_median_ms": benchmark["adapter"]["median_ms"], "adapter_p95_ms": benchmark["adapter"]["p95_ms"],
            "adapter_max_ms": benchmark["adapter"]["max_ms"], "engine_calls_in_acceptance": 0,
            "theoretical_single_core_check_equivalents_at_peak_60percent": race_peak * benchmark["adapter"]["median_ms"] / 1000 / .6,
            "qualification": "Isolated current-code check/adapter; not complete job throughput, measured CPU utilization or fleet sizing"},
        "request_target": {"api_calls_per_dau_day": 40, "average_rps": 1000000*40/86400,
            "peak_rps": 1000000*40/86400*5, "qualification": "Proposed target; preserve explicit competition starts and durable retries"},
        "data_targets": {"primary_live_sql_gib_max": 250,
            "ordinary_detailed_result_days": 7, "terminal_nonprotected_evidence_hours": 24,
            "outstanding_unacknowledged_jobs": "Retain until authoritative terminal handling; never expire live work",
            "permanent_compact_receipt_bytes_per_race": 128,
            "receipt_archive_gib_per_year": races_day*365*128/1024**3,
            "object_storage_gb_total_budget": 4000,
            "recording_pack_records_target": 128, "recording_pack_encoded_max_mib": 6,
            "transient_recording_pack_writes_per_month": math.ceil(races_day*30/128),
            "required_live_references": ["race and lap PBs", "exact challenge results", "creator validation", "published track versions", "purchase/fulfillment records"]},
        "r2_budget_check": {"currency": "USD", "standard_gb_month": .015,
            "class_a_per_million": 4.50, "class_b_per_million": .36, "internet_egress": 0,
            "gb_month_assumption": 4000, "class_a_millions_assumption": 10,
            "class_b_millions_assumption": 200,
            "usd_month_before_free_tier": 4000*.015+10*4.50+200*.36,
            "budget_fx_stress_eur_per_usd": 1.1,
            "fx_qualification": "Stress allowance, not a current foreign-exchange quote",
            "stressed_eur_month": (4000*.015+10*4.50+200*.36)*1.1,
            "no_change_object_operations_warning": "Two separate object writes per race would cost2700USD/month in ClassA alone at300million races"},
        "operational_tradeoff": "Self-managed primary/standby, backups, failover, security and on-call replace managed-service operations. Labour is excluded.",
        "capacity_gates": ["Exact current-image sustained mixed load at declared host profiles", "One-node-loss and primary-failover tests",
            "Hot-board contention and full retention footprint", "Replay-safe receipt compaction with lost/out-of-order replies",
            "Packed-object authorization, range reads, crash recovery and protected-record compaction", "Restore across SQL and object generations",
            "Actual billed bytes/operations and total transfer below budgets"],
        "sources": ["https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/",
            "https://developers.cloudflare.com/r2/pricing/", "https://docs.hetzner.com/robot/general/traffic/"]}
    assert total <= 1800 < .05*min(old_range)
    assert result["r2_budget_check"]["stressed_eur_month"] <= allowances["packed_objects_and_operations"]
    (HERE / "budget.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"total_eur_month": total, "reduction_percent": result["reduction_against_original_range_percent"],
        "strict_ceiling_eur_month": .05*min(old_range), "proof_check_equivalents_at_peak": result["current_verification"]["theoretical_single_core_check_equivalents_at_peak_60percent"],
        "r2_stress_eur_month": result["r2_budget_check"]["stressed_eur_month"]}))


if __name__ == "__main__":
    main()
