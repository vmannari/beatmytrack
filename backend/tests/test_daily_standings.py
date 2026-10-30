"""Verified daily minima, ordinary worker integration and scoped public reads."""
import os
import time
import uuid
from types import SimpleNamespace

import pytest
from alembic import command
from conftest import TestIdentity as IdentityFixture
from sqlalchemy import event, text
from test_domains import FakeVerifier
from test_non_improving_runs import replay

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.daily_standings import accept_verified, eligible_day
from bmt_backend.daily_standings_models import DailyBest
from bmt_backend.db import make_engine
from bmt_backend.discovery_models import TrackOfDay
from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.track_models import Board, PersonalBest, Run, RunTicket, Track, TrackVersion
from bmt_backend.worker import process_one


@pytest.fixture(params=["sqlite", pytest.param("postgres", marks=pytest.mark.postgres)])
def auth_app(tmp_path, request):
    url = "sqlite:///"+(tmp_path/"daily.sqlite").as_posix()
    engine, admin, schema = None, None, ""
    if request.param == "postgres":
        if os.environ.get("BMT_DAILY_STANDINGS_POSTGRES") != "1":
            pytest.skip("Explicit owned loopback PostgreSQL run not requested")
        from sqlalchemy.engine import make_url
        url = os.environ["BMT_DAILY_STANDINGS_DATABASE_URL"]
        address = make_url(url)
        assert address.host in ("127.0.0.1","localhost") and address.database == "bmt_daily_standings"
        admin = make_engine(url)
        schema = "bmt_load_"+uuid.uuid4().hex
        with admin.begin() as connection: connection.execute(text('CREATE SCHEMA "'+schema+'"'))
        engine = make_engine(url,schema=schema)
        def cleanup():
            engine.dispose()
            with admin.begin() as connection: connection.execute(text('DROP SCHEMA IF EXISTS "'+schema+'" CASCADE'))
            admin.dispose()
        request.addfinalizer(cleanup)
    app = create_app(Settings(environment="test", allow_sync_track_validation=True,
        database_url=url, object_dir=str(tmp_path/"objects"),
        google_client_ids=("test-client",), auth_limit_per_minute=10000,
        write_limit_per_minute=10000, rate_limit_per_minute=10000),
        verifier=FakeVerifier(), identity_verifier=IdentityFixture(), engine=engine)
    from legacy_authoring_fixture import install
    install(app)
    upgrade(app.state.engine)
    yield app
    app.state.engine.dispose()


