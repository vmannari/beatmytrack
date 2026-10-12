"""Owned local before/after operational work and query-plan measurements."""
import importlib.util
import json
import os
from pathlib import Path
import statistics
import sys
import time
from urllib.parse import urlsplit
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'backend'))
sys.path.insert(0,str(ROOT/'backend/tests'))
from alembic import command
from sqlalchemy import create_engine,event,insert,select,text,update
from test_domains import FakeVerifier
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.contracts import build_contract
from bmt_backend.db import make_engine
from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration,upgrade
from bmt_backend import operations
from bmt_backend.track_models import Board,HistogramSnapshot,OperationState,Run,RunTicket,Track,TrackVersion,digest,now

FOLDER=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('bmt_backend._scalability_before',FOLDER/'before/backend/bmt_backend/operations.py')
before=importlib.util.module_from_spec(spec);spec.loader.exec_module(before)
url=os.environ['BMT_SCALABILITY_REVIEW_DATABASE_URL']
if urlsplit(url).hostname not in ('127.0.0.1','localhost','::1'):raise ValueError('Owned loopback database required')
schema='bmt_load_'+uuid.uuid4().hex
admin=create_engine(url,connect_args={'connect_timeout':5})
with admin.begin() as c:c.exec_driver_sql('CREATE SCHEMA '+schema)
settings=Settings(database_url=url,object_dir=str(FOLDER/'objects'))
engine=make_engine(url,settings,schema=schema)
app=create_app(settings,engine=engine,verifier=FakeVerifier())
clock=now();operations.now=lambda:clock;before.now=lambda:clock

def measure(fn,iterations=10):
    sql=[];values=[];samples=[];counts=[]
    def record(_conn,_cursor,statement,*_):sql.append(statement)
    event.listen(engine,'before_cursor_execute',record)
    try:
        for _ in range(iterations):
            sql.clear();began=time.perf_counter_ns();values.append(fn());samples.append((time.perf_counter_ns()-began)/1e6);counts.append(len(sql))
        return {'median_ms':statistics.median(samples),'samples_ms':samples,'sql_counts':counts},values
    finally:event.remove(engine,'before_cursor_execute',record)

def plans():
    with engine.connect() as c:
        return {name:c.execute(text('EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) '+statement),{'cut':clock-300}).scalar()
            for name,statement in [('arrivals','SELECT count(*) FROM runs WHERE created_at>=:cut'),
                ('workers',"SELECT * FROM operation_state WHERE updated_at>=:cut AND id LIKE 'worker:%'")]}

try:
    upgrade(engine)
    actor=str(uuid.uuid4());track=str(uuid.uuid4());versions=[]
    manifest={**FakeVerifier().manifest(),'track_content_hash':'review','route_length':220.0}
    with app.state.session_factory() as session:
        session.add(Player(id=actor,display_name='Owned review fixture',needs_username=True))
        session.flush();session.add(Track(id=track,owner_id=actor));session.flush()
        for i in range(200):
            vid=str(uuid.uuid4());versions.append(vid)
            session.add(TrackVersion(id=vid,track_id=track,number=i+1,name=f'Review {i}',content_hash='0'*64,
                manifest=manifest,state='published',published_at=clock-86400))
        session.flush()
        bid=digest({'review':'operational-board'})
        session.add(Board(id=bid,version_id=versions[0],vehicle_id='compact',manifest=manifest))
        session.commit()
    count=100000;recent=100;tickets=[];runs=[]
    for i in range(count):
        tid,rid=str(uuid.uuid4()),str(uuid.uuid4())
        fresh=i>=count-recent;stamp=clock-10 if fresh else clock-86400
        status=('verified','failed','rejected')[i%3] if fresh else 'rejected'
        tickets.append({'id':tid,'player_id':actor,'board_id':bid,'created_at':stamp,'expires_at':stamp+3600})
        runs.append({'id':rid,'ticket_id':tid,'player_id':actor,'board_id':bid,'replay_hash':'0'*64,
            'status':status,'created_at':stamp-10,'finished_at':stamp,'time_ticks':1000,
            'failure_code':None if status=='verified' else 'verifier_unavailable' if status=='failed' else 'invalid_replay'})
    with app.state.session_factory() as session:
        for i in range(0,count,2000):
            session.execute(insert(RunTicket),tickets[i:i+2000]);session.execute(insert(Run),runs[i:i+2000])
        for i in range(0,10000,1000):
            session.execute(insert(OperationState),[{'id':f'worker:old-{j:06d}','updated_at':clock-86400,'details':{'lifecycle':'stopped'}} for j in range(i,i+1000)])
        session.add(OperationState(id='worker:recent',updated_at=clock,details={'build':build_contract(FakeVerifier().manifest())}))
        session.commit()
    command.downgrade(configuration(engine),'0022_histogram_cache')
    with engine.begin() as c:
        for table in ('runs','operation_state','histogram_snapshots','boards'):c.exec_driver_sql('ANALYZE '+table)
    old_measure,old_values=measure(lambda:before.competition_health(app))
    old_plans=plans()
    target=next(row['id'] for row in runs if row['status']=='verified')
    with app.state.session_factory() as session:
        session.execute(update(HistogramSnapshot).values(invalidated=False));session.commit()
        session.get(Run,target).status='rejected';session.commit()
        old_touched=sum(row for row in session.scalars(select(HistogramSnapshot.invalidated)))
        session.get(Run,target).status='verified';session.commit()
    upgrade(engine)
    with engine.begin() as c:
        for table in ('runs','operation_state','histogram_snapshots','boards'):c.exec_driver_sql('ANALYZE '+table)
    new_measure,new_values=measure(lambda:operations.competition_health(app))
    for first,second in zip(old_values,new_values):
        for name in first:
            if name!='storage_free_bytes':assert first[name]==second[name],name
    new_plans=plans()
    with app.state.session_factory() as session:
        session.execute(update(HistogramSnapshot).values(invalidated=False));session.commit()
        session.get(Run,target).status='rejected';session.commit()
        new_touched=sum(row for row in session.scalars(select(HistogramSnapshot.invalidated)))
    def heartbeats(fn,key,coalesce):
        for i in range(100):
            kwargs={'coalesce':True} if coalesce else {}
            fn(app,key,phase='claiming',build={'version':1},**kwargs)
            fn(app,key,phase='verifying',last_queue_wait_seconds=i,**kwargs)
            fn(app,key,phase='idle',last_verification_seconds=.002,**kwargs)
    old_heart,_=measure(lambda:heartbeats(before.heartbeat,'heartbeat-before',False),1)
    original=time.monotonic;time.monotonic=lambda:0
    try:new_heart,_=measure(lambda:heartbeats(operations.heartbeat,'heartbeat-after',True),1)
    finally:time.monotonic=original
    report={'attempts':count,'recent_attempts':recent,'old_workers':10000,'health_before':old_measure,'health_after':new_measure,
        'plans_before':old_plans,'plans_after':new_plans,'invalidation_before':old_touched,'invalidation_after':new_touched,
        'heartbeat_100_jobs_before':old_heart,'heartbeat_100_jobs_after':new_heart}
    (FOLDER/'postgres-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({key:report[key] for key in ('attempts','health_before','health_after','invalidation_before','invalidation_after','heartbeat_100_jobs_before','heartbeat_100_jobs_after')}))
finally:
    engine.dispose()
    with admin.begin() as c:c.exec_driver_sql('DROP SCHEMA '+schema+' CASCADE')
    admin.dispose()
