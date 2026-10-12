"""Lost updates, publication failures and real reset/verification interleavings."""
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace

import pytest
from sqlalchemy import delete, event, select, text
from sqlalchemy.exc import OperationalError
from test_domains import domain as domain_fixture
from test_domains import headers, public_course, race, ticket

from bmt_backend import runs
from bmt_backend.histogram_snapshots import refresh_all_for_diagnostics, refresh_one
from bmt_backend.identity_models import Player
from bmt_backend.lap_bests import accepted_lap, backfill_all_for_diagnostics, backfill_one
from bmt_backend.track_models import (
    Board,
    HistogramSnapshot,
    LapBestState,
    LapPersonalBest,
    OperationState,
    PersonalBest,
    Run,
    RunTicket,
    TrackVersion,
    digest,
    now,
)
from bmt_backend.worker import process_one

domain = domain_fixture
DEFAULT = object()
DEV_KEY = "owned-histogram-recovery-key-20261010"


def fact(d, session, board, player="Alice", *, laps=DEFAULT, created=100, status="verified", run_id=None):
    proof = {"schema":"bmt-replay-v1", "frames":[[0,255,0]]*5}
    issued = RunTicket(board_id=board, player_id=d.players[player], expires_at=now()+7200)
    session.add(issued); session.flush()
    run = Run(id=run_id or str(uuid.uuid4()), ticket_id=issued.id, board_id=board, player_id=d.players[player],
              replay_hash=d.app.state.blobs.put_json(proof), status=status, created_at=created,
              finished_at=now() if status=="verified" else None, time_ticks=500 if status=="verified" else None,
              lap_ticks=[100]*5 if laps is DEFAULT else laps)
    session.add(run); session.flush()
    return run


def snapshot(d, version):
    with d.factory() as session:
        return session.get(HistogramSnapshot,(version["version_id"],"compact",False))


def private_board(d, session, public):
    original=session.get(Board,public)
    manifest={**original.manifest,"test_population":True}
    bid=digest({"version_id":original.version_id,**manifest})
    board=Board(id=bid,version_id=original.version_id,vehicle_id="compact",manifest=manifest)
    session.add(board);session.flush()
    return board


def reset_row(version_id, cutoff, suffix="reset"):
    return OperationState(id="test-pop-batch:"+suffix,details={"vehicle_id":"compact","created_at":cutoff,
        "request":{"clear_test_records":True},"tracks":[{"version_id":version_id}]})


def test_new_verified_pb_behind_backfill_cursor_survives_old_batch(domain):
    version,board=public_course(domain)
    race(domain,version,"Alice",frames=20)
    with domain.factory() as session:
        fact(domain,session,board,laps=[1,18,30,40,50],run_id="80000000-0000-0000-0000-000000000000")
        queued=fact(domain,session,board,status="queued",run_id="00000000-0000-0000-0000-000000000001")
        queued_id=queued.id
        state=session.get(LapBestState,board)
        state.complete=False;state.cursor="70000000-0000-0000-0000-000000000000"
        session.commit()
    assert backfill_one(domain.factory,after_read=lambda: process_one(domain.app))["worked"]
    with domain.factory() as session:
        state=session.get(LapBestState,board)
        lap=session.get(LapPersonalBest,(board,domain.players["Alice"]))
        assert session.get(Run,queued_id).status=="verified"
        assert queued_id<state.cursor
        assert (lap.time_ticks,lap.run_id)==(5,queued_id)


