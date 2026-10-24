"""Record source observations and cost arithmetic; no cloud calls or runtime edits."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def main():
    names = ["backend/bmt_backend/app.py", "backend/bmt_backend/middleware.py",
             "backend/bmt_backend/observability.py", "backend/bmt_backend/tracks.py",
             "backend/bmt_backend/rivalry.py", "backend/bmt_backend/challenges.py",
             "backend/bmt_backend/gcs_storage.py", "backend/bmt_backend/config.py",
             "backend/bmt_backend/runs.py", "backend/bmt_backend/verifier.py",
             "backend/bmt_backend/discovery_v3.py", "game/backend/cloud_tracks.gd",
             "game/backend/backend_client.gd", "game/backend/weekly_rivalry_client.gd",
             "game/backend/challenges_client.gd", "game/backend/discovery_windows.gd",
             "game/backend/menu_snapshot_cache.gd", "game/backend/network_health.gd"]
    sources = {name: (ROOT / name).read_bytes() for name in names}
    prior = json.loads((HERE.parent / "backend-performance-review-2026-10-24/prices.json").read_text(encoding="utf-8"))
    skus = {s["skuId"]: s for group in prior["services"].values() for s in group["skus"]}
    expression = skus["4DBF-185F-A415"]["pricingInfo"][-1]["pricingExpression"]
    price = expression["tieredRates"][-1]["unitPrice"]
    unit_price = int(price.get("units", 0)) + price.get("nanos", 0) / 1e9
    operations = 1000000 * 10 * 30 * 2
    requests = 1000000 * 40 * 30
    scenarios = json.loads((HERE.parent / "google-only-costs-2026-10-24/model.json").read_text(encoding="utf-8"))["download_scenarios"]
    observations = {
        "response_gzip_already_present": "GZipMiddleware, minimum_size=1024, compresslevel=3",
        "track_document_cache_already_present": "Persistent exact-body SHA256 cache; cache hit returns before HTTP",
        "conditional_get_already_present": "Client ETag cache; tracks and Rivalry snapshot endpoints return conditional replies",
        "rivalry_ghost_cache": "Run-ID key, 30-second freshness, process memory, 8-entry/8MiB estimate bounds",
        "challenge_ghost_cache": "ghost() requests recording each call; no own immutable recording cache",
        "ghost_server_response": "Full recording JSON; no ETag on examined Rivalry/challenge ghost handlers",
        "client_network_size": "request_completed body size, after default Godot decompression; not wire egress",
        "server_network_size": "RequestBoundary outside GZipMiddleware records response body bytes after compression; headers/provider routing still additional",
        "successful_request_logs": "One structured INFO event per request in RequestBoundary, before any external sink filtering",
        "object_format": "Each put_json performs one immutable compressed GCS object POST",
        "discovery": "20-row pages; list omits manifest; up to 96 route preview points; client retains two-viewport reserve",
        "existing_completion_features": "Batched run statuses, bounded wait endpoint, poll_after_ms and retry/backoff already exist",
        "retention_configuration": "Ordinary retention_days=90; optional telemetry raw_days=7 and fact_days=180 defaults",
    }
    result = {
        "date": "2026-10-24", "requirements": ["DCO01", "DCO02", "DCO03", "DCO04"],
        "status": "Source-based optimization backlog; no implementation or measured player egress saving",
        "observations": observations,
        "arithmetic": {
            "workload": {"dau": 1000000, "races_per_player_day": 10, "dynamic_requests_per_player_day": 40, "days": 30},
            "gcs_class_a_eur_per_operation": unit_price,
            "two_object_writes_per_race_operations_month": operations,
            "two_object_writes_per_race_eur_month": operations * unit_price,
            "ideal_128_records_per_pack_operations_month": operations / 128,
            "ideal_128_records_per_pack_put_eur_month": operations / 128 * unit_price,
            "packing_limitations": "Ideal full packs only; excludes durable intake, partial flush, compaction, recovery, indexes, reads and deletes. Actual savings require batching before the first billable object write.",
            "one_kib_log_per_request_gib_month": requests * 1024 / 1024**3,
            "one_kib_log_per_request_usd_month_after_50gib": max(0, requests * 1024 / 1024**3 - 50) * .5,
            "logging_limitation": "1KiB/request is illustrative combined logging volume, not measured; USD published rate, not converted to EUR",
            "sixty_kib_ghost_ten_downloads_kib": 60 * 10,
            "sixty_kib_same_ghost_once_kib": 60,
            "ghost_limitation": "Illustration only; does not assume actual compressed ghost size or reuse frequency",
            "managed_cost_reduction_five_to_point_two_mib_eur_month": [
                scenarios[-1]["managed_budget_with_reporting_eur_month_range"][i]
                - scenarios[1]["managed_budget_with_reporting_eur_month_range"][i] for i in (0, 1)],
            "managed_cost_reduction_point_two_to_point_one_mib_eur_month": [
                scenarios[1]["managed_budget_with_reporting_eur_month_range"][i]
                - scenarios[0]["managed_budget_with_reporting_eur_month_range"][i] for i in (0, 1)],
        },
        "source_sha256": {name: hashlib.sha256(body).hexdigest() for name, body in sources.items()},
        "limitations": ["Read-only source audit amid concurrent work; no live traffic or billing reconciliation",
                        "No new endpoint, load, physical-device or phone/tablet attachment tests",
                        "Prior regional pricing reused; no resource, account, retention, logging or billing changes"],
        "official_sources": ["https://docs.godotengine.org/en/stable/classes/class_httprequest.html",
                             "https://cloud.google.com/cdn/pricing", "https://cloud.google.com/storage/pricing",
                             "https://docs.cloud.google.com/storage/docs/soft-delete",
                             "https://cloud.google.com/products/observability/pricing",
                             "https://docs.cloud.google.com/run/docs/configuring/billing-settings"],
    }
    (HERE / "report.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result["arithmetic"], indent=2))


if __name__ == "__main__":
    main()
