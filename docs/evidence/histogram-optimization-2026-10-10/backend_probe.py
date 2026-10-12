"""Disposable histogram review: SQL work, scaling and revision correctness."""
import argparse
import json
import os
from pathlib import Path
import statistics
import sys
import time
from types import SimpleNamespace
import uuid

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'backend'))
sys.path.insert(0,str(ROOT/'backend/tests'))
from test_domains import FakeVerifier
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade
from bmt_backend.db import make_engine
from bmt_backend.identity_models import Player
from bmt_backend.track_models import Track,TrackVersion,Board,RunTicket,Run,PersonalBest,digest
from bmt_backend.runs import board_manifest,results_comparison,histogram
from sqlalchemy import create_engine,event,insert,select,update


def measure(app,version,player,board_id,iterations):
    statements=[];durations=[];packets=[];sql_times=[]
    def record(_connection,_cursor,sql,_params,context,_many):
        statements.append(sql);context.review_started=time.perf_counter_ns()
    def complete(_connection,_cursor,_sql,_params,context,_many):sql_times.append((time.perf_counter_ns()-context.review_started)/1e6)
    event.listen(app.state.engine,'before_cursor_execute',record)
    event.listen(app.state.engine,'after_cursor_execute',complete)
    try:
        for _ in range(iterations):
            statements.clear()
            with app.state.session_factory() as session:
                actor=session.get(Player,player)
                statements.clear();sql_times.clear()
                started=time.perf_counter_ns()
                data=results_comparison(version,'compact',SimpleNamespace(app=app),session,actor,
                    bins=16,race_ticks=9600,lap_ticks=1800,race_from_ticks=None,race_to_ticks=None,
                    lap_from_ticks=None,lap_to_ticks=None)
                durations.append((time.perf_counter_ns()-started)/1e6)
                assert data['race']['population']==data['best_lap']['population']
                assert sum(row['count'] for row in data['race']['bins'])==data['race']['population']
                packets.append({'queries':len(statements),'lap_history_queries':sum('lap_ticks' in sql for sql in statements),
                    'sql_execute_ms':sum(sql_times),'race_population':data['race']['population'],'stats_revision':data['stats_revision']})
        ordered=sorted(durations)
        return {'median_ms':statistics.median(durations),'p95_ms':ordered[int((len(ordered)-1)*.95)],
            'samples_ms':durations,'query_counts':packets}
    finally:
        event.remove(app.state.engine,'before_cursor_execute',record)
        event.remove(app.state.engine,'after_cursor_execute',complete)


