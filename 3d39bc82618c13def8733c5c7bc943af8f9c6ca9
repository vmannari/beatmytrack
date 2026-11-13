"""Scenario arithmetic, not a capacity certification or a provider bill."""
import json
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent
PRICES = json.loads((OUT / "prices.json").read_text(encoding="utf-8"))
SKUS = {s["skuId"]: s for service in PRICES["services"].values() for s in service.get("skus", [])}
LOG_PRICES = json.loads((OUT / "logging-prices.json").read_text(encoding="utf-8"))
SKUS.update({s["skuId"]: s for service in LOG_PRICES["services"] if service["name"] == "Cloud Logging" for s in service["skus"]})
MONTH = 30 * 86400
GIB = 1024**3


def rates(identifier):
    return SKUS[identifier]["pricingInfo"][-1]["pricingExpression"]["tieredRates"]


def money(row):
    value = row["unitPrice"]
    return int(value.get("units", 0)) + value.get("nanos", 0) / 1e9


def rate(identifier):
    return money(rates(identifier)[-1])


def tier(identifier, quantity):
    rows = rates(identifier)
    return sum(max(0, min(quantity, rows[i+1]["startUsageAmount"] if i+1 < len(rows) else quantity)
        - row["startUsageAmount"])*money(row) for i, row in enumerate(rows))


def sql(cpu, ram, ha=True):
    return 720*(cpu*rate("84B5-2F8B-3A6D" if ha else "2154-E036-4CB2")
        + ram*rate("C690-8FB3-59EE" if ha else "8A88-5E4B-2265"))


def scenario(dau, lean, high):
    requests_per_day = 60 if lean else 150
    request_count = dau * 30 * requests_per_day
    race_count = dau * 30 * 10
    rps = dau * requests_per_day / 86400
    races_per_second = dau * 10 / 86400
    request_cpu = .015 if high else .005  # Assumed full CPU per request, NOT observed.
    job_wall = .100 if high else .020  # Serial worker occupancy, NOT checker-only CPU.
    api_busy_equivalents = max(rps*request_cpu/.6, rps*.080/(16*.6))
    request_api = MONTH*(api_busy_equivalents*(rate("4856-B847-F1EB")+rate("02A2-9231-36A6"))
        + max(0, 1-api_busy_equivalents)*(rate("7EBB-8579-2C98")+rate("740D-08F2-7A11")))
    request_api += tier("2DA5-55D3-E679", request_count)
    instance_api = MONTH*max(1, api_busy_equivalents)*(rate("4C19-DF1E-81AB")+rate("A1D5-F449-FAFC"))
    worker_eq = max(1, races_per_second*job_wall/.6)
    worker = worker_eq*MONTH*(rate("F7DC-B124-640A")+(1 if lean else .75)*rate("F30E-913C-E55A"))
    scale = (1000, 10000, 100000, 1000000).index(dau)
    cpu = ((2, 2, 4, 8), (2, 4, 8, 16))[high][scale]
    # Primary SQL physical-data scenarios at one year, with stable DAU.
    hot_days = 7 if lean else 90
    protected_fraction = .01
    retained_days = (1-protected_fraction)*hot_days+365*protected_fraction
    hot_bytes = dau*10*retained_days*3*1024
    permanent_sql = 0 if lean else dau*10*365*2*1024
    # 20 KiB/player MAU of identity/wallet/private state, D/M=0.20.
    account_bytes = (dau/.2)*20*1024
    events_per_day = 20 if lean else 100
    telemetry_bytes = dau*(events_per_day*8*1024 + (3 if high else 1)*180*1024)
    milestone_bytes = dau*365*3*192  # Illustrative one challenge/day, three permanent markers.
    sql_used = (hot_bytes+permanent_sql+account_bytes+telemetry_bytes+milestone_bytes)/GIB
    allocated = max(20, sql_used*1.30)
    # Keep reporting off unless demand/contract requires it (upper variant includes it).
    reporting_cpu = (2, 2, 4, 4)[scale] if high else 0
    sql_primary = sql(cpu, cpu*4)
    sql_reporting = sql(reporting_cpu, reporting_cpu*4, False) if high else 0
    sql_disk = allocated*(rate("D901-4910-1FD2") + (rate("B14E-2B60-F10B") if high else 0))
    backups = max(2, 2*sql_used)*rate("FB45-227E-BC1B")
    # Full unprotected proof+ghost mean 50 KiB; 1% protected for a year.
    # Seven days additional soft-deletion copies; exact cold reward bundle 0.5 KiB/race.
    object_gib = dau*10*(retained_days+7*(1-protected_fraction))*50*1024/GIB
    if lean:
        object_gib += dau*10*365*.5*1024/GIB
    writes = race_count*2
    if lean:
        # Full packs rarely guaranteed: 32-128 records effective occupancy; 15% overhead.
        writes = writes/(32 if high else 128)*1.15
    reads = race_count*(2 if high else 1) + dau*30*4  # checker and recording misses.
    objects = object_gib*rate("A703-5CB6-E0BF") + tier("4DBF-185F-A415", writes) + tier("7870-010B-2763", reads)
    mib_per_day = .5 if lean else 5
    transfer_gib = dau*30*mib_per_day/1024
    delivery = tier("0C22-3157-F0C9", transfer_gib)  # Same current Cloud Run delivery path; no hypothetical CDN.
    log_gib = (request_count*(102.4 if lean else 1024)+race_count*(128 if lean else 512))/GIB
    logging = tier("143F-A1B0-E0BE", log_gib)
    # Registry, secrets, low-volume logging, monitoring and miscellaneous: allowances, not prices.
    ancillary = (20 if not high else 50) + dau*(.00003 if lean else .00010)
    components = {"api": min(request_api, instance_api), "worker": worker, "sql_compute_ha": sql_primary,
        "optional_reporting_compute": sql_reporting, "sql_disks": sql_disk, "sql_backups": backups,
        "gcs_storage_and_operations": objects, "player_delivery": delivery, "log_ingestion": logging,
        "ancillary_allowance": ancillary}
    subtotal = sum(components.values())
    components["contingency_20_percent"] = subtotal*.20
    total = sum(components.values())
    return {"dau": dau, "scenario": "lean-local-features-enabled" if lean else "reference-current-mechanics",
        "variant": "upper" if high else "lower", "components_eur_month": components, "total_eur_month": total,
        "monthly_cost_per_dau_eur": total/dau, "monthly_cost_per_mau_eur": total/(dau/.2),
        "cost_per_1000_races_eur": total/race_count*1000, "cost_per_session_eur": total/(dau*30*2),
        "inputs": {"requests_per_player_day": requests_per_day, "races_per_player_day": 10,
            "sessions_per_player_day": 2, "mib_per_player_day": mib_per_day, "request_cpu_seconds": request_cpu,
            "worker_serial_job_wall_seconds": job_wall, "target_utilization": .6, "hot_days": hot_days,
            "protected_fraction": protected_fraction, "sql_cpu_ram": [cpu, cpu*4],
            "reporting_cpu_ram": [reporting_cpu, reporting_cpu*4], "sql_used_gib": sql_used,
            "telemetry_sql_gib": telemetry_bytes/GIB, "consenting_events_per_player_day": events_per_day,
            "permanent_milestone_sql_gib": milestone_bytes/GIB,
            "logging_gib": log_gib,
            "sql_allocated_gib": allocated, "gcs_gib": object_gib, "gcs_class_a_operations": writes,
            "gcs_class_b_operations": reads, "egress_gib": transfer_gib,
            "api_billing_comparison": {"request_based": request_api, "instance_based": instance_api},
            "average_worker_equivalents": worker_eq, "peak_worker_equivalents_at_5x": max(1,races_per_second*5*job_wall/.6)},
        "load": {"average_rps": rps, "peak_rps_5x": rps*5, "average_races_per_second": races_per_second,
            "peak_races_per_second_5x": races_per_second*5, "peak_concurrent_players_30min_5x": dau*1800/86400*5}}


