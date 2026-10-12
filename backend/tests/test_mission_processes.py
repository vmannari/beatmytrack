"""Real loopback processes and many-player recovery; never deploy these helpers."""
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest
from sqlalchemy import select, text
from test_replica_failures import auth, payload, port, published, race_ticket, sign_in, worker
from test_replica_failures import replicas as replicas_fixture

from bmt_backend.track_models import LapPersonalBest, PersonalBest, QueueCapacity, Run

replicas = replicas_fixture


def until(predicate,timeout=25):
    deadline=time.monotonic()+timeout
    while time.monotonic()<deadline:
        if predicate():return
        threading.Event().wait(.05)
    raise AssertionError("Owned process recovery deadline exceeded")


def drained(r):
    with r.factory() as session:return session.get(QueueCapacity,1).pending==0


def complete(r,submissions):
    with r.factory() as session:
        return all(session.get(Run,row).status=="verified" for row in submissions)


def saved_request(child,token,data,key,*,return_queue_full=False):
    """Model durable client retry on explicitly advertised admission pressure."""
    for attempt in range(12):
        reply=child.client.post("/v1/runs",headers=auth(token,key),json=data)
        if reply.status_code==202 or return_queue_full and reply.status_code==429:return reply
        detail=reply.json().get("detail","")
        assert reply.status_code==429 or reply.status_code==503 and detail=="REQUEST_VALIDATION_BUSY",reply.text
        delay=float(reply.headers.get("retry-after","1"))
        # Stable per-operation jitter disperses reconnecting clients; retries
        # retain the exact original key/body rather than minting new attempts.
        jitter=(sum(key.encode())%17)/100
        threading.Event().wait(min(2,max(.05,delay))+jitter)
    raise AssertionError("Owned saved submission did not recover within bounded retries")


def test_all_api_and_worker_processes_restart_with_accepted_jobs(replicas):
    version=published(replicas)
    players=[sign_in(replicas,f"Restart driver {i}") for i in range(6)]
    saved=[]
    for i,token in enumerate(players):
        issued=race_ticket(replicas,version,token)
        response=replicas.a.client.post("/v1/runs",headers=auth(token,f"restart-save-{i}"),json=payload(issued))
        assert response.status_code==202;saved.append((token,issued,response.json()["run_id"]))
    paused=worker(replicas,pause=True)
    until(lambda:Path(str(paused.prefix)+".claimed").exists(),10)
    for child in (replicas.a,replicas.b,paused):replicas.processes.stop(child,kill=True)
    with replicas.factory() as session:
        for row in session.scalars(select(Run).where(Run.status=="verifying")):row.lease_until=0
        session.commit()
    replicas.a=replicas.processes.start("api",api_port=port())
    replicas.b=replicas.processes.start("api",api_port=port())
    replicas.processes.start("worker",continuous=True)
    for i,(token,issued,run_id) in enumerate(saved):
        retried=replicas.b.client.post("/v1/runs",headers=auth(token,f"restart-save-{i}"),json=payload(issued))
        assert retried.status_code==202 and retried.json()["run_id"]==run_id
        assert replicas.a.client.get("/v1/me",headers=auth(token)).status_code==200
    until(lambda:complete(replicas,[row for _,_,row in saved]) and drained(replicas))
    with replicas.factory() as session:
        for token,_,run_id in saved:
            p=token["player"]["id"];run=session.get(Run,run_id)
            assert session.get(PersonalBest,(run.board_id,p)).run_id==run_id
            assert session.get(LapPersonalBest,(run.board_id,p)).time_ticks==20


def test_slow_replica_storage_is_bounded_and_recovers_without_restart(replicas):
    version=published(replicas);token=sign_in(replicas,"Slow storage driver")
    issued=race_ticket(replicas,version,token)
    replicas.a.fault.write_text("stall")
    assert replicas.a.client.get("/__fixture/invalidate-readiness").status_code==200
    try:
        with ThreadPoolExecutor(max_workers=10) as pool:
            reads=[pool.submit(replicas.a.client.get,"/readyz") for _ in range(10)]
            until(lambda:Path(str(replicas.a.fault)+".stalled").exists(),5)
            assert replicas.a.client.get("/healthz").status_code==200
            accepted=replicas.b.client.post("/v1/runs",headers=auth(token,"healthy-during-stall"),json=payload(issued))
            assert accepted.status_code==202
            replies=[job.result(timeout=5) for job in reads]
            assert all(reply.status_code==503 for reply in replies)
            assert replicas.a.client.get("/__fixture/probe-threads").json()["count"]==1
    finally:replicas.a.fault.unlink(missing_ok=True)
    until(lambda:replicas.a.client.get("/readyz").status_code==200,12)
    worker(replicas)
    with replicas.factory() as session:assert session.get(Run,accepted.json()["run_id"]).status=="verified"


