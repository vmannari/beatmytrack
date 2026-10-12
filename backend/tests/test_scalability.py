"""Complexity, traffic, isolation and failure regressions for the scalability review."""
import asyncio
import errno
import gzip
import json
import uuid
from dataclasses import replace
from pathlib import Path

import httpx
import pytest
import yaml
from fastapi import HTTPException
from sqlalchemy import event, select, text, update
from starlette.responses import JSONResponse
from test_domains import domain as domain_fixture
from test_domains import headers, public_course, submit, ticket
from test_rivalry import add_finishes, join, rivalry_ticket, seed

from bmt_backend.backup_guard import begin, end
from bmt_backend.identity_models import Player
from bmt_backend.load_fixtures import pack_replay
from bmt_backend.maintenance import archive_closed_weeks, cleanup, retain
from bmt_backend.middleware import RequestBoundary
from bmt_backend.object_models import ObjectPin
from bmt_backend.replay_wire import unpack_replay
from bmt_backend.rivalry import skill_score, snapshot
from bmt_backend.rivalry_models import RivalryArchivedBest, RivalryBest, RivalryGroup, RivalryTicket
from bmt_backend.track_models import IdempotencyRecord, QueueCapacity, Run, TrackVersion, now, replay_response
from bmt_backend.verifier import validate_replay
from bmt_backend.worker import process_one

domain = domain_fixture


def test_production_worker_writes_and_pool_budget_is_explicit():
    compose=yaml.safe_load((Path(__file__).parents[1]/"deploy/compose.yaml").read_text())
    worker=compose["services"]["worker"]
    assert "objects:/var/lib/bmt/objects" in worker["volumes"]
    assert all(not entry.endswith(":ro") for entry in worker["volumes"] if entry.startswith("objects:"))
    assert worker["environment"]["BMT_DATABASE_POOL_SIZE"]=="2"
    assert worker["environment"]["BMT_DATABASE_POOL_OVERFLOW"]=="0"
    assert worker["environment"]["BMT_DATABASE_POOL_TIMEOUT_SECONDS"]=="3"


def test_compact_codec_preserves_every_channel_and_receipt():
    frames=[[127,255,0,5,2],[-127,0,255],[0,128,0,255]]+[[0,255,0]]*12
    value={"schema":"bmt-replay-v2","frames":frames,"rewinds":[{"receipt_id":str(uuid.uuid4()),
        "input_offset":8,"from_tick":8,"to_tick":3}]}
    wire=pack_replay(value)
    assert unpack_replay(wire)==value
    validate_replay(unpack_replay(wire))
    for change in ({"frame_count":True},{"frame_count":216001},{"controls":wire["controls"]+"A"},
                   {"controls":"!"*len(wire["controls"])},{"extra":1}):
        with pytest.raises(HTTPException):
            unpack_replay({**wire,**change})


def test_compressed_upload_and_raw_retry_have_identical_identity(domain):
    version,_=public_course(domain)
    issued=ticket(domain,version,"Alice")
    replay={"schema":"bmt-replay-v1","frames":[[0,255,0,0,1]]+[[0,255,0,0]]*99}
    payload={"ticket_id":issued["ticket_id"],"replay":pack_replay(replay)}
    key="compressed-retry-key"
    auth=headers(domain,"Alice",key)
    first=domain.client.post("/v1/runs",content=gzip.compress(json.dumps(payload).encode()),
        headers={**auth,"Content-Type":"application/json","Content-Encoding":"gzip"})
    assert first.status_code==202,first.text
    retry=domain.client.post("/v1/runs",json={"ticket_id":issued["ticket_id"],"replay":replay},headers=auth)
    assert retry.status_code==202 and retry.json()["run_id"]==first.json()["run_id"]
    with domain.factory() as session:
        assert session.get(QueueCapacity,1).pending==1
    assert process_one(domain.app)
    batch=domain.client.get("/v1/runs/status",params={"ids":first.json()["run_id"]},headers=headers(domain,"Alice"))
    assert batch.json()["items"][0]["status"]=="verified"
    assert domain.client.get("/v1/runs/status",params={"ids":first.json()["run_id"]},headers=headers(domain,"Bob")).json()["items"]==[]


