"""Review diagnostics: assertions document current defects without changing runtime."""

import os
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import event, select
from sqlalchemy.exc import DBAPIError

PROJECT_ROOT = next(
    parent
    for parent in Path(__file__).resolve().parents
    if (parent / "backend" / "pyproject.toml").is_file()
)
sys.path.insert(0, str(PROJECT_ROOT / "backend" / "tests"))
import test_replica_failures as replica_tests
from bmt_backend.publication_models import PublicationIntent
from bmt_backend.publications import process_one as publish_one
from bmt_backend.track_models import IdempotencyRecord, Run
from bmt_backend.verifier import GodotVerifier
from bmt_backend.worker import process_one
from test_domains import FakeVerifier, headers, public_course, submit, ticket
from test_domains import domain as domain_fixture
from test_publication_intents import body as publication_body
from test_publication_intents import publications as publications_fixture
from test_publication_intents import request as publish_request

domain = domain_fixture
publications = publications_fixture


@pytest.fixture(params=["sqlite", "postgres"])
def review_replicas(tmp_path, request, monkeypatch):
    if request.param == "postgres" and not os.environ.get("BMT_TEST_DATABASE_URL"):
        config = PROJECT_ROOT / ".tools" / "backend-postgres.env"
        url = next(
            line.split("=", 1)[1].strip()
            for line in config.read_text().splitlines()
            if line.startswith("BMT_TEST_DATABASE_URL=")
        )
        monkeypatch.setenv("BMT_TEST_DATABASE_URL", url)
    yield from replica_tests.replicas.__wrapped__(tmp_path, request)


def test_large_integer_movement_proof_returns_unstructured_500(domain):
    version, _ = public_course(domain)
    issued = ticket(domain, version, "Alice")
    replay = {
        "schema": "bmt-replay-v1",
        "frames": [[0, 255, 0]] * 20,
        "race_proof": {
            "schema": "bmt-race-proof-v1",
            "samples": [[0, 10**400, 0, 0, 0, 0, 0, 0], [20, 0, 0, 0, 0, 0, 0, 0]],
        },
    }
    with TestClient(domain.app, raise_server_exceptions=False) as client:
        reply = client.post(
            "/v1/runs",
            json={"ticket_id": issued["ticket_id"], "replay": replay},
            headers=headers(domain, "Alice"),
        )
    assert reply.status_code == 500, reply.text
    assert reply.text == "Internal Server Error"
    assert "x-request-id" not in reply.headers


def test_optional_ghost_integer_overflow_blocks_valid_verified_result(
    domain, monkeypatch
):
    version, _ = public_course(domain)
    issued = ticket(domain, version, "Alice")
    geometry = {
        "gates": [[1, 0, 0, 0, 1, 0, -1, 1, 0], [-1, 0, 0, 0, 1, 0, -1, 1, 0]],
        "start": [-0.1, 0, 0],
        "creator_start": [-0.1, 0, 0],
        "maximum_speed": {"compact": 1000},
        "extent": [10, 10],
        "manifest": domain.app.state.verifier.validate_track({"shape": "oval"}),
    }
    replay = {
        "schema": "bmt-trajectory-v1",
        "input_count": 10,
        "race_proof": {
            "schema": "bmt-race-path-v1",
            "samples": [
                [tick, -0.1 if tick % 2 == 0 else 0.1, 0, 0] for tick in range(11)
            ],
        },
        "ghost": {
            "ticks": 10,
            "poses": [[0, 10**400, 0, 0, 0, 0, 0], [10, 0, 0, 0, 0, 0]],
        },
    }
    from bmt_backend.trajectory_verifier import check

    assert check(geometry, replay["race_proof"], 10, "compact")["lap_ticks"] == [2] * 5
    accepted = domain.client.post(
        "/v1/runs",
        json={"ticket_id": issued["ticket_id"], "replay": replay},
        headers=headers(domain, "Alice"),
    )
    assert accepted.status_code == 202, accepted.text
    queued = accepted.json()
    adapter = GodotVerifier(domain.app.state.settings)
    monkeypatch.setattr(adapter, "manifest", domain.app.state.verifier.manifest)
    monkeypatch.setattr(adapter, "race_geometry", lambda document: geometry)
    domain.app.state.verifier = adapter
    assert process_one(domain.app)
    with domain.factory() as session:
        run = session.get(Run, queued["run_id"])
        assert run.status == "queued"
        assert run.failure_code == "verifier_unavailable"
    for _ in range(2):
        with domain.factory() as session:
            session.get(Run, queued["run_id"]).lease_until = 0
            session.commit()
        assert process_one(domain.app)
    with domain.factory() as session:
        assert session.get(Run, queued["run_id"]).status == "failed"
    without_ghost = {key: value for key, value in replay.items() if key != "ghost"}
    control = domain.client.post(
        "/v1/runs",
        json={
            "ticket_id": ticket(domain, version, "Bob")["ticket_id"],
            "replay": without_ghost,
        },
        headers=headers(domain, "Bob"),
    )
    assert control.status_code == 202
    assert process_one(domain.app)
    with domain.factory() as session:
        assert session.get(Run, control.json()["run_id"]).status == "verified"


