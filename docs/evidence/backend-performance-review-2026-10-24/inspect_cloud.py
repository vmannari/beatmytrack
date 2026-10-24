"""Read aggregate resource configuration and monitoring; never write to cloud."""
import json
import os
import subprocess
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
CONFIG_DIR = ROOT / ".tools/gcp-staging"


def main():
    config = json.loads((CONFIG_DIR / "config.json").read_text(encoding="utf-8-sig"))
    env = os.environ.copy()
    certificate = CONFIG_DIR / "windows-trust.pem"
    if certificate.exists():
        env["CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE"] = str(certificate)

    def call(*args):
        result = subprocess.run(
            [*config["gcloud"], "--project=" + config["project"], *args, "--quiet"],
            capture_output=True, text=True, encoding="utf-8", env=env, timeout=50, check=False,
        )
        if result.returncode:
            # CLI error text may include configuration; expose only failure type.
            raise RuntimeError("Read-only gcloud command failed: " + " ".join(args[:3]))
        return result.stdout.strip()

    def describe(spec):
        label, args = spec
        try:
            return label, json.loads(call(*args, "--format=json"))
        except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
            return label, {"inspection_error": str(error)}

    prefix, region = "bmt-stg-e7a444ab", config["region"]
    specs = [
        ("api", ("run", "services", "describe", prefix + "-api", "--region=" + region)),
        ("worker", ("run", "worker-pools", "describe", prefix + "-worker", "--region=" + region)),
        ("sql", ("sql", "instances", "describe", prefix + "-db")),
        ("sql_instances", ("sql", "instances", "list")),
        ("bucket", ("storage", "buckets", "describe", "gs://bmt-stg-beat-my-track-e7a444ab")),
    ]
    with ThreadPoolExecutor(max_workers=5) as executor:
        raw = dict(executor.map(describe, specs))
    inventory = {"captured_at_utc": datetime.now(timezone.utc).isoformat(), "region": region}
    allowed_env = {
        "BMT_DATABASE_POOL_SIZE", "BMT_DATABASE_POOL_OVERFLOW", "BMT_MAX_QUEUED_RUNS",
        "BMT_TELEMETRY_ENABLED", "BMT_WORLD_RANKING_LAUNCH_WEEK", "BMT_RETENTION_DAYS",
        "BMT_TEST_DRIVERS_ENABLED", "BMT_PERSISTENT_VERIFIER", "BMT_UPLOAD_CONCURRENCY",
    }
    for role in ("api", "worker"):
        data = raw[role]
        template = data.get("spec", {}).get("template", {})
        runtime = template.get("spec", template)
        containers = runtime.get("containers", [{}])
        container = containers[0]
        inventory[role] = {
            "resources": container.get("resources"), "image": container.get("image"),
            "service_scaling": {k: v for k, v in data.get("metadata", {}).get("annotations", {}).items()
                                if any(s in k.lower() for s in ("scale", "instance", "cpu"))},
            "revision_scaling": {k: v for k, v in template.get("metadata", {}).get("annotations", {}).items()
                                 if any(s in k.lower() for s in ("scale", "instance", "cpu"))},
            "concurrency": runtime.get("containerConcurrency"),
            "timeout_seconds": runtime.get("timeoutSeconds"),
            "flags": {x["name"]: x.get("value") for x in container.get("env", []) if x["name"] in allowed_env},
            "reporting_database_configured": any(x.get("name") == "BMT_STUDIO_ANALYSIS_DATABASE_URL"
                                                and (x.get("value") or x.get("valueFrom"))
                                                for x in container.get("env", [])),
            "inspection_error": data.get("inspection_error"),
        }
    data = raw["sql"]
    inventory["sql"] = {k: data.get("settings", {}).get(k) for k in (
        "tier", "availabilityType", "dataDiskSizeGb", "dataDiskType", "storageAutoResize",
        "databaseFlags", "backupConfiguration", "deletionProtectionEnabled",
    )}
    inventory["sql"]["inspection_error"] = data.get("inspection_error")
    instances = raw["sql_instances"]
    inventory["sql_instance_count"] = len(instances) if isinstance(instances, list) else None
    data = raw["bucket"]
    inventory["bucket"] = {k: data.get(k) for k in (
        "location", "default_storage_class", "soft_delete_policy", "lifecycle_config",
    )}
    inventory["bucket"]["inspection_error"] = data.get("inspection_error")
    (OUT / "cloud-inventory.json").write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(inventory), flush=True)

    # Access token remains exclusively in memory and authenticated HTTPS headers.
    token = call("auth", "print-access-token")
    end = datetime.now(timezone.utc)
    start = end - timedelta(hours=24)
    queries = [
        ("sql_cpu", "cloudsql.googleapis.com/database/cpu/utilization", "cloudsql_database"),
        ("sql_memory", "cloudsql.googleapis.com/database/memory/utilization", "cloudsql_database"),
        ("sql_disk", "cloudsql.googleapis.com/database/disk/bytes_used", "cloudsql_database"),
        ("sql_connections", "cloudsql.googleapis.com/database/postgresql/num_backends", "cloudsql_database"),
        ("api_cpu", "run.googleapis.com/container/cpu/utilizations", "cloud_run_revision"),
        ("api_memory", "run.googleapis.com/container/memory/utilizations", "cloud_run_revision"),
        ("api_requests", "run.googleapis.com/request_count", "cloud_run_revision"),
        ("api_latency", "run.googleapis.com/request_latencies", "cloud_run_revision"),
        ("worker_cpu", "run.googleapis.com/container/cpu/utilizations", "cloud_run_worker_pool"),
        ("worker_memory", "run.googleapis.com/container/memory/utilizations", "cloud_run_worker_pool"),
    ]

    def metric(spec):
        label, metric_type, resource_type = spec
        predicate = f'metric.type="{metric_type}" AND resource.type="{resource_type}"'
        if resource_type == "cloud_run_revision":
            predicate += f' AND resource.labels.service_name="{prefix}-api"'
        elif resource_type == "cloudsql_database":
            predicate += f' AND resource.labels.database_id="{config["project"]}:{prefix}-db"'
        elif resource_type == "cloud_run_worker_pool":
            predicate += f' AND resource.labels.worker_pool_name="{prefix}-worker"'
        try:
            series_list, page_token, pages = [], "", 0
            while True:
                response = requests.get(
                    "https://monitoring.googleapis.com/v3/projects/" + config["project"] + "/timeSeries",
                    headers={"Authorization": "Bearer " + token},
                    params={"filter": predicate, "interval.startTime": start.isoformat(),
                            "interval.endTime": end.isoformat(), "pageSize": 10000, "pageToken": page_token},
                    verify=str(certificate) if certificate.exists() else True, timeout=(5, 35),
                )
                data = response.json()
                pages += 1
                series_list.extend(data.get("timeSeries", []))
                page_token = data.get("nextPageToken", "")
                if not page_token or pages >= 20 or not response.ok:
                    break
            values, samples, distribution_count, weighted_sum = [], 0, 0, 0.0
            timestamp_totals, code_totals = defaultdict(float), Counter()
            for series in series_list:
                for point in series.get("points", []):
                    value = point["value"]
                    samples += 1
                    if "distributionValue" in value:
                        distribution = value["distributionValue"]
                        mean, count = float(distribution.get("mean", 0)), int(distribution.get("count", 0))
                        values.append(mean)
                        distribution_count += count
                        weighted_sum += mean * count
                    elif "doubleValue" in value:
                        values.append(float(value["doubleValue"]))
                    elif "int64Value" in value:
                        values.append(int(value["int64Value"]))
                        timestamp_totals[point["interval"]["endTime"]] += int(value["int64Value"])
                        if label == "api_requests":
                            code_totals[series.get("metric", {}).get("labels", {}).get("response_code", "unknown")] += int(value["int64Value"])
            return label, {
                "http_status": response.status_code, "series": len(series_list), "pages": pages,
                "samples": samples, "maximum_sample_or_distribution_mean": max(values) if values else None,
                "arithmetic_mean_of_samples": sum(values) / len(values) if values else None,
                "sum_of_scalar_samples": sum(values) if values and not distribution_count else None,
                "distribution_count": distribution_count,
                "weighted_distribution_mean": weighted_sum / distribution_count if distribution_count else None,
                "pagination_remaining": bool(page_token),
                "maximum_sum_at_equal_timestamps": max(timestamp_totals.values()) if timestamp_totals else None,
                "response_code_totals": dict(code_totals) if code_totals else None,
                "error_code": data.get("error", {}).get("status"),
                "qualification": "Sample/distribution means are not request p95/p99 or simultaneous sums across series.",
            }
        except (requests.RequestException, ValueError, KeyError, TypeError) as error:
            return label, {"inspection_error_type": type(error).__name__}

    with ThreadPoolExecutor(max_workers=5) as executor:
        metrics = dict(executor.map(metric, queries))
    result = {"start_utc": start.isoformat(), "end_utc": end.isoformat(), "metrics": metrics}
    (OUT / "cloud-metrics.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result), flush=True)


if __name__ == "__main__":
    main()