def test_compression_bombs_truncation_and_concatenated_members_are_bounded(auth_client):
    headers={"Content-Type":"application/json","Content-Encoding":"gzip"}
    bomb=gzip.compress(b'"'+b"a"*32769+b'"')
    assert auth_client.post("/v1/auth/google",content=bomb,headers=headers).status_code==413
    valid=gzip.compress(b"{}")
    for body in (valid[:-2],valid+valid,b"not-gzip"):
        assert auth_client.post("/v1/auth/google",content=body,headers=headers).status_code==400
    assert auth_client.post("/v1/auth/google",content=valid,headers={**headers,"Content-Encoding":"br"}).status_code==415


def test_large_body_slots_cover_endpoint_lifetime(auth_app,monkeypatch):
    monkeypatch.setattr("bmt_backend.middleware.check_budget",lambda *_a,**_kw:True)
    async def exercise():
        release=asyncio.Event();started=asyncio.Event();live=[0]
        async def handler(scope,receive,send):
            assert "bounded_json" in scope["state"]
            live[0]+=1
            if live[0]==2:
                started.set()
            await release.wait()
            live[0]-=1
            await JSONResponse({"ok":True})(scope,receive,send)
        boundary=RequestBoundary(handler,replace(auth_app.state.settings,upload_concurrency=2),auth_app.state.session_factory)
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=boundary),base_url="http://test") as client:
            body={"frames":[[0,255,0]]*1000}
            first=asyncio.create_task(client.post("/v1/runs",json=body))
            second=asyncio.create_task(client.post("/v1/runs",json=body))
            await asyncio.wait_for(started.wait(),2)
            busy=await client.post("/v1/runs",json=body)
            assert busy.status_code==503 and busy.json()["detail"]=="REQUEST_VALIDATION_BUSY"
            assert live[0]==2
            release.set()
            assert [r.status_code for r in await asyncio.gather(first,second)]==[200,200]
            assert (await client.post("/v1/runs",json=body)).status_code==200
    asyncio.run(exercise())


def test_optional_ghost_storage_failure_does_not_delay_scoring_or_hold_db_locks(domain,monkeypatch):
    seed(domain)
    group=join(domain)
    issued=rivalry_ticket(domain,group["group_id"])
    run=submit(domain,issued,"Alice")
    original=domain.app.state.verifier.verify_run
    def with_ghost(*args,**kwargs):
        value=original(*args,**kwargs)
        ticks=value["time_ticks"]
        return {**value,"ghost":{"ticks":ticks,"poses":[[0,0,0,0,0,0,0],[ticks,0,0,0,0,0,0]]}}
    monkeypatch.setattr(domain.app.state.verifier,"verify_run",with_ghost)
    store=domain.app.state.blobs
    original_put=store.put_json
    def broken(_value):
        if domain.postgres:
            with domain.factory() as session:
                # It must be possible to admit unrelated work during object fsync.
                session.execute(text("SELECT id FROM queue_capacity WHERE id=1 FOR UPDATE NOWAIT"))
        raise OSError(errno.EROFS,"injected read-only storage")
    monkeypatch.setattr(store,"put_json",broken)
    assert process_one(domain.app)
    with domain.factory() as session:
        row=session.get(Run,run["run_id"])
        assert row.status=="verified" and row.failure_code is None and row.attempts==1 and row.ghost_hash is None
        best = session.scalar(select(RivalryBest).where(RivalryBest.group_id==group["group_id"]))
        assert best.run_id==row.id and session.get(QueueCapacity,1).pending==0
    monkeypatch.setattr(store,"put_json",original_put)
    assert not process_one(domain.app)
    with domain.factory() as session:
        row=session.get(Run,run["run_id"])
        assert row.status=="verified" and row.attempts==1 and row.ghost_hash is None