def test_connection_loss_during_paused_verification_and_lease_reassignment(replicas):
    if not replicas.postgres:pytest.skip("PostgreSQL dropped connection plus real worker processes")
    version=published(replicas);token=sign_in(replicas,"Disconnected worker driver")
    issued=race_ticket(replicas,version,token)
    accepted=replicas.a.client.post("/v1/runs",headers=auth(token,"connection-loss-save"),json=payload(issued))
    assert accepted.status_code==202
    run_id=accepted.json()["run_id"]
    old=worker(replicas,pause=True)
    marker=Path(str(old.prefix)+".backend-pid")
    try:
        until(marker.exists,10)
        with replicas.factory() as session:
            assert session.scalar(text("SELECT pg_terminate_backend(:pid)"),{"pid":int(marker.read_text())})
            row=session.get(Run,run_id);assert row.status=="verifying"
            row.lease_until=0;session.commit()
        worker(replicas)
        Path(str(old.prefix)+".release").touch()
        assert old.process.wait(timeout=8)==0
        with replicas.factory() as session:
            run=session.get(Run,run_id)
            assert run.status=="verified" and run.time_ticks==100
            assert session.get(PersonalBest,(run.board_id,token["player"]["id"])).time_ticks==100
            assert session.get(LapPersonalBest,(run.board_id,token["player"]["id"])).time_ticks==20
            assert session.get(QueueCapacity,1).pending==0
    finally:replicas.processes.stop(old,kill=True)


def test_reconnection_wave_many_players_repeated_uploads_and_workers(replicas):
    if not replicas.postgres:pytest.skip("Concurrent production submissions require PostgreSQL")
    version=published(replicas)
    players=[sign_in(replicas,f"Recovery wave {i}") for i in range(32)]
    workers=[replicas.processes.start("worker",continuous=True) for _ in range(2)]
    observed=[]
    for round_number in range(2):
        jobs=[]
        for i,token in enumerate(players):
            issued=race_ticket(replicas,version,token)
            data=payload(issued);data["replay"]["frames"]=[[0,255,0]]*(25-round_number*5)
            jobs.append((token,data,f"wave-{round_number}-{i}"))
        def send(index,round_jobs=jobs):
            token,data,key=round_jobs[index//3]
            child=(replicas.a,replicas.b)[index%2]
            reply=saved_request(child,token,data,key)
            return index//3,reply.json()["run_id"]
        with ThreadPoolExecutor(max_workers=12) as pool:replies=list(pool.map(send,range(len(jobs)*3)))
        unique={i:{row for owner,row in replies if owner==i} for i in range(len(jobs))}
        assert all(len(rows)==1 for rows in unique.values())
        run_ids=[next(iter(unique[i])) for i in range(len(jobs))];observed.extend(run_ids)
        until(lambda ids=run_ids:complete(replicas,ids) and drained(replicas),35)
    with replicas.factory() as session:
        assert len(set(observed))==64
        assert all(session.get(Run,run_id).status=="verified" for run_id in observed)
        for token in players:
            pb=session.scalar(select(PersonalBest).where(PersonalBest.player_id==token["player"]["id"]))
            lap=session.get(LapPersonalBest,(pb.board_id,pb.player_id))
            assert pb.time_ticks==100 and lap.time_ticks==20
        assert session.get(QueueCapacity,1).pending==0
    assert all(child.process.poll() is None for child in workers)


def test_low_capacity_backpressure_preserves_each_saved_attempt(replicas):
    if not replicas.postgres:pytest.skip("Concurrent queue admission needs PostgreSQL")
    from dataclasses import replace
    version=published(replicas)
    replicas.processes.stop(replicas.a);replicas.processes.stop(replicas.b)
    replicas.processes.settings=replace(replicas.processes.settings,max_queued_runs=4)
    replicas.a=replicas.processes.start("api",api_port=port())
    replicas.b=replicas.processes.start("api",api_port=port())
    players=[sign_in(replicas,f"Backpressure {i}") for i in range(8)]
    saved=[(token,payload(race_ticket(replicas,version,token)),f"bounded-save-{i}") for i,token in enumerate(players)]
    def send(i):
        token,data,key=saved[i]
        return saved_request(replicas.a,token,data,key,return_queue_full=True)
    with ThreadPoolExecutor(max_workers=8) as pool:replies=list(pool.map(send,range(8)))
    codes=[(r.status_code,r.json().get("detail","")) for r in replies]
    assert sum(reply.status_code==202 for reply in replies)==4,codes
    assert sum(reply.status_code==429 for reply in replies)==4,codes
    with replicas.factory() as session:assert session.get(QueueCapacity,1).pending==4
    replicas.processes.start("worker",continuous=True)
    until(lambda:drained(replicas))
    results=[]
    for i,reply in enumerate(replies):
        if reply.status_code==429:
            until(lambda:drained(replicas))
            reply=send(i)
        assert reply.status_code==202
        results.append(reply.json()["run_id"])
    until(lambda:complete(replicas,results) and drained(replicas))
    assert len(set(results))==8
