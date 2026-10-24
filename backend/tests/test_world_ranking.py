"""Authoritative numeric rules and restartable published generations."""
from dataclasses import replace

import pytest
from sqlalchemy import select
from test_domains import domain as _domain_fixture
from test_domains import headers
from test_rivalry import join, rivalry_ticket, seed

from bmt_backend import world_ranking_build as build
from bmt_backend.identity_models import Player
from bmt_backend.world_ranking_models import (
    Circuit,
    RankingAward,
    RankingBranch,
    RankingCareer,
    RankingControl,
    RankingInput,
    RankingPlayer,
    RankingSnapshot,
    RankingStanding,
)
from bmt_backend.world_ranking_rules import POLICY, WEEK, breakdown, points, sporting_key

LAUNCH = 1792972800  # Monday, 26 October 2026 UTC
ranking_domain = _domain_fixture


def test_exact_points_and_countback():
    assert [points(i, 1000000) for i in (1,2,3,4,100,1000,1000000)] == [1000,850,775,750,535,226,7]
    assert points(1, 1) == 0 and points(1, 128) == 1000 and points(1, 127) == 992
    assert points(100, 1000) == points(100, 1000000)
    a = [(LAUNCH, 1000, 1), (LAUNCH+WEEK, 500, 3)]
    b = [(LAUNCH, 750, 2), (LAUNCH+WEEK, 750, 2)]
    assert sporting_key(a)[1] < sporting_key(b)[1]
    assert sporting_key(a)[1] == sporting_key([(w+WEEK,p,r) for w,p,r in a])[1]


def test_reserves_and_expiry():
    rows = [(LAUNCH+i*WEEK, 100-i, i+1) for i in range(26)]
    view = breakdown(rows, LAUNCH+25*WEEK)
    assert sum(r["counting"] for r in view["results"]) == 12
    assert view["points_at_risk"] == 12
    assert len(breakdown(rows, LAUNCH+26*WEEK)["results"]) == 25


def seeded_build(app, monkeypatch, count=16, player_ids=()):
    monkeypatch.setattr(build, "now", lambda: LAUNCH-1)
    settings = replace(app.state.settings, world_ranking_launch_week=LAUNCH, world_ranking_batch_size=3)
    build.initialize(app.state.session_factory, LAUNCH)
    with app.state.session_factory() as db:
        branch = db.scalar(select(RankingBranch))
        circuit = Circuit(week_start=LAUNCH, contract_key="a"*64, policy=POLICY, tracks=[])
        db.add(circuit)
        db.flush()
        snapshot = RankingSnapshot(branch_id=branch.id, circuit_id=circuit.id, week_start=LAUNCH, field_size=count)
        db.add(snapshot)
        db.flush()
        for index in range(count):
            player = db.get(Player, player_ids[index]) if index < len(player_ids) else Player(display_name=f"WorldDriver{index}")
            player.country_code = "FI" if index%2 else "SE"
            db.add(player)
            db.flush()
            mapped = RankingPlayer(player_id=player.id)
            db.add(mapped)
            db.flush()
            # First two have equal ticks everywhere: genuine joint winners.
            tick = 1000+max(0,index-1)
            db.add(RankingInput(snapshot_id=snapshot.id, player_key=mapped.key,
                t0=tick, t1=tick+1, t2=tick+2, t3=tick+3, t4=tick+4, country=player.country_code))
        branch.snapshot_id, branch.phase = snapshot.id, "track0"
        db.commit()
    monkeypatch.setattr(build, "now", lambda: LAUNCH+WEEK)
    from bmt_backend import world_ranking
    monkeypatch.setattr(world_ranking, "now", lambda: LAUNCH+WEEK)
    return settings


