"""Isolated residual-abuse probes. No runtime edits or deployed requests."""
import asyncio
import hashlib
import ipaddress
import json
import sys
import tempfile
import threading
import time
import uuid
from dataclasses import replace
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
FOLDER = Path(__file__).parent
sys.path.insert(0, str(ROOT / "backend"))

import httpx
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import event, func, select, text

from bmt_backend import discovery_v3, middleware
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.discovery_models import DiscoveryMember
from bmt_backend.discovery_projection import settle_for_diagnostics
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.track_models import Track, TrackVersion

PATHS = ["backend/bmt_backend/middleware.py", "backend/bmt_backend/discovery_v3.py",
         "backend/bmt_backend/config.py", "backend/bmt_backend/client_address.py",
         "backend/bmt_backend/security.py", "game/backend/discovery_windows.gd"]
ORIGIN = "192.0.2.55"
ENDPOINT = "/v1/discovery/v3/tracks"


def hashes():
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in PATHS}


def seed(app):
    stamp, owner = int(time.time()), str(uuid.uuid4())
    with app.state.session_factory() as db:
        db.add(Player(id=owner, username_key="resource review", display_name="Resource Review", needs_username=False))
        for index in range(60):
            track_id = str(uuid.uuid4())
            db.add(Track(id=track_id, owner_id=owner, official=False))
            db.add(TrackVersion(id=str(uuid.uuid4()), track_id=track_id, number=1,
                name=f"Review {index:03}", content_hash="a" * 64, manifest={},
                discovery={"theme": "pine", "points": []}, state="published",
                published_at=stamp-index, created_at=stamp-index, rating_sum=0, rating_count=0))
        db.commit()
    settle_for_diagnostics(app.state.session_factory)


