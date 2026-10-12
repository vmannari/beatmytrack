"""PB-only histogram invalidation, durable provenance and fenced history import."""
from concurrent.futures import ThreadPoolExecutor

import pytest
from alembic import command
from sqlalchemy import delete, event, select
from test_domains import domain as domain_fixture
from test_domains import public_course, race, submit, ticket

from bmt_backend.histogram_snapshots import refresh_all_for_diagnostics, refresh_one
from bmt_backend.identity_models import Player
from bmt_backend.lap_bests import backfill_all_for_diagnostics, backfill_one, legacy_best_lap_times
from bmt_backend.maintenance import retain
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.runs import best_lap_times, comparison_populations
from bmt_backend.track_models import (
    Board,
    HistogramSnapshot,
    LapBestState,
    LapPersonalBest,
    OperationState,
    PersonalBest,
    Run,
    RunTicket,
    now,
)

domain = domain_fixture


def fact(session, board, player, *, laps=None, total=500, created=100, finished=101):
    ticket = RunTicket(board_id=board,player_id=player,expires_at=now()+7200)
    session.add(ticket); session.flush()
    run = Run(ticket_id=ticket.id,board_id=board,player_id=player,replay_hash="0"*64,
              status="verified",time_ticks=total,lap_ticks=laps or [100]*5,created_at=created,finished_at=finished)
    session.add(run); session.flush()
    return run


def state(domain, board, version):
    with domain.factory() as session:
        b = session.get(Board,board)
        snap = session.get(HistogramSnapshot,(version["version_id"],"compact",False))
        return b.stats_revision,b.lap_revision,snap.dirty,snap.generation,snap.next_refresh_at


def test_non_pb_races_leave_revisions_and_due_snapshot_unchanged(domain):
    version,board = public_course(domain)
    winner = race(domain,version,"Alice",frames=20)
    refresh_all_for_diagnostics(domain.app)
    baseline = state(domain,board,version)
    for frames in (20,25,50):
        race(domain,version,"Alice",frames=frames)
        assert state(domain,board,version) == baseline
    assert not refresh_one(domain.app,clock=baseline[-1])
    with domain.factory() as session:
        assert session.get(PersonalBest,(board,domain.players["Alice"])).run_id == winner["run_id"]
        assert session.get(LapPersonalBest,(board,domain.players["Alice"])).run_id == winner["run_id"]


def test_flying_pb_is_independent_of_race_pb_and_ignores_standing_start(domain):
    version,board = public_course(domain)
    winner = race(domain,version,"Alice",frames=20)
    refresh_all_for_diagnostics(domain.app)
    before = state(domain,board,version)
    with domain.factory() as session:
        source = fact(session,board,domain.players["Alice"],laps=[1,19,30,30,45],total=125)
        source_id = source.id
        session.commit()
        lap = session.get(LapPersonalBest,(board,domain.players["Alice"]))
        assert (lap.time_ticks,lap.lap_index,lap.run_id,lap.achieved_at) == (19,1,source_id,101)
        assert session.get(PersonalBest,(board,domain.players["Alice"])).run_id == winner["run_id"]
        assert dict(session.execute(select(best_lap_times(board,session))).all())[domain.players["Alice"]] == 19
    after = state(domain,board,version)
    assert after[0] == before[0] and after[1] == before[1]+1 and after[2]


@pytest.mark.parametrize("splits",[[1,2,3,4],[1,2,3,4,5,6],[1,0,3,4,5],[1,2.5,3,4,5],
                                   [1,"2",3,4,5],[1,True,3,4,5],[1,2,None,4,5]])
def test_malformed_splits_never_become_lap_pbs(domain,splits):
    _,board = public_course(domain)
    with domain.factory() as session:
        fact(session,board,domain.players["Alice"],laps=splits)
        session.commit()
        assert session.get(LapPersonalBest,(board,domain.players["Alice"])) is None


