"""Bounded, measured storage/retention/logging experiments using current source.

Only the newly generated loopback PostgreSQL fixture and synthetic local objects
are used. Cloud operation counts are represented by local adapter calls, not a bill.
"""
import copy
import hashlib
import json
import logging
import math
import statistics
import sys
import time
import uuid
from collections import Counter
from dataclasses import replace
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
BUILD=ROOT/"build/backend-local-cost-simulation-2026-10-26"
sys.path.insert(0,str(ROOT/"backend"))
from sqlalchemy import event,func,insert,select,text,update
from database_probe import fixture_url
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.cost_archives import archive_once,retry_key
from bmt_backend.db import make_engine,make_session_factory
from bmt_backend.http_costs import HttpCostCounters
from bmt_backend.identity_models import Player
from bmt_backend.maintenance import retain
from bmt_backend.migrate import SCHEMA_HEAD,upgrade
from bmt_backend.object_models import ObjectPack,PackedObject
from bmt_backend.packed_storage import PackedBlobStore
from bmt_backend.storage import LocalBlobStore,canonical_json
from bmt_backend.track_models import (Board,IdempotencyRecord,LapPersonalBest,PersonalBest,Run,RunTicket,
    Track,TrackVersion,digest,now,replay_response)


def summary(values):
    rows=sorted(values)
    return {"count":len(rows),"p50_ms":statistics.median(rows),
        "p95_ms":rows[math.ceil(.95*len(rows))-1],"p99_ms":rows[math.ceil(.99*len(rows))-1],"max_ms":max(rows)}


def tree_bytes(path):
    return sum(p.stat().st_size for p in path.rglob("*") if p.is_file())


class SQLMeter:
    def __init__(self,engine):
        self.engine=engine
        self.counts=Counter()
        self.elapsed=0.0
        event.listen(engine,"before_cursor_execute",self.before)
        event.listen(engine,"after_cursor_execute",self.after)
    def before(self,connection,_cursor,statement,*_args):
        self.counts[statement.lstrip().split(None,1)[0].upper()]+=1
        connection.info["cost_lab_sql_start"]=time.perf_counter()
    def after(self,connection,*_args):
        self.elapsed+=time.perf_counter()-connection.info.pop("cost_lab_sql_start")
    def snapshot(self):
        return {"top_level_statements":sum(self.counts.values()),"types":dict(self.counts),"cursor_wall_ms":self.elapsed*1000}
    def reset(self):
        self.counts.clear();self.elapsed=0.0


def wal(engine):
    with engine.connect() as db:
        return str(db.scalar(text("SELECT pg_current_wal_insert_lsn()")))


def wal_diff(engine,start):
    with engine.connect() as db:
        return int(db.scalar(text("SELECT pg_wal_lsn_diff(pg_current_wal_insert_lsn(),:start)"),{"start":start}))


def relation(engine,name):
    assert name in ("domain_idempotency","packed_objects","object_packs","object_partitions")
    with engine.connect() as db:
        physical=db.scalar(text("SELECT pg_total_relation_size(CAST(:name AS regclass))"),{"name":name})
        count,payload=db.execute(text('SELECT count(*),coalesce(sum(pg_column_size(t)),0) FROM "'+name+'" t')).one()
        return {"rows":count,"live_tuple_bytes":int(payload),"allocated_heap_toast_index_bytes":int(physical)}


