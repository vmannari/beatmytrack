"""Historical counterfactual: verification assumptions withdrawn on 2026-10-24."""
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
DAY = 86400
MONTH_SECONDS = 30 * DAY
MONTH_HOURS = 720
GIB = 1024**3
TIB = 1024**4


def main():
    catalogue = json.loads((HERE / "prices.json").read_text(encoding="utf-8"))
    skus = {sku["skuId"]: sku for service in catalogue["services"].values() for sku in service["skus"]}

    def rate(identifier):
        price = skus[identifier]["pricingInfo"][-1]["pricingExpression"]["tieredRates"][-1]["unitPrice"]
        return int(price.get("units", 0)) + price.get("nanos", 0) / 1e9

    def tiered(identifier, quantity):
        rows = skus[identifier]["pricingInfo"][-1]["pricingExpression"]["tieredRates"]
        total = 0
        for index, row in enumerate(rows):
            start = row["startUsageAmount"]
            stop = rows[index + 1]["startUsageAmount"] if index + 1 < len(rows) else quantity
            units = max(0, min(stop, quantity) - start)
            price = row["unitPrice"]
            total += units * (int(price.get("units", 0)) + price.get("nanos", 0) / 1e9)
        return total

    assumptions = {
        "races_per_dau_day": 10, "api_requests_per_dau_day": 150,
        "client_telemetry_events_per_dau_day": 100, "peak_to_average": 5,
        "session_minutes_per_dau_day": 30, "target_utilization": 0.6,
        "warm_proof_service_seconds": 0.14, "warm_full_replay_service_seconds": 1.06,
        "fallback_fraction": 0.1, "api_cpu_seconds_per_request_range": [0.005, 0.020],
        "downloads_mib_per_dau_day": 5, "temporary_sql_kib_per_race_range": [2, 6],
        "permanent_sql_receipt_bundle_kib_per_race_range": [1, 4],
        "replay_and_ghost_combined_stored_kib_per_race_range": [20, 100],
        "race_retention_days": 90, "cost_ledger_age_days": 365,
        "client_telemetry_retention_days_including_grace": 8,
        "client_telemetry_sql_kib_per_event": 1,
        "sql_allocation_factor_for_free_space_and_unmodelled_core": 1.3,
        "backup_used_data_multiplier": 2,
        "object_writes_per_race": 2, "object_reads_per_race": 4,
        "planning_verifier_gib_per_one_cpu_instance": 1,
        "cost_architecture": "Peak verification capacity held all month; HA primary and a full reporting replica; API scales with utilization.",
        "excluded": "Engineering, tax, discounts/credits, store fees, ad delivery, CDN changes, broad attack traffic, extra regions, independent background compute, and unlimited additional years of receipts.",
    }
    worker_month = MONTH_SECONDS * (rate("F7DC-B124-640A") + rate("F30E-913C-E55A"))
    current_worker_month = MONTH_SECONDS * (rate("F7DC-B124-640A") + .75 * rate("F30E-913C-E55A"))
    api_idle_month = MONTH_SECONDS * (rate("7EBB-8579-2C98") + rate("740D-08F2-7A11"))
    sql_small_month = MONTH_HOURS * (rate("2154-E036-4CB2") + 3.75 * rate("8A88-5E4B-2265"))
    service = .9 * .14 + .1 * 1.06
    sizing = {10000: ((2, 8), (4, 16), (2, 8)),
              100000: ((8, 32), (16, 64), (4, 16)),
              1000000: ((32, 128), (64, 256), (8, 32))}
    output = {"status": "WITHDRAWN forecast: superseded proof/full-replay verification assumptions; historical comparison only",
              "correction": "Current acceptance is a Python trajectory check with no full-replay fallback. See ../backend-cost-reduction-2026-10-24/budget.json and the corrected review.",
              "currency": "EUR", "month_days": 30, "assumptions": assumptions,
              "current_fixed_resource_floor_eur": {
                  "warm_idle_api": api_idle_month, "worker": current_worker_month,
                  "sql_cpu_ram": sql_small_month, "sql_10gib_ssd": 10 * rate("B14E-2B60-F10B"),
                  "sum_before_variable_usage": api_idle_month + current_worker_month + sql_small_month + 10 * rate("B14E-2B60-F10B")},
              "planning_one_cpu_one_gib_worker_month_eur": worker_month, "scenarios": []}

    def sql_compute(size, ha=False):
        cpus, memory = size
        return MONTH_HOURS * (cpus * rate("84B5-2F8B-3A6D" if ha else "2154-E036-4CB2")
                              + memory * rate("C690-8FB3-59EE" if ha else "8A88-5E4B-2265"))

    for dau in (10000, 100000, 1000000, 10000000):
        races_day, requests_day = dau * 10, dau * 150
        requests_month, races_month = requests_day * 30, races_day * 30
        peak_races, peak_requests = races_day / DAY * 5, requests_day / DAY * 5
        peak_workers = math.ceil(peak_races * service / .6)
        sql_history = [races_day * 90 * kib * 1024 / GIB for kib in (2, 6)]
        permanent = [races_day * 365 * kib * 1024 / GIB for kib in (1, 4)]
        raw_telemetry = dau * 100 * 8 * 1024 / GIB
        objects = [races_day * 90 * kib * 1024 / GIB for kib in (20, 100)]
        download_gib = dau * 5 * 1024**2 * 30 / GIB
        api_costs = [requests_month * cpu / .6 * (rate("4856-B847-F1EB") + rate("02A2-9231-36A6"))
                     + tiered("2DA5-55D3-E679", requests_month) for cpu in (.005, .020)]
        sql_costs = []
        for index in (0, 1):
            used = sql_history[index] + permanent[index] + raw_telemetry
            allocated = used * 1.3
            # Regional/HA primary and one full zonal reporting replica.
            storage = allocated * (rate("D901-4910-1FD2") + rate("B14E-2B60-F10B"))
            backup = used * 2 * rate("FB45-227E-BC1B")
            sql_costs.append({"allocated_gib_per_copy": allocated, "storage_and_backup_eur": storage + backup})
        object_costs = [gib * rate("A703-5CB6-E0BF") for gib in objects]
        operations = races_month * (2 * rate("4DBF-185F-A415") + 4 * rate("7870-010B-2763"))
        network = tiered("0C22-3157-F0C9", download_gib)
        scenario = {"dau": dau, "races_per_day": races_day,
            "peak_concurrent_players": dau * 1800 / DAY * 5,
            "api_rps_average": requests_day / DAY, "api_rps_peak": peak_requests,
            "verification_rps_average": races_day / DAY, "verification_rps_peak": peak_races,
            "telemetry_eps_average": dau * 100 / DAY, "telemetry_eps_peak": dau * 100 / DAY * 5,
            "peak_serial_verification_engines": peak_workers,
            "api_peak_vcpu_range": [math.ceil(peak_requests * cpu / .6) for cpu in (.005, .020)],
            "sql_history_90d_gib_range": sql_history, "permanent_receipts_after_year_gib_range": permanent,
            "raw_client_telemetry_8d_gib": raw_telemetry, "objects_90d_gib_range": objects,
            "download_gib_month": download_gib,
            "component_costs_eur_month": {"peak_reserved_verifiers": peak_workers * worker_month,
                "api_range": api_costs, "network_europe": network,
                "sql_storage_and_backups_range": [x["storage_and_backup_eur"] for x in sql_costs],
                "object_storage_range": object_costs, "object_operations": operations}}
        if dau in sizing:
            low, high, replica = sizing[dau]
            computes = [sql_compute(low, True) + sql_compute(replica), sql_compute(high, True) + sql_compute(replica)]
            scenario["database_test_envelope"] = {"primary_cpu_ram_low": low, "primary_cpu_ram_high": high,
                                                   "reporting_replica_cpu_ram": replica}
            scenario["component_costs_eur_month"]["sql_compute_range"] = computes
            totals = [peak_workers * worker_month + api_costs[i] + network + sql_costs[i]["storage_and_backup_eur"]
                      + object_costs[i] + operations + computes[i] for i in (0, 1)]
            scenario["subtotal_eur_month_range"] = totals
            scenario["with_25_percent_operational_allowance_eur_month_range"] = [v * 1.25 for v in totals]
        output["scenarios"].append(scenario)

    output["one_million_dau_verification_sensitivity"] = [
        {"fallback_fraction": fallback, "service_seconds": (1-fallback)*.14+fallback*1.06,
         "peak_engines": math.ceil((10000000 / DAY * 5) * ((1-fallback)*.14+fallback*1.06)/.6)}
        for fallback in (0, .1, .5, 1)]
    output["one_million_dau_download_sensitivity"] = [
        {"mib_per_dau_day": mib, "gib_month": 1000000*mib*30/1024,
         "europe_run_egress_eur_month": tiered("0C22-3157-F0C9", 1000000*mib*30/1024)}
        for mib in (1, 5, 10)]
    output["one_million_dau_queue_capacity_seconds_at_peak"] = 128 / (10000000 / DAY * 5)
    output["one_million_dau_client_telemetry_backlog_seconds_at_peak"] = 50000 / (100000000 / DAY * 5)
    (HERE / "capacity-cost-model.json").write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
