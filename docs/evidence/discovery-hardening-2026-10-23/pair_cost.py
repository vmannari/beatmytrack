"""Paired physical-index, bulk-insert and repeat-pair WAL probes; owned DB only."""
import json
import os
from pathlib import Path
import time
import uuid

from sqlalchemy.engine import make_url

from bmt_backend.db import make_engine
from profile import sizes, sql

FOLDER=Path(__file__).parent


def measure(engine, table, clustered):
    stamp=int(time.time()); expiry=str(stamp-1) if clustered else f"{stamp}-g/16-1"
    with engine.connect().execution_options(isolation_level='AUTOCOMMIT') as db:sql(db,'CHECKPOINT')
    with engine.connect() as db:wal=sql(db,'SELECT pg_current_wal_lsn()::text').scalar()
    started=time.perf_counter()
    with engine.begin() as db:
        sql(db,'SET LOCAL statement_timeout=120000')
        sql(db,f"""INSERT INTO {table}(track_id,player_id,partition,last_at,expires_at,counted)
            SELECT tid,md5('cost-player-'||(g/2000))::uuid::text,
            strpos('0123456789abcdef',substr(tid,1,1))-1,({expiry})-604800,{expiry},true
            FROM (SELECT g,md5('cost-track-'||(g%2000))::uuid::text tid
                  FROM generate_series(0,199999) g) p""")
        sql(db,'ANALYZE '+table)
    insert_seconds=time.perf_counter()-started
    with engine.connect() as db:
        insert_wal=int(sql(db,'SELECT pg_wal_lsn_diff(pg_current_wal_lsn(),:wal)',{'wal':wal}).scalar())
        relation=dict(sql(db,"""SELECT pg_table_size(:t::regclass)::bigint AS heap,
            pg_indexes_size(:t::regclass)::bigint AS indexes,
            pg_total_relation_size(:t::regclass)::bigint AS total""".replace(':t::regclass','CAST(:t AS regclass)'),{'t':table}).one()._mapping)
        index_bytes=int(sql(db,'SELECT pg_relation_size(CAST(:t AS regclass))',{'t':table+'_expire'}).scalar())
        ordering='expires_at,track_id,player_id' if table=='wide_pairs' else 'expires_at'
        plan=sql(db,f'EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) SELECT * FROM {table} '
            f'WHERE partition=0 AND expires_at<{stamp} ORDER BY {ordering} LIMIT 128').scalar()
    with engine.connect().execution_options(isolation_level='AUTOCOMMIT') as db:sql(db,'CHECKPOINT')
    with engine.connect() as db:wal=sql(db,'SELECT pg_current_wal_lsn()::text').scalar()
    started=time.perf_counter()
    with engine.begin() as db:
        rows=sql(db,f"UPDATE {table} SET last_at=last_at+60,expires_at=expires_at+60 "
            "WHERE player_id=md5('cost-player-0')::uuid::text").rowcount
    refresh_seconds=time.perf_counter()-started
    with engine.connect() as db:
        refresh_wal=int(sql(db,'SELECT pg_wal_lsn_diff(pg_current_wal_lsn(),:wal)',{'wal':wal}).scalar())
    return {'rows':200000,'expiry_index_bytes':index_bytes,'relation_bytes':relation,
        'insert_seconds':round(insert_seconds,3),'insert_wal_bytes':insert_wal,
        'refresh_rows':rows,'refresh_seconds':round(refresh_seconds,3),'refresh_wal_bytes':refresh_wal,
        'bounded_expiry_plan':plan}


def main():
    url=os.environ['BMT_DISCOVERY_TEST_DATABASE_URL'];parsed=make_url(url)
    assert parsed.host in ('127.0.0.1','localhost') and parsed.database=='bmt_discovery_lab'
    admin=make_engine(url); reports=[]
    try:
        for clustered in (False,True):
            schema='bmt_load_'+uuid.uuid4().hex;engine=None
            try:
                with admin.begin() as db:sql(db,'CREATE SCHEMA '+schema)
                engine=make_engine(url,schema=schema)
                with engine.begin() as db:
                    for table in ('wide_pairs','compact_pairs'):
                        sql(db,f'CREATE TABLE {table}(track_id varchar(36),player_id varchar(36),partition integer NOT NULL,'
                            'last_at bigint NOT NULL,expires_at bigint NOT NULL,counted boolean NOT NULL,PRIMARY KEY(track_id,player_id))')
                        sql(db,f'CREATE INDEX {table}_player ON {table}(player_id,track_id)')
                        keys='partition,expires_at,track_id,player_id' if table=='wide_pairs' else 'partition,expires_at'
                        sql(db,f'CREATE INDEX {table}_expire ON {table}({keys})')
                row={'distribution':'equal expiry timestamps' if clustered else 'spread expiry timestamps'}
                row['before']=measure(engine,'wide_pairs',clustered)
                row['after']=measure(engine,'compact_pairs',clustered)
                row['expiry_index_reduction_percent']=round(100*(1-row['after']['expiry_index_bytes']/row['before']['expiry_index_bytes']),2)
                row['total_relation_reduction_percent']=round(100*(1-row['after']['relation_bytes']['total']/row['before']['relation_bytes']['total']),2)
                reports.append(row)
                (FOLDER/'pair-cost-results.json').write_text(json.dumps({'scope':'Paired local physical PostgreSQL tables; 200k exact-width pairs, checkpoint before WAL samples; bulk SQL is not worker throughput','profiles':reports},indent=2)+'\n')
                print(json.dumps({k:v for k,v in row.items() if k not in ('before','after')}),flush=True)
            finally:
                if engine is not None:engine.dispose()
                with admin.begin() as db:sql(db,'DROP SCHEMA '+schema+' CASCADE')
    finally:admin.dispose()


if __name__=='__main__':main()
