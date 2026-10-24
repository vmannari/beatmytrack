"""Owned temporary SQLite/ASGI review probe; no deployed API or account access."""
import asyncio
import json
import sys
import tempfile
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend"))

import httpx
from fastapi.testclient import TestClient
from sqlalchemy import event, select, update

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.discovery_models import DiscoveryBoundary, DiscoveryPartition
from bmt_backend.discovery_projection import settle_for_diagnostics, step
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.track_models import Track, TrackVersion


def main():
    with tempfile.TemporaryDirectory(prefix="bmt-discovery-review-") as folder:
        settings = Settings(database_url="sqlite:///" + (Path(folder) / "review.sqlite").as_posix(),
                            object_dir=str(Path(folder) / "objects"), google_client_ids=("review",))
        app = create_app(settings)
        upgrade(app.state.engine)
        try:
            owner, stamp = str(uuid.uuid4()), int(time.time())
            with app.state.session_factory() as db:
                db.add(Player(id=owner, username_key="local review", display_name="Local Review", needs_username=False))
                for index in range(60):
                    track_id = str(uuid.uuid4())
                    db.add(Track(id=track_id, owner_id=owner, official=False))
                    db.add(TrackVersion(id=str(uuid.uuid4()), track_id=track_id, number=1,
                        name=f"Review {index:03}", content_hash="a" * 64, manifest={},
                        discovery={"theme": "pine", "points": []}, state="published",
                        published_at=stamp-index, created_at=stamp-index, rating_sum=0, rating_count=0))
                db.commit()
            settle_for_diagnostics(app.state.session_factory)
            statements = []

            def capture(_connection, _cursor, sql, *_args):
                statements.append(sql)

            with TestClient(app) as client:
                event.listen(app.state.engine, "before_cursor_execute", capture)
                try:
                    response = client.post("/v1/discovery/v3/tracks", json={"query": {"sort": "name"}})
                    assert response.status_code == 200, response.text
                    fresh = {"status": response.status_code, "sql_statements": len(statements),
                        "receipt_lag_reads": sum("discovery_changes.created_at" in sql for sql in statements),
                        "inserts": sum(sql.startswith("INSERT") for sql in statements)}
                    statements.clear()
                    response = client.post("/v1/discovery/v3/tracks", json={"cursor": response.json()["next_cursor"]})
                    assert response.status_code == 200, response.text
                    cursor = {"status": response.status_code, "sql_statements": len(statements),
                        "inserts": sum(sql.startswith("INSERT") for sql in statements)}
                finally:
                    event.remove(app.state.engine, "before_cursor_execute", capture)

            async def slow_probe():
                reached, release = asyncio.Event(), asyncio.Event()

                async def receive():
                    reached.set()
                    await release.wait()
                    return {"type": "http.request", "body": b'{"query":{}}', "more_body": False}

                async def send(_message):
                    pass

                path = "/v1/discovery/v3/tracks"
                scope = {"type": "http", "asgi": {"version": "3.0"}, "http_version": "1.1",
                    "method": "POST", "scheme": "http", "path": path, "raw_path": path.encode(),
                    "query_string": b"", "root_path": "", "headers": [(b"content-type", b"application/json"),
                    (b"content-length", b"12")], "client": ("192.0.2.44", 4000), "server": ("test", 80)}
                pending = asyncio.create_task(app(scope, receive, send))
                try:
                    await asyncio.wait_for(reached.wait(), 3)
                    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
                        start = time.perf_counter()
                        response = await client.post(path, json={"query": {}})
                        return {"status": response.status_code, "detail": response.json().get("detail"),
                            "milliseconds": round((time.perf_counter()-start)*1000, 3),
                            "slow_request_still_holds_slot": not pending.done()}
                finally:
                    release.set()
                    await asyncio.wait_for(pending, 5)

            slow = asyncio.run(slow_probe())
            with app.state.session_factory() as db:
                db.execute(update(DiscoveryPartition).values(audit_at=int(time.time()) + 3600))
                db.execute(update(DiscoveryBoundary).values(expires_at=1))
                before = len(list(db.scalars(select(DiscoveryBoundary.id))))
                db.commit()
            worked = step(app.state.session_factory)
            with app.state.session_factory() as db:
                after = len(list(db.scalars(select(DiscoveryBoundary.id))))
            result = {"scope": "Local ASGI/SQLite behavior and statement-count probe; not PostgreSQL/network capacity",
                "fresh_view": fresh, "cursor_page": cursor, "slow_body": slow,
                "cleanup": {"boundary_rows_before": before, "boundary_rows_after": after,
                    "step_reported_work": worked}}
            target = Path(__file__).with_name("backend-result.json")
            target.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
            print("DISCOVERY_BACKEND_REVIEW " + json.dumps(result))
        finally:
            app.state.engine.dispose()


if __name__ == "__main__":
    main()
