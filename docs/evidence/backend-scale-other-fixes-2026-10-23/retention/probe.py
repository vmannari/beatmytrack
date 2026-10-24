"""Synthetic SQLite instruction counts; disposable in-memory data only."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "backend"))

from sqlalchemy import create_engine

from bmt_backend.db import make_session_factory
from bmt_backend.migrate import upgrade
from bmt_backend.studio_platform_models import AnalysisDay, AnalysisPerson
from bmt_backend.telemetry_processing import maintenance
from bmt_backend.telemetry_queue import activate
from bmt_backend.track_models import now


def identity(index):
    return f"{index:08x}-0000-4000-8000-000000000000"


def probe(size):
    engine = create_engine("sqlite://")
    upgrade(engine)
    factory = make_session_factory(engine)
    stamp = now()
    with factory() as session:
        activate(session)
        session.commit()
    with engine.begin() as connection:
        connection.execute(AnalysisPerson.__table__.insert(), [
            {"player_id": identity(index), "first_at": stamp - 181 * 86400, "last_day": stamp // 86400}
            for index in range(size)])
        connection.execute(AnalysisDay.__table__.insert(), [
            {"player_id": identity(index), "day": stamp // 86400, "dimension": "current",
             "first_at": stamp, "last_at": stamp}
            for index in range(size)])
    steps = 0

    def progress():
        nonlocal steps
        steps += 100

    raw = engine.raw_connection()
    raw.driver_connection.set_progress_handler(progress, 100)
    try:
        result = maintenance(factory, at=stamp, force=True)
    finally:
        raw.driver_connection.set_progress_handler(None, 0)
        raw.close()
    with engine.connect() as connection:
        plan = connection.exec_driver_sql("EXPLAIN QUERY PLAN SELECT "
            "EXISTS(SELECT 1 FROM studio_analysis_people WHERE last_day IS NULL) OR "
            f"EXISTS(SELECT 1 FROM studio_analysis_people WHERE last_day < {stamp // 86400 - 180})").all()
    engine.dispose()
    assert not result.get("more")
    return {"active_old_cohort_people": size, "approximate_sqlite_vm_instructions": steps,
            "maintenance": result, "expiry_plan": [list(row) for row in plan]}


if __name__ == "__main__":
    result = {"probe": "retained active cohorts do not create expiry work",
              "limitations": "Synthetic SQLite query-work evidence, not cloud capacity or PostgreSQL load certification.",
              "samples": [probe(size) for size in (1000, 10000, 100000)]}
    Path(__file__).with_name("probe.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
