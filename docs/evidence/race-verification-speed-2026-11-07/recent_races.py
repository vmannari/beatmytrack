import importlib.util
from pathlib import Path
WORK=Path(__file__).resolve().parent
ROOT=WORK.parents[1]
OUT=ROOT/'docs/evidence/race-verification-speed-2026-11-07'
spec=importlib.util.spec_from_file_location('last_release',ROOT/'build/backend-compat-deploy-20261107/deploy.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
r.d.WORK=WORK;r.d.OUT=OUT;r.d.STATE=WORK/'state.private.json';r.d.state={}
code='''import json
from sqlalchemy import text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
s=Settings.from_env();engine=make_engine(s.database_url,s)
with engine.connect() as c:
 c.execute(text('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY'))
 rows=c.execute(text("SELECT r.status,r.failure_code,r.created_at,r.finished_at,r.attempts,b.vehicle_id,p.is_test_driver,r.time_ticks FROM runs r JOIN players p ON p.id=r.player_id JOIN boards b ON b.id=r.board_id ORDER BY r.created_at DESC LIMIT 30")).mappings().all()
 recent=[{**dict(row),'accepted_to_finished_seconds':row['finished_at']-row['created_at'] if row['finished_at'] else None} for row in rows]
 counts=dict(c.execute(text("SELECT status,count(*) FROM runs WHERE created_at>extract(epoch from now())-86400 GROUP BY status")).all())
print('RELEASE_RESULT='+json.dumps({'recent':recent,'last_day_statuses':counts}));engine.dispose()
'''
import json
print(json.dumps(r.d.execute('recent-race-durations',code,job=r.service.n['migrate']),indent=2),flush=True)
