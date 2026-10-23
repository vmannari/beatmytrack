"""Real PostgreSQL plans/timings in generated disposable schemas; synthetic PBs.

Run in the same isolated test container as run_postgres.py. Uses the actual
migration and query implementation. Never prints credentials or touches an
existing schema. These timings exclude HTTP, uploads and complete verification.
"""
import importlib.util
import json
import statistics
import time
import uuid
from pathlib import Path

from alembic.migration import MigrationContext
from alembic.operations import Operations
from bmt_backend.economy_models import RewardRankCount
from bmt_backend.identity_models import Player
from bmt_backend.reward_ranks import TREE_SIZE, percentile_amount, prefix_nodes
from bmt_backend.track_models import LapPersonalBest, PersonalBest
from sqlalchemy import create_engine, func, select
from sqlalchemy.engine import make_url
from sqlalchemy.orm import Session

raw = next(line.split("=", 1)[1].strip() for line in Path("/task/db.env").read_text().splitlines()
           if line.startswith("BMT_TEST_DATABASE_URL="))
engine = create_engine(make_url(raw).set(host="127.0.0.1", port=5432), hide_parameters=True)
source = Path("/task/backend/bmt_backend/migrations/versions/0045_reward_rank_index.py")
spec = importlib.util.spec_from_file_location("reward_migration", source)
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)
reports = []

for population in (1000, 10000, 100000):
    schema = "reward_probe_" + uuid.uuid4().hex
    try:
        with engine.begin() as db:
            db.exec_driver_sql(f'CREATE SCHEMA "{schema}"')
            db.exec_driver_sql(f'SET LOCAL search_path="{schema}",public')
            db.exec_driver_sql("CREATE TABLE boards(id varchar(64) PRIMARY KEY)")
            db.exec_driver_sql("INSERT INTO boards VALUES('board')")
            db.exec_driver_sql("CREATE TABLE players(id varchar(36) PRIMARY KEY,disabled boolean NOT NULL,is_test_driver boolean NOT NULL,deleted_at integer)")
            for table in ("personal_bests", "lap_personal_bests"):
                db.exec_driver_sql(f"CREATE TABLE {table}(board_id varchar(64),player_id varchar(36) REFERENCES players(id),time_ticks integer NOT NULL,PRIMARY KEY(board_id,player_id))")
                db.exec_driver_sql(f"CREATE INDEX ON {table}(board_id,time_ticks,player_id)")
            db.exec_driver_sql(f"INSERT INTO players SELECT n::text,false,false,NULL FROM generate_series(1,{population}) n")
            for table in ("personal_bests", "lap_personal_bests"):
                db.exec_driver_sql(f"INSERT INTO {table} SELECT 'board',n::text,n FROM generate_series(1,{population}) n")
            started = time.perf_counter()
            with Operations.context(MigrationContext.configure(db)):
                migration.upgrade()
            backfill_ms = (time.perf_counter() - started) * 1000
            db.exec_driver_sql("ANALYZE")
        with engine.connect() as db:
            db.exec_driver_sql(f'SET search_path="{schema}",public')
            with Session(bind=db) as session:
                def previous():
                    values = []
                    for model in (PersonalBest, LapPersonalBest):
                        criteria = (model.board_id == "board", Player.disabled.is_(False),
                                    Player.deleted_at.is_(None), Player.is_test_driver.is_(False))
                        total = session.scalar(select(func.count()).select_from(model).join(Player).where(*criteria))
                        ahead = session.scalar(select(func.count()).select_from(model).join(Player).where(*criteria, model.time_ticks < 50000))
                        values.append(next((amount for limit, amount in ((1,500),(10,200),(25,100),(50,50))
                                            if total and (ahead+1)*100 <= total*limit),0))
                    return values

                def current():
                    return [percentile_amount(session, "board", metric, 50000) for metric in ("race", "lap")]

                assert previous() == current()
                times = {"before": [], "after": []}
                for _ in range(12):
                    for name, call in (("before", previous), ("after", current)):
                        started = time.perf_counter()
                        call()
                        times[name].append((time.perf_counter() - started) * 1000)
                query = select(RewardRankCount.node,RewardRankCount.total).where(
                    RewardRankCount.board_id == "board", RewardRankCount.metric == "race",
                    RewardRankCount.node.in_([TREE_SIZE, *prefix_nodes(50000)]))
                compiled = str(query.compile(dialect=db.dialect,compile_kwargs={"literal_binds":True}))
                plan = db.exec_driver_sql("EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) " + compiled).scalar()
                update_plan = db.exec_driver_sql("EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) UPDATE personal_bests SET time_ticks=1 WHERE board_id='board' AND player_id='" + str(population) + "'").scalar()
                assert previous() == current()
                reports.append({"population": population, "migration_backfill_ms":backfill_ms,
                    "before_median_ms":statistics.median(times["before"]),
                    "after_median_ms":statistics.median(times["after"]),
                    "prefix_nodes_requested_per_metric":len(prefix_nodes(50000))+1,
                    "rank_query_plan":plan,"pb_update_plan":update_plan,
                    "qualification":"12 warm alternating samples; synthetic PBs; not complete race or deployment throughput"})
    finally:
        with engine.begin() as db:
            db.exec_driver_sql(f'DROP SCHEMA IF EXISTS "{schema}" CASCADE')

engine.dispose()
Path("/evidence/postgres-benchmark.json").write_text(json.dumps(reports,indent=2)+"\n")
print(json.dumps([{k:row[k] for k in ("population","before_median_ms","after_median_ms","prefix_nodes_requested_per_metric")} for row in reports]))
