"""BR01-BR06: acceptance, concurrency, immutable retries and safe recovery."""

import logging
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
from sqlalchemy.exc import OperationalError

PROJECT_ROOT = next(
    parent for parent in Path(__file__).resolve().parents if (parent / "backend" / "pyproject.toml").is_file()
)
import test_replica_failures as replica_tests
from test_domains import FakeVerifier, headers, public_course, submit, ticket
from test_domains import domain as domain_fixture
from test_publication_intents import body as publication_body
from test_publication_intents import publications as publications_fixture
from test_publication_intents import request as publish_request

from bmt_backend.publication_models import PublicationIntent
from bmt_backend.publications import process_one as publish_one
from bmt_backend.track_models import IdempotencyRecord, Run
from bmt_backend.verifier import GodotVerifier
from bmt_backend.worker import process_one

domain = domain_fixture
publications = publications_fixture


@pytest.fixture(params=["sqlite", "postgres"])
def review_replicas(tmp_path, request, monkeypatch):
    if request.param == "postgres" and not os.environ.get("BMT_TEST_DATABASE_URL"):
        config = PROJECT_ROOT / ".tools" / "backend-postgres.env"
        if not config.is_file():
            pytest.skip("Set BMT_TEST_DATABASE_URL to a disposable PostgreSQL database")
        url = next(
            line.split("=", 1)[1].strip()
            for line in config.read_text().splitlines()
            if line.startswith("BMT_TEST_DATABASE_URL=")
        )
        monkeypatch.setenv("BMT_TEST_DATABASE_URL", url)
    yield from replica_tests.replicas.__wrapped__(tmp_path, request)


def test_large_integer_movement_proof_is_invalid_input(domain):
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
    assert reply.status_code == 422, reply.text
    assert "movement sample" in reply.json()["detail"]
    assert reply.headers["x-request-id"]


