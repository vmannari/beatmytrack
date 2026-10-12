"""Global coverage, shared stable order, visibility, confidence and query cost."""
import time
import uuid
import os
from types import SimpleNamespace

import pytest
from sqlalchemy import event, update, text
from sqlalchemy.engine import make_url
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.migrate import upgrade
from conftest import TestIdentity as DiscoveryIdentity

from bmt_backend import discovery
from bmt_backend.discovery import DiscoverySnapshot
from bmt_backend.track_models import Board, Run, RunTicket, Track, TrackVersion
from bmt_backend.identity_models import Player


@pytest.fixture(params=["sqlite",pytest.param("postgres",marks=pytest.mark.postgres)])
def auth_app(request, tmp_path):
    endpoint = os.environ.get("BMT_DISCOVERY_TEST_DATABASE_URL","")
    schema = ""
    admin = None
    if request.param == "postgres":
        if not endpoint: pytest.skip("Owned discovery PostgreSQL lab not supplied")
        address = make_url(endpoint)
        assert address.host in ("127.0.0.1","localhost") and address.database == "bmt_discovery_lab"
        admin = make_engine(endpoint)
        schema = "bmt_load_"+uuid.uuid4().hex
        with admin.begin() as connection: connection.execute(text('CREATE SCHEMA "'+schema+'"'))
        engine = make_engine(endpoint,schema=schema)
    else:
        endpoint = "sqlite:///"+(tmp_path/"discovery.sqlite").as_posix()
        engine = make_engine(endpoint)
    settings = Settings(database_url=endpoint, object_dir=str(tmp_path/"objects"), google_client_ids=("test-client",),auth_limit_per_minute=10000,write_limit_per_minute=10000,rate_limit_per_minute=10000)
    app = create_app(settings,engine=engine,identity_verifier=DiscoveryIdentity())
    try:
        upgrade(engine)
        yield app
    finally:
        engine.dispose()
        if admin is not None:
            with admin.begin() as connection: connection.execute(text('DROP SCHEMA "'+schema+'" CASCADE'))
            admin.dispose()


@pytest.fixture
def catalog(auth_app, auth_client, sign_in, monkeypatch):
    identity = sign_in("Discovery Author")
    owner = identity["player"]["id"]
    timestamp = int(time.time())
    monkeypatch.setattr(discovery, "time", SimpleNamespace(time=lambda: timestamp+1))
    with auth_app.state.session_factory() as session:
        tracks = [dict(id=str(uuid.uuid5(uuid.NAMESPACE_URL, f"discovery-track-{n}")), owner_id=owner, official=n < 9) for n in range(5000)]
        versions = [dict(id=str(uuid.uuid5(uuid.NAMESPACE_URL, f"discovery-version-{n}")),track_id=tracks[n]["id"],number=1,name=f"Circuit {n:05d}",content_hash="a"*64,manifest={},discovery={"theme":"pine" if n%2 else "desert","points":[[0,0],[10,0],[10,10]]},state="published",published_at=timestamp-n,created_at=timestamp-n,verified_finishers=n%100,rating_sum=0,rating_count=0) for n in range(5000)]
        session.execute(Track.__table__.insert(),tracks)
        session.execute(TrackVersion.__table__.insert(),versions)
        session.commit()
    return SimpleNamespace(app=auth_app,client=auth_client,tracks=tracks,versions=versions,owner=owner,token=identity["access_token"],timestamp=timestamp)


def query(catalog, **body):
    response = catalog.client.post("/v1/discovery/tracks",json=body)
    assert response.status_code == 200, response.text
    return response.json()


def test_global_search_filters_and_deep_page(catalog):
    page = query(catalog,search="Circuit 04999",search_kind=1)
    assert page["total"] == 1 and page["items"][0]["track_id"] == catalog.tracks[4999]["id"]
    filtered = query(catalog,theme="pine",race_count="high",sort="name")
    assert filtered["total"] == 1250
    assert all(row["theme"] == "pine" and row["verified_finishers"] >= 50 for row in filtered["items"])
    first = query(catalog,sort="name")
    deep = query(catalog,sort="name",cursor=first["page_cursor"],offset=4980)
    assert deep["total"] == 5000 and deep["items"][0]["name"] == "Circuit 04980" and deep["next_cursor"] is None
    assert first["items"][0]["name"] == "Circuit 00000"
    assert [row["discovery_index"] for row in deep["items"]] == list(range(4980,5000))
    anchored = query(catalog,sort="name",locate_version=catalog.versions[4983]["id"],fresh=True)
    assert anchored["offset"] == 4980 and anchored["total"] == 5000 and any(row["version_id"] == catalog.versions[4983]["id"] for row in anchored["items"])


