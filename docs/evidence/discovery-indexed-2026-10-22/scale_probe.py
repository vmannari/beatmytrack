"""Synthetic indexed-reader capacity probe; source projection tested separately.

Only the fresh loopback database supplied by postgres_lab.py is accepted. All
schemas are generated and removed. No live API, account or credential is used.
"""
import hashlib
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

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.discovery_projection import settle_for_diagnostics, step
from bmt_backend.migrate import upgrade

FOLDER = Path(__file__).parent


def execute(db, sql):
    return db.execute(text(sql))


def seed(engine, size):
    stamp = int(time.time())
    owner = str(uuid.uuid4())
    with engine.begin() as db:
        # Fixture construction is excluded from request latency and may build
        # a million rows/indexes. Shipping reader deadlines remain unchanged.
        execute(db, "SET LOCAL statement_timeout=600000")
        execute(db, "SET LOCAL idle_in_transaction_session_timeout=600000")
        execute(db, f"""INSERT INTO players(id,username_key,display_name,needs_username,disabled,deleted_at,
            analytics_enabled,is_test_driver,vehicle_appearances,country_code,created_at)
            VALUES('{owner}','discovery scale owner','Discovery scale owner',false,false,NULL,false,false,'{{}}','',{stamp})""")
        execute(db, f"""INSERT INTO tracks(id,owner_id,authoring_id,hidden,archived,official,created_at)
            SELECT md5('discovery-scale-track-'||g)::uuid::text,'{owner}',NULL,false,false,g<=9,{stamp}-g
            FROM generate_series(1,{size}) g""")
        execute(db, f"""INSERT INTO track_versions(id,track_id,number,name,content_hash,manifest,discovery,state,
            created_at,published_at,rating_sum,rating_count,verified_finishers)
            SELECT md5('discovery-scale-version-'||g)::uuid::text,
            md5('discovery-scale-track-'||g)::uuid::text,1,'Circuit '||lpad(g::text,7,'0'),repeat('a',64),'{{}}'::json,
            json_build_object('theme',CASE WHEN g%2=0 THEN 'pine' ELSE 'desert' END,'points',json_build_array(
                json_build_array(0,0),json_build_array(10,0),json_build_array(10,10))),
            'published',{stamp}-g,{stamp}-g,4*(g%101),g%101,g%1000
            FROM generate_series(1,{size}) g""")
        # Explicit synthetic projection fixture. Does not claim backfill/ingress throughput.
        execute(db, """INSERT INTO discovery_heads(track_id,partition,slot,epoch,popularity,due_at)
            SELECT id,p,row_number() OVER(PARTITION BY p ORDER BY id),1,0,0 FROM
            (SELECT id,strpos('0123456789abcdef',substr(id,1,1))-1 p FROM tracks) s""")
        execute(db, """INSERT INTO discovery_entries(track_id,epoch,partition,until,retired_at,version_id,owner_id,
            visible,official,name,creator,name_key,creator_key,theme,published_at,created_at,rating_sum,rating_count,
            rated,score,finishers,popularity)
            SELECT t.id,1,h.partition,NULL,NULL,v.id,t.owner_id,true,t.official,v.name,p.display_name,lower(v.name),
            lower(p.display_name),v.discovery->>'theme',v.published_at,v.created_at,v.rating_sum,v.rating_count,
            v.rating_count>0,floor(((2*v.rating_sum::numeric+35)*1000000000000000000)/(2*v.rating_count+10))::bigint,v.verified_finishers,0
            FROM tracks t JOIN track_versions v ON v.track_id=t.id JOIN players p ON p.id=t.owner_id
            JOIN discovery_heads h ON h.track_id=t.id""")
        execute(db, f"""UPDATE discovery_partitions p SET epoch=1,ready=true,checked_at={time.time_ns()},
            slots=(SELECT count(*) FROM discovery_heads h WHERE h.partition=p.id)""")
        execute(db, "UPDATE discovery_bootstrap SET ready=true")
        execute(db, f"UPDATE discovery_changes SET processed_at={stamp}")
        for table in ("tracks","track_versions","players","discovery_entries","discovery_heads",
                      "discovery_changes","discovery_partitions"):
            execute(db, "ANALYZE " + table)


