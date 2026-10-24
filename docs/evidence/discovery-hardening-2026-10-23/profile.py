"""Paired discovery-core reads, write/WAL and relation/index growth in an owned DB."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import statistics
import sys
import time
import uuid

from fastapi.testclient import TestClient
from sqlalchemy import event, text
from sqlalchemy.engine import make_url

from bmt_backend import discovery_v3
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.discovery_projection import settle_for_diagnostics, step
from bmt_backend.migrate import upgrade

FOLDER = Path(__file__).parent
ROOT = FOLDER.parents[2]


def sql(db, value, params=None):
    return db.execute(text(value), params or {})


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sizes(engine):
    with engine.connect() as db:
        tables = [dict(row._mapping) for row in sql(db,"""SELECT relname,
            pg_table_size(c.oid)::bigint AS table_bytes, pg_indexes_size(c.oid)::bigint AS index_bytes,
            pg_total_relation_size(c.oid)::bigint AS total_bytes
            FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname=current_schema() AND c.relkind='r' ORDER BY relname""")]
        indexes = [dict(row._mapping) for row in sql(db,"""SELECT c.relname,pg_relation_size(c.oid)::bigint AS bytes
            FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname=current_schema() AND c.relkind='i' ORDER BY bytes DESC""")]
    return {"tables":tables,"indexes":indexes,"total_bytes":sum(t["total_bytes"] for t in tables)}


def seed(engine, size):
    stamp = int(time.time())
    creators = min(10000,size)
    with engine.begin() as db:
        sql(db,"SET LOCAL statement_timeout=1800000")
        sql(db,"SET LOCAL idle_in_transaction_session_timeout=1800000")
        for field in ("name","creator"):
            sql(db,f"DROP INDEX ix_discovery_entry_{field}_short")
        sql(db,f"""INSERT INTO players(id,username_key,display_name,needs_username,disabled,deleted_at,
            analytics_enabled,is_test_driver,vehicle_appearances,country_code,created_at)
            SELECT md5('profile-owner-'||g)::uuid::text,'profile-owner-'||g,'Builder '||g,
            false,false,NULL,false,false,'{{}}','',{stamp} FROM generate_series(1,{creators}) g""")
        sql(db,f"""INSERT INTO tracks(id,owner_id,authoring_id,hidden,archived,official,created_at)
            SELECT md5('discovery-scale-track-'||g)::uuid::text,
            md5('profile-owner-'||(1+g%{creators}))::uuid::text,NULL,false,false,g<=9,{stamp}-g
            FROM generate_series(1,{size}) g""")
        sql(db,f"""INSERT INTO track_versions(id,track_id,number,name,content_hash,manifest,discovery,state,
            created_at,published_at,rating_sum,rating_count,verified_finishers)
            SELECT md5('discovery-scale-version-'||g)::uuid::text,
            md5('discovery-scale-track-'||g)::uuid::text,1,'Circuit '||lpad(g::text,7,'0'),repeat('a',64),'{{}}'::json,
            json_build_object('theme',CASE WHEN g%2=0 THEN 'pine' ELSE 'desert' END,
                'points',json_build_array(json_build_array(0,0),json_build_array(10,0),json_build_array(10,10))),
            'published',{stamp}-g,{stamp}-g,4*(g%101),g%101,g%1000 FROM generate_series(1,{size}) g""")
        sql(db,"""INSERT INTO discovery_heads(track_id,partition,slot,epoch,popularity,due_at)
            SELECT id,p,row_number() OVER(PARTITION BY p ORDER BY id),1,0,0 FROM
            (SELECT id,strpos('0123456789abcdef',substr(id,1,1))-1 p FROM tracks) s""")
        sql(db,"""INSERT INTO discovery_entries(track_id,epoch,partition,until,retired_at,version_id,owner_id,
            visible,official,name,creator,name_key,creator_key,theme,published_at,created_at,rating_sum,rating_count,
            rated,score,finishers,popularity)
            SELECT t.id,1,h.partition,NULL,NULL,v.id,t.owner_id,true,t.official,v.name,p.display_name,lower(v.name),
            lower(p.display_name),v.discovery->>'theme',v.published_at,v.created_at,v.rating_sum,v.rating_count,
            v.rating_count>0,floor(((2*v.rating_sum::numeric+35)*1000000000000000000)/(2*v.rating_count+10))::bigint,v.verified_finishers,0
            FROM tracks t JOIN track_versions v ON v.track_id=t.id JOIN players p ON p.id=t.owner_id
            JOIN discovery_heads h ON h.track_id=t.id""")
        sql(db,f"""UPDATE discovery_partitions p SET epoch=1,ready=true,checked_at={time.time_ns()},
            audit_at={stamp}+3600, slots=(SELECT count(*) FROM discovery_heads h WHERE h.partition=p.id)""")
        sql(db,"UPDATE discovery_bootstrap SET ready=true")
        sql(db,"TRUNCATE discovery_changes RESTART IDENTITY")
        for table in ("tracks","track_versions","players","discovery_entries","discovery_heads","discovery_changes"):
            sql(db,"ANALYZE "+table)
    return creators


def reads(app, engine, handle, size):
    current = discovery_v3.handle
    statements=[]
    def capture(_connection,_cursor,query,params,*_args):
        statements.append((query,params))
    discovery_v3.handle=handle
    event.listen(engine,"before_cursor_execute",capture)
    report={"queries":[]}
    try:
        with TestClient(app) as client:
            for label,query in [("new",{"sort":"new"}),("name",{"sort":"name"}),
                ("combined",{"sort":"name","theme":"pine","minimum_rating":3.5,"race_count":"high"}),
                ("rare",{"sort":"name","search":f"Circuit {size:07d}","search_kind":1}),
                ("short_missing",{"sort":"name","search":"zz","search_kind":1}),
                ("short_match",{"sort":"name","search":"it","search_kind":1})]:
                statements.clear(); started=time.perf_counter()
                response=client.post('/v1/discovery/v3/tracks',json={"query":query})
                data=response.json()
                row={"query":label,"status":response.status_code,"milliseconds":round((time.perf_counter()-started)*1000,3),
                     "statements":len(statements),"items":len(data.get('items',[]))}
                assert response.status_code in (200,503),response.text
                if response.status_code==200 and label=='rare': assert len(data['items'])==1
                if response.status_code==200 and label=='short_missing': assert not data['items']
                if label=='short_missing' and response.status_code==200:
                    saved=[(q,p) for q,p in statements if 'discovery_entries' in q and q.startswith('SELECT')]
                    with engine.connect() as db:
                        row['plan']=db.exec_driver_sql('EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) '+saved[0][0],saved[0][1]).scalar()
                report['queries'].append(row)
            first=client.post('/v1/discovery/v3/tracks',json={'query':{'sort':'name'}})
            assert first.status_code==200,first.text
            page=first.json(); latency=[]; counts=[]
            for _ in range(25):
                statements.clear(); started=time.perf_counter()
                response=client.post('/v1/discovery/v3/tracks',json={'cursor':page['next_cursor']})
                latency.append((time.perf_counter()-started)*1000);counts.append(len(statements))
                assert response.status_code==200,response.text
                page=response.json();assert len(page['items'])==20
            report.update(page_median_ms=round(statistics.median(latency),3),page_max_ms=round(max(latency),3),
                          page_statement_counts=sorted(set(counts)))
    finally:
        event.remove(engine,"before_cursor_execute",capture)
        discovery_v3.handle=current
    return report


def run(url,size):
    admin=make_engine(url);schema='bmt_load_'+uuid.uuid4().hex;engine=None
    old=load('bmt_backend._discovery_before',FOLDER/'before/backend__bmt_backend__discovery_v3.py')
    prior_probe=load('discovery_prior_scale_probe',FOLDER.parent/'discovery-indexed-2026-10-22/scale_probe.py')
    report={'tracks':size,'scope':'Local paired core reads through current middleware; explicit synthetic projection, no backfill/DAU certification'}
    try:
        with admin.begin() as db:sql(db,'CREATE SCHEMA '+schema)
        engine=make_engine(url,schema=schema)
        app=create_app(Settings(database_url=url,object_dir=str(FOLDER/'objects'),rate_limit_per_minute=10000,
            discovery_create_per_minute=10000),engine=engine)
        upgrade(engine)
        started=time.perf_counter();report['creators']=seed(engine,size)
        report['seed_seconds_excluded']=round(time.perf_counter()-started,3)
        print('seed complete',size,report['seed_seconds_excluded'],flush=True)
        report['before_indexes']=sizes(engine)
        saved = {}
        if '--guarded' in sys.argv:
            # Keep concurrent admission/security work identical in both arms.
            for name in ('new_session','fetch','boundary','choose'):
                saved[name]=getattr(discovery_v3,name)
                setattr(discovery_v3,name,getattr(old,name))
        try:
            report['before']=reads(app,engine,discovery_v3.handle if saved else old.handle,size)
        finally:
            for name,value in saved.items():setattr(discovery_v3,name,value)
        if size==100001 and '--guarded' not in sys.argv:
            old_projection=load('bmt_backend._projection_before',FOLDER/'before/backend__bmt_backend__discovery_projection.py')
            prior_probe.step=old_projection.step
            prior_probe.settle_for_diagnostics=old_projection.settle_for_diagnostics
            report['projection_burst_before']=prior_probe.project_burst(app,engine)
            # Restore this explicitly synthetic projection between paired runs.
            # No old cursors are used after this reset; all SQL is in the owned schema.
            with engine.begin() as db:
                sql(db,'TRUNCATE discovery_drivers, discovery_changes RESTART IDENTITY')
                sql(db,"DELETE FROM players WHERE username_key LIKE 'burst-player-%'")
                sql(db,'DELETE FROM discovery_entries WHERE until IS NOT NULL')
                sql(db,'UPDATE discovery_entries SET popularity=0 WHERE popularity<>0')
                sql(db,'UPDATE discovery_heads SET popularity=0,due_at=0 WHERE popularity<>0 OR due_at<>0')
            prior_probe.step=step
            prior_probe.settle_for_diagnostics=settle_for_diagnostics
        with engine.begin() as db:
            sql(db,'SET LOCAL statement_timeout=1800000')
            started=time.perf_counter()
            for field in ('name','creator'):
                sql(db,f'CREATE INDEX ix_discovery_entry_{field}_short ON discovery_entries USING gin(discovery_short_grams({field}))')
            sql(db,'ANALYZE discovery_entries')
        report['short_index_build_seconds']=round(time.perf_counter()-started,3)
        report['after_indexes']=sizes(engine)
        # Recheck freshness after fixture construction, outside request timings.
        with engine.begin() as db:sql(db,f'UPDATE discovery_partitions SET checked_at={time.time_ns()}')
        report['after']=reads(app,engine,discovery_v3.handle,size)
        if size==100001 and '--guarded' not in sys.argv:
            report['projection_burst']=prior_probe.project_burst(app,engine)
            before=sizes(engine)
            stamp=int(time.time())
            with engine.begin() as db:
                sql(db,'SET LOCAL statement_timeout=600000')
                wal=sql(db,'SELECT pg_current_wal_lsn()::text').scalar()
                started=time.perf_counter()
                sql(db,f"""INSERT INTO discovery_drivers(track_id,player_id,partition,last_at,expires_at,counted)
                    SELECT tid,md5('profile-owner-'||(1+g/2000))::uuid::text,
                    strpos('0123456789abcdef',substr(tid,1,1))-1,{stamp},{stamp}+604800,true
                    FROM (SELECT g,md5('discovery-scale-track-'||(1+g%2000))::uuid::text tid
                          FROM generate_series(0,199999) g) p ON CONFLICT DO NOTHING""")
                # Keep the derived counter consistent with this independent storage fixture.
                sql(db,f"""UPDATE discovery_heads h SET popularity=(SELECT count(*) FROM discovery_drivers d
                    WHERE d.track_id=h.track_id AND d.counted),due_at={stamp}
                    WHERE h.track_id IN (SELECT DISTINCT track_id FROM discovery_drivers)""")
            report['ledger_insert_seconds']=round(time.perf_counter()-started,3)
            with engine.connect() as db:
                report['ledger_insert_wal_bytes']=int(sql(db,'SELECT pg_wal_lsn_diff(pg_current_wal_lsn(),:wal)',{'wal':wal}).scalar())
                report['recent_pairs']=int(sql(db,'SELECT count(*) FROM discovery_drivers').scalar())
            settle_for_diagnostics(app.state.session_factory)
            report['ledger_before']=before
            report['ledger_after']=sizes(engine)
            # Vacuum/ANALYZE here is an owned diagnostic phase, never a request.
            with engine.connect().execution_options(isolation_level='AUTOCOMMIT') as db:
                started=time.perf_counter()
                for table in ('discovery_entries','discovery_changes','discovery_drivers','discovery_boundaries','discovery_sessions'):
                    db.exec_driver_sql('VACUUM (ANALYZE) '+table)
                report['vacuum_seconds']=round(time.perf_counter()-started,3)
            report['after_vacuum']=sizes(engine)
        return report
    finally:
        if engine is not None:engine.dispose()
        with admin.begin() as db:sql(db,'DROP SCHEMA '+schema+' CASCADE')
        admin.dispose()


def main():
    url=os.environ['BMT_DISCOVERY_TEST_DATABASE_URL'];parsed=make_url(url)
    assert parsed.host in ('127.0.0.1','localhost') and parsed.database=='bmt_discovery_lab'
    reports=[]
    paths=['backend/bmt_backend/'+name for name in ('discovery_v3.py','discovery_projection.py','discovery_models.py','middleware.py','discovery_guard.py','discovery_retention.py')]
    hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths if (ROOT/p).exists()}
    for size in ((100001,) if '--small' in sys.argv else (100001,1000000)):
        reports.append(run(url,size))
        output='profile-guarded-results.json' if '--guarded' in sys.argv else 'profile-results.json'
        changed=[p for p,h in hashes.items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h]
        (FOLDER/output).write_text(json.dumps({'levels':reports,'source_sha256_at_start':hashes,'changed_during_probe':changed,
            'guarded_comparison':'--guarded' in sys.argv},indent=2)+'\n')
        print('profile complete',size,flush=True)


if __name__=='__main__':main()