def test_partial_backfill_writes_and_cursor_roll_back_together(domain):
    _,board=public_course(domain)
    with domain.factory() as session:
        fact(domain,session,board,"Alice",laps=[1,25,30,40,50])
        fact(domain,session,board,"Bob",laps=[1,35,40,50,60])
        session.execute(delete(LapPersonalBest).where(LapPersonalBest.board_id==board))
        state=session.get(LapBestState,board);state.complete=False
        session.commit();revision=session.get(Board,board).lap_revision
    inserts=[]
    def fail_second(_conn,_cursor,sql,*_):
        if sql.startswith("INSERT INTO lap_personal_bests"):
            inserts.append(sql)
            if len(inserts)==2:
                raise OperationalError("owned partial backfill failure",{},Exception("fixture"))
    event.listen(domain.app.state.engine,"before_cursor_execute",fail_second)
    try:
        with pytest.raises(OperationalError):backfill_one(domain.factory)
    finally:event.remove(domain.app.state.engine,"before_cursor_execute",fail_second)
    assert len(inserts)==2
    with domain.factory() as session:
        assert session.scalars(select(LapPersonalBest).where(LapPersonalBest.board_id==board)).all()==[]
        state=session.get(LapBestState,board)
        assert state.cursor=="" and not state.complete and state.invalid_records==0
        assert session.get(Board,board).lap_revision==revision
    backfill_all_for_diagnostics(domain.factory)
    with domain.factory() as session:
        assert session.get(LapPersonalBest,(board,domain.players["Alice"])).time_ticks==25
        assert session.get(LapPersonalBest,(board,domain.players["Bob"])).time_ticks==35
        assert session.get(LapBestState,board).complete


@pytest.mark.parametrize("late_failure",[False,True])
def test_expired_builder_cannot_overwrite_or_clear_replacement(domain,monkeypatch,late_failure):
    version,_=public_course(domain)
    refresh_all_for_diagnostics(domain.app)
    race(domain,version,"Alice",frames=20)
    clock=snapshot(domain,version).next_refresh_at
    original=runs.comparison_populations
    replaced=[]
    def replace_during_build(*args,**kwargs):
        fields=original(*args,**kwargs)
        if not replaced:
            replaced.append(None)
            race(domain,version,"Bob",frames=10)
            assert refresh_one(domain.app,clock=clock+241)
            replaced[0]=snapshot(domain,version)
            if late_failure:raise RuntimeError("Old worker failed after replacement published")
        return fields
    monkeypatch.setattr(runs,"comparison_populations",replace_during_build)
    assert refresh_one(domain.app,clock=clock) is (not late_failure)
    after=snapshot(domain,version);winner=replaced[0]
    assert after.generation==winner.generation and after.payload==winner.payload
    assert after.source_revision==winner.source_revision and after.updated_at==winner.updated_at
    assert after.next_refresh_at==winner.next_refresh_at and not after.dirty
    assert after.lease_token is None and after.lease_until==0
    assert after.population==3


@pytest.mark.parametrize("failure",["generation","publication"])
def test_failed_refresh_keeps_previous_snapshot_and_retries(domain,monkeypatch,failure):
    version,_=public_course(domain)
    refresh_all_for_diagnostics(domain.app)
    baseline=snapshot(domain,version)
    route=f"/v1/track-versions/{version['version_id']}/results-comparison?vehicle_id=compact"
    response=domain.client.get(route,headers=headers(domain)).json()
    race(domain,version,"Alice",frames=20)
    clock=baseline.next_refresh_at
    def fail(*_args,**_kwargs):raise RuntimeError("Owned generation failure")
    def fail_publish(_conn,_cursor,sql,*_):
        if sql.startswith("UPDATE histogram_snapshots SET") and "payload=" in sql:
            raise OperationalError("owned publication failure",{},Exception("fixture"))
    with monkeypatch.context() as patch:
        if failure=="generation":patch.setattr(runs,"comparison_populations",fail)
        else:event.listen(domain.app.state.engine,"before_cursor_execute",fail_publish)
        try:assert not refresh_one(domain.app,clock=clock)
        finally:
            if failure=="publication":event.remove(domain.app.state.engine,"before_cursor_execute",fail_publish)
    after=snapshot(domain,version)
    assert after.generation==baseline.generation and after.payload==baseline.payload
    assert after.source_revision==baseline.source_revision and after.dirty and not after.invalidated
    assert after.lease_token is None and after.lease_until==0 and after.next_refresh_at==clock+30
    assert domain.client.get(route,headers=headers(domain)).json()==response
    assert not refresh_one(domain.app,clock=clock+29)
    assert refresh_one(domain.app,clock=clock+30)
    assert snapshot(domain,version).population==2 and not snapshot(domain,version).dirty