def project_burst(app, engine):
    """Synthetic consumer burst, including a hot track and repeated pairs.

    Excludes source race verification/HTTP and the daemon's scheduling sleeps.
    Source trigger correctness is covered by test_discovery_projection.py.
    """
    stamp = int(time.time())
    hot = str(uuid.UUID(hashlib.md5(b'discovery-scale-track-1').hexdigest()))
    with engine.begin() as db:
        execute(db,"SET LOCAL statement_timeout=600000")
        execute(db,f"""INSERT INTO players(id,username_key,display_name,needs_username,disabled,deleted_at,
            analytics_enabled,is_test_driver,vehicle_appearances,country_code,created_at)
            SELECT md5('burst-player-'||g)::uuid::text,'burst-player-'||g,'Burst player '||g,
            false,false,NULL,false,false,'{{}}','',{stamp} FROM generate_series(0,999) g""")
        execute(db,f"""INSERT INTO discovery_changes(partition,kind,target,player_id,run_id,finished_at,created_at)
            SELECT strpos('0123456789abcdef',substr(tid,1,1))-1,'finish',tid,
            md5('burst-player-'||(g%1000))::uuid::text,NULL,{stamp},{stamp}
            FROM (SELECT g,CASE WHEN g<8000 THEN '{hot}' ELSE
                md5('discovery-scale-track-'||(2+g%999))::uuid::text END tid
                FROM generate_series(0,9999) g) s""")
        wal_start=execute(db,"SELECT pg_current_wal_lsn()::text").scalar()
    started=time.perf_counter()
    turns=0
    while True:
        step(app.state.session_factory)
        turns+=1
        with engine.connect() as db:
            pending=execute(db,"SELECT id FROM discovery_changes WHERE processed_at IS NULL LIMIT 1").scalar()
        if pending is None: break
        assert turns<5000,"Synthetic consumer burst did not drain"
    elapsed=time.perf_counter()-started
    settle_for_diagnostics(app.state.session_factory,clock=stamp+61)
    with engine.connect() as db:
        pairs=int(execute(db,"SELECT count(*) FROM discovery_drivers").scalar())
        hot_pairs=int(execute(db,f"SELECT popularity FROM discovery_heads WHERE track_id='{hot}'").scalar())
        wal=int(db.execute(text("SELECT pg_wal_lsn_diff(pg_current_wal_lsn(),:start)"),{'start':wal_start}).scalar())
    assert hot_pairs==1000 and pairs==3000,(hot_pairs,pairs)
    return {'receipts':10000,'recent_pairs':pairs,'hot_track_pairs':hot_pairs,'consumer_turns':turns,
        'seconds':round(elapsed,3),'receipts_per_second':round(10000/elapsed,1),
        'wal_bytes_including_final_rank_flush':wal,
        'scope':'Unthrottled local step loop; excludes HTTP/verification, daemon sleeps and production concurrency'}


