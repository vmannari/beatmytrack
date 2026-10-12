"""Bounded isolated product database benchmark; no live/game authority claims."""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from types import SimpleNamespace
from uuid import NAMESPACE_URL, uuid4, uuid5

from sqlalchemy import create_engine, event, func, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import ArgumentError

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

from bmt_backend.config import Settings
from bmt_backend.db import Base, make_engine, make_session_factory
from bmt_backend.identity_models import Player
from bmt_backend.product_analytics import (
    DAY,
    prepared_report,
    project_pending,
)
from bmt_backend.telemetry import (
    POLICY,
    SCHEMA,
    Batch,
    accept_batch,
    append_server_event,
    insert_for,
)
from bmt_backend.telemetry_models import ProductEvent, ProductMetric, ProductState


def benchmark(size, *, postgres=False):
    at, schema, admin_engine = int(time.time()), "", None
    if postgres:
        database_url = os.environ.get("BMT_TEST_DATABASE_URL", "")
        try:
            target = make_url(database_url)
        except (ArgumentError, ValueError):
            raise RuntimeError("An explicitly supplied owned-loopback test database is required") from None
        if (target.get_backend_name() != "postgresql" or target.host not in ("127.0.0.1", "localhost")
                or set(target.query) & {"host", "hostaddr", "service", "servicefile"}):
            raise RuntimeError("An explicitly supplied owned-loopback test database is required")
        schema = "product_bench_" + uuid4().hex
        admin_engine = create_engine(database_url, hide_parameters=True, pool_size=1, max_overflow=0,
            connect_args={"connect_timeout": 5, "options": "-c statement_timeout=15000"})
        with admin_engine.begin() as connection:
            connection.execute(text("CREATE SCHEMA " + schema))
        engine = create_engine(database_url, hide_parameters=True, pool_size=1, max_overflow=0,
            connect_args={"connect_timeout": 5,
                "options": "-c search_path=" + schema + " -c statement_timeout=15000"})
    else:
        directory = ROOT / "build/telemetry-analysis-2026-10-11/benchmarks"
        directory.mkdir(parents=True, exist_ok=True)
        engine = make_engine("sqlite:///" + str(directory / ("bench-" + uuid4().hex + ".sqlite")))
    result = {"backlog_rows": size, "database": "postgresql" if postgres else "sqlite",
        "scope": "Owned fixture direct calls; wall latency includes database I/O and loopback transport for PostgreSQL. HTTP, player network, canonical race and device behavior are not exercised.",
        "cpu_scope": "time.process_time for this Python process only: excludes PostgreSQL server CPU, database wait and network wait. SQLite work executes in-process.",
        "sql_scope": "Cursor executions and transaction commits are counted separately; COMMIT is not a cursor SQL statement."}
    try:
        Base.metadata.create_all(engine)
        factory = make_session_factory(engine)
        with factory() as session:
            players = [Player(id=str(uuid4()), display_name="Bench " + str(index)) for index in range(500)]
            session.add_all(players)
            session.add(ProductState(id=1, pending_events=0, processed_events=0, truncated_profiles=0,
                pending_clients=0, pending_capped=False, fact_days=180))
            session.commit()
        seeded = time.perf_counter()
        for first in range(0, size, 1000):
            values = [{"id": str(uuid5(NAMESPACE_URL, schema + "/bench/" + str(index))),
                "player_id": players[index % len(players)].id, "is_test_driver": False, "source": "server",
                "name": "race_accepted", "occurred_at": at, "received_at": at,
                "build_id": "", "platform": "", "clock_quality": "server", "payload_hash": "a" * 64,
                "properties": {"car_id": "compact"}} for index in range(first, min(size, first + 1000))]
            with factory() as session:
                session.execute(insert_for(session, ProductEvent).values(values))
                session.commit()
        result["seed_seconds"] = round(time.perf_counter() - seeded, 3)
        def analyze_owned(tables):
            started = time.perf_counter()
            with engine.begin() as connection:
                for table in tables:
                    connection.execute(text("ANALYZE " + table))
            return round((time.perf_counter() - started) * 1000, 3)
        result["seed_analyze_wall_milliseconds"] = analyze_owned((
            Player.__table__.name, "product_events", "product_metrics", "product_profiles",
            "product_player_days", "product_publications", "product_state"))
        statements = []
        commits = []
        def record(_connection, _cursor, statement, *_args):
            statements.append(statement.lower())
        def record_commit(_connection):
            commits.append(True)
        event.listen(engine, "before_cursor_execute", record)
        event.listen(engine, "commit", record_commit)
        def measure(name, function):
            statements.clear()
            commits.clear()
            began = time.perf_counter()
            cpu_began = time.process_time()
            value = function()
            result[name] = {"wall_milliseconds": round((time.perf_counter() - began) * 1000, 3),
                "process_cpu_milliseconds": round((time.process_time() - cpu_began) * 1000, 3),
                "sql_statements": len(statements), "transaction_commits": len(commits)}
            if name == "dashboard":
                result[name]["raw_event_scans"] = sum("from product_events" in statement for statement in statements)
            return value
        def ingest():
            events = [{"id": str(uuid4()), "name": "menu_ready", "occurred_at": at,
                "session_id": str(uuid4()), "seq": index, "monotonic_ms": index,
                "properties": {}} for index in range(50)]
            batch = Batch(schema=SCHEMA, purpose_policy=POLICY, build_id="bench", platform="android", events=events)
            request = SimpleNamespace(app=SimpleNamespace(state=SimpleNamespace(settings=Settings(telemetry_enabled=True))))
            with factory() as session:
                return accept_batch(batch, request, session, players[0])
        ack = measure("ingest_50", ingest)
        result["ack_bytes"] = len(json.dumps(ack, separators=(",", ":")).encode())
        source, outbox_ticket = str(uuid4()), str(uuid4())
        def outbox():
            with factory() as session:
                append_server_event(session, "race_accepted", source, players[0].id,
                    {"run_id": source, "ticket_id": outbox_ticket, "car_id": "compact"},
                    occurred_at=at, is_test_driver=False)
                session.commit()
        measure("outbox_single_commit", outbox)
        projected = measure("project_500", lambda: project_pending(factory, limit=500, at=at))
        result["project_500"].update(projected)
        result["prepared_analyze_wall_milliseconds"] = analyze_owned((
            "product_metrics", "product_profiles", "product_player_days", "product_publications"))
        def dashboard():
            with factory() as session:
                return prepared_report(session, (at // DAY - 89) * DAY, at + 1, at)
        data = measure("dashboard", dashboard)
        result["dashboard_bytes"] = len(json.dumps(data, separators=(",", ":")).encode())
        measure("idle_probe", lambda: _probe(factory))
        if postgres:
            capped_pending = select(ProductEvent.id).where(ProductEvent.processed_at.is_(None)) \
                .order_by(ProductEvent.received_at, ProductEvent.id).limit(5000)
            queries = {
                "pending_500": select(ProductEvent).where(ProductEvent.processed_at.is_(None))
                    .order_by(ProductEvent.received_at, ProductEvent.id).limit(500),
                "pending_count_capped_5000": select(func.count()).select_from(capped_pending.subquery()),
                "prepared_metrics": select(ProductMetric).where(ProductMetric.day >= at // DAY - 89,
                    ProductMetric.day <= at // DAY).limit(12000),
            }
            with factory() as session:
                result["postgres_plan_scope"] = "Actual PostgreSQL planning/execution wall timings and buffer activity; this is not PostgreSQL CPU measurement. Read-only bounded SELECTs only."
                result["postgres_plans"] = {key: session.scalar(text("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) "
                    + str(query.compile(engine, compile_kwargs={"literal_binds": True}))))
                    for key, query in queries.items()}
                result["product_events_relation_bytes"] = session.scalar(
                    text("SELECT pg_total_relation_size('product_events'::regclass)"))
                result["product_events_heap_bytes"] = session.scalar(
                    text("SELECT pg_relation_size('product_events'::regclass)"))
                result["product_events_index_bytes"] = session.scalar(
                    text("SELECT pg_indexes_size('product_events'::regclass)"))
        event.remove(engine, "before_cursor_execute", record)
        event.remove(engine, "commit", record_commit)
    finally:
        engine.dispose()
        if admin_engine is not None:
            with admin_engine.begin() as connection:
                connection.execute(text("DROP SCHEMA " + schema + " CASCADE"))
            admin_engine.dispose()
    return result


def _probe(factory):
    with factory() as session:
        return session.scalar(select(ProductEvent.id).where(ProductEvent.processed_at.is_(None))
            .order_by(ProductEvent.received_at, ProductEvent.id).limit(1))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--postgres", action="store_true")
    parser.add_argument("--output", default="docs/evidence/telemetry-analysis-2026-10-11/benchmark.json")
    args = parser.parse_args()
    results = [benchmark(size, postgres=args.postgres) for size in (50000, 100000)]
    target = ROOT / args.output
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(results, indent=2) + "\n", encoding="utf8")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
