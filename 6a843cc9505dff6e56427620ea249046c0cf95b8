"""Bounded read-only logging queries using existing local SDK configuration."""
import json
import os
import subprocess
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
config = json.loads((ROOT / ".tools/gcp-staging/config.json").read_text())
env = dict(os.environ, CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE=str(ROOT / ".tools/gcp-staging/windows-trust.pem"))


def read(query, limit, fields):
    result = subprocess.run([*config["gcloud"], "--project=" + config["project"], "logging", "read", query,
                             "--limit=" + str(limit), "--format=json(" + fields + ")", "--quiet"],
                            env=env, capture_output=True, text=True, timeout=60, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr)
    return json.loads(result.stdout)


query = ('resource.type="cloud_run_revision" AND resource.labels.service_name="bmt-stg-e7a444ab-api" '
         'AND timestamp>="2026-11-04T04:30:00Z" AND httpRequest.requestUrl:"/track-of-the-day"')
raw = read(query, 300, "timestamp,httpRequest.latency,httpRequest.status,httpRequest.requestUrl,resource.labels.revision_name")
rows = []
for item in raw:
    http = item.get("httpRequest", {})
    url = urlsplit(http.get("requestUrl", ""))
    params = parse_qs(url.query)
    rows.append({"timestamp": item["timestamp"], "endpoint": url.path, "status": http.get("status"),
                 "latency": http.get("latency"), "vehicle": params.get("vehicle_id", [""])[0],
                 "candidate": "lap_ticks" in params,
                 "revision": item.get("resource", {}).get("labels", {}).get("revision_name")})
report = {"query": query, "limit": 300, "rows": rows}
report["histogram_errors"] = read(
    'timestamp>="2026-11-04T00:00:00Z" AND ("histogram_refresh_failed" OR "histogram_demand_failed")',
    30, "timestamp,resource.type")
(OUT / "cloud-request-timings.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"requests": len(rows), "histogram_errors": len(report["histogram_errors"])}))