def run_level(url, size):
    schema = "bmt_load_" + uuid.uuid4().hex
    admin = make_engine(url)
    engine = None
    report = {"tracks":size,"synthetic":True}
    try:
        with admin.begin() as db:
            execute(db, "CREATE SCHEMA " + schema)
        engine = make_engine(url, schema=schema)
        app = create_app(Settings(database_url=url, object_dir=str(FOLDER / "scale-objects"),
            rate_limit_per_minute=10000, discovery_create_per_minute=1000), engine=engine)
        upgrade(engine)
        started = time.perf_counter()
        seed(engine, size)
        report["seed_seconds_excluded_from_reads"] = round(time.perf_counter()-started,3)
        statements = []
        def capture(_connection,_cursor,sql,params,*_):
            if "discovery_entries" in sql and sql.lstrip().upper().startswith("SELECT"):
                statements.append((sql,params))
        event.listen(engine,"before_cursor_execute",capture)
        with TestClient(app) as client:
            queries = [
                ("new",{"query":{"sort":"new"}}),
                ("name",{"query":{"sort":"name"}}),
                ("popular",{"query":{"feed":"popular"}}),
                ("rated",{"query":{"feed":"rated"}}),
                ("combined",{"query":{"sort":"name","theme":"pine","minimum_rating":3.5,"race_count":"high"}}),
                ("rare",{"query":{"sort":"name","search":f"Circuit {size:07d}","search_kind":1}}),
                ("deep_anchor",{"query":{"sort":"name"},"locate_version":str(uuid.UUID(hashlib.md5(
                    ('discovery-scale-version-'+str(size-3)).encode()).hexdigest()))}),
                ("short_missing",{"query":{"sort":"name","search":"zz","search_kind":1}}),
            ]
            results=[]
            plans=[]
            for label, body in queries:
                statements.clear()
                started=time.perf_counter()
                response=client.post('/v1/discovery/v3/tracks',json=body)
                elapsed=1000*(time.perf_counter()-started)
                data=response.json()
                assert response.status_code in (200,503), response.text
                if response.status_code==503:
                    assert data['detail']=='DISCOVERY_QUERY_BUDGET', data
                else:
                    assert len(data['items'])<=20 and data['total'] is None
                    if label=='rare': assert len(data['items'])==1, data
                    if label=='deep_anchor': assert data['items'][0]['name']==f"Circuit {size-3:07d}",data
                results.append({'query':label,'status':response.status_code,'milliseconds':round(elapsed,3),
                    'returned_items':len(data.get('items',[])),'entry_statements':len(statements)})
                saved=list(statements)
                if label in ('new','name','combined') and response.status_code==200:
                    # Explain the exact indexed query used, outside HTTP timing.
                    with engine.connect() as db:
                        for sql, params in saved[:1]:
                            plan=db.exec_driver_sql('EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) '+sql,params).scalar()
                            plans.append({'query':label,'plan':plan})
            latency=[]
            first=client.post('/v1/discovery/v3/tracks',json={'query':{'sort':'name'}})
            assert first.status_code==200,first.text
            data=first.json()
            for _ in range(25):
                started=time.perf_counter()
                response=client.post('/v1/discovery/v3/tracks',json={'cursor':data['next_cursor']})
                latency.append(1000*(time.perf_counter()-started))
                assert response.status_code==200,response.text
                data=response.json()
                assert len(data['items'])==20
            samples=[]
            for _ in range(16):
                response=client.post('/v1/discovery/v3/random',json={'cursor':data['page_cursor']})
                assert response.status_code==200,response.text
                samples.append(response.json()['items'][0]['track_id'])
            report.update(queries=results,twenty_item_page_median_ms=round(statistics.median(latency),3),
                twenty_item_page_max_ms=round(max(latency),3),random_picks=len(samples),
                random_unique=len(set(samples)),plans=plans)
        event.remove(engine,'before_cursor_execute',capture)
        if size==100001:
            report['projection_burst']=project_burst(app,engine)
        with engine.connect() as db:
            report['database_bytes']=int(execute(db,f"SELECT sum(pg_total_relation_size(quote_ident(schemaname)||'.'||quote_ident(tablename))) FROM pg_tables WHERE schemaname='{schema}'").scalar())
        return report
    finally:
        if engine is not None: engine.dispose()
        with admin.begin() as db:
            execute(db,'DROP SCHEMA '+schema+' CASCADE')
        admin.dispose()


def main():
    url=os.environ['BMT_DISCOVERY_TEST_DATABASE_URL']
    parsed=make_url(url)
    assert parsed.host in ('127.0.0.1','localhost') and parsed.database=='bmt_discovery_lab'
    reports=[]
    for size in ((100001,) if '--small' in sys.argv else (100001,1000000)):
        report=run_level(url,size)
        reports.append(report)
        (FOLDER/'scale-results.json').write_text(json.dumps({'scope':'Local synthetic TestClient/PostgreSQL reader probe; not network or million-DAU capacity',
            'levels':reports},indent=2)+'\n')
        print(json.dumps({k:v for k,v in report.items() if k!='plans'}),flush=True)


if __name__=='__main__': main()