def test_order_snapshot_survives_rating_publish_and_cache_restart(catalog):
    first = query(catalog,sort="score")
    with catalog.app.state.session_factory() as session:
        session.execute(update(TrackVersion).where(TrackVersion.id == catalog.versions[30]["id"]).values(rating_sum=500,rating_count=100))
        session.add(TrackVersion(id=str(uuid.uuid4()),track_id=catalog.tracks[0]["id"],number=2,name="Changed newest",content_hash="b"*64,manifest={},discovery={"theme":"pine","points":[]},state="published",published_at=catalog.timestamp+1,created_at=catalog.timestamp+1))
        session.commit()
    catalog.app.state.discovery_memory.clear() # Second replica/restarted API uses the persistent envelope.
    again = query(catalog,sort="score",cursor=first["page_cursor"],offset=0)
    assert [v["version_id"] for v in first["items"]] == [v["version_id"] for v in again["items"]]
    next_page = query(catalog,sort="score",cursor=first["next_cursor"])
    assert next_page["offset"] == 20 and next_page["items"][0]["discovery_index"] == 20
    assert not set(v["track_id"] for v in first["items"]) & set(v["track_id"] for v in next_page["items"])
    fresh = query(catalog,sort="score",fresh=True)
    assert fresh["items"][0]["track_id"] == catalog.tracks[30]["id"]
    assert catalog.client.post("/v1/discovery/tracks",json={"sort":"name","cursor":first["page_cursor"]}).status_code == 422


def test_shared_first_page_avoids_rebuilding_order(catalog, monkeypatch):
    original = discovery._ordered_ids
    calls = []
    def count(*args): calls.append(1); return original(*args)
    monkeypatch.setattr(discovery,"_ordered_ids",count)
    first = query(catalog,feed="new")
    second = query(catalog,feed="new")
    catalog.app.state.discovery_memory.clear()
    third = query(catalog,feed="new")
    assert first["snapshot"] == second["snapshot"] == third["snapshot"] and len(calls) == 1
    statements = []
    def record(_conn,_cursor,sql,*_args): statements.append(sql)
    event.listen(catalog.app.state.engine,"before_cursor_execute",record)
    try: query(catalog,feed="new",cursor=first["page_cursor"],offset=4000)
    finally: event.remove(catalog.app.state.engine,"before_cursor_execute",record)
    assert len([s for s in statements if "SELECT" in s.upper()]) <= 5
    assert not any("ORDER BY" in s.upper() and "published_at" in s for s in statements)


def test_personal_collections_are_independent_of_preview_cache(catalog):
    favorite = catalog.tracks[4999]["id"]
    page = query(catalog,section="favorites",ids=[favorite])
    assert page["total"] == 1 and page["items"][0]["track_id"] == favorite
    assert query(catalog,section="favorites",ids=[])["total"] == 0
    raced = query(catalog,race_history="raced",raced_ids=[favorite])
    assert raced["total"] == 1 and raced["items"][0]["track_id"] == favorite
    assert query(catalog,race_history="unraced",raced_ids=[favorite])["total"] == 4999
    assert catalog.client.post("/v1/discovery/tracks",json={"section":"saved"}).status_code == 401
    mine = catalog.client.post("/v1/discovery/tracks",json={"section":"saved"},headers={"Authorization":"Bearer "+catalog.token})
    assert mine.status_code == 200 and mine.json()["total"] == 5000


def test_visibility_rechecked_and_unrated_discoverable(catalog):
    first = query(catalog,feed="new")
    hidden = first["items"][0]["track_id"]
    with catalog.app.state.session_factory() as session:
        session.execute(update(Track).where(Track.id == hidden).values(hidden=True))
        session.commit()
    old_page = query(catalog,feed="new",cursor=first["page_cursor"],offset=0)
    assert all(v["track_id"] != hidden for v in old_page["items"])
    fresh = query(catalog,feed="new",fresh=True)
    assert fresh["total"] == 4999 and all(v["rating_average"] is None for v in fresh["items"])
    assert query(catalog,feed="rated")["total"] == 0


