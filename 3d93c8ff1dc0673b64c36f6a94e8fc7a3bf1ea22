"""Measure the current retention receipt predicate on synthetic isolated SQLite."""
import json
import statistics
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path[:0] = [str(ROOT / "backend")]
from sqlalchemy import insert, or_, update
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.track_models import IdempotencyRecord
from bmt_backend.worker_app import create_worker_app

app = create_worker_app(Settings(environment="test", workload_role="worker", database_url="sqlite://",
    object_dir=str(Path(__file__).parent / "objects")), verifier=object())
upgrade(app.state.engine)
with app.state.session_factory() as db:
    db.add(Player(id="synthetic-owner", display_name="Synthetic owner"))
    db.commit()
statement = update(IdempotencyRecord).where(or_(
    IdempotencyRecord.response["run_id"].as_string().in_({"retired-run"}),
    IdempotencyRecord.response["ticket_id"].as_string().in_({"retired-ticket"}),
    IdempotencyRecord.response["race_id"].as_string().in_({"retired-race"}),
    IdempotencyRecord.response["receipt_id"].as_string().in_({"retired-receipt"}),
)).values(response={"retired": True})
compiled = statement.compile(app.state.engine)
params = compiled.construct_params()
# Execute the identical expression predicate as a SELECT for an EXPLAIN with
# bound JSON paths/IDs, keeping JSON value adaptation within SQLAlchemy.
results = []
previous = 0
try:
    for size in (1000, 10000, 100000):
        with app.state.engine.begin() as conn:
            for start in range(previous, size, 1000):
                conn.execute(insert(IdempotencyRecord), [{"player_id":"synthetic-owner", "scope":"run",
                    "key":str(index), "request_hash":"0"*64, "response":{"run_id":"retired-run" if index == 0 else str(index),
                    "ticket_id": "ticket-"+str(index), "status":"verified"}, "created_at":1, "archive_key":""}
                    for index in range(start, min(size, start+1000))])
        previous = size
        elapsed = []
        for _ in range(5):
            with app.state.engine.connect() as conn:
                transaction = conn.begin()
                begin = time.perf_counter()
                result = conn.execute(statement)
                elapsed.append((time.perf_counter()-begin)*1000)
                assert result.rowcount == 1
                transaction.rollback()
        results.append({"history_rows":size, "changed_rows":1, "median_ms":statistics.median(elapsed), "samples_ms":elapsed})
    with app.state.engine.connect() as conn:
        plan = conn.exec_driver_sql("EXPLAIN QUERY PLAN UPDATE domain_idempotency SET response = ? WHERE "
            "JSON_EXTRACT(response, '$.run_id') IN (?) OR JSON_EXTRACT(response, '$.ticket_id') IN (?) OR "
            "JSON_EXTRACT(response, '$.race_id') IN (?) OR JSON_EXTRACT(response, '$.receipt_id') IN (?)",
            ('{"retired":true}', 'retired-run','retired-ticket','retired-race','retired-receipt')).all()
    output = {"scope":"current retention JSON-reference predicate; synthetic in-memory SQLite, not PostgreSQL/live latency",
        "measurements":results, "query_plan":[list(row) for row in plan]}
    Path(__file__).with_name("retention_scan_probe_result.json").write_text(json.dumps(output, indent=2), encoding="utf-8")
    print(json.dumps(output, indent=2))
finally:
    app.state.engine.dispose()
