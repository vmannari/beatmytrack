"""Unusual failure sequences; synthetic verification, real durable SQL/blob paths."""
import asyncio
import errno
import os
import shutil
import sqlite3
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import event, func, select, text
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session, sessionmaker
from test_domains import FakeVerifier, headers, public_course, race, submit, ticket, upload
from test_domains import domain as domain_fixture

from bmt_backend.app import create_app
from bmt_backend.db import get_session, make_engine, make_session_factory
from bmt_backend.histogram_snapshots import refresh_all_for_diagnostics
from bmt_backend.identity_models import Player
from bmt_backend.maintenance import retain
from bmt_backend.readiness import DependencyFailure
from bmt_backend.storage import LocalBlobStore
from bmt_backend.track_models import (
    LapPersonalBest,
    PersonalBest,
    QueueCapacity,
    Run,
    RunTicket,
    TrackVersion,
    now,
)
from bmt_backend.worker import process_one

domain = domain_fixture


def body(issued, frames=20):
    return {"ticket_id":issued["ticket_id"],"replay":{"schema":"bmt-replay-v1","frames":[[0,255,0]]*frames}}


def assert_bests(d,board,player,run_id,ticks):
    with d.factory() as session:
        pb=session.get(PersonalBest,(board,d.players[player]))
        lap=session.get(LapPersonalBest,(board,d.players[player]))
        assert (pb.run_id,pb.time_ticks,lap.run_id,lap.time_ticks)==(run_id,ticks*5,run_id,ticks)


@pytest.mark.parametrize("phase",["upload","verification"])
def test_commit_succeeds_but_acknowledgement_is_lost(domain,monkeypatch,phase):
    version,board=public_course(domain)
    issued=ticket(domain,version,"Alice")
    payload=body(issued)
    if phase=="verification":queued=submit(domain,issued,"Alice")
    lost=[]
    class AmbiguousSession(Session):
        def flush(self,*args,**kwargs):
            target="queued" if phase=="upload" else "verified"
            if any(isinstance(row,Run) and row.player_id==domain.players["Alice"] and (
                   row.status==target or phase=="upload" and row in self.new and row.status is None)
                   for row in list(self.new)+list(self.dirty)):
                self.info["lost_commit_target"]=True
            return super().flush(*args,**kwargs)
        def commit(self):
            super().commit()  # Deliberately lose the acknowledgement AFTER durable commit.
            if self.info.pop("lost_commit_target",False) and not lost:
                lost.append(True)
                raise OperationalError("owned lost commit acknowledgement",{},Exception("connection disappeared"))
    replacement=sessionmaker(domain.app.state.engine,class_=AmbiguousSession,expire_on_commit=False)
    monkeypatch.setattr(domain.app.state,"session_factory",replacement)
    def unreliable_session():
        with replacement() as session:yield session
    domain.app.dependency_overrides[get_session]=unreliable_session
    calls=[];original=domain.app.state.verifier.verify_run
    def counted(*args,**kwargs):calls.append(True);return original(*args,**kwargs)
    monkeypatch.setattr(domain.app.state.verifier,"verify_run",counted)
    if phase=="upload":
        result=domain.client.post("/v1/runs",headers=headers(domain,"Alice","lost-upload-ack"),json=payload)
        assert result.status_code==503
        with domain.factory() as session:
            run=session.scalar(select(Run).where(Run.ticket_id==issued["ticket_id"]))
            assert run and run.status=="queued"
            run_id=run.id
        retry=domain.client.post("/v1/runs",headers=headers(domain,"Alice","lost-upload-ack"),json=payload)
        assert retry.status_code==202 and retry.json()["run_id"]==run_id
        assert process_one(domain.app)
    else:
        with pytest.raises(OperationalError):process_one(domain.app)
        run_id=queued["run_id"]
        assert_bests(domain,board,"Alice",run_id,20)
        assert not process_one(domain.app)  # Resolve the committed result, no repeated verification.
    assert lost==[True] and len(calls)==1
    assert_bests(domain,board,"Alice",run_id,20)
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(Run).where(Run.ticket_id==issued["ticket_id"]))==1
        assert session.get(QueueCapacity,1).pending==0


