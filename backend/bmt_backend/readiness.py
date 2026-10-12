"""Coalesced dependency probes with bounded HTTP waits and one IO thread per API."""
import asyncio
import hashlib
import logging
import threading
import time
import uuid

from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from .migrate import SCHEMA_HEAD
from .storage import canonical_json
from .track_models import OperationState, now

logger = logging.getLogger("bmt.readiness")


class DependencyFailure(Exception):
    def __init__(self, code):
        self.code = code


class ReadinessProbe:
    def __init__(self, app, *, clock=time.monotonic):
        self.app = app
        self.clock = clock
        self.lock = threading.Lock()
        self.pending = None
        self.result = None
        self.expires_at = 0
        self.storage_expires_at = 0
        self.generation = 0
        self.closed = False

    def open(self):
        with self.lock:
            self.closed = False
            self.generation += 1
            self.expires_at = self.storage_expires_at = 0

    def invalidate(self, *, storage=False):
        with self.lock:
            self.generation += 1
            self.expires_at = 0
            if storage:
                self.storage_expires_at = 0

    def _dependencies(self, storage_needed):
        with self.app.state.engine.begin() as connection:
            if connection.dialect.name == "postgresql":
                # Transaction-local; never weaken the application's normal SQL limits.
                connection.execute(text("SELECT set_config('statement_timeout', :timeout, true)"),
                    {"timeout": str(self.app.state.settings.readiness_timeout_seconds * 1000)})
            revision = connection.execute(text("SELECT version_num FROM alembic_version")).scalar()
            if revision != SCHEMA_HEAD:
                raise DependencyFailure("SCHEMA_NOT_READY")
            # A successful schema SELECT does not establish write availability
            # during read-only failover, disk exhaustion or permission changes.
            from sqlalchemy.dialects.postgresql import insert as pg_insert
            from sqlalchemy.dialects.sqlite import insert as sqlite_insert
            insert = sqlite_insert if connection.dialect.name == "sqlite" else pg_insert
            probe = insert(OperationState).values(id="readiness-write",updated_at=now(),details={"schema":revision})
            connection.execute(probe.on_conflict_do_update(index_elements=[OperationState.id],
                set_={"updated_at":probe.excluded.updated_at,"details":probe.excluded.details}))
        if storage_needed:
            blobs = self.app.state.blobs
            # Force an actual create/fsync/read, rather than re-reading the same
            # immutable object forever after storage becomes full/read-only.
            expected = {"storage_probe":"bmt-v1","nonce":uuid.uuid4().hex}
            digest = hashlib.sha256(canonical_json(expected)).hexdigest()
            try:
                if blobs.put_json(expected) != digest or blobs.get_json(digest) != expected:
                    raise DependencyFailure("DEPENDENCY_UNAVAILABLE")
            finally:
                # This unique reserved-format object has no gameplay reference.
                # Cleanup failure never turns failed IO into a successful probe.
                try:
                    blobs.delete(digest)
                except Exception:  # noqa: BLE001 - optional cleanup; age-based GC remains available
                    logger.warning("readiness_object_cleanup_failed")
                release = getattr(blobs,"release_probe_pin",None)
                if release:
                    try:
                        release(digest)
                    except Exception:  # noqa: BLE001 - failed DB cleanup is recovered by pin expiry
                        logger.warning("readiness_pin_cleanup_failed")
        return {"status": "ready", "schema": revision}

    def _run(self, job, storage_needed):
        try:
            result, code = self._dependencies(storage_needed), None
        except DependencyFailure as error:
            result, code = None, error.code
        except (SQLAlchemyError, OSError, ValueError):
            result, code = None, "DEPENDENCY_UNAVAILABLE"
        except Exception:  # noqa: BLE001 - probes fail closed without exposing provider/credential details
            result, code = None, "DEPENDENCY_UNAVAILABLE"
        with self.lock:
            current = self.clock()
            if job["generation"] == self.generation and not self.closed:
                if current >= job["deadline"]:
                    result, code = None, "DEPENDENCY_TIMEOUT"
                self.result = (result, code)
                # Failures have a short retry interval; late success never turns a timeout green.
                self.expires_at = current + (1 if code else self.app.state.settings.readiness_cache_seconds)
                if result and storage_needed:
                    self.storage_expires_at = current + self.app.state.settings.readiness_storage_cache_seconds
                if not code:
                    # Schema-only refreshes must never extend the deep-storage freshness window.
                    self.expires_at = min(self.expires_at, self.storage_expires_at)
            self.pending = None

    async def check(self):
        request_deadline = self.clock() + self.app.state.settings.readiness_timeout_seconds
        while True:
            with self.lock:
                current = self.clock()
                if self.closed:
                    raise DependencyFailure("DEPENDENCY_UNAVAILABLE")
                if current >= request_deadline:
                    raise DependencyFailure("DEPENDENCY_TIMEOUT")
                if current < self.expires_at and self.result is not None:
                    result, code = self.result
                    if code:
                        raise DependencyFailure(code)
                    return dict(result)
                if self.pending is None:
                    job = {"generation": self.generation,
                        "deadline": current + self.app.state.settings.readiness_timeout_seconds}
                    self.pending = job
                    storage_needed = current >= self.storage_expires_at
                    thread = threading.Thread(target=self._run, args=(job, storage_needed),
                        name="bmt-readiness", daemon=True)
                    try:
                        thread.start()
                    except RuntimeError:
                        self.pending = None
                        raise DependencyFailure("DEPENDENCY_UNAVAILABLE") from None
                if current >= self.pending["deadline"]:
                    raise DependencyFailure("DEPENDENCY_TIMEOUT")
            # Async handlers do not occupy the server's request-thread pool while waiting.
            await asyncio.sleep(0.01)

    async def close(self):
        with self.lock:
            self.closed = True
            self.generation += 1
            deadline = self.clock() + self.app.state.settings.readiness_timeout_seconds
        while True:
            with self.lock:
                if self.pending is None or self.clock() >= deadline:
                    return
            await asyncio.sleep(0.01)
