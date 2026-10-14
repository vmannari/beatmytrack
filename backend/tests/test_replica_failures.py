"""Separate API/worker processes sharing only disposable DB and immutable objects."""
import json
import os
import socket
import subprocess
import sys
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict
from pathlib import Path
from types import SimpleNamespace

import httpx
import pytest
from sqlalchemy import create_engine, select
from test_domains import FakeVerifier

from bmt_backend.config import Settings
from bmt_backend.db import make_engine, make_session_factory
from bmt_backend.identity_models import SessionFamily, SessionToken
from bmt_backend.migrate import upgrade
from bmt_backend.resume_models import ResumeReceipt, ResumeWallet
from bmt_backend.resumes import grant_verified
from bmt_backend.track_models import PersonalBest, QueueCapacity, Run
from bmt_backend.verifier import GodotVerifier


def port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


class Processes:
    def __init__(self, root, settings, schema):
        self.root, self.settings, self.schema = root, settings, schema
        self.children = []

    def start(self, role, *, api_port=None, pause=False, fault="", finalize_failure=False, continuous=False):
        prefix = self.root / (role + "-" + uuid.uuid4().hex)
        config = {"role": role, "settings": asdict(self.settings), "schema": self.schema,
            "prefix": str(prefix), "pause": pause, "finalize_failure": finalize_failure, "continuous":continuous}
        if api_port:
            config["port"] = api_port
        config_path = Path(str(prefix) + ".json")
        config_path.write_text(json.dumps(config))
        fault_path = Path(str(prefix) + ".fault")
        if fault:
            fault_path.write_text(fault)
        with Path(str(prefix) + ".log").open("wb") as log:
            process = subprocess.Popen([sys.executable, str(Path(__file__).with_name("replica_process_probe.py")),
                str(config_path)], stdout=log, stderr=log,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        child = SimpleNamespace(process=process, prefix=prefix, fault=fault_path)
        self.children.append(child)
        if api_port:
            deadline = time.monotonic() + 15
            origin = f"http://127.0.0.1:{api_port}"
            while time.monotonic() < deadline and process.poll() is None:
                try:
                    response = httpx.get(origin + "/readyz", timeout=3)
                    if response.status_code == 200:
                        child.client = httpx.Client(base_url=origin, timeout=5)
                        return child
                except httpx.HTTPError:
                    pass
                time.sleep(0.05)
            raise AssertionError("Disposable API did not become ready")
        return child

    def stop(self, child, *, kill=False):
        if hasattr(child, "client"):
            child.client.close()
        if child.process.poll() is None:
            if os.name == "nt":
                GodotVerifier._kill_process(child.process)  # Include the venv launcher's child server.
            else:
                child.process.kill() if kill else child.process.terminate()
            try:
                child.process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                child.process.kill()
                child.process.wait(timeout=5)

    def close(self):
        for child in reversed(self.children):
            self.stop(child)


@pytest.fixture(params=["sqlite", "postgres"])
def replicas(tmp_path, request):
    schema, admin = "", None
    if request.param == "postgres":
        url = os.environ.get("BMT_TEST_DATABASE_URL")
        if not url:
            pytest.skip("Set BMT_TEST_DATABASE_URL to an explicit disposable PostgreSQL test database")
        schema = "bmt_load_" + uuid.uuid4().hex
        admin = create_engine(url, connect_args={"connect_timeout": 3}, hide_parameters=True)
        with admin.begin() as connection:
            connection.exec_driver_sql(f"CREATE SCHEMA {schema}")
    else:
        url = f"sqlite:///{(tmp_path / 'replicas.sqlite').as_posix()}"
    settings = Settings(environment="test", allow_sync_track_validation=True, database_url=url,
        object_dir=str(tmp_path / "objects"), google_client_ids=("fixture-client",),
        google_web_client_id="fixture-client", public_base_url="https://game.example",
        auth_limit_per_minute=10000, rate_limit_per_minute=10000, write_limit_per_minute=10000)
    engine = make_engine(url, settings, schema=schema)
    processes = Processes(tmp_path, settings, schema)
    try:
        upgrade(engine)
        a, b = processes.start("api", api_port=port()), processes.start("api", api_port=port())
        yield SimpleNamespace(a=a, b=b, processes=processes, engine=engine,
            factory=make_session_factory(engine), postgres=request.param == "postgres")
    finally:
        processes.close()
        engine.dispose()
        if admin:
            with admin.begin() as connection:
                connection.exec_driver_sql(f"DROP SCHEMA {schema} CASCADE")
            admin.dispose()


def auth(token, key=None):
    headers = {"Authorization": "Bearer " + token["access_token"]}
    if key is not None:
        headers["Idempotency-Key"] = key
    return headers


def sign_in(replicas, name):
    challenge = replicas.a.client.post("/v1/auth/google/challenge")
    assert challenge.status_code == 201
    credential = json.dumps({"iss": "isolated-test-fixture", "sub": name,
        "nonce": challenge.json()["nonce"], "aud": "fixture-client"})
    response = replicas.b.client.post("/v1/auth/google", json={"id_token": credential,
        "challenge_id": challenge.json()["challenge_id"], "display_name": name})
    assert response.status_code == 200
    return response.json()


def worker(replicas, **options):
    child = replicas.processes.start("worker", **options)
    if not options.get("pause"):
        assert child.process.wait(timeout=10) == (1 if options.get("finalize_failure") else 0)
    return child


def published(replicas):
    creator = sign_in(replicas, "Creator")
    document = {"schema": "creator-track-v5", "id": "replica_fixture", "shape": "oval",
                "points": [[0, 0], [20, 0], [20, 20], [0, 20]]}
    from bmt_backend.publications import CONTRACT_FIELDS
    manifest = FakeVerifier().validate_track(document)
    contract = {field: manifest[field] for field in CONTRACT_FIELDS if field != "config_hash"}
    contract["config_hash"] = manifest["vehicles"]["compact"]["config_hash"]
    uploaded = replicas.a.client.post("/v1/publications", json={"name": "Fixture loop",
        "document": document, "vehicle_id": "compact", "contract": contract,
        "replay": {"schema": "bmt-trajectory-v1", "input_count": 120,
            "race_proof": {"schema": "bmt-race-path-v1", "samples": [[0, 0, 0, 0], [120, 0, 0, 0]]}}},
        headers=auth(creator, "creator-upload"))
    assert uploaded.status_code == 202, uploaded.text
    worker(replicas)
    result = replicas.b.client.get("/v1/me/publications/" + uploaded.json()["publication_id"],
        headers=auth(creator))
    assert result.status_code == 200 and result.json()["state"] == "published", result.text
    return result.json()["receipt"]


def race_ticket(replicas, version, token):
    response = replicas.a.client.post("/v1/run-tickets", json={"version_id": version["version_id"], "vehicle_id": "compact"},
        headers=auth(token, uuid.uuid4().hex))
    assert response.status_code == 201
    return response.json()


def payload(issued):
    return {"ticket_id": issued["ticket_id"], "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]] * 20}}


def expire_lease(replicas, run_id):
    with replicas.factory() as session:
        session.get(Run, run_id).lease_until = 0  # Explicitly simulate expiry in a disposable fixture.
        session.commit()


def one_pb(replicas, token, run_id):
    with replicas.factory() as session:
        row = session.get(Run, run_id)
        assert row.status == "verified"
        records = session.scalars(select(PersonalBest).where(PersonalBest.player_id == token["player"]["id"])).all()
        assert len(records) == 1 and records[0].run_id == run_id
        assert records[0].time_ticks == row.time_ticks == 100
        assert session.get(QueueCapacity, 1).pending == 0


def test_authentication_rotation_logout_and_api_restart_cross_processes(replicas):
    token = sign_in(replicas, "Alternating driver")
    assert replicas.a.process.pid != replicas.b.process.pid
    for child in (replicas.a, replicas.b, replicas.a):
        assert child.client.get("/v1/me", headers=auth(token)).json()["id"] == token["player"]["id"]
    rotated = replicas.a.client.post("/v1/auth/refresh", json={"refresh_token": token["refresh_token"]})
    assert rotated.status_code == 200
    replacement = rotated.json()
    assert replicas.b.client.get("/v1/me", headers=auth(replacement)).status_code == 200
    replicas.processes.stop(replicas.a)
    new = replicas.processes.start("api", api_port=port())
    assert new.client.get("/v1/me", headers=auth(replacement)).status_code == 200
    assert replicas.b.client.post("/v1/auth/logout", headers=auth(replacement)).status_code == 204
    assert new.client.get("/v1/me", headers=auth(replacement)).status_code == 401


def test_browser_handoff_and_consumption_work_across_processes(replicas):
    started = replicas.a.client.post("/v1/auth/google/browser/start", json={"display_name": "Browser fixture"})
    assert started.status_code == 201
    browser_token = started.json()["browser_url"].split("#")[1]
    prepared = replicas.b.client.post("/v1/auth/google/browser/prepare", json={"token": browser_token}).json()
    credential = json.dumps({"iss": "isolated-test-fixture", "sub": "browser-driver",
        "nonce": prepared["nonce"], "aud": "fixture-client"})
    assert replicas.a.client.post("/v1/auth/google/browser/complete",
        json={"token": browser_token, "id_token": credential}).status_code == 200
    response = replicas.b.client.post("/v1/auth/google/browser/poll", json={"token": started.json()["poll_token"]})
    assert response.status_code == 200
    assert replicas.a.client.get("/v1/me", headers=auth(response.json())).status_code == 200
    assert replicas.a.client.post("/v1/auth/google/browser/poll", json={"token": started.json()["poll_token"]}).status_code == 401


def test_same_submission_retries_across_replicas_create_one_run(replicas):
    version = published(replicas)
    token = sign_in(replicas, "Retry driver")
    issued = race_ticket(replicas, version, token)
    responses = [child.client.post("/v1/runs", json=payload(issued), headers=auth(token, "shared-submit"))
        for child in (replicas.a, replicas.b, replicas.a)]
    assert all(r.status_code == 202 for r in responses)
    run_id = responses[0].json()["run_id"]
    assert all(r.json()["run_id"] == run_id for r in responses)
    with replicas.factory() as session:
        assert len(session.scalars(select(Run).where(Run.ticket_id == issued["ticket_id"])).all()) == 1
        assert session.get(QueueCapacity, 1).pending == 1
    worker(replicas)
    one_pb(replicas, token, run_id)


@pytest.mark.parametrize("mode", ["write", "write_after"])
def test_object_publication_failure_retries_on_other_replica_without_duplicate(replicas, mode):
    version = published(replicas)
    token = sign_in(replicas, "Object retry driver")
    issued = race_ticket(replicas, version, token)
    assert replicas.a.client.get("/readyz").status_code == 200
    replicas.a.fault.write_text(mode)
    failed = replicas.a.client.post("/v1/runs", json=payload(issued), headers=auth(token, "object-retry"))
    assert failed.status_code == 503 and failed.json()["detail"] == "STORAGE_UNAVAILABLE"
    assert replicas.a.client.get("/healthz").status_code == 200
    assert replicas.a.client.get("/readyz").status_code == 503
    with replicas.factory() as session:
        assert session.scalar(select(Run).where(Run.ticket_id == issued["ticket_id"])) is None
        assert session.get(QueueCapacity, 1).pending == 0
    retry = replicas.b.client.post("/v1/runs", json=payload(issued), headers=auth(token, "object-retry"))
    assert retry.status_code == 202
    worker(replicas)
    one_pb(replicas, token, retry.json()["run_id"])


@pytest.mark.parametrize("mode", ["read", "finalize"])
def test_failed_worker_is_recovered_by_another_process(replicas, mode):
    version = published(replicas)
    token = sign_in(replicas, "Worker retry driver")
    issued = race_ticket(replicas, version, token)
    response = replicas.a.client.post("/v1/runs", json=payload(issued), headers=auth(token, "worker-retry"))
    assert response.status_code == 202
    run_id = response.json()["run_id"]
    worker(replicas, fault="read" if mode == "read" else "", finalize_failure=mode == "finalize")
    with replicas.factory() as session:
        row = session.get(Run, run_id)
        assert row.status == ("queued" if mode == "read" else "verifying")
        assert session.scalar(select(PersonalBest).where(PersonalBest.player_id == token["player"]["id"])) is None
        assert session.get(QueueCapacity, 1).pending == 1
    expire_lease(replicas, run_id)
    worker(replicas)
    assert replicas.b.client.get(f"/v1/runs/{run_id}", headers=auth(token)).json()["status"] == "verified"
    one_pb(replicas, token, run_id)


@pytest.mark.parametrize("mode", ["kill", "stale"])
def test_dead_or_stale_worker_cannot_duplicate_or_overwrite_verified_result(replicas, mode):
    version = published(replicas)
    token = sign_in(replicas, "Fenced driver")
    issued = race_ticket(replicas, version, token)
    response = replicas.b.client.post("/v1/runs", json=payload(issued), headers=auth(token, "fenced-submit"))
    assert response.status_code == 202
    run_id = response.json()["run_id"]
    old = worker(replicas, pause=True)
    try:
        deadline = time.monotonic() + 10
        while not Path(str(old.prefix) + ".claimed").exists() and time.monotonic() < deadline and old.process.poll() is None:
            time.sleep(0.02)
        assert Path(str(old.prefix) + ".claimed").exists()
        with replicas.factory() as session:
            row = session.get(Run, run_id)
            assert row.status == "verifying" and row.lease_token
        if mode == "kill":
            replicas.processes.stop(old, kill=True)
        expire_lease(replicas, run_id)
        new = worker(replicas)
        assert new.process.pid != old.process.pid
        one_pb(replicas, token, run_id)
        if mode == "stale":
            Path(str(old.prefix) + ".release").touch()
            assert old.process.wait(timeout=5) == 0
            one_pb(replicas, token, run_id)
    finally:
        replicas.processes.stop(old, kill=True)


def test_concurrent_submission_and_resume_retries_are_idempotent_across_replicas(replicas):
    if not replicas.postgres:
        pytest.skip("Concurrent production write serialization requires PostgreSQL row locks")
    version = published(replicas)
    token = sign_in(replicas, "Concurrent driver")
    with replicas.factory() as session:
        grant_verified(session, token["player"]["id"], "award", "fixture-award", quantity=2)
        session.commit()
    race = replicas.a.client.post("/v1/resume-races", json={}, headers=auth(token, "resume-race"))
    assert race.status_code == 201
    barrier = threading.Barrier(2)
    def consume(child):
        barrier.wait(timeout=5)
        return child.client.post(f"/v1/resume-races/{race.json()['race_id']}/resumes",
            json={"ordinal": 1, "input_offset": 100, "from_tick": 100, "to_tick": 50}, headers=auth(token, "consume-once"))
    with ThreadPoolExecutor(max_workers=2) as pool:
        receipts = list(pool.map(consume, (replicas.a, replicas.b)))
    assert all(r.status_code == 200 for r in receipts)
    assert receipts[0].json() == receipts[1].json()
    with replicas.factory() as session:
        assert session.get(ResumeWallet, token["player"]["id"]).balance == 1
        assert len(session.scalars(select(ResumeReceipt)).all()) == 1
    issued = race_ticket(replicas, version, token)
    barrier = threading.Barrier(2)
    for child in (replicas.a, replicas.b):
        child.fault.write_text("publication_barrier")
    def submit(child):
        barrier.wait(timeout=5)
        return child.client.post("/v1/runs", json=payload(issued), headers=auth(token, "concurrent-submit"))
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(submit, child) for child in (replicas.a, replicas.b)]
        try:
            deadline = time.monotonic() + 4
            while not all(Path(str(child.fault) + ".arrived").exists() for child in (replicas.a, replicas.b)) and time.monotonic() < deadline:
                time.sleep(0.01)
            assert all(Path(str(child.fault) + ".arrived").exists() for child in (replicas.a, replicas.b))
        finally:
            for child in (replicas.a, replicas.b):
                Path(str(child.fault) + ".release").touch()
        replies = [future.result(timeout=5) for future in futures]
    for child in (replicas.a, replicas.b):
        child.fault.unlink()
    assert all(r.status_code == 202 for r in replies)
    assert replies[0].json()["run_id"] == replies[1].json()["run_id"]
    worker(replicas)
    one_pb(replicas, token, replies[0].json()["run_id"])


def test_concurrent_refresh_reuse_revokes_replacement_on_both_replicas(replicas):
    if not replicas.postgres:
        pytest.skip("Refresh serialization requires PostgreSQL row locks")
    token = sign_in(replicas, "Refresh reuse fixture")
    barrier = threading.Barrier(2)
    def refresh(child):
        barrier.wait(timeout=5)
        return child.client.post("/v1/auth/refresh", json={"refresh_token": token["refresh_token"]})
    with ThreadPoolExecutor(max_workers=2) as pool:
        replies = list(pool.map(refresh, (replicas.a, replicas.b)))
    assert sorted(r.status_code for r in replies) == [200, 401]
    replacement = next(r.json() for r in replies if r.status_code == 200)
    for child in (replicas.a, replicas.b):
        assert child.client.get("/v1/me", headers=auth(replacement)).status_code == 401
    with replicas.factory() as session:
        assert session.scalar(select(SessionFamily)).revoked
        assert len(session.scalars(select(SessionToken)).all()) == 2


def test_postgres_probe_timeout_is_transaction_local(replicas):
    if not replicas.postgres:
        pytest.skip("PostgreSQL statement timeout is a production adapter contract")
    assert replicas.a.client.get("/readyz").status_code == 200
    # Inspect every connection in the API's own pool, rather than an unrelated parent engine.
    result = replicas.a.client.get("/__fixture/pool-timeouts")
    assert result.status_code == 200
    assert result.json() == [replicas.processes.settings.database_statement_timeout_ms] * replicas.processes.settings.database_pool_size


def test_stalled_storage_probe_keeps_liveness_and_other_replica_responsive(replicas):
    replicas.a.fault.write_text("stall")
    try:
        assert replicas.a.client.get("/__fixture/invalidate-readiness").status_code == 200
        with ThreadPoolExecutor(max_workers=20) as pool:
            started = time.monotonic()
            futures = [pool.submit(replicas.a.client.get, "/readyz") for _ in range(20)]
            marker = Path(str(replicas.a.fault) + ".stalled")
            deadline = time.monotonic() + 3
            while not marker.exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            assert marker.exists()
            health_start = time.monotonic()
            assert replicas.a.client.get("/healthz").status_code == 200
            assert time.monotonic() - health_start < 1
            assert replicas.b.client.get("/readyz").status_code == 200
            responses = [future.result(timeout=4) for future in futures]
            assert all(r.status_code == 503 and r.json()["detail"] == "DEPENDENCY_TIMEOUT" for r in responses)
            assert time.monotonic() - started < 4
        assert replicas.a.client.get("/__fixture/probe-threads").json() == {"count": 1}
        assert replicas.a.client.get("/readyz").status_code == 503
    finally:
        replicas.a.fault.unlink(missing_ok=True)
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if replicas.a.client.get("/readyz").status_code == 200:
            break
        time.sleep(0.05)
    else:
        pytest.fail("Readiness did not recover after storage became available")
