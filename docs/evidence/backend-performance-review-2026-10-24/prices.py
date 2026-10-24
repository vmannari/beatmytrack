"""Read current official catalogue prices; save only selected public SKUs."""
import json
import os
import subprocess
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
DIRECTORY = ROOT / ".tools/gcp-staging"


def main():
    config = json.loads((DIRECTORY / "config.json").read_text(encoding="utf-8-sig"))
    env = os.environ.copy()
    certificate = str(DIRECTORY / "windows-trust.pem")
    env["CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE"] = certificate
    result = subprocess.run([*config["gcloud"], "--project=" + config["project"], "auth", "print-access-token"],
                            capture_output=True, text=True, env=env, timeout=30, check=False)
    if result.returncode:
        raise RuntimeError("Unable to authenticate read-only public pricing catalogue")
    token = result.stdout.strip()
    services = {"Cloud-Run": "152E-C115-5142", "Cloud-SQL": "9662-B51E-5089", "Cloud-Storage": "95FF-2EF5-5EA1"}
    selected_ids = {
        "02A2-9231-36A6", "4856-B847-F1EB", "740D-08F2-7A11", "7EBB-8579-2C98",
        "4C19-DF1E-81AB", "A1D5-F449-FAFC", "F30E-913C-E55A", "F7DC-B124-640A",
        "2154-E036-4CB2", "8A88-5E4B-2265", "84B5-2F8B-3A6D", "C690-8FB3-59EE",
        "B14E-2B60-F10B", "D901-4910-1FD2", "A703-5CB6-E0BF",
        "2DA5-55D3-E679", "0C22-3157-F0C9", "4DBF-185F-A415", "7870-010B-2763", "22EB-AAE8-FBCD",
    }

    def read_service(pair):
        name, service = pair
        page, rows, count = "", [], 0
        while True:
            response = requests.get(f"https://cloudbilling.googleapis.com/v1/services/{service}/skus",
                headers={"Authorization": "Bearer " + token},
                params={"currencyCode": "EUR", "pageSize": 5000, "pageToken": page},
                verify=certificate, timeout=(5, 50))
            if not response.ok:
                return name, {"http_status": response.status_code}
            data = response.json()
            for sku in data.get("skus", []):
                count += 1
                desc = sku["description"]
                include = sku["skuId"] in selected_ids
                include |= name == "Cloud-Run" and desc == "Services Requests"
                include |= name == "Cloud-SQL" and "Backup" in desc and "europe-west1" in sku.get("serviceRegions", [])
                include |= name == "Cloud-Storage" and "europe-west1" in sku.get("serviceRegions", []) and ("Class A" in desc or "Class B" in desc)
                if include:
                    rows.append({k: sku[k] for k in ("name", "skuId", "description", "serviceRegions", "pricingInfo")})
            page = data.get("nextPageToken", "")
            if not page:
                break
        return name, {"http_status": 200, "catalogue_entries_inspected": count, "skus": rows}

    with ThreadPoolExecutor(max_workers=3) as executor:
        services_result = dict(executor.map(read_service, services.items()))
    output = {"checked_at_utc": datetime.now(timezone.utc).isoformat(), "currency": "EUR", "services": services_result}
    (OUT / "prices.json").write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    for name, result in services_result.items():
        print(name, result.get("http_status"), result.get("catalogue_entries_inspected"))
        for sku in result.get("skus", []):
            expression = sku["pricingInfo"][-1]["pricingExpression"]
            rates = [(x["startUsageAmount"], int(x["unitPrice"].get("units", 0)) + x["unitPrice"].get("nanos", 0) / 1e9)
                     for x in expression["tieredRates"]]
            print(sku["skuId"], sku["description"], expression["usageUnit"], rates)


if __name__ == "__main__":
    main()
