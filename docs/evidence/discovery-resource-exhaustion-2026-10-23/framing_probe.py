"""Owned loopback Uvicorn/h11 framing probe against a disposable empty app."""
import hashlib
import importlib.metadata
import json
import socket
import sys
import tempfile
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FOLDER = Path(__file__).parent
sys.path.insert(0, str(ROOT / "backend"))

import uvicorn
from sqlalchemy import event

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.discovery_projection import settle_for_diagnostics
from bmt_backend.middleware import RequestBoundary
from bmt_backend.migrate import upgrade


def boundary(app):
    current = app.middleware_stack
    while current is not None:
        if isinstance(current, RequestBoundary):
            return current
        current = getattr(current, "app", None)
    raise AssertionError("RequestBoundary missing")


def main():
    middleware_source = ROOT / "backend/bmt_backend/middleware.py"
    source_before = hashlib.sha256(middleware_source.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="bmt-framing-review-") as folder:
        settings = Settings(database_url="sqlite:///" + (Path(folder) / "review.sqlite").as_posix(),
                            object_dir=str(Path(folder) / "objects"), google_client_ids=("review",))
        app = create_app(settings)
        upgrade(app.state.engine)
        settle_for_diagnostics(app.state.session_factory)
        held = []

        def capture(_connection, _cursor, sql, *_args):
            if sql.lstrip().upper().startswith("SELECT") and "discovery_partitions" in sql:
                value = boundary(app)
                held.append({"small_slots_available": value.discovery_small_parsers._value,
                             "large_slots_available": value.discovery_parsers._value})

        event.listen(app.state.engine, "before_cursor_execute", capture)
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
        config = uvicorn.Config(app, host="127.0.0.1", port=port, http="h11", lifespan="off",
                                log_level="error", access_log=False, timeout_keep_alive=1)
        server = uvicorn.Server(config)
        runner = threading.Thread(target=server.run, kwargs={"sockets": [listener]}, daemon=True)
        runner.start()
        try:
            deadline = time.monotonic() + 5
            while not server.started and runner.is_alive() and time.monotonic() < deadline:
                time.sleep(0.01)
            assert server.started, "Owned loopback server failed to start"
            body = json.dumps({"query": {"ids": [f"review-{i:05}" for i in range(5000)]}}, separators=(",", ":")).encode()
            assert 16384 < len(body) < 100000
            results = []
            for name, extra in [("honest_content_length", f"Content-Length: {len(body)}\r\n".encode()),
                                ("chunked_without_content_length", b"Transfer-Encoding: chunked\r\n"),
                                ("chunked_with_short_content_length", b"Content-Length: 2\r\nTransfer-Encoding: chunked\r\n")]:
                chunked = b"Transfer-Encoding" in extra
                payload = hex(len(body))[2:].encode() + b"\r\n" + body + b"\r\n0\r\n\r\n" if chunked else body
                request = (b"POST /v1/discovery/v3/tracks HTTP/1.1\r\nHost: localhost\r\n"
                           b"Content-Type: application/json\r\nConnection: close\r\n" + extra + b"\r\n" + payload)
                start = len(held)
                with socket.create_connection(("127.0.0.1", port), timeout=5) as client:
                    client.settimeout(5)
                    client.sendall(request)
                    response = bytearray()
                    while True:
                        packet = client.recv(65536)
                        if not packet:
                            break
                        response.extend(packet)
                status_line = bytes(response).split(b"\r\n", 1)[0].decode()
                results.append({"case": name, "actual_body_bytes": len(body), "status_line": status_line,
                                "query_stage_pool_samples": held[start:]})
        finally:
            server.should_exit = True
            runner.join(5)
            listener.close()
            event.remove(app.state.engine, "before_cursor_execute", capture)
            app.state.engine.dispose()
            assert not runner.is_alive(), "Owned server did not stop"
    result = {"scope": "Real loopback TCP/HTTP through local Uvicorn h11 and the actual FastAPI application; temporary SQLite and synthetic unknown IDs only",
        "uvicorn": importlib.metadata.version("uvicorn"), "h11": importlib.metadata.version("h11"),
        "source_before": source_before, "source_after": hashlib.sha256(middleware_source.read_bytes()).hexdigest(),
        "cases": results, "cloud_ingress": "Not tested; an upstream proxy may reject ambiguous framing before it reaches the app"}
    (FOLDER / "framing-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("FRAMING_REVIEW_RESULT " + json.dumps(result))


if __name__ == "__main__":
    main()