def settle(app, settings, until_idle=True):
    for _ in range(1000):
        build.step(app.state.session_factory, app.state.blobs, settings)
        with app.state.session_factory() as db:
            state = db.get(RankingControl, 1)
            branch = db.get(RankingBranch, state.running_branch)
            if branch.phase == "idle" and state.published_id:
                return state.published_id
    raise AssertionError("Ranking settlement did not complete bounded work")


def test_sqlite_settlement_and_atomic_shared_winners(auth_app, monkeypatch):
    settings = seeded_build(auth_app, monkeypatch)
    for _ in range(8):
        build.step(auth_app.state.session_factory, auth_app.state.blobs, settings)
        with auth_app.state.session_factory() as db:
            assert db.get(RankingControl, 1).published_id is None
    published = settle(auth_app, settings)
    with auth_app.state.session_factory() as db:
        rows = list(db.scalars(select(RankingStanding).where(RankingStanding.snapshot_id == published)
            .order_by(RankingStanding.world_rank, RankingStanding.player_key)))
        assert len(rows) == 16
        assert [r.world_rank for r in rows[:3]] == [1,1,3]
        assert rows[0].total == rows[1].total == points(1,16)
        careers = list(db.scalars(select(RankingCareer).where(RankingCareer.generation == published)))
        assert sum(c.victories for c in careers) == 2
        assert sum(c.weeks_no1 for c in careers) == 0  # small fields do not mint prestige
        assert len(list(db.scalars(select(RankingAward)))) == 16
        assert not list(db.scalars(select(RankingInput)))


def test_bounded_http_pages_profiles_and_cursor_scope(auth_app, auth_client, sign_in, monkeypatch):
    alice = sign_in("RankAlice")
    settings = seeded_build(auth_app, monkeypatch, 60, [alice["player"]["id"]])
    auth_app.state.settings = settings
    settle(auth_app, settings)
    headers = {"Authorization": "Bearer "+alice["access_token"]}
    board = auth_client.get("/v1/ranking", headers=headers)
    assert board.status_code == 200, board.text
    payload = board.json()
    assert len(payload["items"]) == 50 and payload["next_cursor"]
    more = auth_client.get("/v1/ranking", params={"cursor": payload["next_cursor"]}, headers=headers)
    assert more.status_code == 200 and len(more.json()["items"]) == 10
    wrong = auth_client.get("/v1/ranking", params={"cursor": payload["next_cursor"], "scope":"season"}, headers=headers)
    assert wrong.status_code == 422
    near = auth_client.get("/v1/ranking?around=true", headers=headers)
    assert near.status_code == 200 and len(near.json()["items"]) <= 9
    country = auth_client.get("/v1/ranking?scope=country", headers=headers)
    assert country.status_code == 200 and len(country.json()["items"]) == 30
    me = auth_client.get("/v1/ranking/me", headers=headers)
    assert me.status_code == 200, me.text
    assert me.json()["world_rank"] == 1 and len(me.json()["results"]) == 1
    assert me.json()["career"]["victories"] == 1
    import json
    from pathlib import Path

    schema = json.loads((Path(__file__).parents[2] / "docs/schemas/world-ranking-v1.schema.json").read_text(encoding="utf-8"))
    assert me.json().keys() >= set(schema["required"]+schema["oneOf"][1]["required"])
    assert payload.keys() >= set(schema["required"]+schema["oneOf"][0]["required"])
    again = auth_client.get("/v1/ranking/me", headers={**headers,"If-None-Match": me.headers["etag"]})
    assert again.status_code == 304


