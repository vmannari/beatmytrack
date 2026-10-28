"""Read-only operator preview using an existing gcloud identity, without deployment.

Only resource configuration and provider metric aggregates are written. No SQL,
secret values, individual request logs or player records are read.
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))


def main():
    from datetime import datetime, timezone

    import requests
    from bmt_backend.config import Settings
    from bmt_backend.studio_usage import cloud_capacity
    from bmt_backend.studio_usage_cloud import ProviderUnavailable, UsageCloud

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True, help="Existing operator project/region/gcloud configuration")
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--inspect-billing", action="store_true", help="Discover export-table metadata only; never query billing rows")
    args = parser.parse_args()
    config = json.loads(args.config.read_text(encoding="utf-8-sig"))
    cert = args.config.parent / "windows-trust.pem"
    env = os.environ.copy()
    if cert.exists():
        env["CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE"] = str(cert.resolve())
    result = subprocess.run([*config["gcloud"], "auth", "print-access-token", "--quiet"],
        capture_output=True, text=True, encoding="utf-8", env=env, timeout=30, check=False)
    if result.returncode:
        raise SystemExit("Existing operator credential unavailable; no cloud data read")
    token = result.stdout.strip()
    errors = []
    def transport(method, url, **kwargs):
        # Only the bounded summary-log read may use POST. No mutations or
        # BigQuery query jobs are permitted by this operator preview.
        if method != "GET" and not (method == "POST" and url == "https://logging.googleapis.com/v2/entries:list"):
            raise ProviderUnavailable("preview_is_read_only")
        response = requests.request(method, url, headers={"Authorization":"Bearer " + token},
            verify=str(cert.resolve()) if cert.exists() else True, timeout=(3,8), allow_redirects=False, **kwargs)
        if not response.ok:
            body = response.json().get("error", {})
            errors.append({"host":url.split('/')[2],"status":response.status_code,
                "metric":kwargs.get("params",{}).get("filter"),"message":str(body.get("message", ""))[:500]})
            raise ProviderUnavailable("provider_read_denied")
        return response.json()
    settings = Settings(environment="test", studio_usage_project=config["project"], studio_usage_region=config["region"],
        studio_usage_resources=json.dumps({"services":[args.prefix+"-api",args.prefix+"-studio"],
            "workerPools":[args.prefix+"-worker"],"instances":[args.prefix+"-db"]}))
    at = int(datetime.now(timezone.utc).timestamp())
    cloud = UsageCloud(settings,transport=transport).collect((at//86400-6)*86400,at+1)
    billing_discovery = {"status":"not_requested"}
    if args.inspect_billing:
        try:
            datasets = transport("GET", "https://bigquery.googleapis.com/bigquery/v2/projects/"+config["project"]+"/datasets",
                params={"maxResults":20})
            count = 0
            if datasets.get("nextPageToken"):
                raise ProviderUnavailable("dataset_metadata_limit")
            for dataset in datasets.get("datasets", []):
                dataset_id=dataset["datasetReference"]["datasetId"]
                tables=transport("GET", "https://bigquery.googleapis.com/bigquery/v2/projects/"+config["project"]
                    +"/datasets/"+dataset_id+"/tables",params={"maxResults":100})
                if tables.get("nextPageToken"):
                    raise ProviderUnavailable("table_metadata_limit")
                count += sum(t["tableReference"]["tableId"].startswith("gcp_billing_export_resource_v1_") for t in tables.get("tables", []))
            billing_discovery={"status":"observed","detailed_export_table_count":count,
                "scope":"Dataset/table metadata only; no billing rows queried or export created"}
        except ProviderUnavailable:
            billing_discovery={"status":"unavailable"}
    rows, traffic = cloud_capacity(cloud,settings,at)
    payload={"captured_at":at,"scope":"Provider metadata/metrics and bounded application aggregate summaries; existing operator identity; read-only",
        "project":config["project"],"cloud":cloud,"resources":rows,"traffic":traffic,"provider_errors":errors,
        "billing_discovery":billing_discovery}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(payload,indent=2))
    print(json.dumps({"resource_rows":len(rows),"sources":cloud["sources"],
        "provider_errors":errors,"billing_discovery":billing_discovery,"pressure":[{"label":r["label"],"status":r["status"],"used_percent":r["used_percent"]}
            for r in rows if r["status"] in ("warning","critical")]}))


if __name__ == "__main__":
    main()