def run_case(drivers,attempts,iterations,folder):
    path=folder/f'drivers-{drivers}-attempts-{attempts}.sqlite'
    database=os.environ.get('BMT_HISTOGRAM_REVIEW_DATABASE_URL')
    if not database and path.exists():raise RuntimeError('Disposable benchmark file already exists')
    settings=Settings(environment='development',database_url=database or f'sqlite:///{path.as_posix()}',object_dir=str(folder/'objects'),
        test_drivers_enabled=True,dev_auth_enabled=True,dev_auth_key='local-histogram-review-only-'*3)
    admin,engine,schema=None,None,None
    if database:
        from urllib.parse import urlsplit
        if urlsplit(database).hostname not in ('localhost','127.0.0.1'):raise RuntimeError('Only an owned local review database is allowed')
        schema='bmt_load_'+uuid.uuid4().hex
        admin=create_engine(database,connect_args={'connect_timeout':5})
        with admin.begin() as connection:connection.exec_driver_sql('CREATE SCHEMA '+schema)
        engine=make_engine(database,settings,schema=schema)
    app=create_app(settings,engine=engine,verifier=FakeVerifier())
    upgrade(app.state.engine)
    ids=[str(uuid.uuid4()) for _ in range(drivers)]
    track_id,version_id=str(uuid.uuid4()),str(uuid.uuid4())
    manifest={**app.state.verifier.manifest(),'track_content_hash':'review-track','route_length':220.}
    with app.state.session_factory() as session:
        session.execute(insert(Player),[{'id':pid,'display_name':f'Local probe {i}','needs_username':True,
            'disabled':False,'is_test_driver':False} for i,pid in enumerate(ids)])
        session.add(Track(id=track_id,owner_id=ids[0],official=True))
        session.add(TrackVersion(id=version_id,track_id=track_id,number=1,name='Local review circuit',state='published',
            content_hash='0'*64,manifest=manifest,published_at=1))
        session.flush()
        pinned=board_manifest(session.get(TrackVersion,version_id),'compact')
        bid=digest({'version_id':version_id,**pinned})
        session.add(Board(id=bid,version_id=version_id,vehicle_id='compact',manifest=pinned));session.commit()
    runs=[];tickets=[];pbs=[]
    for i,pid in enumerate(ids):
        best_run=None
        for attempt in range(attempts):
            rid,tid=str(uuid.uuid4()),str(uuid.uuid4())
            ticks=9000+i%1200+attempt*25
            lap=1800+i%240-attempt%20
            tickets.append({'id':tid,'player_id':pid,'board_id':bid,'expires_at':2000000000})
            runs.append({'id':rid,'ticket_id':tid,'player_id':pid,'board_id':bid,'replay_hash':'0'*64,
                'status':'verified','time_ticks':ticks,'lap_ticks':[ticks-4*lap,lap,lap,lap,lap],'finished_at':1})
            if attempt==0:best_run=rid
        pbs.append({'board_id':bid,'player_id':pid,'run_id':best_run,'time_ticks':9000+i%1200,'achieved_at':1})
    with app.state.session_factory() as session:
        for offset in range(0,len(runs),2000):
            session.execute(insert(RunTicket),tickets[offset:offset+2000])
            session.execute(insert(Run),runs[offset:offset+2000])
        session.execute(insert(PersonalBest),pbs);session.commit()
    if database:
        with app.state.engine.begin() as connection:
            for table in ('players','tracks','track_versions','boards','personal_bests','runs','board_time_counts'):
                connection.exec_driver_sql('ANALYZE '+table)
    measured=measure(app,version_id,ids[0],bid,iterations)
    # Demonstrate why race-PB revision alone cannot safely key a lap cache.
    with app.state.session_factory() as session:
        revision_before=session.get(Board,bid).stats_revision
        actor=session.get(Player,ids[0])
        before=results_comparison(version_id,'compact',SimpleNamespace(app=app),session,actor,bins=16,
            race_ticks=None,lap_ticks=None,race_from_ticks=None,race_to_ticks=None,lap_from_ticks=None,lap_to_ticks=None)
        tid,rid=str(uuid.uuid4()),str(uuid.uuid4())
        session.add(RunTicket(id=tid,player_id=ids[0],board_id=bid,expires_at=2000000000));session.flush()
        session.add(Run(id=rid,ticket_id=tid,player_id=ids[0],board_id=bid,replay_hash='0'*64,status='verified',
            time_ticks=15000,lap_ticks=[9000,1500,1500,1500,1500],finished_at=2));session.commit()
    with app.state.session_factory() as session:
        after=results_comparison(version_id,'compact',SimpleNamespace(app=app),session,session.get(Player,ids[0]),bins=16,
            race_ticks=None,lap_ticks=None,race_from_ticks=None,race_to_ticks=None,lap_from_ticks=None,lap_to_ticks=None)
        revision_after=session.get(Board,bid).stats_revision
    result={'drivers':drivers,'verified_attempts':drivers*attempts,'measurement':measured,
        'lap_only_improvement':{'race_revision_before':revision_before,'race_revision_after':revision_after,
            'lap_before':before['best_lap']['own_best_ticks'],'lap_after':after['best_lap']['own_best_ticks'],
            'response_changed':before!=after}}
    app.state.engine.dispose()
    if admin:
        with admin.begin() as connection:connection.exec_driver_sql('DROP SCHEMA '+schema+' CASCADE')
        admin.dispose()
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();args.output.parent.mkdir(parents=True,exist_ok=True)
    cases=[(100,1),(100,50),(1000,1),(1000,50)]
    report=[]
    for drivers,attempts in cases:
        result=run_case(drivers,attempts,5,args.output.parent);report.append(result)
        print(json.dumps({'drivers':drivers,'attempts':drivers*attempts,'median_ms':result['measurement']['median_ms'],
            'queries':result['measurement']['query_counts'][0],'lap_revision':result['lap_only_improvement']}),flush=True)
        args.output.write_text(json.dumps(report,indent=2),encoding='utf-8')