def packing(app,meter,count=512):
    original=json.loads((ROOT/"docs/evidence/cost-optimisation-implementation-2026-10-24/ghost-wire-fixture.json").read_text())["original"]
    plain=LocalBlobStore(str(BUILD/"individual-objects"))
    store=PackedBlobStore(LocalBlobStore(str(BUILD/"packed-objects")),app.state.session_factory,
        replace(app.state.settings,object_packing_enabled=True))
    def value(index):
        return {"fixture":"synthetic cost record", "index":index,"recording":original}
    keys,plain_times=[],[]
    started=time.perf_counter()
    for index in range(count):
        begin=time.perf_counter()
        keys.append(plain.put_json(value(index)))
        plain_times.append((time.perf_counter()-begin)*1000)
    plain_seconds=time.perf_counter()-started
    calls=Counter()
    put,get=store.io.put,store.io.get
    def counted_put(key,body):
        calls["physical_pack_writes"]+=1
        return put(key,body)
    def counted_get(key,offset,length):
        calls["range_reads"]+=1
        calls["range_bytes"]+=length
        return get(key,offset,length)
    store.io.put,store.io.get=counted_put,counted_get
    meter.reset();lsn=wal(app.state.engine)
    durations=[]
    started=time.perf_counter()
    for index in range(count):
        begin=time.perf_counter()
        assert store.put_json(value(index))==keys[index]
        durations.append((time.perf_counter()-begin)*1000)
    intake_seconds=time.perf_counter()-started
    pending_bytes=relation(app.state.engine,"packed_objects")
    assert store.get_json(keys[0])==value(0)  # Authoritative pending bytes before publication.
    begin=time.perf_counter()
    while store.flush_once(force=True):
        pass
    flush_seconds=time.perf_counter()-begin
    intake_sql=meter.snapshot()
    intake_wal=wal_diff(app.state.engine,lsn)
    meter.reset()
    reads=[]
    for index in range(0,count,max(1,count//64)):
        begin=time.perf_counter()
        assert store.get_json(keys[index])==plain.get_json(keys[index])==value(index)
        reads.append((time.perf_counter()-begin)*1000)
    pending_value={"fixture":"unflushed record must survive restore","index":count}
    pending=store.put_json(pending_value)
    with app.state.session_factory() as db:
        packs=list(db.scalars(select(ObjectPack.records)))
        assert db.scalar(select(func.count()).select_from(PackedObject).where(PackedObject.pending.is_not(None)))==1
    result={"logical_records":count,"source":"Real2130sample recording repeated with distinct synthetic record identities",
        "individual":{"physical_object_writes":count,"physical_bytes":tree_bytes(plain.root),"write_seconds":plain_seconds,"put_latency":summary(plain_times)},
        "packed":{"physical_object_writes":calls["physical_pack_writes"],"physical_bytes":tree_bytes(store.store.root),
            "intake_seconds":intake_seconds,"flush_seconds":flush_seconds,"put_latency":summary(durations),
            "pending_sql_before_flush":pending_bytes,"sql_after_flush":relation(app.state.engine,"packed_objects"),
            "write_sql":intake_sql,"write_wal_bytes":intake_wal,"range_read_validation":summary(reads),
            "read_sql":meter.snapshot(),"range_requests":calls["range_reads"],"range_bytes":calls["range_bytes"],
            "records_per_pack":packs},"logical_identity_and_reads_exact":True,
        "physical_write_reduction_percent":100*(1-calls["physical_pack_writes"]/count),
        "qualifications":["Local fsync plus loopback PostgreSQL; no GCS latency or billing measurement",
            "Forced end-of-batch flush includes partially occupied hash partitions",
            "Independent record compression preserves byte volume; saving is primarily object operations",
            "PostgreSQL tmpfs is not persistent cloud SSD; WAL delta can include maintenance"]}
    manifest={"packed_keys":keys[::max(1,count//64)],"packed_indexes":list(range(0,count,max(1,count//64))),
        "pending_key":pending,"pending_value":pending_value}
    (BUILD/"restore-validation.json").write_text(json.dumps(manifest),encoding="utf-8")
    (OUT/"packing.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"packing_records":count,"physical_writes_before":count,"physical_writes_after":calls["physical_pack_writes"],
        "sql_wal_bytes":intake_wal}),flush=True)


def archives(app,meter,count=5000):
    players=[]
    with app.state.session_factory() as db:
        for i in range(10):
            player=Player(display_name="Synthetic cost player "+str(i),needs_username=False)
            db.add(player);db.flush();players.append(player.id)
        db.commit()
    stamp=now()-30*86400
    rows=[]
    for i in range(count):
        owner=players[i%len(players)]
        key="v2."+str(stamp)+"."+hashlib.sha256(str(i).encode()).hexdigest()[:48]
        body={"operation":i}
        response={"accepted_operation":i,"synthetic_detail":"acknowledged historical result; "*24}
        rows.append({"player_id":owner,"scope":"cost-lab","key":key,"created_at":stamp,
            "archive_key":retry_key(owner,"cost-lab",key),"request_hash":digest(body),"response":response})
    with app.state.session_factory() as db:
        db.execute(insert(IdempotencyRecord),rows);db.commit()
    before=relation(app.state.engine,"domain_idempotency")
    meter.reset();lsn=wal(app.state.engine);begin=time.perf_counter();batches=0
    while archive_once(app.state.session_factory,app.state.blobs,kind="retry",days=7,limit=500):
        batches+=1
        assert batches<=math.ceil(count/500)+1
    elapsed=time.perf_counter()-begin
    after=relation(app.state.engine,"domain_idempotency")
    assert after["rows"]==0
    roundtrips=[]
    for row in rows[::max(1,count//20)]:
        with app.state.session_factory() as db:
            begin=time.perf_counter()
            assert replay_response(db,row["player_id"],row["scope"],row["key"],{"operation":row["response"]["accepted_operation"]})==row["response"]
            roundtrips.append((time.perf_counter()-begin)*1000)
    (BUILD/"archive-restore-probes.json").write_text(json.dumps(rows[::max(1,count//20)]),encoding="utf-8")
    result={"receipts":count,"synthetic_accounts":len(players),"hot_before":before,"hot_after":after,
        "archive_batches":batches,"archive_seconds":elapsed,"archive_object_bytes":tree_bytes(Path(app.state.settings.object_dir)),
        "sql":meter.snapshot(),"wal_bytes":wal_diff(app.state.engine,lsn),"exact_cold_retries":summary(roundtrips),
        "all_sampled_replies_exact":True,"qualifications":["Archive replies are invented; no real player/financial data",
            "Deletion frees live rows/reusable pages, not necessarily allocated database files",
            "No production VACUUM FULL or disk shrink is performed"]}
    (OUT/"archives.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"archived_receipts":count,"hot_rows_after":after["rows"],"batches":batches,
        "allocated_bytes_before_after":[before["allocated_heap_toast_index_bytes"],after["allocated_heap_toast_index_bytes"]]}),flush=True)
    return players


def retention(app,players):
    from bmt_backend.contracts import current_manifest
    fixture=json.loads((ROOT/"backend/tests/fixtures/verified_oval.json").read_text())
    content=app.state.blobs.put_json(fixture["document"])
    manifest=current_manifest(fixture["expected_manifest"])
    issued=[]
    with app.state.session_factory() as db:
        track=Track(owner_id=players[0],official=True);db.add(track);db.flush()
        version=TrackVersion(track_id=track.id,number=1,name="Synthetic retention course",state="published",
            content_hash=content,manifest=manifest,published_at=now()-200*86400,discovery={"theme":"pine"})
        db.add(version);db.flush()
        board=Board(id=digest({"retention_fixture":version.id}),version_id=version.id,vehicle_id="compact",manifest=manifest)
        db.add(board);db.flush()
        for i in range(120):
            player=players[i%len(players)];age=(10,40,100)[i%3];stamp=now()-age*86400
            ticket=RunTicket(player_id=player,board_id=board.id,created_at=stamp,expires_at=stamp+7200)
            db.add(ticket);db.flush()
            run=Run(ticket_id=ticket.id,player_id=player,board_id=board.id,status="verified",created_at=stamp,
                finished_at=stamp,replay_hash=content,time_ticks=5000,lap_ticks=[1000]*5)
            db.add(run);db.flush();issued.append(run.id)
            if i<len(players):
                db.add(PersonalBest(board_id=board.id,player_id=player,run_id=run.id,time_ticks=5000,achieved_at=stamp))
                db.flush()
        db.commit()
    with app.state.session_factory() as db:
        protected=set(db.scalars(select(PersonalBest.run_id)))|set(db.scalars(select(LapPersonalBest.run_id)))
    policies={str(days):retain(app.state.session_factory,app.state.blobs,days=days,scan_objects=False) for days in (7,30,90)}
    applied=retain(app.state.session_factory,app.state.blobs,days=7,apply=True,online=True,scan_objects=False)
    with app.state.session_factory() as db:
        remaining=set(db.scalars(select(Run.id)))
        assert protected<=remaining and len(remaining)==120-applied["runs"]
    result={"synthetic_runs":120,"age_buckets_days":[10,40,100],"protected_pb_and_lap_run_count":len(protected),
        "candidate_runs_by_policy":{k:v["runs"] for k,v in policies.items()},"applied_seven_day_removed":applied["runs"],
        "remaining_runs":len(remaining),"all_protected_runs_retained":True,
        "scope":"Timestamped synthetic records exercise current retention; no server wall-clock or real retention policy changed"}
    (OUT/"retention.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(result),flush=True)


def logging_experiment():
    class Capture(logging.Handler):
        def __init__(self): super().__init__();self.rows=[]
        def emit(self,record): self.rows.append(record.getMessage())
    logger=logging.getLogger("bmt.requests");previous=(logger.handlers,logger.level,logger.propagate)
    capture=Capture();logger.handlers=[capture];logger.setLevel(logging.INFO);logger.propagate=False
    clock=[0.0]
    metrics=HttpCostCounters(Settings(http_success_sample_per_mille=10),clock=lambda:clock[0])
    value={"event":"http_request","route":"/v1/cost-lab/{id}","method":"GET","status":200,"duration_ms":15,
        "request_wire_bytes":0,"response_wire_bytes":400,"request_id":"0"*32}
    try:
        for i in range(10000): metrics.observe(value|{"request_id":f"{i:032x}"})
        state=metrics.snapshot()["rows"][0]
        assert state["requests"]==10000 and state["response_wire_bytes"]==4000000
        detail=[r for r in capture.rows if json.loads(r).get("event")=="http_request"]
        assert len(detail)==100
        metrics.flush()
        before=len(capture.rows)
        metrics.observe(value|{"status":503,"request_id":"f"*32})
        assert len(capture.rows)==before+1
        result={"successful_requests":10000,"success_detail_logs":len(detail),"aggregate_requests":state["requests"],
            "aggregate_response_bytes":state["response_wire_bytes"],"error_detail_retained":True,
            "success_detail_reduction_percent":99,"scope":"Actual application counter/sampler on synthetic request observations; provider logs excluded"}
        (OUT/"logging.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    finally:
        logger.handlers,logger.level,logger.propagate=previous


def main():
    settings=Settings(environment="test",database_url=fixture_url(),object_dir=str(BUILD/"archive-objects"),
        database_pool_size=4,database_pool_overflow=0)
    app=create_app(settings)
    upgrade(app.state.engine)
    meter=SQLMeter(app.state.engine)
    try:
        packing(app,meter)
        players=archives(app,meter)
        retention(app,players)
        logging_experiment()
        (OUT/"lab-summary.json").write_text(json.dumps({"schema":SCHEMA_HEAD,"postgres":True,
            "packing":"passed","archive_recovery":"passed","retention":"passed","logging":"passed",
            "cloud_calls":0,"live_player_records":0},indent=2)+"\n",encoding="utf-8")
    finally:
        app.state.blobs.close() if hasattr(app.state.blobs,"close") else None
        app.state.engine.dispose()


if __name__=="__main__":
    main()
