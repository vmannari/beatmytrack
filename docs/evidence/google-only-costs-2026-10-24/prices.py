"""Read public Google catalogue prices; no account or resource mutations."""
import json
import os
import subprocess
from datetime import datetime, timezone
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
    result = subprocess.run([*config["gcloud"], "--project=" + config["project"], "auth", "print-access-token"],
                            capture_output=True, text=True, env=env, timeout=30, check=False)
    if result.returncode:
        raise RuntimeError("Unable to authenticate read-only catalogue access")
    session = requests.Session()
    session.verify = certificate
    session.headers["Authorization"] = "Bearer " + result.stdout.strip()
    page, selected, inspected, pages = "", [], 0, 0
    while True:
        response = session.get("https://cloudbilling.googleapis.com/v1/services/6F81-5844-456A/skus",
            params={"currencyCode": "EUR", "pageSize": 5000, "pageToken": page}, timeout=(5, 50))
        response.raise_for_status()
        data = response.json()
        pages += 1
        for sku in data.get("skus", []):
            inspected += 1
            desc = sku["description"].lower()
            regions = sku.get("serviceRegions", [])
            regional = "europe-west1" in regions
            include = regional and "e2 instance" in desc and any(x in desc for x in ("core", "ram")) and "spot" not in desc and "preemptible" not in desc
            include |= regional and any(x in desc for x in ("ssd backed pd capacity", "balanced pd capacity", "storage pd capacity"))
            include |= "cdn" in desc and any(x in desc for x in ("europe", "cache look", "cache lookup", "cache fill"))
            include |= "standard tier" in desc and (regional or "europe" in desc)
            if include:
                selected.append({k: sku[k] for k in ("name", "skuId", "description", "serviceRegions", "pricingInfo")})
        page = data.get("nextPageToken", "")
        if not page:
            break
    output = {"captured_at_utc": datetime.now(timezone.utc).isoformat(), "currency": "EUR",
              "region": "europe-west1", "catalogue_entries_inspected": inspected, "pages": pages, "skus": selected}
    (HERE / "prices.json").write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"entries_inspected": inspected, "pages": pages, "selected": len(selected)}))
    for sku in selected:
        expression = sku["pricingInfo"][-1]["pricingExpression"]
        rates = [(row["startUsageAmount"], int(row["unitPrice"].get("units", 0)) + row["unitPrice"].get("nanos", 0)/1e9)
                 for row in expression["tieredRates"]]
        print(sku["skuId"], sku["description"], expression["usageUnit"], rates)


if __name__ == "__main__":
    main()