def test_skill_is_two_queries_for_twenty_boards_and_visibility_is_exact(domain):
    versions=seed(domain,20)
    with domain.factory() as session:
        fifth=Player(display_name="Fifth test racer");session.add(fifth);session.flush()
        actors=[domain.players[name] for name in ("Alice","Bob","Carol","Creator")]+[fifth.id]
        session.commit()
    for version in versions:
        add_finishes(domain,version,5,same_players=actors)
    statements=[]
    def record(_c,_cur,sql,_params,_context,_many):
        statements.append(sql)
    event.listen(domain.app.state.engine,"before_cursor_execute",record)
    try:
        with domain.factory() as session:
            result=skill_score(session,actors[0],"compact",domain.app.state.verifier.manifest(),now())
        assert result==1000 and len(statements)==2
    finally:
        event.remove(domain.app.state.engine,"before_cursor_execute",record)
    with domain.factory() as session:
        player=session.get(Player,actors[-1]);player.disabled=True;session.commit()
        assert skill_score(session,actors[0],"compact",domain.app.state.verifier.manifest(),now()) is None
        version=session.get(TrackVersion,versions[0])
        assert version.verified_finishers==4


def test_snapshot_is_batched_read_and_etag_rechecks_visibility(domain):
    seed(domain)
    joined=join(domain)
    statements=[]
    def record(_c,_cur,sql,_params,_context,_many):
        statements.append(sql)
    with domain.factory() as session:
        group=session.get(RivalryGroup,joined["group_id"])
        event.listen(domain.app.state.engine,"before_cursor_execute",record)
        try:
            value=snapshot(session,group,domain.players["Alice"])
        finally:
            event.remove(domain.app.state.engine,"before_cursor_execute",record)
    assert len(statements)==4 and not any("FOR UPDATE" in sql for sql in statements)
    assert len(value["tracks"])==5
    path=f"/v1/rivalry/{joined['group_id']}"
    first=domain.client.get(path,headers=headers(domain,"Alice"))
    assert first.status_code==200 and first.headers.get("content-encoding")=="gzip"
    auth={**headers(domain,"Alice"),"If-None-Match":first.headers["etag"]}
    same=domain.client.get(path,headers=auth)
    assert same.status_code==304 and not same.content and same.headers["x-server-time"]
    with domain.factory() as session:
        session.get(Player,domain.players["Creator"]).disabled=True;session.commit()
    changed=domain.client.get(path,headers=auth)
    assert changed.status_code==200 and all(not row["available"] for row in changed.json()["tracks"])


def test_online_gc_respects_publication_pins_and_backup_without_stopping_writers(domain):
    blobs=domain.app.state.blobs
    key=blobs.put_json({"temporary-publication":"test"})
    import os
    old=now()-100*86400;os.utime(blobs._path(key),(old,old))
    assert retain(domain.factory,blobs,apply=True,online=True)["orphaned_objects"]==0
    guard=begin(domain.factory)
    assert blobs.put_json({"writer-during-backup":True})
    with pytest.raises(RuntimeError,match="paused"):
        retain(domain.factory,blobs,apply=True,online=True)
    with pytest.raises(RuntimeError,match="token"):
        end(domain.factory,"wrong-token")
    end(domain.factory,guard)
    with domain.factory() as session:
        session.execute(update(ObjectPin).where(ObjectPin.digest==key).values(expires_at=0));session.commit()
    assert retain(domain.factory,blobs,apply=True,online=True)["orphaned_objects"]==1
    assert not blobs._path(key).exists()


def test_closed_week_retains_scores_and_releases_optional_evidence(domain):
    versions=seed(domain)
    joined=join(domain)
    issued=rivalry_ticket(domain,joined["group_id"])
    run=submit(domain,issued,"Alice")
    assert process_one(domain.app)
    with domain.factory() as session:
        group=session.get(RivalryGroup,joined["group_id"])
        original=snapshot(session,group,domain.players["Alice"])
        group.ends_at=now()-100*86400;session.commit()
    assert archive_closed_weeks(domain.factory,apply=True)==1
    assert archive_closed_weeks(domain.factory,apply=True)==0
    with domain.factory() as session:
        group=session.get(RivalryGroup,joined["group_id"])
        archived=snapshot(session,group,domain.players["Alice"])
        assert archived["standings"]==original["standings"]
        assert session.scalar(select(RivalryArchivedBest)).time_ticks==original["tracks"][0]["entries"][0]["ticks"]
        assert session.scalar(select(RivalryBest)) is None and session.scalar(select(RivalryTicket)) is None
        # The public PB remains authoritative and keeps its replay evidence.
        assert session.get(Run,run["run_id"]) is not None
        assert all(not item["available"] for item in archived["tracks"])
    assert versions