def test_accepted_upload_can_be_recovered_after_ticket_expiry(domain):
    version,board=public_course(domain)
    issued=ticket(domain,version,"Alice")
    payload=body(issued)
    first=domain.client.post("/v1/runs",headers=headers(domain,"Alice","before-outage"),json=payload)
    assert first.status_code==202
    assert process_one(domain.app)
    with domain.factory() as session:
        session.get(RunTicket,issued["ticket_id"]).expires_at=now()-1;session.commit()
    retry=domain.client.post("/v1/runs",headers=headers(domain,"Alice","after-outage-new-key"),json=payload)
    assert retry.status_code==202,retry.text
    assert retry.json()["run_id"]==first.json()["run_id"] and retry.json()["status"]=="verified"
    assert retry.json()["time_ticks"]==100 and retry.json()["lap_ticks"]==[20]*5
    conflict=domain.client.post("/v1/runs",headers=headers(domain,"Alice"),json=body(issued,21))
    assert conflict.status_code==409
    assert_bests(domain,board,"Alice",first.json()["run_id"],20)


def test_lost_resume_commit_acknowledgement_does_not_spend_twice(domain):
    from bmt_backend.resume_models import ResumeReceipt, ResumeWallet
    from bmt_backend.resumes import grant_verified
    _,_=public_course(domain)
    with domain.factory() as session:
        grant_verified(session,domain.players["Alice"],"award","mission-resume-award",2);session.commit()
    begun=domain.client.post("/v1/resume-races",headers=headers(domain,"Alice"),json={})
    assert begun.status_code==201
    lost=[]
    class LostResumeAck(Session):
        def commit(self):
            target=any(isinstance(row,ResumeReceipt) for row in list(self.new)+list(self.identity_map.values()))
            super().commit()
            if target and not lost:
                lost.append(True);raise OperationalError("owned committed resume ack lost",{},Exception("fixture"))
    factory=sessionmaker(domain.app.state.engine,class_=LostResumeAck,expire_on_commit=False)
    def unreliable():
        with factory() as session:yield session
    domain.app.dependency_overrides[get_session]=unreliable
    path=f"/v1/resume-races/{begun.json()['race_id']}/resumes"
    selection={"ordinal":1,"input_offset":120,"from_tick":120,"to_tick":0}
    first=domain.client.post(path,headers=headers(domain,"Alice","unknown-resume-commit"),json=selection)
    assert first.status_code==503
    recovered=domain.client.post(path,headers=headers(domain,"Alice","unknown-resume-commit"),json=selection)
    assert recovered.status_code==200 and lost==[True]
    with domain.factory() as session:
        assert session.get(ResumeWallet,domain.players["Alice"]).balance==1
        assert session.scalar(select(func.count()).select_from(ResumeReceipt))==1


def test_lost_competitive_commit_acknowledgement_preserves_exact_points(domain,monkeypatch):
    from test_rivalry import join, rivalry_ticket, seed

    from bmt_backend.rivalry_models import RivalryBest, RivalryTicket
    seed(domain);group=join(domain)
    issued=rivalry_ticket(domain,group["group_id"]);queued=submit(domain,issued,"Alice")
    lost=[]
    class LostPointsAck(Session):
        def commit(self):
            target=any(isinstance(row,Run) and row.id==queued["run_id"] and row.status=="verified"
                for row in self.identity_map.values())
            super().commit()
            if target and not lost:
                lost.append(True);raise OperationalError("owned committed score ack lost",{},Exception("fixture"))
    monkeypatch.setattr(domain.app.state,"session_factory",
        sessionmaker(domain.app.state.engine,class_=LostPointsAck,expire_on_commit=False))
    with pytest.raises(OperationalError):process_one(domain.app)
    with domain.factory() as session:
        outcome=session.get(RivalryTicket,issued["ticket_id"]).outcome
        assert outcome and outcome["points_delta"]>0
    assert not process_one(domain.app)
    with domain.factory() as session:
        assert session.get(RivalryTicket,issued["ticket_id"]).outcome==outcome
        assert session.scalar(select(func.count()).select_from(RivalryBest).where(RivalryBest.run_id==queued["run_id"]))==1