def test_archive_correction_rebuild_keeps_old_publication(auth_app, auth_client, monkeypatch):
    import uuid
    settings = seeded_build(auth_app, monkeypatch)
    settings = replace(settings, admin_owner_key="ranking-owner-private-key-0123456789")
    auth_app.state.settings = settings
    original = settle(auth_app, settings)
    with auth_app.state.session_factory() as db:
        first = db.scalar(select(RankingStanding).where(RankingStanding.snapshot_id == original).order_by(RankingStanding.player_key))
        target = db.get(RankingPlayer, first.player_key)
        circuit = db.get(RankingSnapshot, original).circuit_id
        body = {"command_id":str(uuid.uuid4()), "expected_snapshot":original,
                "circuit_id":circuit,"player_id":target.player_id,"reason":"Invalid original verified result"}
    denied = auth_client.post("/v1/admin/ranking/corrections", json=body)
    assert denied.status_code == 401
    response = auth_client.post("/v1/admin/ranking/corrections", json=body,
        headers={"Authorization":"Bearer ranking-owner-private-key-0123456789"})
    assert response.status_code == 200, response.text
    repeat = auth_client.post("/v1/admin/ranking/corrections", json=body,
        headers={"Authorization":"Bearer ranking-owner-private-key-0123456789"})
    assert repeat.json() == response.json()
    for _ in range(8):
        build.step(auth_app.state.session_factory, auth_app.state.blobs, settings)
        with auth_app.state.session_factory() as db:
            assert db.get(RankingControl, 1).published_id == original
    corrected = settle(auth_app, settings)
    assert corrected != original
    with auth_app.state.session_factory() as db:
        assert db.get(RankingControl,1).previous_id == original
        assert db.scalar(select(RankingStanding).where(RankingStanding.snapshot_id == corrected,
            RankingStanding.player_key == first.player_key)) is None
        rows = list(db.scalars(select(RankingStanding).where(RankingStanding.snapshot_id == corrected)
            .order_by(RankingStanding.world_rank)))
        assert len(rows) == 15 and rows[0].world_rank == 1 and rows[0].total == points(1,15)


def test_calendar_expiry_and_career_survival(auth_app, monkeypatch):
    settings = seeded_build(auth_app, monkeypatch, 3)
    settle(auth_app, settings)
    for age in range(1,27):
        monkeypatch.setattr(build, "now", lambda age=age: LAUNCH+(age+1)*WEEK)
        current = settle(auth_app, settings)
        with auth_app.state.session_factory() as db:
            rows = list(db.scalars(select(RankingStanding).where(RankingStanding.snapshot_id == current)))
            assert len(rows) == (3 if age < 26 else 0)
    with auth_app.state.session_factory() as db:
        latest = {}
        careers = list(db.scalars(select(RankingCareer).order_by(RankingCareer.generation.desc())))
        for career in careers:
            latest.setdefault(career.player_key, career)
        assert len(latest) == 3 and len(careers) <= 6
        assert all(c.peak_week == LAUNCH and c.peak_field == 3 for c in latest.values())
        assert sum(c.victories for c in latest.values()) == 2


def test_domain_generation_and_reads(ranking_domain, monkeypatch):
    app = ranking_domain.app
    settings = seeded_build(app, monkeypatch, 40, [ranking_domain.players["Alice"]])
    app.state.settings = settings
    current = settle(app, settings)
    response = ranking_domain.client.get("/v1/ranking/me", headers=headers(ranking_domain,"Alice"))
    assert response.status_code == 200, response.text
    assert response.json()["snapshot_id"] == current and response.json()["world_rank"] == 1
    board = ranking_domain.client.get("/v1/ranking?scope=season", headers=headers(ranking_domain,"Alice"))
    assert board.status_code == 200 and len(board.json()["items"]) == 40


