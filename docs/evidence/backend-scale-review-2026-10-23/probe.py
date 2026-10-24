"""Read-only-source review probes; every write is synthetic in-memory SQLite."""
import ast
import inspect
import json
import sys
import time
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend"))

from bmt_backend import rivalry, runs
from bmt_backend.db import make_session_factory
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.race_statistics_models import RaceStatisticsReceipt
from bmt_backend.rivalry_models import RivalryGroup
from bmt_backend.studio_platform_models import AnalysisDay, AnalysisPerson
from bmt_backend.telemetry_processing import maintenance
from bmt_backend.track_models import (
    Board,
    BoardTimeCount,
    PersonalBest,
    now,
)
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session


def identity(index):
    return f"{index:08x}-0000-4000-8000-000000000000"


def measure(session, callback):
    steps = 0

    def progress():
        nonlocal steps
        steps += 100

    raw = session.connection().connection.driver_connection
    raw.set_progress_handler(progress, 100)
    started = time.perf_counter()
    try:
        result = callback()
    finally:
        elapsed = (time.perf_counter() - started) * 1000
        raw.set_progress_handler(None, 0)
    return {"vm_instructions_approximately": steps, "ms": round(elapsed, 3), "result": result}


def matching_groups(size):
    engine = create_engine("sqlite://")
    RivalryGroup.__table__.create(engine)
    with engine.begin() as db:
        db.execute(RivalryGroup.__table__.insert(), [{"id": identity(index), "week_start": 0,
            "ends_at": 604800, "vehicle_id": "compact", "contract_key": "c" * 64,
            "skill_band": -1, "member_count": 20 if index < size else 1,
            "tracks": [], "created_at": index} for index in range(size + 1)])
    # Execute the actual groups assignment from join(), not a replacement query.
    tree = ast.parse(inspect.getsource(rivalry.join))
    expression = next(node for node in ast.walk(tree) if isinstance(node, ast.Assign)
                      and any(isinstance(target, ast.Name) and target.id == "groups" for target in node.targets))
    code = compile(ast.Module(body=[expression], type_ignores=[]), "rivalry.join:groups", "exec")
    with Session(engine) as session:
        namespace = {**vars(rivalry), "session": session, "start": 0, "contract": "c" * 64, "band": -1}

        def execute():
            exec(code, namespace)  # noqa: S102 - execute only the reviewed repository query assignment
            return len(namespace["groups"])

        observed = measure(session, execute)
        assert observed["result"] == 1
        observed["closed_groups"] = size
        statement = select(RivalryGroup).where(RivalryGroup.week_start == 0,
            RivalryGroup.contract_key == "c" * 64, RivalryGroup.skill_band == -1,
            RivalryGroup.member_count < 20).order_by(RivalryGroup.created_at).limit(100)
        sql = str(statement.compile(engine, compile_kwargs={"literal_binds": True}))
        observed["sqlite_plan"] = [tuple(row) for row in session.connection().exec_driver_sql("EXPLAIN QUERY PLAN " + sql)]
    engine.dispose()
    return observed


