"""Local review evidence; no network, service mutation or runtime edits."""
import hashlib
import json
import sys
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "backend"))
from bmt_backend.config import Settings
from bmt_backend.load_fixtures import golden_fixture, pack_replay
from bmt_backend.replay_wire import unpack_replay
from bmt_backend.verifier import GodotVerifier, VerificationError

HERE = Path(__file__).resolve().parent
fixture = golden_fixture()
packed = pack_replay(fixture["replay"])
decoded = unpack_replay(packed)
verifier = GodotVerifier(Settings())
try:
    verifier.verify_run(fixture["document"], decoded, "compact")
except VerificationError as error:
    rejection = str(error)
else:
    raise AssertionError("Expected current acceptance to reject missing race proof")
finally:
    verifier.close()
assert rejection == "Race trajectory is required; update the client"
assert "race_proof" not in packed and "race_proof" not in decoded

seconds = 30 * 86400
sources = [
    "backend/bmt_backend/load_fixtures.py", "backend/bmt_backend/loadtest.py",
    "backend/bmt_backend/verifier.py", "backend/deploy/gcp/staging.py",
    "backend/bmt_backend/studio_usage_cloud.py",
]
inventory = json.loads((HERE.parent / "cloud-inventory.json").read_text())
details = json.loads((HERE.parent / "cloud-details.json").read_text())
usage = json.loads((HERE.parent / "cloud-usage.json").read_text())
query = usage["billing"]["query"]
assert query["job_complete"] and not query["has_page_token"]


def billing_window(first, through, expected_days):
    rows = [row for row in query["rows"] if first <= row["day"] <= through]
    assert {row["currency"] for row in rows} == {"EUR"}
    assert len({row["day"] for row in rows}) == expected_days
    charges = sum((Decimal(row["charges"]) for row in rows), Decimal(0))
    credits = sum((Decimal(row["credits"]) for row in rows), Decimal(0))
    groups = {}
    for row in rows:
        group = groups.setdefault(row["service"], {"charges": Decimal(0), "credits": Decimal(0)})
        group["charges"] += Decimal(row["charges"])
        group["credits"] += Decimal(row["credits"])
    return {
        "first_utc_day": first, "last_utc_day_inclusive": through, "days": expected_days,
        "currency": "EUR", "gross": str(charges), "credits": str(credits), "net": str(charges + credits),
        "gross_daily_average": str(charges / expected_days),
        "gross_30day_linear_run_rate": str(charges / expected_days * 30),
        "services": {name: {"gross": str(values["charges"]), "credits": str(values["credits"]),
            "net": str(values["charges"] + values["credits"]),
            "gross_percent": str(values["charges"] / charges * 100)} for name, values in groups.items()},
    }


