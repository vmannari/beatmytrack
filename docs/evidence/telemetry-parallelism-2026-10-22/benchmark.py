"""Small disposable-schema diagnostic, not a production capacity qualification."""
import json
import os
import statistics
import subprocess
import sys
import time
from pathlib import Path
from uuid import uuid4

from bmt_backend.db import make_engine, make_session_factory
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.quality_models import QualityFact
from bmt_backend.telemetry_models import ProductEvent, ProductMetric, ProductProfile
from bmt_backend.telemetry_processing import publish
from bmt_backend.telemetry_queue import activate, register_ids
from bmt_backend.telemetry_queue_models import TelemetryCredit
from bmt_backend.track_models import now
from sqlalchemy import create_engine, func, select, text
from sqlalchemy.engine import make_url

lines = Path("/task/db.env").read_text().splitlines()
raw = next(line.split("=", 1)[1].strip() for line in lines if line.startswith("BMT_TEST_DATABASE_URL="))
url = make_url(raw).set(host="127.0.0.1", port=5432).render_as_string(hide_password=False)
admin = create_engine(url, hide_parameters=True)
results = []
try:
    for kind in ("uniform", "one_shared_context"):
        for workers in (1, 4):
            schema = "bmt_load_" + uuid4().hex
            with admin.begin() as db:
                db.execute(text(f"CREATE SCHEMA {schema}"))
            engine = make_engine(url, schema=schema)
            factory = make_session_factory(engine)
            try:
                upgrade(engine)
                stamp, count = now(), int(os.environ.get("TELEMETRY_BENCH_EVENTS", "4000"))
                players = [str(uuid4()) for _ in range(1000)]
                with factory() as db:
                    db.execute(Player.__table__.insert(), [{"id": identity, "display_name": identity,
                               "needs_username": True} for identity in players])
                    activate(db)
                    db.commit()
                name = "menu_ready" if kind == "uniform" else "process_exit"
                for offset in range(0, count, 500):
                    values = [{"id": str(uuid4()), "player_id": players[index % len(players)],
                               "source": "client", "name": name, "is_test_driver": False,
                               "occurred_at": stamp, "received_at": stamp, "payload_hash": "benchmark",
                               "properties": {} if kind == "uniform" else
                                   {"exit_reason": 4, "device_class": "desktop"}}
                              for index in range(offset, min(offset + 500, count))]
                    with factory() as db:
                        db.execute(ProductEvent.__table__.insert(), values)
                        register_ids(db, [row["id"] for row in values])
                        db.commit()
                children = []
                env = {**os.environ, "TELEMETRY_TEST_URL": url,
                       "TELEMETRY_TEST_OPTIONS": f"-c search_path={schema} -c statement_timeout=15000"}
                for _index in range(workers):
                    children.append(subprocess.Popen([sys.executable, "/evidence/benchmark_worker.py"],
                        env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True))
                for child in children:
                    assert child.stdout.readline().strip() == "READY"
                with engine.connect() as db:
                    wal_start = db.scalar(text("SELECT pg_current_wal_insert_lsn()"))
                started = time.perf_counter()
                for child in children:
                    child.stdin.write("GO\n")
                    child.stdin.flush()
                measurements = []
                try:
                    for child in children:
                        output, errors = child.communicate(timeout=120)
                        assert child.returncode == 0, errors[-1000:]
                        measurements.append(json.loads(output.strip()))
                finally:
                    for child in children:
                        if child.poll() is None:
                            child.kill()
                            child.communicate(timeout=10)
                processed = sum(row["processed"] for row in measurements)
                durations = [value for row in measurements for value in row["durations"]]
                publish(factory, stamp)
                total_seconds = time.perf_counter() - started
                with factory() as db:
                    used = db.scalar(select(func.sum(TelemetryCredit.capacity - TelemetryCredit.free)))
                    total = db.get(ProductMetric, (stamp // 86400, "event_" + name, "")).value
                    profiles = db.scalar(select(func.count()).select_from(ProductProfile))
                    pending = db.scalar(select(func.count()).select_from(ProductEvent).where(ProductEvent.processed_at.is_(None)))
                    quality = db.scalar(select(func.sum(QualityFact.reports))) or 0
                    wal_bytes = int(db.scalar(text("SELECT pg_wal_lsn_diff(pg_current_wal_insert_lsn(), :start)"),
                                              {"start": wal_start}))
                assert processed == total == count and used == pending == 0 and profiles == len(players)
                assert quality == (count if kind == "one_shared_context" else 0)
                results.append({"kind": kind, "workers": workers, "events": count, "players": len(players),
                    "all_stage_seconds": round(total_seconds, 3),
                    "all_stage_events_per_second": round(count / total_seconds, 2),
                    "actor_batch_p50_ms": round(statistics.median(durations), 2),
                    "actor_batch_max_ms": round(max(durations), 2),
                    "processing_wal_bytes": wal_bytes,
                    "exact_total": total, "remaining_credits_used": used, "pending": pending})
            finally:
                engine.dispose()
                with admin.begin() as db:
                    db.execute(text(f"DROP SCHEMA {schema} CASCADE"))
finally:
    admin.dispose()
report = {"environment": "Local Windows/WSL Docker PostgreSQL; Python test client capped at 2 CPUs and 1 GiB",
          "scope": "Internal durable queue drain with no simultaneous producer or gameplay; 1000 profiles, not 500 million accounts",
          "qualification": "Does not establish HTTP latency, sustained throughput, WAL budget, gameplay isolation or production capacity",
          "results": results}
Path("/evidence/benchmark.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report))
