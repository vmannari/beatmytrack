"""Allowlisted resource metadata and ordinary unauthenticated GETs only."""
import json
import os
import subprocess
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
CONFIG = json.loads((ROOT / ".tools/gcp-staging/config.json").read_text(encoding="utf-8-sig"))
CERT = ROOT / ".tools/gcp-staging/windows-trust.pem"
ENV = os.environ.copy()
if CERT.exists():
    ENV["CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE"] = str(CERT)
VERIFY = str(CERT) if CERT.exists() else True
PREFIX = "bmt-stg-e7a444ab"


def call(args):
    result = subprocess.run([*CONFIG["gcloud"], "--project="+CONFIG["project"], *args, "--quiet"],
        capture_output=True, text=True, encoding="utf-8", env=ENV, timeout=45)
    if result.returncode:
        return {"read_failed": True, "command_family": args[:3]}
    return json.loads(result.stdout)


def main():
    allow = {"BMT_ENVIRONMENT", "BMT_WORKLOAD_ROLE", "BMT_DEV_AUTH_ENABLED", "BMT_TEST_DRIVERS_ENABLED",
        "BMT_TRUSTED_PROXY_NETWORKS", "BMT_OBJECT_PACKING_ENABLED", "BMT_RETENTION_DAYS",
        "BMT_WORLD_RANKING_LAUNCH_WEEK", "BMT_TEMPORARY_AD_RESUMES_ENABLED", "BMT_STUDIO_LEGACY_KEYS_ENABLED",
        "BMT_HTTP_SUCCESS_SAMPLE_PER_MILLE", "BMT_TELEMETRY_ENABLED", "BMT_DATABASE_POOL_SIZE"}
    data = call(["run", "services", "describe", PREFIX+"-api", "--region="+CONFIG["region"], "--format=json"])
    spec = data.get("spec", {}).get("template", {}).get("spec", {})
    container = spec.get("containers", [{}])[0]
    result = {"captured_at_utc": datetime.now(timezone.utc).isoformat(),
        "scope": "metadata, histogram aggregates, public health/bootstrap; no secret values or player records",
        "api": {"traffic": data.get("status", {}).get("traffic"),
            "flags": {x["name"]: x.get("value") for x in container.get("env", []) if x["name"] in allow},
            "command": container.get("command"), "args": container.get("args"),
            "ingress": data.get("metadata", {}).get("annotations", {}).get("run.googleapis.com/ingress")}}
    url = data.get("status", {}).get("url")
    result["public_gets"] = {}
    if url:
        for path in ("/health", "/ready", "/v1/bootstrap"):
            try:
                response = requests.get(url+path, timeout=(4, 12), verify=VERIFY)
                body = response.json()
                selected = {k: v for k, v in body.items() if k in (
                    "status", "ready", "schema", "schema_revision", "worker", "dependencies", "features",
                    "build", "physics_version", "compiler_version", "rules_key", "compatibility", "capabilities")}
                result["public_gets"][path] = {"status": response.status_code, "selected": selected,
                    "top_level_keys": sorted(body) if isinstance(body, dict) else []}
            except (requests.RequestException, ValueError, TypeError, AttributeError) as exc:
                result["public_gets"][path] = {"error_type": type(exc).__name__}
    specs = {
        "schedules": ["scheduler", "jobs", "list", "--location="+CONFIG["region"],
            "--format=json(name,state,schedule,timeZone,httpTarget.uri,httpTarget.httpMethod)"],
        "jobs": ["run", "jobs", "list", "--region="+CONFIG["region"],
            "--format=json(metadata.name,status.lastExecution)"],
        "alert_policies": ["alpha", "monitoring", "policies", "list", "--format=json(displayName,enabled)"],
        "log_exclusions": ["logging", "exclusions", "list", "--format=json(name,disabled,filter)"],
    }
    with ThreadPoolExecutor(max_workers=4) as executor:
        result.update(dict(executor.map(lambda item: (item[0], call(item[1])), specs.items())))
    # Histogram values are aggregated in memory; no individual request logs.
    token_result = subprocess.run([*CONFIG["gcloud"], "--project="+CONFIG["project"], "auth", "print-access-token", "--quiet"],
        capture_output=True, text=True, encoding="utf-8", env=ENV, timeout=30)
    if token_result.returncode == 0:
        end = datetime.now(timezone.utc)
        params = {"filter": 'metric.type="run.googleapis.com/request_latencies" AND resource.type="cloud_run_revision"'
            +' AND resource.labels.service_name="'+PREFIX+'-api"', "interval.startTime": (end-timedelta(hours=24)).isoformat(),
            "interval.endTime": end.isoformat(), "pageSize": 10000}
        counts, options, pages, failed = Counter(), {}, 0, False
        while True:
            response = requests.get("https://monitoring.googleapis.com/v3/projects/"+CONFIG["project"]+"/timeSeries",
                headers={"Authorization": "Bearer "+token_result.stdout.strip()}, params=params, verify=VERIFY, timeout=(5, 35))
            body = response.json()
            if not response.ok:
                failed = True
                break
            for series in body.get("timeSeries", []):
                for point in series.get("points", []):
                    d = point["value"].get("distributionValue", {})
                    key = json.dumps(d.get("bucketOptions", {}), sort_keys=True)
                    options[key] = d.get("bucketOptions", {})
                    for index, count in enumerate(d.get("bucketCounts", [])):
                        counts[key, index] += int(count)
            pages += 1
            if not body.get("nextPageToken") or pages >= 20:
                break
            params["pageToken"] = body["nextPageToken"]
        bounds = Counter()
        for (key, index), count in counts.items():
            option = options[key]
            if "exponentialBuckets" in option:
                p = option["exponentialBuckets"]
                n, scale, factor = p["numFiniteBuckets"], p["scale"], p["growthFactor"]
                lower = 0 if index == 0 else scale*factor**(index-1)
                upper = float("inf") if index > n else scale*factor**index
            elif "explicitBuckets" in option:
                b = option["explicitBuckets"]["bounds"]
                lower, upper = (0 if index == 0 else b[index-1]), (float("inf") if index >= len(b) else b[index])
            else:
                continue
            bounds[lower, upper] += count
        total = sum(bounds.values())
        quantiles = {}
        for q in (0.5, 0.95, 0.99):
            running = 0
            for (lo, hi), count in sorted(bounds.items()):
                running += count
                if running >= total*q:
                    quantiles[str(q)] = {"lower_ms": lo, "upper_ms": hi}
                    break
        result["service_latency_histogram"] = {"samples": total, "quantile_bucket_bounds": quantiles,
            "read_failed": failed, "pages": pages,
            "qualification": "Provider histogram bucket bounds over ALL service requests/statuses; not endpoint or mobile latency."}
    (OUT / "cloud-detail.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
