"""Test admission classification of non-text filters without expensive scans."""
import asyncio
import json
import tempfile
import threading
from pathlib import Path
from unittest.mock import patch

from probe import ENDPOINT, FOLDER, create_app, hashes, seed

import httpx
from fastapi import HTTPException

from bmt_backend import discovery_v3
from bmt_backend.config import Settings
from bmt_backend.middleware import RequestBoundary
from bmt_backend.migrate import upgrade


def main():
    before = hashes()
    with tempfile.TemporaryDirectory(prefix="bmt-filter-review-") as folder:
        settings = Settings(database_url="sqlite:///" + (Path(folder) / "review.sqlite").as_posix(),
            object_dir=str(Path(folder) / "objects"), google_client_ids=("review",))
        app = create_app(settings)
        upgrade(app.state.engine)
        seed(app)
        started, release, lock = threading.Event(), threading.Event(), threading.Lock()
        entered = []

        def held(*_args, **_kwargs):
            with lock:
                entered.append(threading.get_ident())
                if len(entered) == 3:
                    started.set()
            release.wait(2)
            raise HTTPException(503, "DISCOVERY_QUERY_BUDGET", headers={"Retry-After": "1"})

        async def exercise():
            transport = httpx.ASGITransport(app=app, client=("192.0.2.57", 4000))
            async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post(ENDPOINT, json={"query": {"minimum_rating": 5, "sort": "name"}})
                assert response.status_code == 200, response.text
                cursor = response.json()["page_cursor"]
                with patch.object(discovery_v3, "page", held):
                    pending = [asyncio.create_task(client.post(ENDPOINT, json={"cursor": cursor})) for _ in range(3)]
                    try:
                        overlap = await asyncio.to_thread(started.wait, 1)
                        current = app.middleware_stack
                        while current is not None and not isinstance(current, RequestBoundary):
                            current = getattr(current, "app", None)
                        assert current is not None
                        gate_was_free = current.discovery_expensive.acquire(blocking=False)
                        if gate_was_free:
                            current.discovery_expensive.release()
                        slots = current.discovery_small_parsers._value
                    finally:
                        release.set()
                    replies = await asyncio.gather(*pending)
                return {"scope": "Real routing and cursor resolution with an instrumented query stage; no expensive scan executed",
                    "filter": {"minimum_rating": 5, "sort": "name", "search": ""},
                    "three_requests_entered_work_concurrently": overlap, "query_stage_entries": len(entered),
                    "expensive_query_gate_remained_free": gate_was_free, "ordinary_slots_remaining": slots,
                    "statuses": [value.status_code for value in replies],
                    "interpretation": "Non-text filters are outside the expensive-query gate. Their actual worst-case DB cost needs PostgreSQL load/plan measurements."}
        try:
            result = asyncio.run(exercise())
        finally:
            app.state.engine.dispose()
    result.update({"source_before": before, "source_after": hashes()})
    (FOLDER / "filter-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("FILTER_REVIEW_RESULT " + json.dumps({k: v for k, v in result.items() if not k.startswith("source_")}))


if __name__ == "__main__":
    main()