def test_publication_retry_does_not_save_identity_and_reexecutes(
    publications, monkeypatch
):
    domain = publications
    domain.app.state.settings = replace(domain.app.state.settings, max_job_attempts=1)

    def unavailable(*args, **kwargs):
        raise RuntimeError("synthetic dependency failure")

    monkeypatch.setattr(domain.app.state.verifier, "verify_run", unavailable)
    intent = publish_request(domain)
    assert publish_one(domain.app)
    identity = intent["publication_id"]
    auth = headers(domain, key="same-publication-retry-operation")
    path = "/v1/me/publications/" + identity + "/retry"
    assert domain.client.post(path, headers=auth, json={}).json()["state"] == "queued"
    assert publish_one(domain.app)
    assert domain.client.post(path, headers=auth, json={}).json()["state"] == "queued"
    with domain.factory() as session:
        assert session.get(PublicationIntent, identity).attempts == 0
        assert (
            session.scalar(
                select(IdempotencyRecord).where(
                    IdempotencyRecord.key == "same-publication-retry-operation"
                )
            )
            is None
        )


def test_retry_and_finalize_have_opposite_postgres_lock_order(domain, monkeypatch):
    if not domain.postgres:
        pytest.skip("Requires actual PostgreSQL row locks")
    version, _ = public_course(domain)
    queued = submit(domain, ticket(domain, version, "Alice"), "Alice")
    barrier = threading.Barrier(2)
    armed = threading.Event()
    actual = domain.app.state.verifier.verify_run

    def verify(*args, **kwargs):
        result = actual(*args, **kwargs)
        armed.set()
        return result

    monkeypatch.setattr(domain.app.state.verifier, "verify_run", verify)
    observed = set()
    sqlstates = []

    def capture_error(context):
        sqlstates.append(getattr(context.original_exception, "sqlstate", None))

    def after_sql(connection, cursor, sql, params, context, many):
        if not armed.is_set() or "FOR UPDATE" not in sql:
            return
        name = threading.current_thread().name
        lock = (
            "run"
            if name.startswith("review-worker") and "FROM runs" in sql
            else "player"
            if name.startswith("review-retry") and "FROM players" in sql
            else None
        )
        if lock and lock not in observed:
            observed.add(lock)
            barrier.wait(timeout=10)

    event.listen(domain.app.state.engine, "after_cursor_execute", after_sql)
    event.listen(domain.app.state.engine, "handle_error", capture_error)
    try:
        with (
            TestClient(domain.app, raise_server_exceptions=False) as client,
            ThreadPoolExecutor(
                max_workers=1, thread_name_prefix="review-worker"
            ) as workers,
        ):
            job = workers.submit(process_one, domain.app)
            assert armed.wait(10)

            # FastAPI sync endpoints execute on an AnyIO thread. Tag the
            # connection using the Player lock after the armed worker enters finalization.
            def endpoint_sql(connection, cursor, sql, params, context, many):
                if (
                    armed.is_set()
                    and "FOR UPDATE" in sql
                    and "FROM players" in sql
                    and not threading.current_thread().name.startswith("review-worker")
                    and "player" not in observed
                ):
                    observed.add("player")
                    barrier.wait(timeout=10)

            event.listen(domain.app.state.engine, "after_cursor_execute", endpoint_sql)
            try:
                reply = client.post(
                    "/v1/runs/" + queued["run_id"] + "/retry",
                    json={},
                    headers=headers(domain, "Alice"),
                )
                try:
                    job.result(timeout=15)
                    failure = None
                except DBAPIError as exc:
                    failure = getattr(exc.orig, "sqlstate", None)
            finally:
                event.remove(
                    domain.app.state.engine, "after_cursor_execute", endpoint_sql
                )
        assert observed == {"run", "player"}
        assert failure == "40P01" or reply.status_code == 503, (
            failure,
            reply.status_code,
        )
        assert "40P01" in sqlstates
        print("Deadlock SQLSTATE:", sqlstates, "Retry HTTP status:", reply.status_code)
    finally:
        event.remove(domain.app.state.engine, "after_cursor_execute", after_sql)
        event.remove(domain.app.state.engine, "handle_error", capture_error)


