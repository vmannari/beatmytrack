"""Owned PostgreSQL fixtures: driver-scale reads and finalization DB cost."""
import json
import os
from pathlib import Path
import statistics
import sys
import time
from urllib.parse import urlsplit
import uuid

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'backend'),str(ROOT/'backend/tests')]
from alembic import command
from sqlalchemy import create_engine,event,select,text
from test_domains import FakeVerifier
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.histogram_snapshots import refresh_all_for_diagnostics,load_snapshot
from bmt_backend.identity_models import Player
from bmt_backend.lap_bests import backfill_all_for_diagnostics,legacy_best_lap_times
from bmt_backend.migrate import configuration,upgrade
from bmt_backend.runs import comparison_populations
from bmt_backend.track_models import Board,Run,RunTicket,Track,TrackVersion,digest,now

FOLDER=Path(__file__).resolve().parent
url=os.environ['BMT_TEST_DATABASE_URL']
if urlsplit(url).hostname not in ('127.0.0.1','localhost','::1'):raise ValueError('Owned loopback database required')
schema='bmt_load_'+uuid.uuid4().hex
admin=create_engine(url)
with admin.begin() as c:c.exec_driver_sql('CREATE SCHEMA '+schema)
settings=Settings(database_url=url,object_dir=str(FOLDER/'objects'),database_statement_timeout_ms=60000)
engine=make_engine(url,settings,schema=schema)
app=create_app(settings,engine=engine,verifier=FakeVerifier())
clock=now();report={'scope':'owned local PostgreSQL, synthetic accepted-data fixture; no network races'}

def measure(fn,n=9):
    samples=[];sql=[];counts=[];history=[]
    def record(_conn,_cursor,statement,*_):sql.append(statement)
    event.listen(engine,'before_cursor_execute',record)
    try:
        for _ in range(n):
            sql.clear();began=time.perf_counter_ns();fn();samples.append((time.perf_counter_ns()-began)/1e6)
            counts.append(len(sql));history.append(sum('FROM runs' in s for s in sql))
    finally:event.remove(engine,'before_cursor_execute',record)
    return {'median_ms':statistics.median(samples),'samples_ms':samples,'sql_counts':counts,'history_selects':history}

def seed_players(c,start,end):
    c.execute(text("""INSERT INTO players(id,display_name,needs_username,disabled,is_test_driver,created_at)
        SELECT md5('player'||n), 'Owned driver '||n,true,false,false,:clock FROM generate_series(CAST(:start AS integer),CAST(:end AS integer)) n"""),
        {'start':start,'end':end,'clock':clock})

def seed_history(c,start,end,drivers=1000,prefix='history'):
    # Only this isolated generated schema disables USER triggers while making
    # bulk historical fixtures. Normal projection/acceptance uses real triggers.
    c.execute(text("""INSERT INTO run_tickets(id,player_id,board_id,created_at,expires_at)
        SELECT md5(:prefix||'ticket'||n),md5('player'||(1+(n-1)%:drivers)),:board,:clock,:clock+7200
        FROM generate_series(CAST(:start AS integer),CAST(:end AS integer)) n"""),{'prefix':prefix,'drivers':drivers,'board':bid,'clock':clock,'start':start,'end':end})
    c.exec_driver_sql('ALTER TABLE runs DISABLE TRIGGER USER')
    c.execute(text("""INSERT INTO runs(id,ticket_id,player_id,board_id,replay_hash,status,created_at,finished_at,
        attempts,lease_until,time_ticks,lap_ticks)
        SELECT md5(:prefix||'run'||n),md5(:prefix||'ticket'||n),md5('player'||(1+(n-1)%:drivers)),:board,
        repeat('0',64),'verified',:clock,:clock,0,0,60000+(n%1000),
        json_build_array(12000,12000+(n%1000),13000,14000,15000) FROM generate_series(CAST(:start AS integer),CAST(:end AS integer)) n"""),
        {'prefix':prefix,'drivers':drivers,'board':bid,'clock':clock,'start':start,'end':end})
    c.exec_driver_sql('ALTER TABLE runs ENABLE TRIGGER USER')

def seed_pbs(c,start,end,prefix='history'):
    c.exec_driver_sql('ALTER TABLE personal_bests DISABLE TRIGGER USER')
    c.execute(text("""INSERT INTO personal_bests(board_id,player_id,run_id,time_ticks,achieved_at)
        SELECT :board,md5('player'||n),md5(:prefix||'run'||n),60000+(n%1000),:clock FROM generate_series(CAST(:start AS integer),CAST(:end AS integer)) n"""),
        {'board':bid,'prefix':prefix,'clock':clock,'start':start,'end':end})
    c.exec_driver_sql('ALTER TABLE personal_bests ENABLE TRIGGER USER')

def finalize_sample():
    with app.state.session_factory() as s:
        ticket=RunTicket(board_id=bid,player_id=actor,expires_at=clock+7200);s.add(ticket);s.flush()
        run=Run(ticket_id=ticket.id,board_id=bid,player_id=actor,replay_hash='0'*64,status='queued');s.add(run);s.commit()
        began=time.perf_counter_ns()
        s.execute(text("UPDATE runs SET status='verified',time_ticks=99999,lap_ticks='[12000,20000,20000,20000,20000]',finished_at=:clock WHERE id=:id"),{'clock':clock,'id':run.id})
        s.execute(text("""INSERT INTO personal_bests(board_id,player_id,run_id,time_ticks,achieved_at) VALUES(:b,:p,:r,99999,:clock)
            ON CONFLICT(board_id,player_id) DO UPDATE SET run_id=excluded.run_id,time_ticks=excluded.time_ticks
            WHERE personal_bests.time_ticks>excluded.time_ticks"""),{'b':bid,'p':actor,'r':run.id,'clock':clock})
        s.commit();return (time.perf_counter_ns()-began)/1e6

