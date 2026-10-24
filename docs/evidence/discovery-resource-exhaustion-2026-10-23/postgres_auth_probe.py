"""Owned PostgreSQL authentication-lock pressure probe; never uses a live DB."""
import asyncio
import json
import os
import subprocess
import tempfile
import time
import uuid
from pathlib import Path

from probe import ENDPOINT, FOLDER, ORIGIN, create_app, hashes

import httpx
from alembic import command
from fastapi.testclient import TestClient
from sqlalchemy import select, text

from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration


def docker(*args, check=True):
    return subprocess.run(["wsl", "-d", "Ubuntu", "--", "docker", *args], capture_output=True,
                          text=True, check=check, timeout=30)


class Identity:
    def __init__(self):
        self.claims = {}

    def verify(self, token):
        return self.claims[token]


def main():
    before = hashes()
    owner = uuid.uuid4().hex
    name = "bmt-resource-review-" + owner[:12]
    created = False
    engine = None
    app = None
    holder = None
    try:
        docker("run", "--pull=never", "-d", "--name", name, "--label", "bmt.resource.owner=" + owner,
            "--memory=512m", "--cpus=1", "-p", "127.0.0.1::5432", "-e", "POSTGRES_HOST_AUTH_METHOD=trust",
            "-e", "POSTGRES_USER=bmt_review", "-e", "POSTGRES_DB=bmt_resource_review", "postgres:17-bookworm",
            "-c", "max_connections=16", "-c", "shared_buffers=32MB")
        created = True
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            if docker("exec", name, "pg_isready", "-U", "bmt_review", check=False).returncode == 0:
                break
            time.sleep(.1)
        else:
            raise RuntimeError("Owned DB did not become ready")
        port = docker("port", name, "5432/tcp").stdout.strip().rsplit(":", 1)[1]
        endpoint = "postgresql+psycopg://bmt_review@127.0.0.1:" + port + "/bmt_resource_review"
        with tempfile.TemporaryDirectory(prefix="bmt-auth-pressure-review-") as folder:
            settings = Settings(database_url=endpoint, object_dir=str(Path(folder) / "objects"),
                google_client_ids=("review",), auth_limit_per_minute=1000, database_pool_size=4,
                database_pool_overflow=0)
            identity = Identity()
            app = create_app(settings, identity_verifier=identity)
            # Pin the probe's existing auth/discovery schema. Concurrent rank/
            # retention migration work is outside this security investigation.
            command.upgrade(configuration(app.state.engine), "0054_priority_scaling")
            logins = []
            with TestClient(app, client=(ORIGIN, 4000)) as client:
                for display in ("Pressure owner", "Other driver"):
                    challenge = client.post("/v1/auth/google/challenge").json()
                    token = uuid.uuid4().hex
                    identity.claims[token] = {"sub": display, "nonce": challenge["nonce"]}
                    response = client.post("/v1/auth/google", json={"id_token": token,
                        "challenge_id": challenge["challenge_id"], "display_name": display})
                    assert response.status_code == 200, response.text
                    logins.append(response.json())
                for login in logins:
                    assert client.get("/v1/me", headers={"Authorization": "Bearer " + login["access_token"]}).status_code == 200
            engine = make_engine(endpoint)
            holder = app.state.session_factory()
            holder.execute(select(Player.id).where(Player.id == logins[0]["player"]["id"]).with_for_update()).scalar_one()

            async def exercise():
                nonlocal holder
                transport = httpx.ASGITransport(app=app, client=(ORIGIN, 4000))
                async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
                    requests = [asyncio.create_task(client.post(ENDPOINT, json={"query": {}},
                        headers={"Authorization": "Bearer " + logins[0]["access_token"]})) for _ in range(3)]
                    waiters = 0
                    deadline = time.monotonic() + 1
                    while time.monotonic() < deadline:
                        with engine.connect() as db:
                            waiters = db.scalar(text("SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() "
                                "AND wait_event_type='Lock' AND query LIKE '%FOR UPDATE%'"))
                        if waiters == 3:
                            break
                        await asyncio.sleep(.01)
                    checked_out = app.state.engine.pool.checkedout()
                    start = time.monotonic()
                    healthy = asyncio.create_task(client.get("/v1/me",
                        headers={"Authorization": "Bearer " + logins[1]["access_token"]}))
                    await asyncio.sleep(.15)
                    healthy_waiting = not healthy.done()
                    holder.rollback()
                    holder.close()
                    holder = None
                    result = await healthy
                    elapsed = time.monotonic() - start
                    replies = await asyncio.gather(*requests)
                    return {"scope": "Controlled owner-row lock holds one real API-pool connection, representing an in-flight discovery transaction; three actual authenticated POSTs then contend during pre-body authentication",
                        "api_pool_size": 4, "checked_out_connections": checked_out,
                        "same_account_authentication_lock_waiters": waiters,
                        "unrelated_account_read_waiting_after_150ms": healthy_waiting,
                        "unrelated_account_read_status_after_release": result.status_code,
                        "unrelated_account_read_elapsed_ms": round(elapsed*1000, 3),
                        "discovery_statuses_after_release": [r.status_code for r in replies],
                        "interpretation": "The admission/search gates do not stop pre-body account-lock waiters from occupying the shared API DB pool. The 150ms hold is controlled, not a production latency measurement."}

            result = asyncio.run(exercise())
        result.update({"source_before": before, "source_after": hashes(), "schema_revision": "0054_priority_scaling",
            "environment": {"database": "Owned disposable PostgreSQL 17", "loopback_port": int(port),
                            "cpu_limit": 1, "memory_limit": "512MiB", "no_network_image_pull": True}})
        (FOLDER / "postgres-auth-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print("POSTGRES_AUTH_REVIEW " + json.dumps({k: v for k, v in result.items() if not k.startswith("source_")}))
    finally:
        if holder is not None:
            holder.rollback()
            holder.close()
        if app is not None:
            app.state.engine.dispose()
        if engine is not None:
            engine.dispose()
        if created:
            inspected = json.loads(docker("inspect", name).stdout)[0]
            assert inspected["Config"]["Labels"].get("bmt.resource.owner") == owner
            docker("rm", "-f", name)
            print("Owned resource-review PostgreSQL removed")


if __name__ == "__main__":
    main()