def test_shared_circuit_group_independence_and_free_resumes(ranking_domain, monkeypatch):
    from bmt_backend import resumes, rivalry, rivalry_planning
    from bmt_backend.resume_models import ResumeReceipt, ResumeWallet
    from bmt_backend.rivalry_models import RivalryBest
    from bmt_backend.track_models import Run
    from bmt_backend.world_circuit import ensure_circuits
    app = ranking_domain.app
    settings = replace(app.state.settings, world_ranking_launch_week=LAUNCH, world_ranking_batch_size=2,
        temporary_ad_resumes_enabled=False)
    app.state.settings = settings
    seed(ranking_domain)
    monkeypatch.setattr(rivalry,"now",lambda: LAUNCH+20)
    monkeypatch.setattr(rivalry,"skill_score",lambda _db,pid,*_args: 950 if pid == ranking_domain.players["Bob"] else 100)
    active = app.state.verifier.manifest()
    with ranking_domain.factory() as db:
        rivalry_planning.ensure_vehicle(db,active,"compact",LAUNCH-60)
        ensure_circuits(db,app,active,LAUNCH-60)
        db.commit()
    alice, bob = join(ranking_domain,"Alice"), join(ranking_domain,"Bob")
    assert alice["group_id"] != bob["group_id"]
    assert alice["world_circuit"]["id"] == bob["world_circuit"]["id"]
    assert [r["board_id"] for r in alice["tracks"]] == [r["board_id"] for r in bob["tracks"]]
    issued = rivalry_ticket(ranking_domain,alice["group_id"])
    ticket_id = issued["ticket_id"]
    with ranking_domain.factory() as db:
        db.add(ResumeWallet(player_id=ranking_domain.players["Alice"],balance=9,free_day=resumes.now()//86400))
        db.commit()
    wallet = ranking_domain.client.get("/v1/resumes",params={"ticket_id":ticket_id},headers=headers(ranking_domain,"Alice"))
    assert wallet.json()["circuit_free"] is True and wallet.json()["free_rewinds"] is True
    recovery = ranking_domain.client.post("/v1/resume-recovery",json={"begin_key":"missing-begin-key-123",
        "consume_key":"missing-consume-key-123","ticket_id":ticket_id,"action":"inspect",
        "selection":{"ordinal":1,"input_offset":100,"from_tick":100,"to_tick":0}},headers=headers(ranking_domain,"Alice"))
    assert recovery.status_code == 200, recovery.text
    assert recovery.json()["state"] == "absent" and recovery.json()["wallet"]["circuit_free"] is True
    beginning = ranking_domain.client.post("/v1/resume-races",json={"ticket_id":ticket_id},headers=headers(ranking_domain,"Alice"))
    assert beginning.status_code == 201, beginning.text
    for index in range(1,4):
        consumed = ranking_domain.client.post(f"/v1/resume-races/{beginning.json()['race_id']}/resumes",
            json={"ordinal":index,"input_offset":index*100,"from_tick":60+index*40,"to_tick":index*40},
            headers=headers(ranking_domain,"Alice"))
        assert consumed.status_code == 200, consumed.text
        assert consumed.json()["wallet"]["balance"] == 9
    with ranking_domain.factory() as db:
        assert list(db.scalars(select(ResumeReceipt.source))) == ["circuit"]*3
    fourth = ranking_domain.client.post(f"/v1/resume-races/{beginning.json()['race_id']}/resumes",
        json={"ordinal":4,"input_offset":400,"from_tick":500,"to_tick":400},headers=headers(ranking_domain,"Alice"))
    assert fourth.status_code == 422
    for name, group in (("Alice",alice),("Bob",bob)):
        for slot in range(5):
            receipt = issued if name == "Alice" and slot == 0 else rivalry_ticket(ranking_domain,group["group_id"],name,slot)
            with ranking_domain.factory() as db:
                tick = 1000+slot+(0 if name == "Alice" else 10)
                run = Run(ticket_id=receipt["ticket_id"],player_id=ranking_domain.players[name],
                    board_id=receipt["board_id"],replay_hash="0"*64,status="verified",time_ticks=tick,
                    created_at=LAUNCH+30,finished_at=LAUNCH+40)
                db.add(run)
                db.flush()
                db.add(RivalryBest(group_id=group["group_id"],player_id=ranking_domain.players[name],
                    slot=slot,run_id=run.id,time_ticks=tick))
                db.commit()
    monkeypatch.setattr(build,"now",lambda: LAUNCH-1)
    build.initialize(ranking_domain.factory,LAUNCH)
    monkeypatch.setattr(build,"now",lambda: LAUNCH+WEEK)
    with ranking_domain.factory() as db:
        pending = db.scalar(select(Run).order_by(Run.id))
        pending.status = "queued"
        pending.created_at = LAUNCH+WEEK-1
        pending_id = pending.id
        db.commit()
    assert build.step(ranking_domain.factory,app.state.blobs,settings) is False
    with ranking_domain.factory() as db:
        assert db.get(RankingControl,1).published_id is None
        db.get(Run,pending_id).status = "verified"
        db.commit()
    current = settle(app,settings)
    with ranking_domain.factory() as db:
        results = list(db.scalars(select(RankingStanding).where(RankingStanding.snapshot_id == current).order_by(RankingStanding.world_rank)))
        assert [r.world_rank for r in results] == [1,2]
        assert [r.total for r in results] == [points(1,2),points(2,2)]


@pytest.mark.parametrize("count", [1,127,128,1024])
def test_sql_points_exact_across_small_field_boundary(auth_app, monkeypatch, count):
    settings = replace(seeded_build(auth_app,monkeypatch,count),world_ranking_batch_size=256)
    published = settle(auth_app,settings)
    with auth_app.state.session_factory() as db:
        circuit = db.get(RankingSnapshot,published).circuit_id
        rows = list(db.scalars(select(RankingAward).where(RankingAward.circuit_id == circuit)))
        assert len(rows) == count
        assert all(row.points == points(row.weekly_place,count) for row in rows)
        assert db.get(RankingSnapshot,published).ranked_count == (0 if count == 1 else count)


def test_archive_failure_restarts_without_duplicate_or_partial_publication(auth_app,monkeypatch):
    from bmt_backend.world_ranking_models import RankingArchive
    settings = seeded_build(auth_app,monkeypatch)
    factory, blobs = auth_app.state.session_factory, auth_app.state.blobs
    for _ in range(100):
        with factory() as db:
            branch = db.scalar(select(RankingBranch))
            if branch.phase == "week_archive": break
        build.step(factory,blobs,settings)
    original = blobs.put_json
    def unavailable(_body): raise OSError("Injected object storage outage")
    monkeypatch.setattr(blobs,"put_json",unavailable)
    with pytest.raises(OSError): build.step(factory,blobs,settings)
    with factory() as db:
        assert db.get(RankingControl,1).published_id is None
        assert not list(db.scalars(select(RankingArchive)))
        assert db.scalar(select(RankingBranch)).failure.startswith("OSError:")
    assert build.step(factory,blobs,settings) is False
    monkeypatch.setattr(blobs,"put_json",original)
    monkeypatch.setattr(build,"now",lambda:LAUNCH+WEEK+10)
    current = settle(auth_app,settings)
    with factory() as db:
        assert db.get(RankingSnapshot,current).ranked_count == 16
        assert len(list(db.scalars(select(RankingAward)))) == 16


def test_owner_void_unavailable_first_week(auth_app,auth_client,monkeypatch):
    import uuid

    from bmt_backend import world_ranking
    settings = replace(seeded_build(auth_app,monkeypatch),admin_owner_key="ranking-owner-private-key-0123456789")
    auth_app.state.settings = settings
    with auth_app.state.session_factory() as db:
        branch = db.scalar(select(RankingBranch))
        snapshot_id = branch.snapshot_id
        circuit = db.get(Circuit,db.get(RankingSnapshot,snapshot_id).circuit_id)
        circuit_id = circuit.id
        circuit.tracks = [{"version_id":"unavailable-"+str(i)} for i in range(5)]
        from sqlalchemy import delete
        db.execute(delete(RankingInput))
        db.execute(delete(RankingSnapshot))
        branch.snapshot_id,branch.phase = None,"idle"
        db.commit()
    with pytest.raises(build.CircuitUnavailable):
        build.step(auth_app.state.session_factory,auth_app.state.blobs,settings)
    monkeypatch.setattr(world_ranking,"now",lambda:LAUNCH+WEEK+10)
    monkeypatch.setattr(build,"now",lambda:LAUNCH+WEEK+10)
    response = auth_client.post("/v1/admin/ranking/corrections",json={"command_id":str(uuid.uuid4()),
        "expected_snapshot":0,"circuit_id":circuit_id,"void_week":True,"reason":"Track unavailable to all participants"},
        headers={"Authorization":"Bearer ranking-owner-private-key-0123456789"})
    assert response.status_code == 200, response.text
    current = settle(auth_app,settings)
    with auth_app.state.session_factory() as db:
        assert db.get(RankingSnapshot,current).field_size == 0
        assert db.get(RankingSnapshot,current).ranked_count == 0


def test_season_best_six_and_prestige_counters(auth_app,monkeypatch):
    settings = replace(seeded_build(auth_app,monkeypatch,1000),world_ranking_batch_size=256)
    current = settle(auth_app,settings)
    factory = auth_app.state.session_factory
    for week in range(1,13):
        with factory() as db:
            branch = db.scalar(select(RankingBranch))
            circuit = Circuit(week_start=LAUNCH+week*WEEK,contract_key="a"*64,policy=POLICY,tracks=[])
            db.add(circuit)
            db.flush()
            snapshot = RankingSnapshot(branch_id=branch.id,circuit_id=circuit.id,week_start=circuit.week_start,
                field_size=1000,previous_id=current,season_qualifying_weeks=week)
            db.add(snapshot)
            db.flush()
            keys = list(db.scalars(select(RankingPlayer.key)))
            db.add_all([RankingInput(snapshot_id=snapshot.id,player_key=k,country="FI",
                **{f"t{s}":1000+max(0,k-2)+s for s in range(5)}) for k in keys])
            branch.phase,branch.snapshot_id = "track0",snapshot.id
            db.commit()
        monkeypatch.setattr(build,"now",lambda week=week:LAUNCH+(week+1)*WEEK)
        current = settle(auth_app,settings)
    with factory() as db:
        winners = list(db.scalars(select(RankingStanding).where(RankingStanding.snapshot_id == current,
            RankingStanding.world_rank == 1)))
        assert len(winners) == 2 and all(w.total == 12000 and w.season_points == 6000 for w in winners)
        for winner in winners:
            career = db.get(RankingCareer,(branch.id,winner.player_key,current))
            assert career.weeks_no1 == 13 and career.weeks_top100 == 13
            assert career.season_titles == 1 and career.victories == 13


def test_upgrade_preserves_previous_schema_rows(ranking_domain):
    import hashlib
    import json

    from alembic import command
    from sqlalchemy import MetaData

    from bmt_backend.migrate import configuration, upgrade
    app = ranking_domain.app
    seed(ranking_domain)
    join(ranking_domain,"Alice")
    command.downgrade(configuration(app.state.engine),"0058_challenge_series")
    metadata = MetaData()
    metadata.reflect(bind=app.state.engine)
    def fingerprints():
        result = {}
        with app.state.engine.connect() as db:
            for name, table in metadata.tables.items():
                if name == "alembic_version": continue
                rows = sorted(json.dumps(dict(row),sort_keys=True,default=str) for row in db.execute(select(table)).mappings())
                result[name] = (len(rows),hashlib.sha256("\n".join(rows).encode()).hexdigest())
        return result
    before = fingerprints()
    upgrade(app.state.engine)
    assert fingerprints() == before
    assert len(before) >= 90


def test_archives_are_referenced_by_object_retention(auth_app,monkeypatch):
    from bmt_backend import maintenance
    from bmt_backend.world_ranking_models import RankingArchive
    settings = seeded_build(auth_app,monkeypatch)
    settle(auth_app,settings)
    with auth_app.state.session_factory() as db:
        objects = set(db.scalars(select(RankingArchive.digest)))
    assert len(objects) > 0
    # Old files remain referenced, while unrelated old objects can be collected.
    orphan = auth_app.state.blobs.put_json({"orphan":"ranking-test"})
    import os
    from pathlib import Path
    for file in Path(auth_app.state.settings.object_dir).rglob("*"):
        if file.is_file(): os.utime(file,(1,1))
    outcome = maintenance.retain(auth_app.state.session_factory,auth_app.state.blobs,
                                 apply=True,offline=True)
    assert outcome["orphaned_objects"] >= 1
    for digest in objects: assert auth_app.state.blobs.get_json(digest)["format"] == "bmt-ranking-1"
    with pytest.raises(FileNotFoundError): auth_app.state.blobs.get_json(orphan)


def test_domain_correction_command_retries(ranking_domain,monkeypatch):
    import uuid
    from concurrent.futures import ThreadPoolExecutor
    settings = replace(seeded_build(ranking_domain.app,monkeypatch),admin_owner_key="ranking-owner-private-key-0123456789")
    ranking_domain.app.state.settings = settings
    old = settle(ranking_domain.app,settings)
    with ranking_domain.factory() as db:
        circuit = db.get(RankingSnapshot,old).circuit_id
    body = {"command_id":str(uuid.uuid4()),"expected_snapshot":old,"circuit_id":circuit,
            "void_week":True,"reason":"Official contract invalidated after publication"}
    def request():
        return ranking_domain.client.post("/v1/admin/ranking/corrections",json=body,
            headers={"Authorization":"Bearer ranking-owner-private-key-0123456789"})
    if ranking_domain.postgres:
        with ThreadPoolExecutor(max_workers=2) as pool: responses = list(pool.map(lambda _:request(),range(2)))
    else:
        responses = [request(),request()]
    assert all(r.status_code == 200 for r in responses), [r.text for r in responses]
    assert responses[0].json() == responses[1].json()
    with ranking_domain.factory() as db: assert db.get(RankingControl,1).published_id == old
    new = settle(ranking_domain.app,settings)
    assert new != old
    with ranking_domain.factory() as db:
        assert db.get(RankingSnapshot,new).ranked_count == 0
        assert not list(db.scalars(select(RankingCareer).where(RankingCareer.generation == new)))


def test_mixed_track_ties_match_exact_reference(auth_app,monkeypatch):
    from collections import Counter

    from sqlalchemy import delete
    times = [[10,20,30,40,50],[20,30,40,50,10],[30,40,50,10,20],
             [40,50,10,20,30],[50,10,20,30,40],[60,60,60,60,60],
             [10,20,30,40,50],[15,15,15,55,55]]
    settings = seeded_build(auth_app,monkeypatch,len(times))
    with auth_app.state.session_factory() as db:
        branch = db.scalar(select(RankingBranch))
        keys = list(db.scalars(select(RankingPlayer.key).order_by(RankingPlayer.key)))
        db.execute(delete(RankingInput))
        for index in reversed(range(len(times))):
            db.add(RankingInput(snapshot_id=branch.snapshot_id,player_key=keys[index],country="FI",
                **{f"t{s}":tick for s,tick in enumerate(times[index])}))
        db.commit()
    classification = []
    for row in times:
        places = [2*sum(other[s] < row[s] for other in times)+sum(other[s] == row[s] for other in times)+1 for s in range(5)]
        classification.append((sum(places),*sorted(places)))
    expected = [1+sum(other < value for other in classification) for value in classification]
    current = settle(auth_app,settings)
    with auth_app.state.session_factory() as db:
        circuit = db.get(RankingSnapshot,current).circuit_id
        awards = list(db.scalars(select(RankingAward).where(RankingAward.circuit_id == circuit).order_by(RankingAward.player_key)))
        assert [a.weekly_place for a in awards] == expected
        assert Counter(a.weekly_place for a in awards) == Counter(expected)


def test_friends_country_and_fresh_redaction(ranking_domain,monkeypatch):
    from bmt_backend.community_models import PlayerBlock
    from bmt_backend.news_models import Friendship
    app, domain = ranking_domain.app, ranking_domain
    settings = seeded_build(app,monkeypatch,60,[domain.players["Alice"],domain.players["Bob"],domain.players["Carol"]])
    app.state.settings = settings
    current = settle(app,settings)
    alice,bob = domain.players["Alice"],domain.players["Bob"]
    with domain.factory() as db:
        low,high = sorted([alice,bob])
        db.add(Friendship(low_id=low,high_id=high,requested_by=alice,accepted=True))
        db.commit()
    board = domain.client.get("/v1/ranking?scope=friends",headers=headers(domain,"Alice"))
    assert board.status_code == 200, board.text
    assert len(board.json()["items"]) == 2
    assert [r["rank"] for r in board.json()["items"]] == [1,1]
    original = domain.client.get("/v1/ranking",headers=headers(domain,"Alice"))
    with domain.factory() as db:
        db.add(PlayerBlock(player_id=alice,blocked_id=bob))
        db.get(Player,domain.players["Carol"]).deleted_at = LAUNCH
        db.commit()
    redacted = domain.client.get("/v1/ranking",headers={**headers(domain,"Alice"),"If-None-Match":original.headers["etag"]})
    assert redacted.status_code == 200
    items = redacted.json()["items"]
    assert items[1]["name"] == "Blocked player" and items[1]["player_id"] == ""
    assert items[2]["name"] == "Removed account" and items[2]["country"] == ""
    assert domain.client.get("/v1/ranking/players/"+bob,headers=headers(domain,"Alice")).status_code == 403
    with domain.factory() as db: assert db.get(RankingSnapshot,current).field_size == 60


def test_delayed_foreground_queue_yields_before_any_ranking_work(ranking_domain,monkeypatch):
    from test_domains import public_course, submit, ticket

    from bmt_backend.worker import process_one
    app,domain = ranking_domain.app,ranking_domain
    version,_ = public_course(domain)
    issued = ticket(domain,version,"Alice")
    submit(domain,issued,"Alice")
    settings = seeded_build(app,monkeypatch)
    assert build.step(domain.factory,app.state.blobs,settings) is False
    with domain.factory() as db:
        assert db.scalar(select(RankingBranch)).phase == "track0"
        assert db.get(RankingControl,1).published_id is None
    assert process_one(app)
    assert build.step(domain.factory,app.state.blobs,settings) is True


def test_two_workers_do_not_repeat_a_claimed_phase(ranking_domain,monkeypatch):
    import threading
    from concurrent.futures import ThreadPoolExecutor

    from bmt_backend.world_ranking_models import RankingPlace
    if not ranking_domain.postgres:
        pytest.skip("Real row-lock concurrency uses PostgreSQL")
    domain,app = ranking_domain,ranking_domain.app
    settings = seeded_build(app,monkeypatch)
    original = build._lock
    entered,release = threading.Event(),threading.Event()
    def held(db,identity,token):
        if not entered.is_set():
            entered.set()
            assert release.wait(5)
        return original(db,identity,token)
    monkeypatch.setattr(build,"_lock",held)
    with ThreadPoolExecutor(max_workers=2) as pool:
        future = pool.submit(build.step,domain.factory,app.state.blobs,settings)
        assert entered.wait(5)
        try:
            assert build.step(domain.factory,app.state.blobs,settings) is False
        finally:
            release.set()
        assert future.result(5) is True
    with domain.factory() as db:
        assert db.scalar(select(RankingBranch)).phase == "track1"
        assert len(list(db.scalars(select(RankingPlace)))) == 16
