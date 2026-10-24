"""Local reader/admission overhead and real PostgreSQL owner-lock checks."""
import importlib.util
import json
import os
from pathlib import Path
import statistics
import sys
import tempfile
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
FOLDER = Path(__file__).parent
sys.path.insert(0, str(ROOT / "backend"))

from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import event, select, text
from sqlalchemy.engine import make_url

from bmt_backend import discovery_v3
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade


class Identity:
    def __init__(self):
        self.claims = {}

    def verify(self, token):
        return self.claims[token]


def main():
    endpoint = os.environ["BMT_DISCOVERY_TEST_DATABASE_URL"]
    address = make_url(endpoint)
    assert address.host == "127.0.0.1" and address.database == "bmt_discovery_lab"
    schema = "bmt_load_"+uuid.uuid4().hex
    admin = make_engine(endpoint)
    with admin.begin() as db:
        db.execute(text('CREATE SCHEMA "'+schema+'"'))
    engine = make_engine(endpoint, schema=schema)
    objects = tempfile.TemporaryDirectory(prefix="bmt-resource-profile-")
    try:
        upgrade(engine)
        spec = importlib.util.spec_from_file_location("reader_seed", ROOT/"docs/evidence/discovery-indexed-2026-10-22/scale_probe.py")
        fixture = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(fixture)
        fixture.seed(engine, 5001)
        identity = Identity()
        settings = Settings(database_url=endpoint, object_dir=objects.name,
            google_client_ids=("review",))
        app = create_app(settings, engine=engine, identity_verifier=identity)
        statements = []

        def capture(_connection, _cursor, sql, *_args):
            statements.append(sql)

        event.listen(engine, "before_cursor_execute", capture)
        with TestClient(app) as client:
            start = time.perf_counter()
            first = client.post("/v1/discovery/v3/tracks", json={"query": {"sort": "name"}})
            assert first.status_code == 200, first.text
            fresh = {"milliseconds": (time.perf_counter()-start)*1000, "statements": len(statements)}
            cursor = first.json()["next_cursor"]
            latencies, counts = [], []
            for _ in range(25):
                statements.clear()
                start = time.perf_counter()
                response = client.post("/v1/discovery/v3/tracks", json={"cursor": cursor})
                latencies.append((time.perf_counter()-start)*1000)
                counts.append(len(statements))
                assert response.status_code == 200 and len(response.json()["items"]) == 20, response.text
                cursor = response.json()["next_cursor"]
            searched = client.post("/v1/discovery/v3/tracks", json={"query": {"search": "Circuit", "sort": "name"}})
            assert searched.status_code == 200, searched.text
            entered = []

            def failed(*_args):
                entered.append(True)
                raise HTTPException(503, "DISCOVERY_QUERY_BUDGET", headers={"Retry-After": "1"})

            with patch.object(discovery_v3, "page", failed):
                body = {"cursor": searched.json()["page_cursor"]}
                failure = client.post("/v1/discovery/v3/tracks", json=body)
                attempts = [client.post("/v1/discovery/v3/tracks", json=body) for _ in range(5)]
            ordinary = client.post("/v1/discovery/v3/tracks", json={"cursor": cursor})

            logins = []
            for subject in ("Guard owner", "Independent player"):
                challenge = client.post("/v1/auth/google/challenge").json()
                token = uuid.uuid4().hex
                identity.claims[token] = {"sub": subject, "nonce": challenge["nonce"]}
                signed = client.post("/v1/auth/google", json={"id_token": token,
                    "challenge_id": challenge["challenge_id"], "display_name": subject})
                assert signed.status_code == 200, signed.text
                logins.append(signed.json())
            headers = [{"Authorization": "Bearer "+login["access_token"]} for login in logins]
            for value in headers:
                assert client.get("/v1/me", headers=value).status_code == 200
            with app.state.session_factory() as holder, ThreadPoolExecutor(max_workers=3) as pool:
                holder.scalar(select(Player.id).where(Player.id == logins[0]["player"]["id"]).with_for_update())
                start = time.perf_counter()
                requests = [pool.submit(client.post, "/v1/discovery/v3/tracks", json={"query": {}}, headers=headers[0]) for _ in range(3)]
                replies = [request.result(1.25) for request in requests]
                same_account_ms = (time.perf_counter()-start)*1000
                checked_out = engine.pool.checkedout()
                start = time.perf_counter()
                other = client.get("/v1/me", headers=headers[1])
                unrelated_ms = (time.perf_counter()-start)*1000
            result = {"scope": "Local synthetic5001-track TestClient/PostgreSQL probe, not cloud/network/DAU capacity",
                "fresh_view": fresh, "twenty_item_cursor_pages": {"samples": len(latencies),
                    "median_ms": statistics.median(latencies), "max_ms": max(latencies), "statement_counts": sorted(set(counts))},
                "timeout_replay": {"instrumented_execution_attempts": len(entered), "initial_status": failure.status_code,
                    "initial_retry_after": failure.headers.get("retry-after"),
                    "repeat_statuses": [r.status_code for r in attempts],
                    "repeat_details": [r.json().get("detail") for r in attempts], "ordinary_page_status": ordinary.status_code},
                "held_owner_lock": {"pool_size": engine.pool.size(), "connections_checked_out_after_three_rejections": checked_out,
                    "same_account_statuses": [r.status_code for r in replies],
                    "same_account_details": [r.json().get("detail") for r in replies],
                    "three_rejections_ms": same_account_ms, "other_player_read_status": other.status_code,
                    "other_player_read_ms_while_lock_held": unrelated_ms}}
            assert all(r.status_code == 503 and r.json().get("detail") == "DISCOVERY_ACCOUNT_BUSY" for r in replies)
            assert other.status_code == ordinary.status_code == 200
            assert len(entered) == 1 and all(r.json().get("detail") == "DISCOVERY_RETRY_COOLDOWN" for r in attempts)
            (FOLDER/"profile-result.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
            print(json.dumps(result, indent=2))
    finally:
        engine.dispose()
        with admin.begin() as db:
            db.execute(text('DROP SCHEMA "'+schema+'" CASCADE'))
        admin.dispose()
        objects.cleanup()


if __name__ == "__main__":
    main()
