"""Google-only component arithmetic; candidate resources are not capacity claims."""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
PRIOR = HERE.parent / "backend-performance-review-2026-10-24"


def main():
    compute = json.loads((HERE / "prices.json").read_text(encoding="utf-8"))["skus"]
    networking = json.loads((HERE / "network-prices.json").read_text(encoding="utf-8"))["Networking"]
    prior = json.loads((PRIOR / "prices.json").read_text(encoding="utf-8"))["services"]
    skus = {row["skuId"]: row for row in [*compute, *networking, *[s for value in prior.values() for s in value["skus"]]]}

    def expression(identifier):
        return skus[identifier]["pricingInfo"][-1]["pricingExpression"]

    def price(row):
        return int(row.get("units", 0)) + row.get("nanos", 0)/1e9

    def rate(identifier):
        return price(expression(identifier)["tieredRates"][-1]["unitPrice"])

    def tier(identifier, quantity):
        rows = expression(identifier)["tieredRates"]
        return sum(max(0, min(quantity, rows[i+1]["startUsageAmount"] if i+1 < len(rows) else quantity)-r["startUsageAmount"])
                   * price(r["unitPrice"]) for i, r in enumerate(rows))

    def vm(cpu, ram):
        return 720 * (cpu * rate("9FE0-8F60-A9F0") + ram * rate("F268-6CE7-AC16"))

    def sql(cpu, ram, ha=False):
        return 720 * (cpu * rate("84B5-2F8B-3A6D" if ha else "2154-E036-4CB2")
                      + ram * rate("C690-8FB3-59EE" if ha else "8A88-5E4B-2265"))

    run_unit = 2592000 * (rate("4C19-DF1E-81AB") + rate("A1D5-F449-FAFC"))
    worker_unit = 2592000 * (rate("F7DC-B124-640A") + rate("F30E-913C-E55A"))
    object_cost = 4096 * rate("A703-5CB6-E0BF") + 10000000*rate("4DBF-185F-A415") + 200000000*rate("7870-010B-2763")
    managed = []
    for cpu, ram in ((4, 16), (8, 32)):
        lines = {"api_average_three_one_cpu_one_gib_instances": 3*run_unit,
                 "worker_four_cpu_gib_equivalents": 4*worker_unit,
                 "ha_sql_primary_cpu_ram": sql(cpu, ram, True),
                 "reporting_replica_four_cpu_sixteen_gib": sql(4, 16),
                 "ha_primary_and_replica_disks_250gib_each": 250*(rate("D901-4910-1FD2")+rate("B14E-2B60-F10B")),
                 "sql_backups_500gib_used": 500*rate("FB45-227E-BC1B"),
                 "gcs_four_tib_plus_operations": object_cost,
                 "load_balancing_security_allowance": 100, "logging_monitoring_allowance": 50,
                 "internal_traffic_misc_allowance": 50, "contingency": 150}
        managed.append({"ha_primary_cpu_ram": [cpu, ram], "components_eur_month": lines,
                        "subtotal_before_delivery_eur_month": sum(lines.values())})
    scenarios = []
    for mib in (.1, .2, .5, 1, 5):
        gib = 1000000*30*mib/1024
        delivery = tier("2A8D-245C-0E0B", gib)
        private_gib = 1000000*30*.05/1024
        public_gib = gib-private_gib
        private_delivery = tier("0C22-3157-F0C9", private_gib)
        public_delivery = tier("2A8D-245C-0E0B", public_gib)
        fill = .1*public_gib*rate("AFF5-F24B-5F78")
        lookups = [count*rate("4762-E550-B5D2") for count in (50000000, 200000000)]
        totals = [managed[i]["subtotal_before_delivery_eur_month"]+public_delivery+private_delivery+fill+lookups[i] for i in (0, 1)]
        discounts = [.25*(m["components_eur_month"]["ha_sql_primary_cpu_ram"]+m["components_eur_month"]["reporting_replica_four_cpu_sixteen_gib"])
                     + .28*(3*run_unit+4*worker_unit) for m in managed]
        scenarios.append({"mib_downloaded_per_dau_day": mib, "gib_month": gib,
            "cdn_europe_delivery_if_all_bytes_cacheable_eur_month": delivery,
            "private_dynamic_mib_per_dau_day_assumption": .05,
            "actual_split_public_cdn_eur_month": public_delivery,
            "actual_split_private_cloud_run_egress_eur_month": private_delivery,
            "cdn_fill_at_tenpercent_miss_eur_month": fill,
            "cdn_lookup_eur_month_range": lookups,
            "managed_budget_with_reporting_eur_month_range": totals,
            "conditional_one_year_commit_covered_compute_saving_eur_month_range": discounts,
            "conditional_commit_budget_eur_month_range": [totals[i]-discounts[i] for i in (0, 1)]})
    result = {"date": "2026-10-24", "currency": "EUR", "region": "europe-west1", "month_days": 30,
        "status": "Component pricing and unvalidated budget scenarios; no deployment or target-population capacity qualification",
        "workload": {"dau": 1000000, "races_per_dau_day": 10, "dynamic_requests_per_dau_day_target": 40,
            "peak_factor": 5, "peak_acceptances_per_second": 10000000*5/86400},
        "managed_profiles": managed, "download_scenarios": scenarios,
        "compute_engine_cpu_ram_floors_eur_month": {
            "one_e2_standard_8": vm(8, 32), "one_e2_highmem_8": vm(8, 64),
            "two_standard8_and_two_highmem8_total32vcpu192gib": 2*vm(8, 32)+2*vm(8, 64),
            "four_standard16_total64vcpu256gib": 4*vm(16, 64),
            "qualification": "On-demand CPU/RAM only. Disks, backup, network, operations and availability remain additional. Profile sizes are test choices, not equivalent demonstrated capacity."},
        "instance_billing_one_cpu_one_gib_month_eur": run_unit,
        "request_based_fee_at_1point2b_calls_eur_month": tier("2DA5-55D3-E679", 1200000000),
        "qualifications": ["Current trajectory checker is used; no native replay fallback is assumed",
            "Packed objects, bounded hot SQL and request reductions are prerequisites",
            "AverageCloudRun3 and worker4 resource equivalents are targets; peak scaling and Nplus1 capacity must be proved",
            "Bulk-delivery-only column assumes cacheability. Total model instead splits0.05MiB/day of private/dynamic bytes through CloudRun premium egress and the remainder through European CDN, without double-counting. Actual split and response/header bytes remain unmeasured.",
            "50million to200million CDN lookups and10percent cache-fill bytes are assumptions",
            "Storage allowances include a full reporting reader; removing it makes broad Studio reports unavailable under the current contract",
            "Commitments are optional illustrations for a fully used covered baseline; not a recommendation to purchase before load is measured",
            "Tax, engineering, migration costs and extra regions excluded; live bill not reconciled"],
        "sources": ["https://cloud.google.com/cdn/pricing", "https://docs.cloud.google.com/run/docs/configuring/billing-settings",
            "https://docs.cloud.google.com/compute/docs/general-purpose-machines", "https://docs.cloud.google.com/sql/docs/postgres/cud",
            "https://docs.cloud.google.com/compute/docs/instances/committed-use-discounts-overview"]}
    assert scenarios[1]["cdn_europe_delivery_if_all_bytes_cacheable_eur_month"] < 413
    assert 7314 < scenarios[-1]["cdn_europe_delivery_if_all_bytes_cacheable_eur_month"] < 7316
    (HERE / "model.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"compute_floors": result["compute_engine_cpu_ram_floors_eur_month"],
        "managed_base": [m["subtotal_before_delivery_eur_month"] for m in managed], "downloads": scenarios}, indent=2))


if __name__ == "__main__":
    main()
