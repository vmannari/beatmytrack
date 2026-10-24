"""Actual query plans in one generated schema; never access live application rows."""
import ast
import inspect
import json
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from types import SimpleNamespace
from uuid import uuid4

from bmt_backend import achievements, rivalry
from bmt_backend.db import make_session_factory
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.rivalry_models import RivalryGroup
from bmt_backend.track_models import QueueCapacity, QueueReservation, now
from sqlalchemy import create_engine, event, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.orm import Session

lines = Path("/task/db.env").read_text().splitlines()
raw = next(line.split("=", 1)[1].strip() for line in lines if line.startswith("BMT_TEST_DATABASE_URL="))
url = make_url(raw).set(host="127.0.0.1", port=5432)
admin = create_engine(url, hide_parameters=True)
schema = "bmt_scale_review_" + uuid4().hex
with admin.begin() as db:
    db.execute(text(f"CREATE SCHEMA {schema}"))
engine = create_engine(url, hide_parameters=True,
    connect_args={"options": f"-c search_path={schema} -c statement_timeout=15000", "application_name": schema})
tree = ast.parse(inspect.getsource(rivalry.join))
node = next(node for node in ast.walk(tree) if isinstance(node, ast.Assign)
            and any(isinstance(target, ast.Name) and target.id == "groups" for target in node.targets))
code = compile(ast.Module(body=[node], type_ignores=[]), "rivalry.join:groups", "exec")
report = {"scope": "Isolated local PostgreSQL, actual join-query assignment, synthetic groups and current migrations",
          "plans": [], "queue_pending_count_plans": []}
try:
    upgrade(engine)
    for size in (1000, 10000, 100000):
        with engine.begin() as db:
            db.execute(text("TRUNCATE rivalry_groups CASCADE"))
            for offset in range(0, size + 1, 1000):
                db.execute(RivalryGroup.__table__.insert(), [{"id": str(uuid4()), "week_start": 0,
                    "ends_at": 604800, "vehicle_id": "compact", "contract_key": "c" * 64,
                    "skill_band": -1, "member_count": 20 if index < size else 1,
                    "tracks": [], "created_at": index} for index in range(offset, min(size + 1, offset + 1000))])
            db.execute(text("ANALYZE rivalry_groups"))
        statements = []

        def capture(_conn, _cursor, statement, params, _context, _many, statements=statements):
            if statement.startswith("SELECT rivalry_groups."):
                statements.append((statement, params))

        event.listen(engine, "before_cursor_execute", capture)
        try:
            with Session(engine) as db:
                scope = {**vars(rivalry), "session": db, "start": 0, "contract": "c" * 64, "band": -1}
                exec(code, scope)  # noqa: S102 - execute only the reviewed repository query assignment
                assert len(scope["groups"]) == 1
        finally:
            event.remove(engine, "before_cursor_execute", capture)
        statement, params = statements[0]
        with engine.connect() as db:
            plan = db.exec_driver_sql("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + statement, params).scalar_one()
        report["plans"].append({"closed_groups": size, "returned_groups": 1, "explain": plan})
    owner = str(uuid4())
    with engine.begin() as db:
        db.execute(Player.__table__.insert().values(id=owner, display_name="Synthetic ledger owner", needs_username=True))
    for size in (1000, 10000, 100000):
        with engine.begin() as db:
            db.execute(text("TRUNCATE queue_reservations"))
            for offset in range(0, size, 1000):
                db.execute(QueueReservation.__table__.insert(), [{"kind": "review", "job_id": str(index),
                    "player_id": owner, "slot": index} for index in range(offset, min(size, offset + 1000))])
            db.execute(text("ANALYZE queue_reservations"))
        sql = str(select(QueueCapacity.pending).compile(engine, compile_kwargs={"literal_binds": True}))
        with engine.connect() as db:
            plan = db.exec_driver_sql("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + sql).scalar_one()
            assert db.scalar(select(QueueCapacity.pending)) == size
        report["queue_pending_count_plans"].append({"reservations": size, "explain": plan})
    actors = [str(uuid4()), str(uuid4())]
    with engine.begin() as db:
        db.execute(Player.__table__.insert(), [{"id": identity, "display_name": identity, "needs_username": True}
            for identity in actors])
    factory = make_session_factory(engine)
    with factory() as db:
        achievements.state(db, owner, "creator")
        db.commit()

    def accepted_race(actor):
        board = SimpleNamespace(id=uuid4().hex * 2, manifest={}, vehicle_id="compact")
        version = SimpleNamespace(manifest={"route_length": 200}, discovery={"theme": "pine"}, state="published")
        track = SimpleNamespace(id=str(uuid4()), owner_id=owner, hidden=False, archived=False)
        acceptance = SimpleNamespace(board=board, version=version, track=track, rivalry=None, challenge=None)
        run = SimpleNamespace(id=str(uuid4()), status="verified", board_id=board.id, player_id=actor,
            time_ticks=1000, lap_ticks=[200] * 5, finished_at=now())
        with factory() as db:
            achievements.capture_race(db, run, (0, 0), acceptance=acceptance)
            db.commit()

    with ThreadPoolExecutor(max_workers=2) as pool, factory() as locked:
        achievements.state(locked, owner, "creator")
        futures = [pool.submit(accepted_race, actor) for actor in actors]
        try:
            deadline, waiting = time.monotonic() + 5, 0
            while waiting < 2 and time.monotonic() < deadline:
                with engine.connect() as db:
                    waiting = db.scalar(text("SELECT COUNT(*) FROM pg_stat_activity WHERE application_name=:app "
                        "AND wait_event_type='Lock' AND query LIKE '%achievement_states%'"), {"app": schema})
                if waiting < 2:
                    time.sleep(.02)
            if waiting != 2:
                for future in futures:
                    if future.done():
                        future.result()
            assert waiting == 2 and not any(future.done() for future in futures)
        finally:
            locked.rollback()
        for future in futures:
            future.result(timeout=10)
    with factory() as db:
        state = achievements.state(db, owner, "creator")
        assert state.metrics["creator_plays"] == 2
    report["creator_achievement_lock"] = {"different_actors": 2, "different_track_and_board_contexts": 2,
        "postgres_confirmed_lock_waiters": waiting, "creator_plays_after_release": 2,
        "qualification": "Actual capture_race on minimal synthetic accepted-result contexts; no canonical verifier or HTTP throughput measured"}
finally:
    engine.dispose()
    with admin.begin() as db:
        db.execute(text(f"DROP SCHEMA {schema} CASCADE"))
        report["other_fixture_clients_at_end"] = db.scalar(text("SELECT COUNT(*) FROM pg_stat_activity "
            "WHERE datname=current_database() AND backend_type='client backend' AND pid<>pg_backend_pid()"))
    admin.dispose()
Path("/evidence/postgres-plans.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"cases": len(report["plans"]), "other_fixture_clients_at_end": report["other_fixture_clients_at_end"],
    "summary": [{"closed_groups": row["closed_groups"],
                 "ms": row["explain"][0]["Execution Time"],
                 "plan": row["explain"][0]["Plan"]["Node Type"]} for row in report["plans"]],
    "queue_counts": [{"reservations": row["reservations"], "ms": row["explain"][0]["Execution Time"]}
                     for row in report["queue_pending_count_plans"]]}))
