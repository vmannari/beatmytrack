"""Actual middleware/FastAPI replay decoding peak Python allocation, not load capacity."""
import asyncio
import json
import sys
import tracemalloc
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT / "backend"))
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.security import current_player
import bmt_backend.middleware as middleware


async def run():
    body = json.dumps({"ticket_id":"00000000-0000-4000-8000-000000000001",
        "replay":{"schema":"bmt-replay-v1","frames":[[0,255,0,255]]*216000}},separators=(",",":")).encode()
    original = middleware.check_budget
    middleware.check_budget = lambda *_:True
    app = create_app(Settings(environment="test",database_url="sqlite://",object_dir=str(ROOT / ".tools/review-memory-objects")))
    upgrade(app.state.engine)
    app.dependency_overrides[current_player] = lambda:Player(id="fixture-player",display_name="Fixture")
    try:
        # Input bytes are built before tracing; the measured allocation includes
        # strict decode, FastAPI/Pydantic, canonical replay checks and DB lookup.
        tracemalloc.start()
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app),base_url="http://fixture") as client:
            response = await client.post("/v1/runs",content=body,headers={"content-type":"application/json","idempotency-key":"fixture-only-key"})
        current, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        assert response.status_code == 404 and response.json()["detail"] == "Run ticket not found", response.text
        result = {"frames":216000,"request_bytes":len(body),"current_python_bytes":current,"peak_python_bytes":peak,
            "response":404,"limitations":"One full four-channel replay through actual FastAPI. Rate DB writes stubbed. tracemalloc excludes native allocator/RSS and input bytes; not a NAS, concurrency or throughput benchmark."}
        Path(__file__).with_name("framework-memory.json").write_text(json.dumps(result,indent=2))
        print(json.dumps(result))
    finally:
        middleware.check_budget = original
        app.state.engine.dispose()

asyncio.run(run())