@pytest.mark.parametrize("old_clock_shift",[-3600,3600])
def test_suspended_worker_with_clock_jump_cannot_overwrite_replacement(domain,monkeypatch,old_clock_shift):
    from bmt_backend import worker as worker_module
    version,board=public_course(domain)
    queued=submit(domain,ticket(domain,version,"Alice"),"Alice")
    stamp=now();clocks=threading.local();entered=threading.Event();released=threading.Event()
    monkeypatch.setattr(worker_module,"now",lambda:getattr(clocks,"value",stamp))
    original=domain.app.state.verifier.verify_run
    def paused(*args,**kwargs):
        entered.set();assert released.wait(10)
        clocks.value=stamp+old_clock_shift
        return {**original(*args,**kwargs),"time_ticks":5,"lap_ticks":[1]*5}
    monkeypatch.setattr(domain.app.state.verifier,"verify_run",paused)
    replacement=create_app(domain.app.state.settings,engine=domain.app.state.engine,verifier=FakeVerifier())
    try:
        with ThreadPoolExecutor(max_workers=1) as pool:
            old=pool.submit(process_one,domain.app)
            assert entered.wait(5)
            clocks.value=stamp+domain.app.state.settings.job_lease_seconds+1
            assert process_one(replacement)
            assert_bests(domain,board,"Alice",queued["run_id"],20)
            released.set();assert old.result(timeout=5)
    finally:released.set()
    assert_bests(domain,board,"Alice",queued["run_id"],20)


def test_never_accepted_expired_ticket_is_explicit_and_does_not_publish(domain):
    version,_=public_course(domain)
    issued=ticket(domain,version,"Alice");saved=body(issued)
    with domain.factory() as session:
        session.get(RunTicket,issued["ticket_id"]).expires_at=now()-1;session.commit()
    response=domain.client.post("/v1/runs",headers=headers(domain,"Alice"),json=saved)
    assert response.status_code==410 and saved["replay"]["frames"]
    with domain.factory() as session:
        assert session.scalar(select(Run).where(Run.ticket_id==issued["ticket_id"])) is None
        assert session.get(QueueCapacity,1).pending==0


@pytest.mark.parametrize("error_number",[errno.EACCES,errno.ENOSPC])
def test_existing_objects_readable_but_fresh_storage_write_is_unavailable(domain,monkeypatch,error_number):
    version,_=public_course(domain)
    issued=ticket(domain,version,"Alice")
    probe=domain.app.state.readiness
    assert asyncio.run(probe.check())["status"]=="ready"
    with domain.factory() as session:
        retained=session.get(TrackVersion,version["version_id"]).content_hash
    original=os.link
    def unavailable(*_args,**_kwargs):raise OSError(error_number,"owned storage write failure")
    with monkeypatch.context() as patch:
        patch.setattr(os,"link",unavailable)
        assert domain.app.state.blobs.get_json(retained)["shape"]=="oval"
        probe.invalidate(storage=True)
        response=domain.client.get("/readyz")
        assert response.status_code==503,response.text
        assert domain.client.get("/healthz").status_code==200
        failed=domain.client.post("/v1/runs",headers=headers(domain,"Alice","saved-on-disk-failure"),json=body(issued))
        assert failed.status_code==503
    assert os.link is original
    probe.invalidate(storage=True)
    assert domain.client.get("/readyz").status_code==200
    retry=domain.client.post("/v1/runs",headers=headers(domain,"Alice","saved-on-disk-failure"),json=body(issued))
    assert retry.status_code==202 and process_one(domain.app)


def test_schema_reads_succeed_but_commit_capability_is_unavailable(domain):
    probe=domain.app.state.readiness;clock=[100.0];probe.clock=lambda:clock[0]
    assert asyncio.run(probe.check())["status"]=="ready"
    clock[0]+=3  # Only the database probe is due; storage success is still fresh.
    def readonly(_conn,_cursor,sql,parameters,*_):
        if "INSERT INTO operation_state" in sql and "readiness-write" in str(parameters):
            raise OperationalError("owned read-only database",{},Exception("writes unavailable"))
    event.listen(domain.app.state.engine,"before_cursor_execute",readonly)
    try:
        with pytest.raises(DependencyFailure):asyncio.run(probe.check())
        assert domain.client.get("/healthz").status_code==200
    finally:event.remove(domain.app.state.engine,"before_cursor_execute",readonly)
    probe.invalidate()
    assert asyncio.run(probe.check())["status"]=="ready"