@pytest.mark.parametrize("coordinate", [10**400, 1e300, -1e300])
def test_optional_ghost_integer_overflow_preserves_valid_verified_result(domain, monkeypatch, coordinate):
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
            "samples": [[tick, -0.1 if tick % 2 == 0 else 0.1, 0, 0] for tick in range(11)],
        },
        "ghost": {
            "ticks": 10,
            "poses": [[0, coordinate, 0, 0, 0, 0, 0], [10, 0, 0, 0, 0, 0]],
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
        assert run.status == "verified"
        assert run.failure_code is None and run.ghost_hash is None
        assert run.attempts == 1 and run.time_ticks == 10
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


def test_publication_retry_saves_identity_without_reexecuting(publications, monkeypatch):
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
    first = domain.client.post(path, headers=auth, json={})
    assert first.status_code == 200 and first.json()["state"] == "queued"
    assert publish_one(domain.app)
    assert domain.client.post(path, headers=auth, json={}).json() == first.json()
    with domain.factory() as session:
        row = session.get(PublicationIntent, identity)
        assert row.status == "failed" and row.attempts == 1
        assert (
            session.scalar(
                select(IdempotencyRecord).where(IdempotencyRecord.key == "same-publication-retry-operation")
            )
            is not None
        )


def test_retry_and_finalize_complete_concurrently_without_deadlock(domain, monkeypatch):
    if not domain.postgres:
        pytest.skip("Requires actual PostgreSQL row locks")
    version, _ = public_course(domain)
    queued = submit(domain, ticket(domain, version, "Alice"), "Alice")
    armed = threading.Event()
    locked, release, retry_attempted, retry_locked = (threading.Event() for _ in range(4))
    actual = domain.app.state.verifier.verify_run

    def verify(*args, **kwargs):
        result = actual(*args, **kwargs)
        armed.set()
        return result

    monkeypatch.setattr(domain.app.state.verifier, "verify_run", verify)
    sqlstates = []

    def capture_error(context):
        sqlstates.append(getattr(context.original_exception, "sqlstate", None))

    def before_sql(connection, cursor, sql, params, context, many):
        if (
            armed.is_set()
            and "FOR UPDATE" in sql
            and "FROM players" in sql
            and not threading.current_thread().name.startswith("review-worker")
        ):
            retry_attempted.set()

    def after_sql(connection, cursor, sql, params, context, many):
        if armed.is_set() and "FOR UPDATE" in sql:
            if threading.current_thread().name.startswith("review-worker") and not locked.is_set():
                locked.set()
                assert release.wait(10)
            elif "FROM players" in sql:
                retry_locked.set()

    event.listen(domain.app.state.engine, "after_cursor_execute", after_sql)
    event.listen(domain.app.state.engine, "before_cursor_execute", before_sql)
    event.listen(domain.app.state.engine, "handle_error", capture_error)
    try:
        with (
            TestClient(domain.app, raise_server_exceptions=False) as client,
            ThreadPoolExecutor(max_workers=1, thread_name_prefix="review-worker") as workers,
            ThreadPoolExecutor(max_workers=1) as callers,
        ):
            job = workers.submit(process_one, domain.app)
            assert locked.wait(10)
            try:
                retry = callers.submit(
                    client.post,
                    "/v1/runs/" + queued["run_id"] + "/retry",
                    json={},
                    headers=headers(domain, "Alice"),
                )
                assert retry_attempted.wait(10)
                # With the old Run -> Player order the retry can hold Player
                # here; releasing the worker then creates the actual SQL cycle.
                retry_locked.wait(0.1)
            finally:
                release.set()
            assert job.result(timeout=15)
            assert retry.result(timeout=15).status_code == 200
        assert not sqlstates
        with domain.factory() as session:
            assert session.get(Run, queued["run_id"]).status == "verified"
    finally:
        release.set()
        event.remove(domain.app.state.engine, "after_cursor_execute", after_sql)
        event.remove(domain.app.state.engine, "before_cursor_execute", before_sql)
        event.remove(domain.app.state.engine, "handle_error", capture_error)


def test_interrupted_local_publication_temporary_is_reclaimed_by_retention(domain):
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
    pending = [path for path in root.glob("*/.pending-*") if not path.name.endswith(".guard")]
    assert len(pending) == 1
    from bmt_backend.maintenance import retain
    from bmt_backend.track_models import now

    os.utime(pending[0], (now() - 100 * 86400,) * 2)
    result = retain(domain.factory, domain.app.state.blobs, apply=True, online=True)
    assert result["orphaned_objects"] == 0
    assert result["temporary_files"] == 2
    assert not pending[0].exists()
    assert not list(root.glob("*/.pending-*"))


def test_store_restart_reclaims_an_aged_interrupted_upload(tmp_path):
    from bmt_backend.storage import LocalBlobStore

    root = tmp_path / "objects"
    child = subprocess.run(
        [
            sys.executable,
            "-c",
            (
                "import os,sys; from bmt_backend.storage import LocalBlobStore; "
                "store=LocalBlobStore(sys.argv[1]); os.link=lambda *args: os._exit(86); "
                "store.put_json({'interrupted':'restart'})"
            ),
            str(root),
        ],
        timeout=10,
        check=False,
    )
    assert child.returncode == 86
    pending = next(path for path in root.glob("*/.pending-*") if not path.name.endswith(".guard"))
    os.utime(pending, (time.time() - 100 * 86400,) * 2)
    LocalBlobStore(str(root))
    assert not list(root.glob("*/.pending-*"))


def test_local_archive_and_restore_refuse_corrupt_content(tmp_path):
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
    assert archived.returncode != 0 and b"integrity" in archived.stderr
    import io
    import tarfile

    content = io.BytesIO()
    with tarfile.open(fileobj=content, mode="w") as tar:
        entry = tarfile.TarInfo(key[:2] + "/" + key + ".json")
        entry.size = 7
        tar.addfile(entry, io.BytesIO(b"corrupt"))
    restored = subprocess.run(
        [sys.executable, str(archive_script), "restore", "--root", str(target)],
        input=content.getvalue(),
        capture_output=True,
        timeout=10,
        check=False,
        env=os.environ | {"BMT_OBJECT_BACKEND": "local"},
    )
    assert restored.returncode != 0 and b"integrity" in restored.stderr
    assert not LocalBlobStore(str(target))._path(key).exists()


@pytest.mark.parametrize("stream_error", ["timeout", "protocol"])
def test_s3_stream_timeout_is_normalized_to_storage_failure(monkeypatch, auth_app, stream_error):
    from urllib3.exceptions import ProtocolError, ReadTimeoutError

    from bmt_backend.config import Settings
    from bmt_backend.s3_storage import S3BlobStore

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
            if stream_error == "timeout":
                raise ReadTimeoutError(None, None, "private stream timeout")
            raise ProtocolError("private interrupted stream")

    monkeypatch.setattr("bmt_backend.s3_storage.requests.request", lambda *args, **kwargs: Response())
    with pytest.raises(OSError, match="Object service unavailable"):
        S3BlobStore(settings).get_json("0" * 64)
    adapter = S3BlobStore(settings)

    @auth_app.get("/v1/robustness-storage")
    def read_storage():
        return adapter.get_json("0" * 64)

    with TestClient(auth_app, raise_server_exceptions=False) as client:
        auth_app.state.readiness.storage_expires_at = time.monotonic() + 60
        response = client.get("/v1/robustness-storage")
        assert response.status_code == 503 and response.json()["detail"] == "STORAGE_UNAVAILABLE"
        assert response.json()["request_id"] == response.headers["x-request-id"]
        assert response.headers["retry-after"] == "5"
        assert auth_app.state.readiness.storage_expires_at == 0
        assert "private" not in response.text


def test_actual_worker_kill_recovery_with_current_publication_workflow(review_replicas):
    from types import SimpleNamespace

    replicas = review_replicas
    creator = replica_tests.sign_in(replicas, "Creator")
    content = publication_body(
        SimpleNamespace(app=SimpleNamespace(state=SimpleNamespace(verifier=FakeVerifier())))
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
            replicas.b.client.get("/v1/runs/" + identity, headers=replica_tests.auth(token)).json()["status"]
            == "verified"
        )
    finally:
        replicas.processes.stop(old, kill=True)


def test_publication_retry_key_cannot_target_another_intent(publications, monkeypatch):
    monkeypatch.setattr(
        publications.app.state.verifier,
        "verify_run",
        lambda *args, **kwargs: (_ for _ in ()).throw(RuntimeError("unavailable")),
    )
    first = publish_request(publications)
    second = publish_request(publications, publication_body(publications, id="another_local_document"))
    for identity in (first["publication_id"], second["publication_id"]):
        with publications.factory() as session:
            row = session.get(PublicationIntent, identity)
            row.status, row.failure_code = "failed", "validator_unavailable"
            session.commit()
    auth = headers(publications, key="bound-publication-retry")
    assert (
        publications.client.post(
            "/v1/me/publications/" + first["publication_id"] + "/retry", headers=auth
        ).status_code
        == 200
    )
    assert (
        publications.client.post(
            "/v1/me/publications/" + second["publication_id"] + "/retry", headers=auth
        ).status_code
        == 409
    )
    with publications.factory() as session:
        assert session.get(PublicationIntent, second["publication_id"]).status == "failed"


def test_concurrent_publication_retry_has_one_durable_receipt(review_replicas):
    from types import SimpleNamespace

    replicas = review_replicas
    creator = replica_tests.sign_in(replicas, "Creator")
    content = publication_body(
        SimpleNamespace(app=SimpleNamespace(state=SimpleNamespace(verifier=FakeVerifier())))
    )
    created_reply = replicas.a.client.post(
        "/v1/publications", json=content, headers=replica_tests.auth(creator, "concurrent-publication-source")
    )
    assert created_reply.status_code == 202
    created = created_reply.json()
    with replicas.factory() as session:
        row = session.get(PublicationIntent, created["publication_id"])
        row.status, row.failure_code, row.attempts = "failed", "validator_unavailable", 3
        session.commit()
    auth = replica_tests.auth(creator, "concurrent-publication-retry")
    path = "/v1/me/publications/" + created["publication_id"] + "/retry"
    with ThreadPoolExecutor(max_workers=4) as pool:
        replies = list(pool.map(lambda _: replicas.a.client.post(path, headers=auth), range(4)))
    assert all(reply.status_code == 200 for reply in replies)
    assert all(reply.json() == replies[0].json() for reply in replies)
    with replicas.factory() as session:
        assert (
            len(
                session.scalars(
                    select(IdempotencyRecord).where(IdempotencyRecord.key == "concurrent-publication-retry")
                ).all()
            )
            == 1
        )


def test_retention_preserves_an_aged_active_upload(domain):
    root = domain.app.state.blobs.root
    ready, release = root.parent / "active-ready", root.parent / "active-release"
    program = (
        "import os,sys,time; from pathlib import Path; from bmt_backend.storage import LocalBlobStore; "
        "real=os.link\n"
        "def pause(*args):\n"
        " Path(sys.argv[2]).touch()\n"
        " while not Path(sys.argv[3]).exists(): time.sleep(0.01)\n"
        " return real(*args)\n"
        "os.link=pause\n"
        "LocalBlobStore(sys.argv[1]).put_json({'active':'immutable'})\n"
    )
    child = subprocess.Popen(
        [sys.executable, "-c", program, str(root), str(ready), str(release)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
    )
    try:
        deadline = time.monotonic() + 10
        while not ready.exists() and child.poll() is None and time.monotonic() < deadline:
            time.sleep(0.02)
        assert ready.exists()
        pending = next(path for path in root.glob("*/.pending-*") if not path.name.endswith(".guard"))
        from bmt_backend.maintenance import retain
        from bmt_backend.track_models import now

        os.utime(pending, (now() - 100 * 86400,) * 2)
        result = retain(domain.factory, domain.app.state.blobs, apply=True, online=True)
        assert result["temporary_files"] == 0 and pending.exists()
        release.touch()
        assert child.wait(timeout=10) == 0
        assert not list(root.glob("*/.pending-*"))
    finally:
        release.touch()
        if child.poll() is None:
            child.kill()
        child.wait(timeout=10)
        child.stderr.close()


def test_unguarded_legacy_temporary_requires_offline_cleanup(domain):
    from bmt_backend.maintenance import retain
    from bmt_backend.track_models import now

    directory = domain.app.state.blobs.root / "00"
    directory.mkdir()
    pending = directory / ".pending-legacy"
    pending.write_bytes(b"interrupted")
    os.utime(pending, (now() - 100 * 86400,) * 2)
    assert retain(domain.factory, domain.app.state.blobs, apply=True, online=True)["temporary_files"] == 0
    assert pending.exists()
    assert retain(domain.factory, domain.app.state.blobs, apply=True, offline=True)["temporary_files"] == 1
    assert not pending.exists()


def test_temporary_cleanup_is_bounded_and_keeps_young_uploads(domain):
    from bmt_backend.maintenance import retain
    from bmt_backend.track_models import now

    directory = domain.app.state.blobs.root / "00"
    directory.mkdir()
    for index in range(11):
        data = directory / f".pending-old{index:06d}"
        data.write_bytes(b"saved")
        data.with_name(data.name + ".guard").write_bytes(b"0")
        os.utime(data, (now() - 100 * 86400,) * 2)
    young = directory / ".pending-young000"
    young.write_bytes(b"active")
    young.with_name(young.name + ".guard").write_bytes(b"0")
    cursor, removed = None, 0
    for _ in range(30):
        result = retain(
            domain.factory,
            domain.app.state.blobs,
            apply=True,
            online=True,
            scan_limit=3,
            object_cursor=cursor,
        )
        assert result["objects_inspected"] <= 3
        removed += result["temporary_files"]
        cursor = result["next_object_cursor"]
        if cursor is None:
            break
    assert cursor is None and removed == 22
    assert young.exists() and young.with_name(young.name + ".guard").exists()
    assert len(list(directory.iterdir())) == 2


def test_unexpected_errors_and_dependency_errors_are_private_and_correlated(auth_app):
    from bmt_backend.observability import JsonFormatter

    captured = []
    handler = logging.Handler()
    handler.emit = lambda record: captured.append(JsonFormatter().format(record))
    logging.getLogger("bmt").addHandler(handler)

    @auth_app.get("/v1/robustness-unexpected")
    def unexpected():
        raise RuntimeError("private credential in an unexpected exception")

    @auth_app.get("/v1/robustness-database")
    def database():
        class Cause(Exception):
            sqlstate = "08006"

        raise OperationalError("private SQL", {}, Cause("private password"))

    try:
        with TestClient(auth_app, raise_server_exceptions=False) as client:
            unknown = client.get("/v1/robustness-unexpected")
            assert unknown.status_code == 500 and unknown.json()["detail"] == "INTERNAL_ERROR"
            assert unknown.json()["request_id"] == unknown.headers["x-request-id"]
            database = client.get("/v1/robustness-database")
            assert database.status_code == 503 and database.headers["retry-after"] == "5"
            assert database.json()["request_id"] == database.headers["x-request-id"]
        assert all("private" not in entry for entry in captured)
        assert any(
            '"sqlstate":"08006"' in entry and database.headers["x-request-id"] in entry for entry in captured
        )
    finally:
        logging.getLogger("bmt").removeHandler(handler)


@pytest.mark.parametrize("failure", ["disk", "size", "database"])
def test_optional_ghost_storage_failure_preserves_race_proof(domain, monkeypatch, failure):
    version, _ = public_course(domain)
    queued = submit(domain, ticket(domain, version, "Alice"), "Alice")
    actual = domain.app.state.verifier.verify_run

    def with_ghost(*args, **kwargs):
        result = actual(*args, **kwargs)
        result["ghost"] = {
            "ticks": result["time_ticks"],
            "poses": [[0, 0, 0, 0, 0, 0, 0], [result["time_ticks"], 0, 0, 0, 0, 0, 0]],
        }
        return result

    def unavailable(_ghost):
        if failure == "database":
            raise OperationalError("synthetic object pin failure", {}, Exception("unavailable"))
        if failure == "size":
            raise ValueError("Object exceeds limit")
        raise OSError("Disk unavailable")

    monkeypatch.setattr(domain.app.state.verifier, "verify_run", with_ghost)
    monkeypatch.setattr(domain.app.state.blobs, "put_json", unavailable)
    assert process_one(domain.app)
    with domain.factory() as session:
        run = session.get(Run, queued["run_id"])
        assert run.status == "verified" and run.time_ticks == 100
        assert run.ghost_hash is None and run.attempts == 1
