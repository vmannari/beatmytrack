"""Retrieve public Cloud Logging EUR SKUs; credentials remain in memory."""
import json
import subprocess
from datetime import datetime, timezone

import requests

from cloud_detail import CONFIG, ENV, OUT, VERIFY


def main():
    auth = subprocess.run([*CONFIG["gcloud"], "auth", "print-access-token", "--quiet"],
        capture_output=True, text=True, encoding="utf-8", env=ENV, timeout=30)
    if auth.returncode:
        raise RuntimeError("Read-only price authentication unavailable")
    headers = {"Authorization": "Bearer "+auth.stdout.strip()}
    root = "https://cloudbilling.googleapis.com/v1/"
    page, services = "", []
    while True:
        response = requests.get(root+"services", headers=headers, params={"pageSize":5000,"pageToken":page}, verify=VERIFY, timeout=25)
        response.raise_for_status()
        body = response.json()
        services.extend(s for s in body.get("services",[]) if s["displayName"] == "Cloud Logging")
        page = body.get("nextPageToken","")
        if not page:
            break
    output = {"checked_at_utc":datetime.now(timezone.utc).isoformat(),"currency":"EUR","services":[]}
    for service in services:
        rows, page = [], ""
        while True:
            response = requests.get(root+service["name"]+"/skus",headers=headers,
                params={"currencyCode":"EUR","pageSize":5000,"pageToken":page},verify=VERIFY,timeout=25)
            response.raise_for_status()
            body=response.json()
            rows.extend(body.get("skus",[]))
            page=body.get("nextPageToken","")
            if not page:
                break
        output["services"].append({"name":service["displayName"],"skus":rows})
    (OUT/"logging-prices.json").write_text(json.dumps(output,indent=2)+"\n",encoding="utf-8")
    print(json.dumps([{ "service":s["name"],"skus":[{"id":r["skuId"],"description":r["description"],
        "pricing":r["pricingInfo"][-1]["pricingExpression"]} for r in s["skus"]]}
        for s in output["services"]],indent=2))


if __name__=="__main__":
    main()