def test_creator_proof_has_no_flying_pb(domain):
    _,board=public_course(domain)
    with domain.factory() as session:
        ordinary=session.get(Board,board)
        creator=Board(id="creator-proof-fixture",version_id=ordinary.version_id,vehicle_id=ordinary.vehicle_id,
                      manifest={**ordinary.manifest,"purpose":"creator_test"})
        session.add(creator);session.flush()
        assert session.get(LapPersonalBest,(creator.id,domain.players["Creator"])) is None
        fact(session,creator.id,domain.players["Alice"],laps=[1,2,3,4,5])
        session.commit()
        assert session.get(LapPersonalBest,(creator.id,domain.players["Alice"])) is None


def test_retention_keeps_flying_source_but_redundant_attempts_do_not_dirty(domain):
    version,board = public_course(domain)
    race(domain,version,"Alice",frames=20)
    with domain.factory() as session:
        source = fact(session,board,domain.players["Alice"],laps=[1,19,30,30,45],total=125,finished=now()-100*86400)
        redundant = fact(session,board,domain.players["Alice"],laps=[1,25,30,30,45],total=130,finished=now()-100*86400)
        source_id,redundant_id = source.id,redundant.id
        session.commit()
    refresh_all_for_diagnostics(domain.app)
    before = state(domain,board,version)
    report = retain(domain.factory,domain.app.state.blobs,days=90,apply=True,offline=True)
    assert report["runs"] == 1 and report["applied"]
    with domain.factory() as session:
        assert session.get(Run,source_id) and session.get(Run,redundant_id) is None
        assert session.get(LapPersonalBest,(board,domain.players["Alice"])).time_ticks == 19
    assert state(domain,board,version) == before


def test_winning_source_retirement_repairs_only_its_driver(domain):
    version,board = public_course(domain)
    race(domain,version,"Alice",frames=20)
    with domain.factory() as session:
        source = fact(session,board,domain.players["Alice"],laps=[1,19,30,30,45],total=125)
        source_id = source.id; session.commit()
    refresh_all_for_diagnostics(domain.app)
    with domain.factory() as session:
        session.execute(delete(Run).where(Run.id==source_id)); session.commit()
        assert session.get(LapPersonalBest,(board,domain.players["Alice"])).time_ticks == 20
        assert session.get(HistogramSnapshot,(version["version_id"],"compact",False)).invalidated
        # Correction of a nonwinner leaves the restored minimum alone.
        source = fact(session,board,domain.players["Alice"],laps=[1,30,30,30,45],total=125)
        source.lap_ticks=[1,35,35,35,45]; session.commit()
        assert session.get(LapPersonalBest,(board,domain.players["Alice"])).time_ticks == 20


def test_migration_bounded_backfill_matches_legacy_and_survives_restart(domain):
    version,board = public_course(domain)
    race(domain,version,"Alice",frames=20)
    with domain.factory() as session:
        fact(session,board,domain.players["Alice"],laps=[1,19,30,30,45],total=125)
        session.commit()
        expected = session.execute(select(legacy_best_lap_times(board,session))).all()
        provenance = session.execute(select(Run.id,Run.status,Run.lap_ticks)).all()
    command.downgrade(configuration(domain.app.state.engine),"0023_operational_read_indexes")
    upgrade(domain.app.state.engine)
    with domain.factory() as session:
        assert session.execute(select(Run.id,Run.status,Run.lap_ticks)).all()==provenance
        assert session.get(LapBestState,board).complete is False
        with pytest.raises(RuntimeError): best_lap_times(board,session)
    batches=0
    while backfill_one(domain.factory,limit=1)["worked"]: batches+=1
    assert batches>=3
    with domain.factory() as session:
        assert session.execute(select(best_lap_times(board,session))).all()==expected
        assert session.get(LapBestState,board).complete
    assert backfill_one(domain.factory)["complete"]