def test_real_reset_fences_a_verification_already_computing(domain,monkeypatch):
    _,public=public_course(domain)
    domain.app.state.settings=replace(domain.app.state.settings,environment="development",dev_auth_enabled=True,
        dev_auth_key=DEV_KEY,test_drivers_enabled=True)
    with domain.factory() as session:
        session.get(Player,domain.players["Alice"]).is_test_driver=True
        private=private_board(domain,session,public)
        old=fact(domain,session,private.id,laps=[12]*5,created=now()-100)
        session.add(PersonalBest(board_id=private.id,player_id=old.player_id,run_id=old.id,time_ticks=500))
        queued=fact(domain,session,private.id,status="queued",created=now()-100)
        bid,queued_id=private.id,queued.id;session.commit()
    entered,released=threading.Event(),threading.Event()
    original=domain.app.state.verifier.verify_run
    def paused(*args,**kwargs):
        entered.set();assert released.wait(10)
        return original(*args,**kwargs)
    monkeypatch.setattr(domain.app.state.verifier,"verify_run",paused)
    try:
        with ThreadPoolExecutor(max_workers=1) as pool:
            verifying=pool.submit(process_one,domain.app)
            assert entered.wait(5)
            operator={"X-Dev-Auth-Key":DEV_KEY}
            preview=domain.client.get("/v1/dev/test-drivers/batches/preview?vehicle_id=compact",headers=operator)
            assert preview.status_code==200,preview.text
            reset=domain.client.post("/v1/dev/test-drivers/batches",headers=operator,json={"seed":102610,
                "count":1,"inventory_digest":preview.json()["inventory_digest"]})
            assert reset.status_code==200,reset.text
            released.set();assert verifying.result(timeout=8)
    finally:released.set()
    with domain.factory() as session:
        queued=session.get(Run,queued_id)
        assert queued.status=="failed" and queued.failure_code=="test_records_reset"
        assert session.get(PersonalBest,(bid,domain.players["Alice"])) is None
        assert session.get(LapPersonalBest,(bid,domain.players["Alice"])) is None


def wait_for_lock(factory,pid):
    deadline=time.monotonic()+5
    while time.monotonic()<deadline:
        with factory() as session:
            waiting=session.scalar(text("SELECT wait_event_type='Lock' FROM pg_stat_activity WHERE pid=:pid"),{"pid":pid})
        if waiting:return
        threading.Event().wait(.01)
    raise AssertionError("Owned writer did not reach its database lock barrier")