def test_confidence_rating_and_global_random(catalog, monkeypatch):
    with catalog.app.state.session_factory() as session:
        session.execute(update(TrackVersion).where(TrackVersion.id == catalog.versions[4000]["id"]).values(rating_sum=5,rating_count=1))
        session.execute(update(TrackVersion).where(TrackVersion.id == catalog.versions[4001]["id"]).values(rating_sum=480,rating_count=100))
        session.commit()
    rated = query(catalog,feed="rated")
    assert rated["items"][0]["track_id"] == catalog.tracks[4001]["id"] and rated["items"][0]["rating_average"] == 4.8
    import random
    monkeypatch.setattr(discovery.random,"SystemRandom",lambda: random.Random(17))
    response = catalog.client.post("/v1/discovery/random",json={"theme":"pine","sort":"name"})
    assert response.status_code == 200
    picked = response.json()["items"][0]
    assert picked["theme"] == "pine" and picked["discovery_index"] > 1000


def test_expiry_and_bad_inputs_preserve_documents(catalog):
    first = query(catalog,feed="new")
    with catalog.app.state.session_factory() as session:
        session.execute(update(DiscoverySnapshot).values(expires_at=catalog.timestamp))
        session.commit()
    catalog.app.state.discovery_memory.clear()
    assert catalog.client.post("/v1/discovery/tracks",json={"feed":"new","cursor":first["page_cursor"]}).status_code == 410
    for body in ({"cursor":"bad"},{"offset":-1},{"feed":"unknown"},{"minimum_rating":6},{"ids":["x"*81]}):
        assert catalog.client.post("/v1/discovery/tracks",json=body).status_code == 422
    assert query(catalog,feed="new",fresh=True)["total"] == 5000


def test_popular_uses_distinct_recent_verified_drivers(catalog):
    with catalog.app.state.session_factory() as session:
        real = [str(uuid.uuid4()) for _ in range(3)]
        artificial = str(uuid.uuid4())
        session.add_all([Player(id=value,display_name="Activity fixture",needs_username=True,is_test_driver=value==artificial) for value in [*real,artificial]])
        session.flush()
        def finish(track_number, player, age=0, status="verified", manifest=None):
            board_id = uuid.uuid4().hex+uuid.uuid4().hex
            ticket_id = str(uuid.uuid4())
            session.add(Board(id=board_id,version_id=catalog.versions[track_number]["id"],vehicle_id="compact",manifest=manifest or {}))
            session.flush()
            session.add(RunTicket(id=ticket_id,player_id=player,board_id=board_id,expires_at=catalog.timestamp+1000))
            session.flush()
            session.add(Run(ticket_id=ticket_id,player_id=player,board_id=board_id,replay_hash="a"*64,status=status,finished_at=catalog.timestamp-age))
            session.flush()
        for _ in range(8): finish(0,real[0])
        finish(1,real[1]); finish(1,real[2])
        finish(2,artificial)
        finish(2,real[0],manifest={"test_population":True})
        finish(2,real[1],manifest={"purpose":"creator_test"})
        finish(2,real[2],age=8*86400)
        finish(2,real[0],status="failed")
        session.commit()
    popular = query(catalog,feed="popular")
    assert [row["track_id"] for row in popular["items"][:2]] == [catalog.tracks[1]["id"],catalog.tracks[0]["id"]]


def test_random_rechecks_sparse_visibility_and_allows_sole_current_track(catalog):
    initial = query(catalog,sort="name")
    survivor = catalog.tracks[4999]["id"]
    with catalog.app.state.session_factory() as session:
        session.execute(update(Track).where(Track.id != survivor).values(hidden=True))
        session.commit()
    picked = catalog.client.post("/v1/discovery/random",json={"sort":"name","cursor":initial["page_cursor"],"exclude":survivor})
    assert picked.status_code == 200 and picked.json()["items"][0]["track_id"] == survivor