def test_reset_fences_backfill_and_does_not_revive_retained_artificial_history(domain):
    _,public = public_course(domain)
    with domain.factory() as session:
        b = session.get(Board,public)
        private=Board(id="private-lap-fixture",version_id=b.version_id,vehicle_id=b.vehicle_id,
                      manifest={**b.manifest,"test_population":True})
        session.add(private); session.flush()
        player=session.get(Player,domain.players["Alice"]); player.is_test_driver=True
        old=fact(session,private.id,player.id,laps=[1,2,3,4,5],created=10)
        session.add(PersonalBest(board_id=private.id,player_id=player.id,run_id=old.id,time_ticks=500))
        session.flush()
        session.execute(delete(LapPersonalBest).where(LapPersonalBest.board_id==private.id))
        session.get(LapBestState,private.id).complete=False
        version=b.version_id; session.commit()
    def reset():
        with domain.factory() as session:
            session.add(OperationState(id="test-pop-batch:lap-fence",details={"vehicle_id":"compact",
                "created_at":50,"request":{"clear_test_records":True},"tracks":[{"version_id":version}]}))
            session.commit()
    assert backfill_one(domain.factory,after_read=reset)["fenced"]
    backfill_all_for_diagnostics(domain.factory)
    with domain.factory() as session:
        assert session.get(LapPersonalBest,(private.id,domain.players["Alice"])) is None
        fresh=fact(session,private.id,domain.players["Alice"],laps=[1,20,30,40,50],created=60)
        session.commit()
        assert session.get(LapPersonalBest,(private.id,domain.players["Alice"])).run_id==fresh.id
        # Removing progress/audit metadata cannot remove a durable tombstone.
        session.execute(delete(OperationState).where(OperationState.id=="test-pop-batch:lap-fence"))
        session.get(LapBestState,private.id).complete=False
        session.get(LapBestState,private.id).cursor="";session.commit()
    backfill_all_for_diagnostics(domain.factory)
    with domain.factory() as session:
        assert session.get(LapPersonalBest,(private.id,domain.players["Alice"])).time_ticks==20


def test_histogram_generation_reads_driver_pbs_without_run_history(domain):
    _,board=public_course(domain)
    with domain.factory() as session:
        statements=[]
        def record(_conn,_cursor,sql,*_): statements.append(sql)
        event.listen(domain.app.state.engine,"before_cursor_execute",record)
        try:
            races,laps=comparison_populations(session,[board],board,"absent",False)
            assert len(races.own)==len(laps.own)==1
        finally: event.remove(domain.app.state.engine,"before_cursor_execute",record)
    assert not any("FROM runs" in sql for sql in statements)


def test_failed_transaction_does_not_publish_a_lap_best(domain):
    _,board=public_course(domain)
    with domain.factory() as session:
        fact(session,board,domain.players["Alice"],laps=[1,2,3,4,5]); session.rollback()
        assert session.get(LapPersonalBest,(board,domain.players["Alice"])) is None


def test_reset_preserves_existing_all_car_scope_and_real_private_laps(domain):
    version,public=public_course(domain)
    with domain.factory() as session:
        b=session.get(Board,public)
        session.get(Player,domain.players["Alice"]).is_test_driver=True
        for vehicle in ("compact","kart"):
            private=Board(id="reset-"+vehicle,version_id=b.version_id,vehicle_id=vehicle,
                          manifest={**b.manifest,"test_population":True})
            session.add(private);session.flush()
            fact(session,private.id,domain.players["Alice"],laps=[1,2,3,4,5],created=10)
            fact(session,private.id,domain.players["Bob"],laps=[1,5,6,7,8],created=10)
        session.add(OperationState(id="test-pop-batch:all-cars",details={"vehicle_id":"compact",
            "created_at":50,"request":{"clear_test_records":True},"tracks":[{"version_id":version["version_id"]}]}))
        session.commit()
        for vehicle in ("compact","kart"):
            assert session.get(LapBestState,"reset-"+vehicle).cutoff==50
            assert session.get(LapPersonalBest,("reset-"+vehicle,domain.players["Alice"])) is None
            assert session.get(LapPersonalBest,("reset-"+vehicle,domain.players["Bob"])).time_ticks==5
        # A board created after the reset inherits the same cutoff.
        later=Board(id="reset-later-car",version_id=b.version_id,vehicle_id="pickup",
                    manifest={**b.manifest,"test_population":True})
        session.add(later);session.flush()
        assert session.get(LapBestState,later.id).cutoff==50
        session.commit()