def test_reset_waiting_for_finalization_preserves_inventory_without_deadlock(domain):
    if not domain.postgres:pytest.skip("Real PostgreSQL writer locks required")
    _,public=public_course(domain)
    domain.app.state.settings=replace(domain.app.state.settings,environment="development",dev_auth_enabled=True,
        dev_auth_key=DEV_KEY,test_drivers_enabled=True)
    with domain.factory() as session:
        session.get(Player,domain.players["Alice"]).is_test_driver=True
        private=private_board(domain,session,public)
        old=fact(domain,session,private.id,laps=[12]*5,created=now()-100)
        session.add(PersonalBest(board_id=private.id,player_id=old.player_id,run_id=old.id,time_ticks=500))
        queued=fact(domain,session,private.id,status="queued",created=now()-100)
        bid,queued_id=private.id,queued.id;session.commit()
    entered,released,reset_started=threading.Event(),threading.Event(),threading.Event()
    reset_pid=[]
    database_errors=[]
    def capture_database_error(context):
        database_errors.append(getattr(context.original_exception,"sqlstate",None))
    def pause_before_pb(connection,_cursor,sql,*_):
        if sql.startswith("INSERT INTO personal_bests"):
            entered.set();assert released.wait(10)
        elif entered.is_set() and not reset_started.is_set() and sql.startswith(
                ("DELETE FROM personal_bests", "UPDATE runs SET")):
            reset_pid.append(connection.exec_driver_sql("SELECT pg_backend_pid()").scalar())
            reset_started.set()
    event.listen(domain.app.state.engine,"before_cursor_execute",pause_before_pb)
    event.listen(domain.app.state.engine,"handle_error",capture_database_error)
    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            verifying=pool.submit(process_one,domain.app)
            assert entered.wait(5)
            operator={"X-Dev-Auth-Key":DEV_KEY}
            preview=domain.client.get("/v1/dev/test-drivers/batches/preview?vehicle_id=compact",headers=operator)
            assert preview.status_code==200,preview.text
            resetting=pool.submit(domain.client.post,"/v1/dev/test-drivers/batches",headers=operator,
                json={"seed":102611,"count":1,"inventory_digest":preview.json()["inventory_digest"]})
            assert reset_started.wait(5);wait_for_lock(domain.factory,reset_pid[0])
            released.set();assert verifying.result(timeout=8)
            response=resetting.result(timeout=8)
            assert response.status_code==409 and response.json()["detail"]=="RECORD_INVENTORY_CHANGED", (
                response.text+"; database SQLSTATEs="+str(database_errors))
            assert database_errors==[]
    finally:
        released.set();event.remove(domain.app.state.engine,"before_cursor_execute",pause_before_pb)
        event.remove(domain.app.state.engine,"handle_error",capture_database_error)
    with domain.factory() as session:
        assert session.get(Run,queued_id).status=="verified"
        assert session.get(PersonalBest,(bid,domain.players["Alice"])).run_id==queued_id
        assert session.get(LapPersonalBest,(bid,domain.players["Alice"])).run_id==queued_id


def test_reset_racing_winning_source_repair_cannot_restore_old_laps(domain):
    if not domain.postgres:pytest.skip("Real PostgreSQL transactions and lock barriers required")
    version,public=public_course(domain)
    with domain.factory() as session:
        session.get(Player,domain.players["Alice"]).is_test_driver=True
        private=private_board(domain,session,public)
        winner=fact(domain,session,private.id,laps=[1,5,30,40,50],created=100)
        fact(domain,session,private.id,laps=[1,10,30,40,50],created=120)
        bid,source=private.id,winner.id;session.commit()
    ready=threading.Event();pid=[]
    def repair():
        with domain.factory() as session:
            pid.append(session.scalar(text("SELECT pg_backend_pid()")));ready.set()
            session.execute(delete(Run).where(Run.id==source));session.commit()
    # State then PB follows reset publication order. The repair reads old facts
    # and blocks before publishing while this transaction advances the cutoff.
    with domain.factory() as blocker:
        blocker.scalar(select(LapBestState).where(LapBestState.board_id==bid).with_for_update())
        blocker.scalar(select(LapPersonalBest).where(LapPersonalBest.board_id==bid).with_for_update())
        with ThreadPoolExecutor(max_workers=1) as pool:
            future=pool.submit(repair)
            try:
                assert ready.wait(5);wait_for_lock(domain.factory,pid[0])
                blocker.add(reset_row(version["version_id"],150,"repair-race"));blocker.commit()
            finally:blocker.rollback()
            future.result(timeout=8)
    with domain.factory() as session:
        assert session.get(LapPersonalBest,(bid,domain.players["Alice"])) is None
        fresh=fact(domain,session,bid,laps=[1,20,30,40,50],created=151);session.commit()
        assert session.get(LapPersonalBest,(bid,domain.players["Alice"])).run_id==fresh.id