def test_fresh_readiness_probes_do_not_accumulate_objects_or_pins(domain):
    from bmt_backend.object_models import ObjectPin
    public_course(domain)
    raw=domain.app.state.blobs.store
    files={str(p) for p in raw.root.rglob("*.json")}
    with domain.factory() as session:pins=set(session.scalars(select(ObjectPin.digest)))
    for _ in range(3):
        domain.app.state.readiness.invalidate(storage=True)
        assert asyncio.run(domain.app.state.readiness.check())["status"]=="ready"
    assert {str(p) for p in raw.root.rglob("*.json")}==files
    with domain.factory() as session:assert set(session.scalars(select(ObjectPin.digest)))==pins


def test_postgres_read_only_primary_transition_is_not_reported_ready(domain):
    if not domain.postgres:pytest.skip("PostgreSQL transaction read-only simulation")
    probe=domain.app.state.readiness;clock=[100.0];probe.clock=lambda:clock[0]
    assert asyncio.run(probe.check())["status"]=="ready"
    clock[0]+=3
    def read_only(connection,_record,_proxy):connection.read_only=True
    event.listen(domain.app.state.engine,"checkout",read_only)
    try:
        with pytest.raises(DependencyFailure):asyncio.run(probe.check())
    finally:
        event.remove(domain.app.state.engine,"checkout",read_only);domain.app.state.engine.dispose()
    probe.invalidate()
    assert asyncio.run(probe.check())["status"]=="ready"


def test_killed_postgres_connections_recover_durable_jobs(domain):
    if not domain.postgres:pytest.skip("PostgreSQL connection-loss simulation, not managed failover")
    version,board=public_course(domain)
    queued=submit(domain,ticket(domain,version,"Alice"),"Alice")
    # Kill only this owned fixture pool's idle connection using a separate engine.
    connection=domain.app.state.engine.connect();pid=connection.scalar(text("SELECT pg_backend_pid()"));connection.close()
    admin=make_engine(domain.app.state.settings.database_url)
    try:
        with admin.begin() as other:assert other.scalar(text("SELECT pg_terminate_backend(:pid)"),{"pid":pid})
        response=domain.client.get(f"/v1/runs/{queued['run_id']}",headers=headers(domain,"Alice"))
        assert response.status_code in (200,503)
        assert domain.client.get(f"/v1/runs/{queued['run_id']}",headers=headers(domain,"Alice")).status_code==200
        assert process_one(domain.app)
        assert_bests(domain,board,"Alice",queued["run_id"],20)
    finally:admin.dispose()


def test_corrupt_track_cannot_starve_healthy_track_or_become_cheating_rejection(domain):
    bad,_=public_course(domain)
    good=upload(domain,"Bob",document={"shape":"healthy-other-track"})
    race(domain,good,"Bob",frames=60)
    published=domain.client.post(f"/v1/track-versions/{good['version_id']}/publish",headers=headers(domain,"Bob"))
    assert published.status_code==200
    bad_runs=[submit(domain,ticket(domain,bad,"Alice"),"Alice",frames=20+i) for i in range(4)]
    healthy=[submit(domain,ticket(domain,good,"Carol"),"Carol",frames=30+i) for i in range(4)]
    raw=domain.app.state.blobs.store
    with domain.factory() as session:damaged=session.get(TrackVersion,bad["version_id"]).content_hash
    path=raw._path(damaged);original=path.read_bytes();path.write_bytes(b"owned corrupt fixture")
    try:
        for _ in range(12):
            process_one(domain.app)
            with domain.factory() as session:
                if all(session.get(Run,row["run_id"]).status=="verified" for row in healthy):break
        with domain.factory() as session:
            assert all(session.get(Run,row["run_id"]).status=="verified" for row in healthy)
            assert all(session.get(Run,row["run_id"]).status!="rejected" for row in bad_runs)
            assert all(session.get(Run,row["run_id"]).attempts<=domain.app.state.settings.max_job_attempts for row in bad_runs)
    finally:path.write_bytes(original)
    with domain.factory() as session:
        for row in bad_runs:session.get(Run,row["run_id"]).lease_until=0
        session.commit()
    for _ in bad_runs:assert process_one(domain.app)
    with domain.factory() as session:
        assert all(session.get(Run,row["run_id"]).status=="verified" for row in bad_runs)


