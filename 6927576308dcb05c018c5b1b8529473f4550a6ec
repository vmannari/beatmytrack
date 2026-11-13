"""Isolated synthetic query review; no remote I/O or shipping mutation."""
from pathlib import Path
import hashlib
import json
import statistics
import sys
import time
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "backend"))
from sqlalchemy import create_engine, event, insert, select
from sqlalchemy.orm import Session
from bmt_backend.identity_models import Player
from bmt_backend.track_models import (
    Track, TrackVersion, Board, RunTicket, Run, PersonalBest, LapPersonalBest,
    LapBestState, digest,
)
from bmt_backend.histogram_population import HistogramPopulation
from bmt_backend.daily_lap_standings import build
from bmt_backend.tracks import my_tracks
from bmt_backend.profile_statistics import car_history, track_races


def samples(fn, repetitions=5):
    result = []
    for _ in range(repetitions):
        start = time.perf_counter()
        value = fn()
        result.append((time.perf_counter() - start) * 1000)
    return {"median_ms": statistics.median(result), "samples_ms": result}, value


def make():
    engine = create_engine("sqlite:///:memory:")
    for model in (Player, Track, TrackVersion, Board, RunTicket, Run,
                  PersonalBest, LapPersonalBest, LapBestState):
        model.__table__.create(engine)
    return engine


def lap_pages(size):
    engine = make()
    version = "v" * 36
    manifest = {"laps": 5, "vehicle_id": "compact"}
    board = digest({"version_id": version, **manifest})
    context = {"version_id": version, "manifest": manifest, "day": 1, "generation": "g"}
    ticks = [(i * 37) % 8000 + 1000 for i in range(size)]
    with engine.begin() as conn:
        conn.execute(insert(Player), [{"id": f"{i:036d}", "display_name": f"P{i}",
                                      "needs_username": True} for i in range(size)])
        conn.execute(insert(PersonalBest), [{"board_id": board, "player_id": f"{i:036d}",
                    "run_id": f"{i:036d}", "time_ticks": ticks[i]*5} for i in range(size)])
        conn.execute(insert(LapPersonalBest), [{"board_id": board, "player_id": f"{i:036d}",
                    "run_id": f"{i:036d}", "time_ticks": ticks[i], "lap_index": 1,
                    "achieved_at": 1, "source_created_at": 1} for i in range(size)])
    from collections import Counter
    population = HistogramPopulation.from_frequencies(sorted(Counter(ticks).items()))
    cases = {}
    for indexed in (False, True):
        if indexed:
            with engine.begin() as conn:
                conn.exec_driver_sql("CREATE INDEX probe_lap_order ON lap_personal_bests(board_id,time_ticks,player_id)")
        for around in (False, True):
            statements = []
            def record(conn, cursor, statement, parameters, context, many):
                if statement.lstrip().startswith("SELECT"):
                    statements.append((statement, parameters))
            event.listen(engine, "before_cursor_execute", record)
            with Session(engine) as session:
                timing, value = samples(lambda: build(session, context, population, None,
                    limit=10, cursor="", around=around, candidate=5000 if around else None,
                    artificial=False))
            event.remove(engine, "before_cursor_execute", record)
            page_query = next((sql, params) for sql, params in statements if "ORDER BY" in sql)
            with engine.connect() as conn:
                plan = [tuple(row) for row in conn.exec_driver_sql("EXPLAIN QUERY PLAN " + page_query[0], page_query[1])]
            key = ("index" if indexed else "current") + ("_around" if around else "_top")
            cases[key] = {**timing, "result_digest": hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest(),
                          "items": len(value["items"]), "sql": page_query[0], "plan": plan}
    engine.dispose()
    return {"population": size, "cases": cases}


def own_tracks(unrelated):
    engine = make()
    with engine.begin() as conn:
        conn.execute(insert(Player), [{"id": "owner", "needs_username": True},
                                      {"id": "other", "needs_username": True}])
        conn.execute(insert(Track), [{"id": str(i), "owner_id": "owner" if i<12 else "other"}
                                     for i in range(unrelated+12)])
        conn.execute(insert(TrackVersion), [{"id": str(i), "track_id": str(i), "number": 1,
                     "name": f"T{i}", "state": "published", "manifest": {"laps":5},
                     "content_hash": "h"*64} for i in range(unrelated+12)])
    request = SimpleNamespace(app=SimpleNamespace(state=SimpleNamespace(settings=
        SimpleNamespace(local_drafts_only=True, public_base_url="https://invalid.example"))))
    statements = []
    def record(conn, cursor, statement, parameters, context, many):
        statements.append((statement, parameters))
    def execute():
        with Session(engine) as session:
            player = session.get(Player, "owner")
            return my_tracks(request, session, player, offset=0, limit=12, heads=True, profile_stats=True)
    timing, value = samples(execute)
    event.listen(engine, "before_cursor_execute", record)
    execute()
    event.remove(engine, "before_cursor_execute", record)
    query = next((sql, params) for sql, params in statements if "GROUP BY" in sql and "max(" in sql)
    with engine.connect() as conn:
        plan = [tuple(row) for row in conn.exec_driver_sql("EXPLAIN QUERY PLAN " + query[0], query[1])]
    engine.dispose()
    return {"unrelated_tracks": unrelated, "returned": len(value["items"]), **timing,
            "sql_count_including_one_auth_player_get": len(statements),
            "track_gets": sum("FROM tracks \nWHERE tracks.id =" in sql for sql, _ in statements),
            "sql": query[0], "plan": plan}


if __name__ == "__main__":
    result = {"kind": "REJECTED SCHEMA BASELINE: ORM metadata omits migrated ix_news_lap_rank; no missing-index finding is valid",
              "lap_pages": [lap_pages(n) for n in (4097, 50000, 100000)],
              "own_tracks": [own_tracks(n) for n in (0, 50000)],
              "source_sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in [ROOT/"backend/bmt_backend/daily_lap_standings.py", ROOT/"backend/bmt_backend/tracks.py",
                           ROOT/"backend/bmt_backend/profile_statistics.py", ROOT/"backend/bmt_backend/track_models.py"]}}
    output = Path(__file__).with_name("probe-results.json")
    output.write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