def test_interrupted_local_publication_temporary_survives_restart_and_retention(domain):
    root = domain.app.state.blobs.root
    child = subprocess.run(
        [
            sys.executable,
            "-c",
            (
                "import os,sys; from bmt_backend.storage import LocalBlobStore; "
                "store=LocalBlobStore(sys.argv[1]); os.link=lambda *args: os._exit(86); "
                "store.put_json({'interrupted-upload':'saved-evidence'})"
            ),
            str(root),
        ],
        timeout=10,
        check=False,
    )
    assert child.returncode == 86
    pending = list(root.glob("*/.pending-*"))
    assert len(pending) == 1
    from bmt_backend.maintenance import retain
    from bmt_backend.storage import LocalBlobStore
    from bmt_backend.track_models import now

    os.utime(pending[0], (now() - 100 * 86400,) * 2)
    LocalBlobStore(str(root))  # Same initialization on a fresh API/worker process.
    result = retain(domain.factory, domain.app.state.blobs, apply=True, online=True)
    assert result["orphaned_objects"] == 0
    assert pending[0].is_file()


def test_local_archive_and_restore_accept_corrupt_content(tmp_path):
    from bmt_backend.storage import LocalBlobStore

    source, target = tmp_path / "source", tmp_path / "target"
    store = LocalBlobStore(str(source))
    key = store.put_json({"durable": "course"})
    store._path(key).write_bytes(b"corrupt")
    archive_script = PROJECT_ROOT / "backend" / "deploy" / "object_archive.py"
    archived = subprocess.run(
        [sys.executable, str(archive_script), "archive", "--root", str(source)],
        capture_output=True,
        timeout=10,
        check=False,
        env=os.environ | {"BMT_OBJECT_BACKEND": "local"},
    )
    assert archived.returncode == 0, archived.stderr
    restored = subprocess.run(
        [sys.executable, str(archive_script), "restore", "--root", str(target)],
        input=archived.stdout,
        capture_output=True,
        timeout=10,
        check=False,
        env=os.environ | {"BMT_OBJECT_BACKEND": "local"},
    )
    assert restored.returncode == 0, restored.stderr
    with pytest.raises(OSError):
        LocalBlobStore(str(target)).get_json(key)


def test_s3_stream_timeout_bypasses_storage_exception_mapping(monkeypatch):
    from bmt_backend.config import Settings
    from bmt_backend.s3_storage import S3BlobStore
    from urllib3.exceptions import ReadTimeoutError

    settings = Settings(
        object_backend="s3",
        s3_endpoint="https://objects.example",
        s3_bucket="review-bucket",
        s3_access_key="synthetic-access",
        s3_secret_key="synthetic-secret",
    )

    class Response:
        status_code = 200

        def __enter__(self):
            return self

        def __exit__(self, *args):
            pass

        @property
        def raw(self):
            return self

        def read(self, *args, **kwargs):
            raise ReadTimeoutError(None, None, "synthetic stream timeout")

    monkeypatch.setattr(
        "bmt_backend.s3_storage.requests.request", lambda *args, **kwargs: Response()
    )
    with pytest.raises(ReadTimeoutError):
        S3BlobStore(settings).get_json("0" * 64)


def test_actual_worker_kill_recovery_with_current_publication_workflow(review_replicas):
    from types import SimpleNamespace

    replicas = review_replicas
    creator = replica_tests.sign_in(replicas, "Creator")
    content = publication_body(
        SimpleNamespace(
            app=SimpleNamespace(state=SimpleNamespace(verifier=FakeVerifier()))
        )
    )
    requested = replicas.a.client.post(
        "/v1/publications",
        json=content,
        headers=replica_tests.auth(creator, "review-create-publication"),
    )
    assert requested.status_code == 202, requested.text
    replica_tests.worker(replicas)
    published = replicas.b.client.get(
        "/v1/me/publications/" + requested.json()["publication_id"],
        headers=replica_tests.auth(creator),
    ).json()
    assert published["state"] == "published", published
    token = replica_tests.sign_in(replicas, "Restart driver")
    issued = replica_tests.race_ticket(replicas, published["receipt"], token)
    accepted = replicas.b.client.post(
        "/v1/runs",
        json=replica_tests.payload(issued),
        headers=replica_tests.auth(token, "review-worker-kill"),
    )
    assert accepted.status_code == 202, accepted.text
    identity = accepted.json()["run_id"]
    old = replica_tests.worker(replicas, pause=True)
    try:
        deadline = time.monotonic() + 10
        while (
            not Path(str(old.prefix) + ".claimed").exists()
            and time.monotonic() < deadline
            and old.process.poll() is None
        ):
            time.sleep(0.02)
        assert Path(str(old.prefix) + ".claimed").exists()
        with replicas.factory() as session:
            assert session.get(Run, identity).status == "verifying"
        replicas.processes.stop(old, kill=True)
        replica_tests.expire_lease(replicas, identity)
        new = replica_tests.worker(replicas)
        assert new.process.pid != old.process.pid
        replica_tests.one_pb(replicas, token, identity)
        assert (
            replicas.b.client.get(
                "/v1/runs/" + identity, headers=replica_tests.auth(token)
            ).json()["status"]
            == "verified"
        )
    finally:
        replicas.processes.stop(old, kill=True)
