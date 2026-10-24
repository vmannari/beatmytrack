"""Read official public networking/CDN prices, with credentials only in memory."""
import json
import os
import subprocess
from pathlib import Path

import requests

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def main():
    folder = ROOT / ".tools/gcp-staging"
    config = json.loads((folder / "config.json").read_text(encoding="utf-8-sig"))
    certificate = str(folder / "windows-trust.pem")
    env = os.environ.copy()
    env["CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE"] = certificate
    token = subprocess.run([*config["gcloud"], "--project=" + config["project"], "auth", "print-access-token"],
        capture_output=True, text=True, env=env, timeout=30, check=True).stdout.strip()
    session = requests.Session()
    session.verify = certificate
    session.headers["Authorization"] = "Bearer " + token
    response = session.get("https://cloudbilling.googleapis.com/v1/services", params={"pageSize": 5000}, timeout=(5, 30))
    response.raise_for_status()
    services = response.json().get("services", [])
    output = {}
    for service in services:
        name = service["displayName"]
        if name in ("Cloud CDN", "Networking", "Network Service Tiers", "Network Services"):
            print(name, service["name"], flush=True)
        if name not in ("Cloud CDN", "Networking", "Network Service Tiers", "Network Services"):
            continue
        rows, page = [], ""
        while True:
            response = session.get("https://cloudbilling.googleapis.com/v1/" + service["name"] + "/skus",
                params={"pageSize": 5000, "currencyCode": "EUR", "pageToken": page}, timeout=(5, 45))
            response.raise_for_status()
            data = response.json()
            for sku in data.get("skus", []):
                desc = sku["description"].lower()
                include = "cdn" in desc
                include |= "standard" in desc and ("emea" in desc or "europe" in desc or "europe-west1" in sku.get("serviceRegions", []))
                if include:
                    rows.append(sku)
            page = data.get("nextPageToken", "")
            if not page:
                break
        output[name] = rows
    (HERE / "network-prices.json").write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    for name, rows in output.items():
        for sku in rows:
            e = sku["pricingInfo"][-1]["pricingExpression"]
            rates = [(x["startUsageAmount"], int(x["unitPrice"].get("units", 0)) + x["unitPrice"].get("nanos", 0)/1e9)
                     for x in e["tieredRates"]]
            print(name, sku["skuId"], sku["description"], rates)


if __name__ == "__main__":
    main()
