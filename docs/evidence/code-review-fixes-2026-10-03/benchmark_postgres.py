"""Representative PostgreSQL plans in the local disposable test database only."""
import json
import sys
import uuid
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.engine import make_url

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend"))
config = (ROOT / ".tools/backend-postgres.env").read_text()
url = next(line.split("=", 1)[1].strip() for line in config.splitlines() if line.startswith("BMT_TEST_DATABASE_URL="))
parsed = make_url(url)
assert parsed.host in ("localhost", "127.0.0.1") and parsed.port == 55439, "Disposable test DB required"
engine = create_engine(url)
schema = "review_plans_" + uuid.uuid4().hex
assert schema.startswith("review_plans_") and schema.replace("_", "").isalnum()
plans = {}
try:
    with engine.begin() as db:
        db.exec_driver_sql(f"CREATE SCHEMA {schema}")
        db.exec_driver_sql(f"SET LOCAL search_path={schema}")
        db.exec_driver_sql("CREATE TABLE players (id varchar(36) PRIMARY KEY, display_name varchar(80), disabled boolean NOT NULL)")
        db.exec_driver_sql("CREATE TABLE personal_bests (board_id varchar(64), player_id varchar(36), time_ticks integer, run_id varchar(36), achieved_at integer, PRIMARY KEY(board_id,player_id))")
        db.exec_driver_sql("CREATE INDEX ix_pb_rank ON personal_bests(board_id,time_ticks,player_id)")
        db.exec_driver_sql("INSERT INTO players SELECT lpad(n::text,36,'0'),'Racer '||n,false FROM generate_series(1,100000) n")
        db.exec_driver_sql("INSERT INTO personal_bests SELECT 'board',id,1000+n/3,id,0 FROM players, LATERAL (SELECT id::integer n) s")
        db.exec_driver_sql("ANALYZE players")
        db.exec_driver_sql("ANALYZE personal_bests")
        projection = "SELECT pb.player_id,pb.time_ticks,p.display_name FROM personal_bests pb JOIN players p ON p.id=pb.player_id WHERE pb.board_id='board' AND NOT p.disabled"
        queries = {
            "top20": projection+" ORDER BY pb.time_ticks,pb.player_id LIMIT 20",
            "predecessors3": projection+" AND (pb.time_ticks,pb.player_id)<(17666,'000000000000000000000000000000050000') ORDER BY pb.time_ticks DESC,pb.player_id DESC LIMIT 3",
            "successors3": projection+" AND (pb.time_ticks,pb.player_id)>(17666,'000000000000000000000000000000050000') ORDER BY pb.time_ticks,pb.player_id LIMIT 3",
            "rank_count": "SELECT count(*) FROM ("+projection+" AND pb.time_ticks<17666) s",
            "histogram_cold": "SELECT floor((s.time_ticks-1000)/3334),count(*) FROM ("+projection+") s GROUP BY 1",
            "window_baseline": "SELECT * FROM (SELECT s.*,row_number() OVER (ORDER BY time_ticks,player_id) pos,rank() OVER (ORDER BY time_ticks) rank FROM ("+projection+") s) r WHERE pos BETWEEN 49998 AND 50004",
        }
        for name, query in queries.items():
            runs = [db.exec_driver_sql("EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) "+query).scalar()[0] for _ in range(3)]
            plans[name] = {"execution_ms":[r["Execution Time"] for r in runs], "plan":runs[-1]}
finally:
    with engine.begin() as db:
        db.exec_driver_sql(f"DROP SCHEMA IF EXISTS {schema} CASCADE")
    engine.dispose()
output = {"population":100000,"environment":"desktop WSL PostgreSQL, disposable schema; warm runs, no NAS/network load", "queries":plans}
(Path(__file__).with_name("postgres-plans.json")).write_text(json.dumps(output,indent=2))
print(json.dumps({name:value["execution_ms"] for name,value in plans.items()}))
