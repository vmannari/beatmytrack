"""Repeat the review's maximum replay benchmark on the fixed boundary."""
import asyncio
import json
import logging
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend"))
from bmt_backend.config import Settings
from bmt_backend import middleware


async def run():
    logging.disable(logging.CRITICAL)
    middleware.check_budget = lambda *args: True  # Isolate CPU; no database/network measurements.
    body = json.dumps({"replay":{"schema":"bmt-replay-v1","frames":[[0,255,0,255]]*216000}},separators=(",",":")).encode()
    async def application(scope, receive, send):
        assert len(scope["state"]["bounded_json"]["replay"]["frames"]) == 216000
        await send({"type":"http.response.start","status":200,"headers":[]})
        await send({"type":"http.response.body","body":b"{}"})
    boundary = middleware.RequestBoundary(application, Settings(), None)
    samples = []
    for _ in range(3):
        gaps = []
        running = True
        async def heartbeat():
            previous = time.perf_counter()
            while running:
                await asyncio.sleep(0.001)
                current = time.perf_counter()
                gaps.append(current-previous)
                previous = current
        async def receive(): return {"type":"http.request","body":body,"more_body":False}
        async def send(message): pass
        task = asyncio.create_task(heartbeat())
        await asyncio.sleep(0)
        started = time.perf_counter()
        await boundary({"type":"http","path":"/v1/runs","method":"POST","headers":[(b"content-type",b"application/json")],"state":{}},receive,send)
        elapsed = time.perf_counter()-started
        running = False
        await task
        samples.append({"elapsed_seconds":elapsed,"maximum_heartbeat_gap_seconds":max(gaps)})
    result = {"request_bytes":len(body),"frames":216000,"samples":samples,"limitations":"Synthetic ASGI receive; database quota stubbed. Measures boundary CPU and event-loop scheduling, not HTTP throughput, PostgreSQL or NAS capacity."}
    print(json.dumps(result,indent=2))
    Path(__file__).with_name("boundary.json").write_text(json.dumps(result,indent=2)+"\n")


if __name__ == "__main__": asyncio.run(run())
