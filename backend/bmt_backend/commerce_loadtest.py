"""Replay one simulated payment concurrently; assert exactly one slot grant."""
import argparse
import json
import statistics
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import urlsplit
from uuid import uuid4

import httpx


def run(url, key, requests=100, concurrency=8):
    parsed = urlsplit(url)
    if (parsed.scheme != "http" or parsed.hostname not in ("127.0.0.1", "localhost")
            or parsed.username or parsed.path not in ("", "/") or parsed.query or parsed.fragment):
        raise ValueError("Purchase replay tooling is restricted to the owned loopback lab")
    if not 1 <= requests <= 1000 or not 1 <= concurrency <= 32:
        raise ValueError("Bounded request/concurrency allowance exceeded")
    url = url.rstrip("/")
    with httpx.Client(base_url=url, timeout=30) as client:
        bootstrap = client.get("/v1/bootstrap")
        bootstrap.raise_for_status()
        if not bootstrap.json().get("purchase_simulation"):
            raise ValueError("Purchase simulation is not enabled")
        login = client.post("/v1/auth/developer", json={}, headers={"X-Dev-Auth-Key": key})
        login.raise_for_status()
        client.headers["Authorization"] = "Bearer " + login.json()["access_token"]
        initial = client.get("/v1/me/entitlements")
        initial.raise_for_status()
        before = initial.json()["publishing_slots"]
        body = {"request_id": str(uuid4()), "product_id": "creator_slot_1", "outcome": "approved"}
        def send(_):
            started = time.perf_counter()
            response = client.post("/v1/development/purchases", json=body)
            return response.status_code, (time.perf_counter()-started)*1000, len(response.content)
        started = time.perf_counter()
        with ThreadPoolExecutor(max_workers=concurrency) as pool:
            samples = list(pool.map(send, range(requests)))
        elapsed = time.perf_counter() - started
        final = client.get("/v1/me/entitlements")
        final.raise_for_status()
        slots = final.json()["publishing_slots"]
    latencies = sorted(value[1] for value in samples)
    result = {"requests": requests, "concurrency": concurrency,
        "requests_per_second": round(requests/elapsed, 2), "p50_ms": round(statistics.median(latencies), 2),
        "p95_ms": round(latencies[min(len(latencies)-1, int(len(latencies)*0.95))], 2),
        "max_ms": round(max(latencies), 2), "max_response_bytes": max(value[2] for value in samples),
        "status_counts": {str(code): sum(value[0] == code for value in samples) for code in sorted({v[0] for v in samples})},
        "errors": sum(value[0] != 200 for value in samples), "slot_delta": slots-before,
        "single_grant": slots == before+1}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:18182")
    parser.add_argument("--key-file", type=Path, required=True)
    parser.add_argument("--requests", type=int, default=100)
    parser.add_argument("--concurrency", type=int, default=8)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = run(args.url, args.key_file.read_text(encoding="utf-8").strip(), args.requests, args.concurrency)
    encoded = json.dumps(result, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded+"\n", encoding="utf-8")
    print(encoded)
    raise SystemExit(0 if result["errors"] == 0 and result["single_grant"] else 1)


if __name__ == "__main__":
    main()