billing = {
    "source": "../cloud-usage.json", "captured_at_utc": usage["captured_at_utc"],
    "bytes_processed": query["total_bytes_processed"], "source_groups": query["total_rows"],
    "recent_complete_utc_dates": billing_window("2026-11-01", "2026-11-05", 5),
    "all_complete_utc_dates": billing_window("2026-10-27", "2026-11-05", 10),
    "partial_2026_11_06_excluded": True,
    "qualification": "Actual exported project usage-date gross charges and credits at query time. Complete calendar dates do not prove final provider delivery; export can lag/restatement can occur. Tiny negative net is retained exactly, not claimed as an owner refund. Thirty-day multiplication is a current-workload run rate, not an invoice, post-credit guaranteed bill or future-player forecast. Other projects/account-only charges excluded; credits may expire.",
}
report = {
    "review_date": "2026-11-06", "requirements": ["BPC-INFRA", "BPC-COST", "BPC-CAPACITY"],
    "sources_sha256": {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sources},
    "cloud_evidence": ["../cloud-inventory.json", "../cloud-metrics.json", "../cloud-details.json"],
    "observed_inventory_captured_at_utc": inventory["captured_at_utc"],
    "live_topology": {
        "region": inventory["region"], "api_resources": inventory["api"]["resources"],
        "api_scaling": inventory["api"]["service_scaling"], "api_concurrency": inventory["api"]["concurrency"],
        "worker_resources": inventory["worker"]["resources"], "worker_scaling": inventory["worker"]["service_scaling"],
        "studio_resources": details["studio"]["resources"], "studio_scaling": details["studio"]["service_scaling"],
        "sql": inventory["sql"], "bucket": inventory["bucket"],
        "registry_bytes": details["repositories"][0]["sizeBytes"],
    },
    "public_price_sources_checked": [
        "https://cloud.google.com/run/pricing",
        "https://docs.cloud.google.com/run/docs/configuring/workerpools/manual-scaling",
        "https://cloud.google.com/artifact-registry/pricing",
        "https://docs.cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/detailed-usage",
    ],
    "price_arithmetic": {
        "currency": "USD", "period_days": 30,
        "region": "europe-west1; official Cloud Run Tier 1",
        "worker_cpu_per_vcpu_second": 0.000011244,
        "worker_memory_per_gib_second": 0.000001235,
        "worker_1cpu_768mib_continuous": seconds * (0.000011244 + 0.75 * 0.000001235),
        "worker_768_to_512mib_saving": seconds * 0.25 * 0.000001235,
        "api_1cpu_1gib_minimum_idle": seconds * (0.0000025 + 0.0000025),
        "api_1cpu_1gib_continuous_instance_billing": seconds * (0.000018 + 0.000002),
        "qualification": "Illustrative list-price components, before free tier/credits/tax/discounts. Not actual charges, a EUR quote, a whole-backend estimate or capacity proof. SQL regional price was not freshly resolved, so omitted.",
    },
    "capacity_probe": {
        "passed_assertions": 3, "packed_schema": packed["schema"],
        "packed_has_race_proof": "race_proof" in packed,
        "decoded_has_race_proof": "race_proof" in decoded,
        "current_verifier_rejection": rejection,
        "native_process_started": verifier._engine_checked,
        "qualification": "Local exact producer/unpack/acceptance-boundary check, not full HTTP throughput test. Existing load lab still cannot validate current accepted-race capacity.",
    },
    "findings": [
        {"id": "INFRA01", "priority": "P1 for capacity decisions", "title": "Repair the load workload before sizing or forecasting",
         "sources": ["backend/bmt_backend/load_fixtures.py:43", "backend/bmt_backend/loadtest.py:197", "backend/bmt_backend/loadtest.py:211", "backend/bmt_backend/verifier.py:389"],
         "detail": "Current pack_replay drops race_proof, and real verification rejects the decoded submission. The read mix exercises legacy /v1/tracks and lacks discovery-v3 and Daily. Synthetic adapter throughput cannot establish current total acceptance or cost per accepted race."},
        {"id": "INFRA02", "priority": "P2", "title": "Use allocated lifetime, not CPU utilization alone, to evaluate worker savings",
         "sources": ["backend/deploy/gcp/staging.py:193", "backend/deploy/gcp/staging.py:206", "../cloud-inventory.json"],
         "detail": "One manual worker is continuously billed; reduced CPU at the same allocation creates headroom but no compute price reduction. Saving 256MiB gives only about USD0.80/30d before credits. Retain safe simultaneous native-operation headroom; current lower utilization alone is insufficient justification to resize."},
        {"id": "INFRA03", "priority": "P2 before public launch", "title": "Database savings have explicit availability and recovery limits",
         "sources": ["../cloud-inventory.json"],
         "detail": "Live SQL remains zonal, PITR disabled, 10GiB disk with automatic growth disabled and seven enabled daily backups. Sampled disk occupancy is low, so this is not a current disk emergency. Set recovery objectives and test restoration; do not represent this small floor as an HA capacity design."},
    ],
    "cost_visibility": {
        "sources": ["backend/bmt_backend/studio_usage_cloud.py:236", "backend/bmt_backend/studio_usage_cloud.py:253", "backend/bmt_backend/studio_usage_cloud.py:255"],
        "detail": "Existing project-filtered detailed export query preserves NUMERIC charges, credits and currencies and limits scans to 100MB/2000 groups. Coverage and asynchronous-query limits are explicit. Current parent-collected aggregate export contains real charges; the previous October empty-export limitation no longer applies.",
    },
    "actual_exported_costs": billing,
    "limits": ["No runtime changes or deployments", "No cloud requests by this script", "No phone/device test", "No claimed million-DAU capacity", "No registry cleanup recommendation without active/recovery image inventory", "Current source review distinguished from exact live image provenance"],
}
(HERE / "review.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"capacity_probe": report["capacity_probe"], "actual_exported_costs": billing}, indent=2))
