"""Measure only ASGI boundary validation and event loop scheduling delay."""

import asyncio
import json
import logging
import sys
import time
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend"))
from bmt_backend.middleware import RequestBoundary


async def run():
    logging.disable(logging.CRITICAL)
    body = json.dumps({"replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0, 255]] * 216000}},
                      separators=(",", ":")).encode()
    async def application(scope, receive, send):
        await receive()
        await send({"type": "http.response.start", "status": 200, "headers": []})
        await send({"type": "http.response.body", "body": b"{}"})
    boundary = RequestBoundary(application, SimpleNamespace(max_body_bytes=8388608), None)
    gaps, elapsed = [], []
    for _ in range(3):
        scope = {"type": "http", "path": "/healthz", "method": "POST",
                 "headers": [(b"content-type", b"application/json")], "state": {}}
        async def receive():
            return {"type": "http.request", "body": body, "more_body": False}
        async def send(message):
            pass
        started = time.perf_counter()
        heartbeat = asyncio.create_task(asyncio.sleep(0))
        await boundary(scope, receive, send)
        elapsed.append(time.perf_counter() - started)
        await heartbeat
        gaps.append(time.perf_counter() - started)
    print(json.dumps({"request_bytes": len(body), "frames": 216000,
                      "boundary_seconds": elapsed, "scheduled_task_delay_seconds": gaps,
                      "limitations": "Synthetic in-memory receive, bypassed rate DB via health path; isolates middleware CPU, not HTTP throughput or deployed NAS latency."}, indent=2))


if __name__ == "__main__":
    asyncio.run(run())
