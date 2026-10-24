"""Paired actual handlers and scheduled worker turns in disposable SQLite."""
import json
import logging
import sys
import tempfile
import time
from contextlib import contextmanager
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "backend/tests")]
before = "--before" in sys.argv
if before:
    import baseline_runner  # noqa: F401 - installs task-start import loader
logging.disable(logging.CRITICAL)

from sqlalchemy import event, update
from test_domains import domain

from bmt_backend import discovery_projection, telemetry_queue
from bmt_backend.discovery_models import DiscoveryPartition
from bmt_backend.economy import balance
from bmt_backend.track_models import now


@contextmanager
def counts(engine):
    statements = []
    def record(_connection, _cursor, sql, *_args):
        statements.append(sql)
    event.listen(engine, "before_cursor_execute", record)
    try:
        yield statements
    finally:
        event.remove(engine, "before_cursor_execute", record)


with tempfile.TemporaryDirectory(prefix="bmt-scale-read-") as folder:
    fixture = domain.__wrapped__(Path(folder), SimpleNamespace(param="sqlite"))
    d = next(fixture)
    try:
        with d.factory() as session:
            warm = balance(session, SimpleNamespace(id=d.players["Alice"]))
        with counts(d.app.state.engine) as wallet_sql, d.factory() as session:
            wallet = balance(session, SimpleNamespace(id=d.players["Alice"]))
        assert wallet == warm
        stamp = now()
        discovery_projection.settle_for_diagnostics(d.factory, clock=stamp)
        with d.factory() as session:
            session.execute(update(DiscoveryPartition).values(checked_at=time.time_ns(), audit_at=stamp+60))
            session.commit()
        maintenance = None if before else discovery_projection.DiscoveryMaintenance()
        if not before:
            discovery_projection.step(d.factory, clock=stamp, tick=1, maintenance=maintenance)
        with counts(d.app.state.engine) as discovery_sql:
            for tick in (2, 2.1, 2.2):
                worked = discovery_projection.step(d.factory, clock=stamp) if before else \
                    discovery_projection.step(d.factory, clock=stamp, tick=tick, maintenance=maintenance)
                assert not worked
        if before:
            telemetry_queue.prepare(d.factory)
        else:
            preparation = telemetry_queue.PreparationSchedule()
            preparation.step(d.factory, tick=1)
        with counts(d.app.state.engine) as telemetry_sql:
            for tick in (2, 2.1, 2.2):
                assert (telemetry_queue.prepare(d.factory) if before else preparation.step(d.factory, tick=tick)) == 0
        result = {"variant": "before" if before else "after", "wallet_handler_sql": len(wallet_sql),
                  "wallet_payload": wallet, "idle_turns": 3, "discovery_sql": len(discovery_sql),
                  "discovery_updates": sum(sql.lstrip().upper().startswith("UPDATE") for sql in discovery_sql),
                  "telemetry_preparation_sql": len(telemetry_sql),
                  "limits": "SQLite; scheduled after-checks within the five-second interval; excludes due maintenance and authentication"}
    finally:
        fixture.close()
target = Path(__file__).with_name("reads-before.json" if before else "reads-after.json")
target.write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
print(json.dumps({k: v for k, v in result.items() if k != "wallet_payload"}))