def exercise(app, settings):
    first_query = {"query": {"sort": "name", "search": "Review"}}
    with TestClient(app, client=(ORIGIN, 4000)) as client:
        first = client.post(ENDPOINT, json=first_query)
        assert first.status_code == 200, first.text
        cursor = first.json()["next_cursor"]
        attempted = []

        def fail_query(*_args, **_kwargs):
            attempted.append(time.monotonic())
            raise HTTPException(503, "DISCOVERY_QUERY_BUDGET", headers={"Retry-After": "1"})

        replies = []
        with patch.object(discovery_v3, "page", fail_query):
            for body in [{"cursor": cursor}] * 4 + [first_query] * 4:
                response = client.post(ENDPOINT, json=body)
                replies.append({"status": response.status_code, "retry_after": response.headers.get("retry-after")})
        replay = {"scope": "Actual routing/admission with an instrumented query stage returning the real timeout response shape; no CPU-intensive scan",
            "creation_limit_per_minute": 1, "work_stage_entries": len(attempted), "responses": replies,
            "minimum_gap_seconds": min(b-a for a, b in zip(attempted, attempted[1:])),
            "all_adjacent_attempts_inside_retry_after": all(b-a < 1 for a, b in zip(attempted, attempted[1:]))}

        statements = []

        def capture(_connection, _cursor, sql, *_args):
            statements.append(sql)

        event.listen(app.state.engine, "before_cursor_execute", capture)
        try:
            denied = [client.post(ENDPOINT, json={"query": {"sort": "new", "search": "Review"}}) for _ in range(6)]
        finally:
            event.remove(app.state.engine, "before_cursor_execute", capture)
        quota = {"statuses": [r.status_code for r in denied], "detail": denied[0].json().get("detail"),
            "sql_statements": len(statements),
            "pending_lag_reads_before_denial": sum("discovery_changes.created_at" in sql for sql in statements)}

        app.state.settings = replace(settings, discovery_create_per_minute=20)
        unknown = [str(uuid.uuid5(uuid.NAMESPACE_URL, f"unknown-review-{i}")) for i in range(2000)]
        with app.state.session_factory() as db:
            before = db.scalar(select(func.count()).select_from(DiscoveryMember))
        response = client.post(ENDPOINT, json={"query": {"section": "favorites", "ids": unknown[:1000],
                                                        "raced_ids": unknown[1000:]}})
        with app.state.session_factory() as db:
            after = db.scalar(select(func.count()).select_from(DiscoveryMember))
            matching = db.scalar(select(func.count()).select_from(DiscoveryMember).join(Track, Track.id == DiscoveryMember.track_id))
        collection = {"anonymous": True, "submitted_ids": len(unknown), "status": response.status_code,
            "returned_cards": len(response.json().get("items", [])), "persisted_member_rows": after-before,
            "member_rows_matching_source_tracks": matching}
        app.state.settings = settings

    async def ipv6_probe():
        addresses = ["2001:db8:1234:5678::1", "2001:db8:1234:5678::2", "2001:db8:1234:5678::3"]
        result = []
        for address in addresses:
            transport = httpx.ASGITransport(app=app, client=(address, 4000))
            async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
                accepted = await client.post(ENDPOINT, json=first_query)
                denied = await client.post(ENDPOINT, json={"query": {"sort": "new", "search": "Review"}})
                result.append({"peer": address, "first_status": accepted.status_code, "second_status": denied.status_code})
        return {"scope": "Simulated actual connection peers, not caller-supplied forwarding headers",
            "shared_prefix": str(ipaddress.ip_network(addresses[0] + "/64", strict=False)),
            "creation_limit_per_peer_per_minute": 1, "results": result}

    second_app = create_app(settings, engine=app.state.engine)
    started, release, lock = threading.Event(), threading.Event(), threading.Lock()
    concurrent = []

    def held_query(*_args, **_kwargs):
        with lock:
            concurrent.append(threading.get_ident())
            if len(concurrent) == 2:
                started.set()
        release.wait(2)
        raise HTTPException(503, "DISCOVERY_QUERY_BUDGET", headers={"Retry-After": "1"})

    async def two_replicas():
        transports = [httpx.ASGITransport(app=value, client=(ORIGIN, 4000)) for value in (app, second_app)]
        async with httpx.AsyncClient(transport=transports[0], base_url="http://test") as a:
            async with httpx.AsyncClient(transport=transports[1], base_url="http://test") as b:
                pending = [asyncio.create_task(value.post(ENDPOINT, json={"cursor": cursor})) for value in (a, b)]
                try:
                    overlap = await asyncio.to_thread(started.wait, 1)
                finally:
                    release.set()
                responses = await asyncio.gather(*pending)
                return {"scope": "Two API app instances sharing one temporary DB, each with its existing admission semaphore; instrumented query stage",
                    "same_actor_same_cursor": True, "both_entered_work_concurrently": overlap,
                    "query_stage_entries": len(concurrent), "statuses": [r.status_code for r in responses]}

    ipv6 = asyncio.run(ipv6_probe())
    with patch.object(discovery_v3, "page", held_query):
        replicas = asyncio.run(two_replicas())
    return {"retry_and_creation_budget": replay, "already_exhausted_creation_quota": quota,
            "anonymous_unknown_ids": collection, "ipv6_budget_scope": ipv6,
            "duplicate_work_across_replicas": replicas}


def main():
    source_before = hashes()
    (FOLDER / "before").mkdir(exist_ok=True)
    for name in PATHS:
        (FOLDER / "before" / name.replace("/", "__")).write_bytes((ROOT / name).read_bytes())
    with tempfile.TemporaryDirectory(prefix="bmt-resource-review-") as folder:
        settings = Settings(database_url="sqlite:///" + (Path(folder) / "review.sqlite").as_posix(),
            object_dir=str(Path(folder) / "objects"), google_client_ids=("review",), discovery_create_per_minute=1)
        app = create_app(settings)
        try:
            with app.state.engine.connect() as db:
                db.execute(text("PRAGMA journal_mode=WAL"))
            upgrade(app.state.engine)
            seed(app)
            # Keep fixed-minute admission comparisons deterministic, including if a wall-clock minute rolls over.
            stamp = time.time()
            clock = SimpleNamespace(time=lambda: stamp, monotonic=time.monotonic)
            with patch.object(middleware, "time", clock):
                result = exercise(app, settings)
        finally:
            app.state.engine.dispose()
    result.update({"scope": "Isolated local ASGI/SQLite abuse-path behavior, not a production load test",
        "source_before": source_before, "source_after": hashes(),
        "high_priority_work": "Slow-body/admission split, browser retry guard and expiry scheduling treated as existing work; no runtime changes made here"})
    (FOLDER / "results.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("RESOURCE_REVIEW_RESULT " + json.dumps({k: v for k, v in result.items() if not k.startswith("source_")}))


if __name__ == "__main__":
    main()