def test_backfill_rechecks_corrected_source_before_publication(domain):
    _,board=public_course(domain)
    with domain.factory() as session:
        source=fact(session,board,domain.players["Alice"],laps=[1,2,3,4,5])
        source_id=source.id;session.flush()
        session.execute(delete(LapPersonalBest).where(LapPersonalBest.board_id==board))
        session.get(LapBestState,board).complete=False;session.commit()
    def correct():
        with domain.factory() as session:
            session.get(Run,source_id).status="rejected";session.commit()
    result=backfill_one(domain.factory,after_read=correct)
    assert result["worked"]
    with domain.factory() as session:
        assert session.get(LapPersonalBest,(board,domain.players["Alice"])) is None


def test_reclassified_artificial_driver_cannot_keep_a_pre_reset_lap(domain):
    version,public=public_course(domain)
    with domain.factory() as session:
        b=session.get(Board,public)
        private=Board(id="reclassified-private",version_id=b.version_id,vehicle_id=b.vehicle_id,
                      manifest={**b.manifest,"test_population":True})
        session.add(private);session.flush()
        fact(session,private.id,domain.players["Alice"],laps=[1,2,3,4,5],created=10)
        fact(session,private.id,domain.players["Alice"],laps=[1,20,30,40,50],created=60)
        session.add(OperationState(id="test-pop-batch:reclass",details={"vehicle_id":"compact",
            "created_at":50,"request":{"clear_test_records":True},"tracks":[{"version_id":version["version_id"]}]}))
        session.commit()
        assert session.get(LapPersonalBest,(private.id,domain.players["Alice"])).time_ticks==2
        session.get(Player,domain.players["Alice"]).is_test_driver=True;session.commit()
        assert session.get(LapPersonalBest,(private.id,domain.players["Alice"])).time_ticks==20


def test_player_verification_precedes_backfill_between_batches(domain):
    from bmt_backend.worker import process_worker_job
    version,board=public_course(domain)
    with domain.factory() as session:
        session.get(LapBestState,board).complete=False;session.commit()
    queued=submit(domain,ticket(domain,version,"Alice"),"Alice",frames=20)
    assert process_worker_job(domain.app)
    with domain.factory() as session:
        assert session.get(Run,queued["run_id"]).status=="verified"
        assert not session.get(LapBestState,board).complete
        assert session.get(LapBestState,board).cursor==""
    assert process_worker_job(domain.app)
    with domain.factory() as session:
        assert session.get(LapBestState,board).complete


def test_backfill_reports_invalid_facts_and_restarts_after_a_crash(domain):
    _,board=public_course(domain)
    with domain.factory() as session:
        fact(session,board,domain.players["Alice"],laps=[1,2,3,4])
        session.get(LapBestState,board).complete=False;session.commit()
    def crash(): raise RuntimeError("Owned fixture interrupted before publication")
    with pytest.raises(RuntimeError,match="Owned fixture"):
        backfill_one(domain.factory,after_read=crash)
    with domain.factory() as session:
        assert session.get(LapBestState,board).cursor==""
    report=backfill_one(domain.factory)
    assert report["invalid_records"]==1
    with domain.factory() as session:
        assert session.get(LapBestState,board).invalid_records==1
        assert session.get(LapPersonalBest,(board,domain.players["Alice"])) is None


def test_concurrent_improvements_choose_minimum(domain):
    if not domain.postgres: pytest.skip("Separate PostgreSQL writer transactions required")
    _,board=public_course(domain)
    def finish(ticks):
        with domain.factory() as session:
            fact(session,board,domain.players["Alice"],laps=[1,ticks,80,80,80])
            session.commit()
    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(finish,[30,10,20,15]))
    with domain.factory() as session:
        assert session.get(LapPersonalBest,(board,domain.players["Alice"])).time_ticks==10