@pytest.mark.parametrize("private",[False,True])
def test_real_player_public_and_private_writes_do_not_wait_on_reset_state(domain,private):
    if not domain.postgres:pytest.skip("PostgreSQL row-lock isolation required")
    _,public=public_course(domain)
    with domain.factory() as session:
        bid=private_board(domain,session,public).id if private else public
        session.commit()
    def write():
        with domain.factory() as session:
            result=fact(domain,session,bid,laps=[1,5,30,40,50]);session.commit()
            return result.id
    with domain.factory() as blocker:
        blocker.scalar(select(LapBestState).where(LapBestState.board_id==bid).with_for_update())
        with ThreadPoolExecutor(max_workers=1) as pool:
            pending=pool.submit(write)
            try:source=pending.result(timeout=5)
            finally:blocker.rollback()
    with domain.factory() as session:
        assert session.get(LapPersonalBest,(bid,domain.players["Alice"])).run_id==source


@pytest.mark.parametrize("correction",["worse","invalid","last_source"])
def test_correcting_winning_source_repairs_or_removes_minimum(domain,correction):
    version,board=public_course(domain)
    with domain.factory() as session:
        winner=fact(domain,session,board,laps=[1,5,30,40,50])
        if correction!="last_source":fact(domain,session,board,laps=[1,10,30,40,50])
        source=winner.id;session.commit()
    refresh_all_for_diagnostics(domain.app)
    with domain.factory() as session:
        winner=session.get(Run,source)
        if correction=="worse":winner.lap_ticks=[1,30,40,50,60]
        elif correction=="invalid":winner.lap_ticks=[1,0,30,40,50]
        else:winner.status="rejected"
        session.commit()
        lap=session.get(LapPersonalBest,(board,domain.players["Alice"]))
        if correction=="last_source":assert lap is None
        else:assert lap.time_ticks==10 and lap.run_id!=source
        assert session.get(HistogramSnapshot,(version["version_id"],"compact",False)).invalidated


def test_race_only_pb_changes_race_revision_and_preserves_flying_pb(domain):
    version,board=public_course(domain)
    race(domain,version,"Alice",frames=20)
    with domain.factory() as session:
        flying=fact(domain,session,board,laps=[1,5,30,40,50]);flying_id=flying.id;session.commit()
    refresh_all_for_diagnostics(domain.app)
    before=snapshot(domain,version)
    with domain.factory() as session:
        b=session.get(Board,board);revisions=(b.stats_revision,b.lap_revision)
    result=race(domain,version,"Alice",frames=15)
    with domain.factory() as session:
        b=session.get(Board,board)
        assert (b.stats_revision,b.lap_revision)==(revisions[0]+1,revisions[1])
        assert session.get(PersonalBest,(board,domain.players["Alice"])).run_id==result["run_id"]
        assert session.get(LapPersonalBest,(board,domain.players["Alice"])).run_id==flying_id
    assert refresh_one(domain.app,clock=before.next_refresh_at)
    after=snapshot(domain,version)
    assert after.payload["race"]["own"][domain.players["Alice"]]==75
    assert after.payload["best_lap"]["own"][domain.players["Alice"]]==5


