"""Test-only API/worker processes; never copied into the deployment image."""
import json
import sys
import threading
import time
from contextlib import ExitStack
from pathlib import Path

import uvicorn
from fastapi import HTTPException
from sqlalchemy import event, text
from sqlalchemy.exc import OperationalError
from test_domains import FakeVerifier

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.worker import process_one, process_worker_job
from bmt_backend.worker_lifecycle import run_worker


class FixtureIdentity:
    def verify(self, token):
        try:
            claims = json.loads(token)
            if claims["iss"] == "isolated-test-fixture" and isinstance(claims["sub"], str):
                return claims
        except (ValueError, KeyError, TypeError):
            pass
        raise HTTPException(401, "INVALID_FIXTURE_IDENTITY")


class FaultStore:
    def __init__(self, delegate, marker):
        self.delegate, self.marker = delegate, Path(marker)

    def __getattr__(self, name):
        return getattr(self.delegate, name)

    def mode(self):
        try:
            mode = self.marker.read_text()
        except FileNotFoundError:
            return ""
        while mode == "stall":
            Path(str(self.marker) + ".stalled").touch()
            threading.Event().wait(0.02)
            try:
                mode = self.marker.read_text()
            except FileNotFoundError:
                return ""
        return mode

    def put_json(self, value):
        mode = self.mode()
        if mode == "publication_barrier":
            Path(str(self.marker) + ".arrived").touch()
            deadline = time.monotonic() + 5
            while not Path(str(self.marker) + ".release").exists():
                if time.monotonic() >= deadline:
                    raise OSError("Fixture publication barrier timed out")
                threading.Event().wait(0.01)
        if mode in ("write", "all"):
            raise OSError("Injected object publication failure")
        digest = self.delegate.put_json(value)
        if mode == "write_after":
            raise OSError("Injected lost object publication acknowledgement")
        return digest

    def get_json(self, digest):
        if self.mode() in ("read", "all"):
            raise OSError("Injected object read failure")
        return self.delegate.get_json(digest)


def main(config_path):
    config = json.loads(Path(config_path).read_text())
    settings = Settings(**config["settings"])
    prefix = Path(config["prefix"])
    class ControlledVerifier(FakeVerifier):
        def verify_run(self, *args, **kwargs):
            if config.get("pause"):
                Path(str(prefix) + ".claimed").touch()
                if engine.dialect.name == "postgresql":
                    with engine.connect() as connection:
                        pid = connection.scalar(text("SELECT pg_backend_pid()"))
                    Path(str(prefix) + ".backend-pid").write_text(str(pid))
                while not Path(str(prefix) + ".release").exists():
                    threading.Event().wait(0.02)
            result = super().verify_run(*args, **kwargs)
            if config.get("pause"):
                # Make stale output observably different so PB upsert alone cannot hide a broken fence.
                result = {**result, "time_ticks": 5, "lap_ticks": [1] * 5}
            return result
    engine = make_engine(settings.database_url, settings, schema=config.get("schema", ""))
    app = create_app(settings, engine=engine, verifier=ControlledVerifier(), identity_verifier=FixtureIdentity())
    app.state.blobs = FaultStore(app.state.blobs, str(prefix) + ".fault")
    if config["role"] == "api":
        @app.get("/__fixture/pool-timeouts")
        def pool_timeouts():
            with ExitStack() as stack:
                connections = [stack.enter_context(engine.connect()) for _ in range(settings.database_pool_size)]
                return [int(c.execute(text("SELECT extract(epoch from current_setting('statement_timeout')::interval) * 1000")).scalar())
                    for c in connections]
        @app.get("/__fixture/invalidate-readiness")
        def invalidate_readiness():
            app.state.readiness.invalidate(storage=True)
            return {"invalidated": True}
        @app.get("/__fixture/probe-threads")
        def probe_threads():
            return {"count": sum(t.name == "bmt-readiness" for t in threading.enumerate())}
        try:
            uvicorn.run(app, host="127.0.0.1", port=config["port"], log_level="warning",
                access_log=False, timeout_graceful_shutdown=5)
        finally:
            engine.dispose()
        return
    if config.get("finalize_failure"):
        def fault(_conn, _cursor, statement, parameters, _context, _many):
            if statement.startswith("UPDATE runs SET") and "verified" in str(parameters):
                raise OperationalError("Injected finalization failure", {}, Exception("disposable fault"))
        event.listen(engine, "before_cursor_execute", fault)
    run_worker(app, process_worker_job if config.get("continuous") else process_one, once=not config.get("continuous",False))


if __name__ == "__main__":
    main(sys.argv[1])