def test_accepted_rivalry_job_finishes_after_week_rollover_exactly_once(domain,monkeypatch):
    from test_rivalry import join, rivalry_ticket, seed

    from bmt_backend import rivalry
    from bmt_backend.rivalry_models import RivalryBest, RivalryGroup, RivalryTicket
    seed(domain);group=join(domain)
    issued=rivalry_ticket(domain,group["group_id"])
    queued=submit(domain,issued,"Alice")
    with domain.factory() as session:
        g=session.get(RivalryGroup,group["group_id"])
        ended=g.ends_at;session.get(Run,queued["run_id"]).created_at=ended-1;session.commit()
    monkeypatch.setattr(rivalry,"now",lambda:ended+300)
    assert process_one(domain.app)
    with domain.factory() as session:
        outcome=session.get(RivalryTicket,issued["ticket_id"]).outcome
        assert outcome and outcome["points_delta"]>0
        assert session.scalar(select(func.count()).select_from(RivalryBest).where(RivalryBest.run_id==queued["run_id"]))==1
    retry=domain.client.post("/v1/runs",headers=headers(domain,"Alice"),json=body(issued))
    assert retry.status_code==202 and retry.json()["run_id"]==queued["run_id"]
    assert not process_one(domain.app)
    with domain.factory() as session:assert session.get(RivalryTicket,issued["ticket_id"]).outcome==outcome


def test_old_ticket_waits_for_matching_worker_and_unknown_schema_fails_closed(domain):
    version,board=public_course(domain)
    queued=submit(domain,ticket(domain,version,"Alice"),"Alice")
    original=domain.app.state.verifier
    class NextBuild(FakeVerifier):
        def manifest(self):return {**super().manifest(),"physics_version":"next-unrelated-contract"}
    domain.app.state.verifier=NextBuild()
    assert not process_one(domain.app)
    with domain.factory() as session:
        run=session.get(Run,queued["run_id"])
        assert run.status=="queued" and run.attempts==0
    domain.app.state.verifier=original
    assert process_one(domain.app);assert_bests(domain,board,"Alice",queued["run_id"],20)
    with domain.app.state.engine.begin() as connection:
        head=connection.scalar(text("SELECT version_num FROM alembic_version"))
        connection.execute(text("UPDATE alembic_version SET version_num='unknown_future'"))
    try:
        domain.app.state.readiness.invalidate()
        assert domain.client.get("/readyz").status_code==503
        assert domain.client.get("/healthz").status_code==200
    finally:
        with domain.app.state.engine.begin() as connection:
            connection.execute(text("UPDATE alembic_version SET version_num=:head"),{"head":head})
        domain.app.state.readiness.invalidate()
    assert domain.client.get("/readyz").status_code==200


def test_hot_track_many_pbs_survive_histogram_refresh_and_retention(domain):
    if not domain.postgres:pytest.skip("Concurrent production writers require PostgreSQL")
    version,board=public_course(domain)
    names=[f"Mission driver {i}" for i in range(24)]
    with domain.factory() as session:
        for name in names:
            p=Player(display_name=name);session.add(p);session.flush();domain.players[name]=p.id
        session.commit()
    submissions=[]
    for round_number in range(2):
        for name in names:
            submissions.append((name,submit(domain,ticket(domain,version,name),name,frames=30-round_number*5)))
    def verify():
        for _ in range(len(submissions)):
            process_one(domain.app)
            with domain.factory() as session:
                if session.get(QueueCapacity,1).pending==0:return
    def maintenance():
        for _ in range(3):
            refresh_all_for_diagnostics(domain.app)
            retain(domain.factory,domain.app.state.blobs,apply=True,offline=False,online=True)
    with ThreadPoolExecutor(max_workers=3) as pool:
        jobs=[pool.submit(verify),pool.submit(verify),pool.submit(maintenance)]
        for job in jobs:job.result(timeout=30)
    with domain.factory() as session:
        assert all(session.get(Run,row["run_id"]).status=="verified" for _,row in submissions)
        assert session.get(QueueCapacity,1).pending==0
        for name in names:
            assert session.get(PersonalBest,(board,domain.players[name])).time_ticks==125
            assert session.get(LapPersonalBest,(board,domain.players[name])).time_ticks==25