def main():
    output = {"currency": "EUR", "region": "europe-west1", "month_days": 30,
        "prices_checked_at": PRICES["checked_at_utc"], "dau_mau_ratio": .2,
        "status": "Hypothetical steady-activity one-year scenarios; resource envelopes are not measured capacity",
        "qualifications": ["API billing is the cheaper arithmetic choice; traffic shape, billing rounding and idle instance variation need validation",
            "Request CPU and entire serial job occupancy are assumptions, not verifier benchmark measurements",
            "HA primary in every scale; optional physical reporting reader only in upper variant",
            "Warm API minimum and worker minimum one; same-region GCS/SQL/Run; no CDN or new region assumed",
            "Reference uses 90-day unprotected race detail and one-year permanent 2KiB reward/receipt SQL bundle",
            "Lean assumes explicitly approved seven-day unprotected history, packing and archives enabled, and60 requests/day",
            "One-percent long-lived protected evidence, fiftyKiB proof-plus-ghost, threeKiB hot SQL/race and 0.5KiB archived receipt are assumptions",
            "SQL allocation includes30percent headroom; backups use two logical data equivalents, not measured incremental backup billing",
            "Ancillary EUR allowance and20percent contingency are assumptions, not catalogue service prices",
            "All model players consent to telemetry:100/20 events per reference/lean day,1KiB/event8days,1-3 oneKiB/day contexts180days; these are physical-size assumptions",
            "Both variants include three192-byte permanent milestone rows/player/day for one year; history does not stop growing after that year",
            "Logs assume1KiB/request+512B/race reference versus102.4B/request+128B/race lean; application and provider sampling must both be verified",
            "Tax, engineering, ads/Play revenue share, native app distribution, extended DR, restore staging and extraordinary attacks are excluded",
            "Free request and object operation tiers follow captured SKU expressions; shared CPU/memory free allowances and credits not deducted",
            "Egress is Europe-to-Europe; international mix, headers/TLS accounting and routing must be added from actual byte totals",
            "Current source cannot service these allocations within the deployed40connection budget; redesign/calibration is a prerequisite, not included as accomplished work"],
        "scenarios": [scenario(d, lean, high) for lean in (False, True) for d in (1000,10000,100000,1000000) for high in (False,True)]}
    output["existing_staging_fixed_floor_eur_month_before_free_allowances"] = {
        "sql_zonal_cpu_ram": sql(1,3.75,False), "sql_10gib_disk": 10*rate("B14E-2B60-F10B"),
        "api_one_idle_min_cpu_1gib": MONTH*(rate("7EBB-8579-2C98")+rate("740D-08F2-7A11")),
        "worker_one_cpu_768mib": MONTH*(rate("F7DC-B124-640A")+.75*rate("F30E-913C-E55A"))}
    assert all(math.isfinite(row["total_eur_month"]) and row["total_eur_month"] > 0 for row in output["scenarios"])
    (OUT / "cost-model.json").write_text(json.dumps(output,indent=2)+"\n",encoding="utf-8")
    for lean in (False, True):
        for d in (1000,10000,100000,1000000):
            rows = [x for x in output["scenarios"] if x["dau"] == d and x["scenario"].startswith("lean" if lean else "reference")]
            print(rows[0]["scenario"], d, [round(x["total_eur_month"],2) for x in rows])
    print(json.dumps(output["existing_staging_fixed_floor_eur_month_before_free_allowances"],indent=2))


if __name__ == "__main__":
    main()