def leaderboards(size, tied):
    engine = create_engine("sqlite://")
    for model in (Player, Board, PersonalBest, BoardTimeCount):
        model.__table__.create(engine)
    active = {"rules_key": "rules", "physics_version": "physics",
              "vehicles": {"compact": {"config_hash": "c"}}}
    board_id = "b" * 64
    with engine.begin() as db:
        db.execute(Player.__table__.insert(), [{"id": identity(index), "display_name": "Player " + str(index),
            "needs_username": True} for index in range(size)])
        db.execute(Board.__table__.insert().values(id=board_id, version_id=identity(size + 1),
            vehicle_id="compact", public_count=size, all_count=size,
            manifest={"rules_key": "rules", "physics_version": "physics", "config_hash": "c"}))
        db.execute(PersonalBest.__table__.insert(), [{"board_id": board_id, "player_id": identity(index),
            "run_id": identity(index + size + 2), "time_ticks": 1000 if tied else index + 1000}
            for index in range(size)])
        db.execute(BoardTimeCount.__table__.insert(), [{"board_id": board_id, "time_ticks": 1000,
            "public_count": size, "all_count": size}] if tied else [{"board_id": board_id,
            "time_ticks": index + 1000, "public_count": 1, "all_count": 1} for index in range(size)])
    with Session(engine) as session:
        original = runs.public_board
        runs.public_board = lambda *_: SimpleNamespace(id=board_id)
        try:
            measured = measure(session, lambda: runs.around_me(board_id, session,
                SimpleNamespace(id=identity(size // 2)), radius=3)["player"]["position"])
        finally:
            runs.public_board = original
        measured.update(players=size, distinct_tick_values=1 if tied else size)
        if not tied:
            measured["rivalry_skill_query"] = measure(session, lambda: rivalry.skill_score(session,
                identity(size // 2), "compact", active, now()))
    engine.dispose()
    return measured


def cleanup_backlog():
    engine = create_engine("sqlite://")
    upgrade(engine)
    factory = make_session_factory(engine)
    stamp = now()
    with factory() as db:
        db.execute(RaceStatisticsReceipt.__table__.insert(), [{"player_id": identity(0),
            "race_id": identity(index + 1), "event_id": identity(index + 2000),
            "payload_hash": "synthetic", "received_at": stamp - 9 * 86400} for index in range(1001)])
        db.commit()
    first = maintenance(factory, stamp, limit=500)
    second = maintenance(factory, stamp + 1, limit=500)
    with factory() as db:
        remaining = db.scalar(select(func.count()).select_from(RaceStatisticsReceipt))
    engine.dispose()
    assert first.get("more") is False and remaining == 501
    return {"initial_expired_race_receipts": 1001, "first": first, "second_one_second_later": second,
            "remaining": remaining, "unrelated_backlogs_present": False,
            "max_rows_per_day_at_500_per_minute": 500 * 60 * 24}


def busy_worker_schedule():
    from bmt_backend import achievements, histogram_snapshots, news, privacy, worker

    calls = {"foreground": 0, "privacy": 0, "histograms": 0, "achievements": 0, "news": 0}

    def called(name, result):
        def invoke(*_args, **_kwargs):
            calls[name] += 1
            return result
        return invoke

    originals = [(worker, "process_one"), (privacy, "cleanup_one"), (histogram_snapshots, "refresh_one"),
                 (achievements, "drive_idle"), (news, "process_requested")]
    saved = [getattr(module, name) for module, name in originals]
    try:
        worker.process_one = called("foreground", True)
        privacy.cleanup_one = called("privacy", False)
        histogram_snapshots.refresh_one = called("histograms", False)
        achievements.drive_idle = called("achievements", False)
        news.process_requested = called("news", False)
        app = SimpleNamespace(state=SimpleNamespace())
        for _index in range(64):
            assert worker.process_worker_job(app)
    finally:
        for (module, name), original in zip(originals, saved, strict=True):
            setattr(module, name, original)
    assert calls == {"foreground": 64, "privacy": 4, "histograms": 4, "achievements": 0, "news": 0}
    return {"scope": "Actual process_worker_job with foreground processing stubbed as perpetually busy", "calls": calls}


def active_people_retention_scan():
    engine = create_engine("sqlite://")
    upgrade(engine)
    factory, stamp = make_session_factory(engine), now()
    with factory() as db:
        db.execute(AnalysisPerson.__table__.insert(), [{"player_id": identity(index),
            "first_at": stamp - 181 * 86400} for index in range(128)])
        db.execute(AnalysisDay.__table__.insert(), [{"player_id": identity(index),
            "day": stamp // 86400, "dimension": "d" * 64, "counters": {"active": 1},
            "first_at": stamp, "last_at": stamp} for index in range(128)])
        db.commit()
    passes = 0
    while passes < 20:
        result = maintenance(factory, stamp, limit=500)
        passes += 1
        if not result.get("more"):
            break
    with factory() as db:
        kept = db.scalar(select(func.count()).select_from(AnalysisPerson))
    next_cycle = maintenance(factory, stamp + 61, limit=500)
    engine.dispose()
    assert passes == 9 and kept == 128 and next_cycle.get("more") is True
    return {"people": 128, "all_have_current_activity": True, "people_deleted": 0,
            "passes_per_complete_population_walk": passes,
            "scan_restarts_after_61_seconds": next_cycle.get("more"), "candidates_per_pass": 16}


if __name__ == "__main__":
    report = {"scope": "Actual source queries on synthetic in-memory SQLite with model indexes; no PostgreSQL timing or live data",
              "matching": [matching_groups(size) for size in (1000, 10000, 100000)],
              "tied_leaderboards": [leaderboards(size, True) for size in (1000, 10000, 100000)],
              "distinct_leaderboards": [leaderboards(size, False) for size in (1000, 10000, 100000)],
              "independent_cleanup_backlog": cleanup_backlog(), "busy_worker_schedule": busy_worker_schedule(),
              "active_people_retention_scan": active_people_retention_scan()}
    Path(__file__).with_name("probe-results.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))
