"""Isolated SQLite rank-index cost/storage probe; synthetic, not DAU certification."""
import importlib.util
import json
import random
import sys
import uuid
from pathlib import Path

from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

root = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(root / "backend"))
from bmt_backend.leaderboard_ranks import tied_before, time_counts  # noqa: E402
from bmt_backend.runs import population_window  # noqa: E402

spec = importlib.util.spec_from_file_location("rank_migration", root / "backend/bmt_backend/migrations/versions/0055_bounded_rank_reads.py")
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)
engine = create_engine("sqlite://")
with engine.begin() as connection:
    connection.exec_driver_sql("CREATE TABLE boards(id TEXT PRIMARY KEY)")
    connection.exec_driver_sql("CREATE TABLE players(id TEXT PRIMARY KEY,disabled BOOLEAN NOT NULL,is_test_driver BOOLEAN NOT NULL,display_name TEXT,country_code TEXT)")
    connection.exec_driver_sql("CREATE TABLE personal_bests(board_id TEXT,player_id TEXT,time_ticks INTEGER,run_id TEXT,achieved_at INTEGER,PRIMARY KEY(board_id,player_id))")
    connection.exec_driver_sql("INSERT INTO boards VALUES('ties')")
    with Operations.context(MigrationContext.configure(connection)):
        migration.upgrade()
rng = random.Random(85)
ids = []
results = []
for size in (100,1000,10000):
    new = [str(uuid.UUID(int=rng.getrandbits(128))) for _ in range(size-len(ids))]
    ids += new
    with engine.begin() as connection:
        connection.execute(text("INSERT INTO players VALUES(:id,0,0,:id,'FI')"),[{"id":identity} for identity in new])
        connection.execute(text("INSERT INTO personal_bests VALUES('ties',:id,150,:id,1)"),[{"id":identity} for identity in new])
    ordered = sorted(ids)
    identity = ordered[len(ordered)//2]
    with Session(engine) as session:
        dbapi = session.connection().connection.driver_connection
        steps = [0]
        def step():
            steps[0] += 1
            return 0
        dbapi.set_progress_handler(step,1)
        position = tied_before(session,"ties",150,identity)+1
        counts = time_counts(session,"ties",150)
        dbapi.set_progress_handler(None,0)
        assert position == len(ordered)//2+1 and counts == (0,size,0)
        nodes = session.scalar(text("SELECT COUNT(*) FROM leaderboard_tie_nodes"))
        counters = session.scalar(text("SELECT COUNT(*) FROM leaderboard_rank_counts"))
        results.append({"population":size,"position":position,"sqlite_vm_steps":steps[0],"tie_nodes":nodes,
                        "nodes_per_pb":nodes/size,"time_counter_rows":counters})
with engine.begin() as connection:
    connection.exec_driver_sql("INSERT INTO boards VALUES('hidden')")
    for index in range(20):
        identity = f"visible-{index:028d}"
        connection.execute(text("INSERT INTO players VALUES(:id,0,0,:id,'FI')"),{"id":identity})
        connection.execute(text("INSERT INTO personal_bests VALUES('hidden',:id,150,:id,1)"),{"id":identity})
hidden = 0
windows = []
for size in (1000,10000):
    with engine.begin() as connection:
        new = [{"id":f"hidden-{index:029d}"} for index in range(hidden,size)]
        connection.execute(text("INSERT INTO players VALUES(:id,1,0,:id,'FI')"),new)
        connection.execute(text("INSERT INTO personal_bests VALUES('hidden',:id,150,:id,1)"),new)
    hidden = size
    with Session(engine) as session:
        dbapi = session.connection().connection.driver_connection
        steps = [0]
        dbapi.set_progress_handler(step,1)
        rows = session.execute(population_window("hidden",3)).all()
        dbapi.set_progress_handler(None,0)
        assert len(rows) == 3
        statement = str(population_window("hidden",3).compile(session.bind,compile_kwargs={"literal_binds":True}))
        plan = [row[3] for row in session.execute(text("EXPLAIN QUERY PLAN "+statement))]
        assert any("ix_leaderboard_visible_order" in row for row in plan)
        windows.append({"hidden_pb_rows":size,"visible_window":len(rows),"sqlite_vm_steps":steps[0],"plan":plan})
output = {"ties":results,"hidden_candidates":windows}
Path(__file__).with_name("probe.json").write_text(json.dumps(output,indent=2)+"\n")
print(json.dumps(output))
