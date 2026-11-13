"""Read current worker code against an owned empty SQLite database; no cloud IO."""
import json
import sys
import time
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "backend/tests")]

from bmt_backend.config import Settings
from bmt_backend.cost_archives import archive_once
from bmt_backend.migrate import upgrade
from bmt_backend.publication_worker import process_job
from bmt_backend.worker import process_worker_job
from bmt_backend.worker_app import create_worker_app
from sqlalchemy import event
from test_domains import FakeVerifier

settings = Settings(environment="test", workload_role="worker", database_url="sqlite://",
    object_dir=str(Path(__file__).parent / "objects"))
app = create_worker_app(settings, verifier=FakeVerifier())
upgrade(app.state.engine)
counts = Counter()
statements = Counter()

def record(_conn, _cursor, statement, _parameters, _context, _many):
    counts[statement.split()[0].lower()] += 1
    statements[statement] += 1

event.listen(app.state.engine, "before_cursor_execute", record)
output = {"database": "empty migrated SQLite in memory", "native_verifier": "test FakeVerifier; no engine started",
    "scope": "statement counts, not production latency, throughput, or bill"}
try:
    process_worker_job(app)
    counts.clear()
    statements.clear()
    started = time.perf_counter()
    for _ in range(100):
        assert process_worker_job(app) is False
    output["competition_100_immediate_empty_scans"] = {"statements": dict(counts), "elapsed_ms": (time.perf_counter()-started)*1000,
        "unique_sql": len(statements), "sql_counts": dict(statements)}
    counts.clear()
    statements.clear()
    for _ in range(100):
        assert process_job(app) is False
    output["publication_100_immediate_empty_scans"] = {"statements": dict(counts), "unique_sql": len(statements), "sql_counts": dict(statements)}
    for kind in ("reward", "retry"):
        counts.clear()
        statements.clear()
        for _ in range(10):
            assert archive_once(app.state.session_factory, app.state.blobs, kind=kind) is False
        output[f"archive_{kind}_10_empty_scans"] = {"statements": dict(counts), "sql_counts": dict(statements)}
finally:
    app.state.engine.dispose()
Path(__file__).with_name("idle_probe_result.json").write_text(json.dumps(output, indent=2), encoding="utf-8")
print(json.dumps({key: {k: v for k, v in value.items() if k != "sql_counts"} if isinstance(value, dict) else value
    for key, value in output.items()}, indent=2))
