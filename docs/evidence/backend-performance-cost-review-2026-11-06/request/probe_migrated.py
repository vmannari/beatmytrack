"""Recheck initial ORM-only review against the complete Alembic schema."""
import json
from pathlib import Path
import probe_requests as probe
from sqlalchemy import create_engine, inspect
from bmt_backend.migrate import upgrade


def make_migrated():
    engine = create_engine("sqlite:///:memory:")
    upgrade(engine)
    return engine


engine = make_migrated()
indexes = inspect(engine).get_indexes("lap_personal_bests")
assert any(row["name"] == "ix_news_lap_rank" and row["column_names"] ==
           ["board_id", "time_ticks", "player_id"] for row in indexes)
engine.dispose()
probe.make = make_migrated
result = {"kind": "Full Alembic migration SQLite component review; not PostgreSQL or live latency",
          "missing_lap_index_finding": "WITHDRAWN: migration 0038 already creates ix_news_lap_rank",
          "lap_indexes": indexes,
          "own_tracks": [probe.own_tracks(n) for n in (0, 50000)]}
Path(__file__).with_name("migrated-results.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
print(json.dumps(result, indent=2))