def fields():
    with app.state.session_factory() as s:
        races,laps=comparison_populations(s,[bid],bid,'absent',False)
        for metric,field in (('race',races),('best_lap',laps)):
            a,b=field.frame(None,None,None);field.histogram(bid,metric,16,a,b)
        assert len(races.own)==len(laps.own)==drivers

def legacy():
    with app.state.session_factory() as s:s.execute(select(legacy_best_lap_times(bid,s))).all()

try:
    command.upgrade(configuration(engine),'0023_operational_read_indexes')
    actor=digest('player1')[:32]  # replaced by SQL md5 fixture identity below
    owner=str(uuid.uuid4());tid=str(uuid.uuid4());vid=str(uuid.uuid4())
    manifest={**FakeVerifier().manifest(),'track_content_hash':'owned-lap-probe','route_length':220.0}
    with app.state.session_factory() as s:
        s.add(Player(id=owner,display_name='Owned fixture owner',needs_username=True));s.flush()
        s.add(Track(id=tid,owner_id=owner));s.flush()
        s.add(TrackVersion(id=vid,track_id=tid,number=1,name='Owned lap fixture',content_hash='0'*64,manifest=manifest,state='published',published_at=clock));s.flush()
        # Use the actual pinned public board key so snapshot preparation matches.
        from bmt_backend.runs import board_manifest
        pinned=board_manifest(s.get(TrackVersion,vid),'compact');bid=digest({'version_id':vid,**pinned})
        s.add(Board(id=bid,version_id=vid,vehicle_id='compact',manifest=pinned));s.commit()
    with engine.begin() as c:
        seed_players(c,1,1000);seed_history(c,1,1000);seed_pbs(c,1,1000)
        actor=c.execute(text("SELECT md5('player1')")).scalar()
    old=[finalize_sample() for _ in range(35)]
    began=time.perf_counter();upgrade(engine);batches=backfill_all_for_diagnostics(app.state.session_factory)
    report['initial_migration_backfill']={'seconds':time.perf_counter()-began,'batches':batches,'attempts':1035}
    new=[finalize_sample() for _ in range(35)]
    report['non_pb_finalize_db_before']={'median_ms':statistics.median(old[5:]),'samples_ms':old}
    report['non_pb_finalize_db_after']={'median_ms':statistics.median(new[5:]),'samples_ms':new}
    cases=[];drivers=1000;previous=1000
    for attempts in (1,50,500):
        target=drivers*attempts
        with engine.begin() as c:
            if target>previous:seed_history(c,previous+1,target)
            for table in ('runs','players','personal_bests','lap_personal_bests'):c.exec_driver_sql('ANALYZE '+table)
        previous=target
        old_read=measure(legacy,5);new_read=measure(fields)
        cases.append({'drivers':drivers,'attempts_per_driver':attempts,'legacy_lap_scan':old_read,'durable_both_fields':new_read})
        print(json.dumps({k:v for k,v in cases[-1].items() if k not in ('legacy_lap_scan','durable_both_fields')})+
              f" legacy={old_read['median_ms']:.3f}ms both_PB_fields={new_read['median_ms']:.3f}ms",flush=True)
    report['history_scaling']=cases
    drivers=100000
    with engine.begin() as c:
        seed_players(c,1001,drivers);seed_history(c,1001,drivers,drivers=drivers,prefix='large');seed_pbs(c,1001,drivers,prefix='large')
        c.exec_driver_sql('ALTER TABLE lap_personal_bests DISABLE TRIGGER USER')
        c.execute(text("""INSERT INTO lap_personal_bests(board_id,player_id,run_id,time_ticks,lap_index,achieved_at,source_created_at)
            SELECT :board,md5('player'||n),md5('large'||'run'||n),12000+(n%1000),1,:clock,:clock
            FROM generate_series(1001,100000) n"""),{'board':bid,'clock':clock})
        c.exec_driver_sql('ALTER TABLE lap_personal_bests ENABLE TRIGGER USER')
        for table in ('runs','players','personal_bests','lap_personal_bests'):c.exec_driver_sql('ANALYZE '+table)
    report['large_driver_field']=measure(fields,5)
    report['large_snapshot_refresh']=measure(lambda:refresh_all_for_diagnostics(app),1)
    def cold():
        from bmt_backend import board_cache
        with board_cache._lock:board_cache._caches.pop(engine,None)
        with app.state.session_factory() as s:
            result=load_snapshot(s,vid,'compact',False);assert len(result[2][0].own)==drivers
    report['large_cold_snapshot']=measure(cold,3)
    with app.state.session_factory() as s:
        from bmt_backend.track_models import HistogramSnapshot
        payload=s.get(HistogramSnapshot,(vid,'compact',False)).payload
        report['large_snapshot_payload_bytes']=len(json.dumps(payload,separators=(',',':')).encode())
    (FOLDER/'postgres-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({'large_fields_ms':report['large_driver_field']['median_ms'],
        'large_refresh_ms':report['large_snapshot_refresh']['median_ms'],'cold_payload_ms':report['large_cold_snapshot']['median_ms'],
        'payload_bytes':report['large_snapshot_payload_bytes'],'finalize_before_ms':report['non_pb_finalize_db_before']['median_ms'],
        'finalize_after_ms':report['non_pb_finalize_db_after']['median_ms']}),flush=True)
finally:
    engine.dispose()
    with admin.begin() as c:c.exec_driver_sql('DROP SCHEMA '+schema+' CASCADE')
    admin.dispose()