def test_expiring_retry_keys_are_rejected_after_pruning_and_legacy_keys_remain(domain):
    stamp=now()-100*86400
    old=f"v2.{stamp}."+"a"*48
    with domain.factory() as session:
        for key in (old,"legacy-permanent-retry"):
            session.add(IdempotencyRecord(player_id=domain.players["Alice"],scope="test",key=key,
                request_hash="0"*64,response={"retired":True},created_at=stamp))
        session.commit()
    assert cleanup(domain.factory)["expired_retry_keys"]==1
    with domain.factory() as session:
        assert session.get(IdempotencyRecord,(domain.players["Alice"],"test","legacy-permanent-retry")) is not None
        with pytest.raises(HTTPException) as error:
            replay_response(session,domain.players["Alice"],"test",old,{})
        assert error.value.status_code==410


def test_finalization_db_failure_keeps_fenced_job_recoverable(domain):
    from sqlalchemy.exc import OperationalError
    version,_=public_course(domain)
    run=submit(domain,ticket(domain,version,"Alice"),"Alice")
    failed=[False]
    def fault(_c,_cur,sql,parameters,_ctx,_many):
        if not failed[0] and sql.startswith("UPDATE runs SET") and "verified" in str(parameters):
            failed[0]=True
            raise OperationalError("injected finalization failure",{},Exception("disposable test"))
    event.listen(domain.app.state.engine,"before_cursor_execute",fault)
    try:
        with pytest.raises(OperationalError):process_one(domain.app)
    finally:
        event.remove(domain.app.state.engine,"before_cursor_execute",fault)
    with domain.factory() as session:
        row=session.get(Run,run["run_id"])
        assert row.status=="verifying" and row.lease_token and row.attempts==1
        row.lease_until=0;session.commit()
    assert process_one(domain.app)
    with domain.factory() as session:
        row=session.get(Run,run["run_id"])
        assert row.status=="verified" and row.attempts==2 and session.get(QueueCapacity,1).pending==0


def test_aggregate_cache_coalesces_concurrent_cold_reads(auth_app):
    import threading
    import time
    from concurrent.futures import ThreadPoolExecutor

    from bmt_backend.board_cache import cached
    calls=[0]; barrier=threading.Barrier(12)
    def reader(_index):
        with auth_app.state.session_factory() as session:
            barrier.wait(timeout=5)
            def compute():
                calls[0]+=1;time.sleep(.04)
                return {"exact":100}
            return cached(session,("hot-board",1),compute)
    with ThreadPoolExecutor(max_workers=12) as pool:
        assert list(pool.map(reader,range(12)))==[{"exact":100}]*12
    assert calls[0]==1


def test_gc_racing_publication_recreates_before_reference_commit(domain,monkeypatch):
    if not domain.postgres:pytest.skip("PostgreSQL row-lock race")
    import os
    import threading
    from concurrent.futures import ThreadPoolExecutor
    blobs=domain.app.state.blobs;value={"gc-race":"synthetic"};key=blobs.put_json(value)
    os.utime(blobs._path(key),(now()-100*86400,)*2)
    with domain.factory() as session:
        session.execute(update(ObjectPin).where(ObjectPin.digest==key).values(expires_at=0));session.commit()
    entered,release=threading.Event(),threading.Event()
    original=blobs.store.delete
    def deleting(digest):
        assert digest==key;entered.set();assert release.wait(3);original(digest)
    monkeypatch.setattr(blobs.store,"delete",deleting)
    with ThreadPoolExecutor(max_workers=2) as pool:
        collecting=pool.submit(retain,domain.factory,blobs,apply=True,online=True)
        assert entered.wait(3)
        publishing=pool.submit(blobs.put_json,value)
        assert not publishing.done()
        release.set()
        assert collecting.result(timeout=5)["orphaned_objects"]==1
        assert publishing.result(timeout=5)==key
    assert blobs.get_json(key)==value