def test_crashed_backup_guard_blocks_gc_but_not_new_race_progress(domain):
    from bmt_backend.backup_guard import begin, end
    version,board=public_course(domain)
    token=begin(domain.factory)
    restarted_factory=make_session_factory(domain.app.state.engine)
    try:
        result=race(domain,version,"Alice",frames=20)
        assert_bests(domain,board,"Alice",result["run_id"],20)
        with pytest.raises(RuntimeError,match="already active"):begin(restarted_factory)
        with pytest.raises(RuntimeError,match="paused"):
            retain(restarted_factory,domain.app.state.blobs,apply=True,online=True)
        with pytest.raises(RuntimeError,match="token"):end(restarted_factory,"wrong-owner-token")
    finally:end(restarted_factory,token)
    assert retain(restarted_factory,domain.app.state.blobs,apply=True,online=True)["applied"]
    assert_bests(domain,board,"Alice",result["run_id"],20)


def test_isolated_sqlite_restore_detects_missing_evidence_then_recovers(domain,tmp_path):
    if domain.postgres:pytest.skip("SQLite backup API drill; PostgreSQL provider restore remains separate")
    version,board=public_course(domain)
    completed=race(domain,version,"Alice",frames=20)
    issued=ticket(domain,version,"Bob")
    queued=submit(domain,issued,"Bob",frames=25)
    target=tmp_path/"restored.sqlite"
    source=domain.app.state.engine.raw_connection()
    destination=sqlite3.connect(target)
    try:source.driver_connection.backup(destination)
    finally:destination.close();source.close()
    objects=tmp_path/"restored-objects";shutil.copytree(domain.app.state.blobs.store.root,objects)
    store=LocalBlobStore(str(objects))
    engine=make_engine("sqlite:///"+target.as_posix());factory=make_session_factory(engine)
    def missing():
        with factory() as session:
            hashes=set(session.scalars(select(TrackVersion.content_hash)))|set(session.scalars(select(Run.replay_hash)))
        failures=[]
        for value in hashes:
            try:store.get_json(value)
            except (OSError,ValueError):failures.append(value)
        return failures
    try:
        assert missing()==[]
        with factory() as session:essential=session.get(Run,queued["run_id"]).replay_hash
        retained=store._path(essential).read_bytes();store.delete(essential)
        assert missing()==[essential]  # A valid DB/backup marker alone is insufficient.
        store._path(essential).write_bytes(retained)
        assert missing()==[]
        settings=replace(domain.app.state.settings,database_url="sqlite:///"+target.as_posix(),object_dir=str(objects))
        restored=create_app(settings,engine=engine,verifier=FakeVerifier())
        restored.dependency_overrides=domain.app.dependency_overrides.copy()
        with TestClient(restored) as client:
            assert process_one(restored)
            response=client.post("/v1/runs",headers=headers(domain,"Bob"),json=body(issued,25))
            assert response.status_code==202 and response.json()["run_id"]==queued["run_id"]
        with factory() as session:
            assert session.get(PersonalBest,(board,domain.players["Alice"])).run_id==completed["run_id"]
            assert session.get(PersonalBest,(board,domain.players["Bob"])).run_id==queued["run_id"]
            assert session.get(LapPersonalBest,(board,domain.players["Bob"])).time_ticks==25
            assert session.get(QueueCapacity,1).pending==0
    finally:engine.dispose()