def test_authorized_rewind_and_completed_upload_retry_preserve_both_pbs(domain):
    version,board=public_course(domain)
    race(domain,version,"Alice",frames=250)
    issued=ticket(domain,version,"Alice")
    begun=domain.client.post("/v1/resume-races",headers=headers(domain,"Alice"),json={"ticket_id":issued["ticket_id"]})
    assert begun.status_code==201,begun.text
    spent=domain.client.post(f"/v1/resume-races/{begun.json()['race_id']}/resumes",headers=headers(domain,"Alice"),
        json={"ordinal":1,"input_offset":120,"from_tick":120,"to_tick":0})
    assert spent.status_code==200,spent.text
    replay={"schema":"bmt-replay-v2","frames":[[0,255,0]]*180,"rewinds":[
        {"receipt_id":spent.json()["receipt_id"],"input_offset":120,"from_tick":120,"to_tick":0}]}
    body={"ticket_id":issued["ticket_id"],"replay":replay}
    uploaded=domain.client.post("/v1/runs",headers=headers(domain,"Alice"),json=body)
    assert uploaded.status_code==202,uploaded.text
    assert process_one(domain.app)
    with domain.factory() as session:
        pb=session.get(PersonalBest,(board,domain.players["Alice"]))
        lap=session.get(LapPersonalBest,(board,domain.players["Alice"]))
        assert (pb.time_ticks,lap.time_ticks)==(900,180)
        assert pb.run_id==lap.run_id==uploaded.json()["run_id"]
        b=session.get(Board,board);revisions=(b.stats_revision,b.lap_revision)
    retried=domain.client.post("/v1/runs",headers=headers(domain,"Alice"),json=body)
    assert retried.status_code==202,retried.text
    assert retried.json()["run_id"]==uploaded.json()["run_id"]
    assert not process_one(domain.app)
    with domain.factory() as session:
        b=session.get(Board,board);assert (b.stats_revision,b.lap_revision)==revisions
        assert session.get(PersonalBest,(board,domain.players["Alice"])).run_id==uploaded.json()["run_id"]
        assert session.get(LapPersonalBest,(board,domain.players["Alice"])).run_id==uploaded.json()["run_id"]


def test_reset_cutoff_is_inclusive_monotonic_and_covers_old_versions(domain):
    version,public=public_course(domain)
    with domain.factory() as session:
        session.get(Player,domain.players["Alice"]).is_test_driver=True
        old=private_board(domain,session,public)
        original=session.get(TrackVersion,version["version_id"])
        newer=TrackVersion(track_id=original.track_id,number=2,name="New pinned version",content_hash=original.content_hash,
            manifest=original.manifest,state="published")
        session.add(newer);session.flush()
        new=Board(id="new-private-version",version_id=newer.id,vehicle_id="compact",manifest=old.manifest)
        session.add(new);session.flush()
        for b in (old,new):
            fact(domain,session,b.id,laps=[1,5,30,40,50],created=149)
            fact(domain,session,b.id,laps=[1,10,30,40,50],created=150)
            fact(domain,session,b.id,laps=[1,20,30,40,50],created=151)
        session.add(reset_row(newer.id,150,"boundary"));session.commit()
        for b in (old,new):
            assert session.get(LapPersonalBest,(b.id,domain.players["Alice"])).time_ticks==10
            assert session.get(LapBestState,b.id).cutoff==150
        session.add(reset_row(newer.id,150,"repeated"))
        session.add(reset_row(newer.id,140,"older"));session.commit()
        for b in (old,new):
            assert session.get(LapBestState,b.id).epoch==1
            assert session.get(LapBestState,b.id).cutoff==150
            assert session.get(LapPersonalBest,(b.id,domain.players["Alice"])).time_ticks==10


@pytest.mark.parametrize("splits,valid",[(None,False),({},False),([],False),([1,-1,2,3,4],False),
                                        ([1,216000,2,3,4],True),([1,216001,2,3,4],False)])
def test_trigger_and_backfill_agree_on_split_boundaries(domain,splits,valid):
    _,board=public_course(domain)
    with domain.factory() as session:
        run=fact(domain,session,board,laps=splits)
        oracle=accepted_lap(run,session.get(Board,board).manifest)
        session.commit()
        captured=session.get(LapPersonalBest,(board,domain.players["Alice"]))
        assert (oracle is not None)==valid and (captured is not None)==valid
        expected=(captured.time_ticks,captured.lap_index,captured.run_id) if captured else None
        session.execute(delete(LapPersonalBest).where(LapPersonalBest.board_id==board))
        session.get(LapBestState,board).complete=False;session.commit()
    backfill_all_for_diagnostics(domain.factory)
    with domain.factory() as session:
        imported=session.get(LapPersonalBest,(board,domain.players["Alice"]))
        assert ((imported.time_ticks,imported.lap_index,imported.run_id) if imported else None)==expected