@pytest.fixture
def daily(auth_app, auth_client, sign_in):
    identities = {name: sign_in(name) for name in ("Creator", "Alice", "Bob", "Carol")}
    document = {"shape":"oval", "name":"Daily fixture", "creator":"Creator",
                "points":[[0,0],[40,0],[40,40],[0,40]], "theme":"pine"}
    digest = auth_app.state.blobs.put_json(document)
    with auth_app.state.session_factory() as db:
        track = Track(owner_id=identities["Creator"]["player"]["id"])
        db.add(track)
        db.flush()
        version = TrackVersion(track_id=track.id, number=1, name="Daily fixture", content_hash=digest,
            manifest=auth_app.state.verifier.validate_track(document), discovery=document,
            state="published", published_at=int(time.time()))
        db.add(version)
        db.commit()
    return SimpleNamespace(app=auth_app, client=auth_client, identities=identities,
        factory=auth_app.state.session_factory, version=version, day=int(time.time())//86400)


def auth(d, name="Alice", key=None):
    return {"Authorization":"Bearer "+d.identities[name]["access_token"],
            "Idempotency-Key":key or str(uuid.uuid4())}


def feature(d):
    with d.factory() as db:
        db.add(TrackOfDay(day=d.day, policy="track-of-day-v1", track_id=d.version.track_id,
            version_id=d.version.id, reason="top", selected_at=d.day*86400))
        db.commit()


def issue(d, name="Alice"):
    r = d.client.post("/v1/run-tickets", json={"version_id":d.version.id,"vehicle_id":"compact"}, headers=auth(d,name))
    assert r.status_code == 201, r.text
    return r.json()


def submit(d, ticks=100, name="Alice", issued=None):
    issued = issued or issue(d,name)
    r = d.client.post("/v1/runs", json={"ticket_id":issued["ticket_id"],"replay":replay([ticks//5]*5)}, headers=auth(d,name))
    assert r.status_code == 202, r.text
    return r.json()


def finish(d, ticks=100, name="Alice"):
    result = submit(d,ticks,name)
    assert result["status"] == "queued", result
    assert process_one(d.app)
    with d.factory() as db:
        run = db.get(Run,result["run_id"])
        assert run.status == "verified", run.failure_code
    return result


def board(d, *, name=None, **query):
    return d.client.get("/v1/track-of-the-day/standings", params={"day":d.day,
        "version_id":d.version.id,"vehicle_id":"compact",**query}, headers=auth(d,name) if name else {})


def test_first_and_improving_daily_times_verify_independently_of_all_time_pb(daily):
    d = daily
    original = finish(d,80)
    feature(d)
    first = finish(d,120)
    assert board(d).json()["items"][0]["time_ticks"] == 120
    faster = finish(d,100)
    with d.factory() as db:
        best = db.get(DailyBest,(d.day,first["board_id"],d.identities["Alice"]["player"]["id"]))
        assert best.time_ticks == 100 and best.run_id == faster["run_id"]
        assert db.get(PersonalBest,(first["board_id"],best.player_id)).run_id == original["run_id"]
    tied = submit(d,100)
    assert tied["status"] == "skipped"
    assert submit(d,140)["status"] == "skipped"
    assert board(d,name="Alice").json()["player"]["time_ticks"] == 100


def test_exact_ties_paging_self_highlight_and_visibility(daily):
    d = daily
    feature(d)
    finish(d,100,"Alice")
    finish(d,100,"Bob")
    finish(d,120,"Carol")
    first = board(d,limit=1)
    assert first.status_code == 200, first.text
    assert first.headers["cache-control"] == "private, no-store"
    values = [first.json()]
    while values[-1]["next_cursor"]:
        values.append(board(d,limit=1,cursor=values[-1]["next_cursor"]).json())
    assert [v["items"][0]["rank"] for v in values] == [1,1,3]
    assert [v["items"][0]["time_ticks"] for v in values] == [100,100,120]
    assert len({v["items"][0]["player_id"] for v in values}) == 3
    own = board(d,name="Carol").json()
    assert own["population"] == 3 and own["player"]["rank"] == 3 and own["player"]["gap_ticks"] == 20
    assert board(d).json()["player"] is None
    with d.factory() as db:
        db.get(Player,d.identities["Bob"]["player"]["id"]).disabled = True
        db.get(Player,d.identities["Alice"]["player"]["id"]).is_test_driver = True
        db.commit()
    only = board(d).json()
    assert only["population"] == 1 and only["items"][0]["rank"] == 1


def test_server_day_boundaries_delayed_verification_and_atomic_projection(daily):
    d = daily
    feature(d)
    result = finish(d)
    with d.factory() as db:
        run = db.get(Run,result["run_id"])
        pinned = db.get(Board,run.board_id)
        ticket = db.get(RunTicket,run.ticket_id)
        assert eligible_day(db,ticket,pinned,ticket.created_at) == d.day
        assert eligible_day(db,ticket,pinned,(d.day+1)*86400) is None
        assert eligible_day(db,ticket,pinned,ticket.created_at-1) is None
        best = db.get(DailyBest,(d.day,run.board_id,run.player_id))
        source = best.run_id
        assert accept_verified(db,run,pinned)
        db.flush()
        assert best.run_id == source
        run.status = "skipped"
        assert not accept_verified(db,run,pinned)
        db.rollback()
    assert board(d).json()["population"] == 1


def test_old_scope_hidden_track_unknown_car_and_invalid_cursor_do_not_leak(daily, monkeypatch):
    from bmt_backend import daily_standings
    d = daily
    feature(d)
    assert board(d,day=d.day-1).status_code == 409
    assert board(d,version_id=str(uuid.uuid4())).status_code == 409
    assert board(d,vehicle_id="missing").status_code in (404,422)
    assert board(d,cursor="bad").status_code == 422
    with d.factory() as db:
        db.get(Track,d.version.track_id).hidden = True
        db.commit()
    assert board(d).status_code == 404
    monkeypatch.setattr(daily_standings,"now",lambda:(d.day+1)*86400)
    assert board(d).status_code == 503


def test_migration_seeds_only_independently_verified_matching_daily_results(daily):
    d = daily
    feature(d)
    finish(d,120)
    finish(d,100)
    assert submit(d,140)["status"] == "skipped"
    command.downgrade(configuration(d.app.state.engine),"0070_reward_cache_revisions")
    upgrade(d.app.state.engine)
    rows = board(d).json()["items"]
    assert len(rows) == 1 and rows[0]["time_ticks"] == 100


def test_http_reads_only_daily_projection_and_uses_scoped_rank_index(daily):
    d = daily
    feature(d)
    finish(d)
    statements = []
    def capture(_connection,_cursor,sql,*_args): statements.append(sql.lower())
    event.listen(d.app.state.engine,"before_cursor_execute",capture)
    try:
        response = board(d,name="Alice")
        assert response.status_code == 200, response.text
    finally:
        event.remove(d.app.state.engine,"before_cursor_execute",capture)
    assert not any("from runs" in sql or "join runs" in sql for sql in statements)
    writes = [sql for sql in statements if sql.lstrip().startswith(("insert ","update ","delete "))]
    # The common HTTP limiter reserves its normal bucket; the score read is pure.
    assert all(sql.startswith("insert into rate_buckets ") for sql in writes), writes
    assert len(statements) < 24
    with d.factory() as db:
        if db.bind.dialect.name == "postgresql":
            db.execute(text("SET LOCAL enable_seqscan=off"))
        explain = "EXPLAIN QUERY PLAN " if db.bind.dialect.name == "sqlite" else "EXPLAIN "
        plan = db.execute(text(explain+"SELECT player_id FROM track_of_day_bests "
            "WHERE day=:day AND board_id=:board AND time_ticks<200 ORDER BY time_ticks,player_id LIMIT 10"),
            {"day":d.day,"board":response.json()["board_id"]}).all()
    assert any("ix_daily_best_order" in str(row) for row in plan)