def test_join_retry_recovers_committed_membership_after_snapshot_failure(domain,monkeypatch):
    import bmt_backend.rivalry as api
    from bmt_backend.rivalry_models import RivalryMember
    seed(domain)
    original=api.snapshot
    def broken(*_a,**_kw):raise OSError("injected snapshot failure after durable join")
    monkeypatch.setattr(api,"snapshot",broken)
    auth=headers(domain,"Alice","recoverable-join")
    failed=domain.client.post("/v1/rivalry/join",json={"vehicle_id":"compact"},headers=auth)
    assert failed.status_code==503
    with domain.factory() as session:
        record=session.get(IdempotencyRecord,(domain.players["Alice"],"rivalry_join","recoverable-join"))
        assert record.response["_rivalry_snapshot_pending"]
        gid=record.response["group_id"]
        assert session.get(RivalryGroup,gid).member_count==1
    monkeypatch.setattr(api,"snapshot",original)
    recovered=domain.client.post("/v1/rivalry/join",json={"vehicle_id":"compact"},headers=auth)
    assert recovered.status_code==200 and recovered.json()["group_id"]==gid
    assert domain.client.post("/v1/rivalry/join",json={"vehicle_id":"compact"},headers=auth).json()==recovered.json()
    with domain.factory() as session:
        assert session.get(RivalryMember,(gid,domain.players["Alice"])) is not None
        assert session.get(RivalryGroup,gid).member_count==1


def test_authenticated_budgets_are_independent_behind_one_nat(auth_app,auth_client,sign_in):
    first=sign_in("nat-racer-one")
    second=sign_in("nat-racer-two")
    auth_app.state.settings=replace(auth_app.state.settings,rate_limit_per_minute=2)
    a={"Authorization":"Bearer "+first["access_token"]}
    b={"Authorization":"Bearer "+second["access_token"]}
    assert [auth_client.get("/v1/me",headers=a).status_code for _ in range(3)]==[200,200,429]
    assert [auth_client.get("/v1/me",headers=b).status_code for _ in range(2)]==[200,200]


def test_concurrent_restriction_and_pb_improvement_keep_projections_exact(domain):
    if not domain.postgres:pytest.skip("PostgreSQL visibility writer race")
    import threading
    from concurrent.futures import ThreadPoolExecutor

    from bmt_backend.track_models import Board, BoardTimeCount, PersonalBest
    version,bid=public_course(domain)
    submit(domain,ticket(domain,version,"Alice"),"Alice",frames=40)
    assert process_one(domain.app)
    submit(domain,ticket(domain,version,"Alice"),"Alice",frames=20)
    paused,release=threading.Event(),threading.Event()
    def before_pb(_c,_cur,sql,_params,_ctx,_many):
        if sql.startswith("INSERT INTO personal_bests"):
            paused.set();assert release.wait(3)
    def restrict():
        with domain.factory() as session:
            player=session.scalar(select(Player).where(Player.id==domain.players["Alice"]).with_for_update())
            player.disabled=True;session.commit()
    event.listen(domain.app.state.engine,"before_cursor_execute",before_pb)
    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            verifying=pool.submit(process_one,domain.app)
            assert paused.wait(3)
            restricting=pool.submit(restrict)
            assert not restricting.done()
            release.set()
            assert verifying.result(timeout=5)
            restricting.result(timeout=5)
    finally:
        release.set();event.remove(domain.app.state.engine,"before_cursor_execute",before_pb)
    with domain.factory() as session:
        assert session.get(PersonalBest,(bid,domain.players["Alice"])).time_ticks==100
        assert session.get(Board,bid).public_count==1
        assert sum(row.public_count for row in session.scalars(select(BoardTimeCount).where(BoardTimeCount.board_id==bid)))==1
