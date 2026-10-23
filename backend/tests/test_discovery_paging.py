"""Global coverage, shared stable order, visibility, confidence and query cost."""
import os
import time
import uuid
from types import SimpleNamespace

import pytest
from conftest import TestIdentity as DiscoveryIdentity
from sqlalchemy import text
from sqlalchemy.engine import make_url

from bmt_backend import discovery
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.migrate import upgrade
from bmt_backend.track_models import Track, TrackVersion


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
        tracks = [{"id": str(uuid.uuid5(uuid.NAMESPACE_URL, f"discovery-track-{n}")), "owner_id": owner, "official": n < 9} for n in range(5000)]
        versions = [{"id": str(uuid.uuid5(uuid.NAMESPACE_URL, f"discovery-version-{n}")),"track_id": tracks[n]["id"],"number": 1,"name": f"Circuit {n:05d}","content_hash": "a"*64,"manifest": {},"discovery": {"theme":"pine" if n%2 else "desert","points":[[0,0],[10,0],[10,10]]},"state": "published","published_at": timestamp-n,"created_at": timestamp-n,"verified_finishers": n%100,"rating_sum": 0,"rating_count": 0} for n in range(5000)]
        session.execute(Track.__table__.insert(),tracks)
        session.execute(TrackVersion.__table__.insert(),versions)
        session.commit()
    return SimpleNamespace(app=auth_app,client=auth_client,tracks=tracks,versions=versions,owner=owner,token=identity["access_token"],timestamp=timestamp)



@pytest.mark.parametrize("path", ["/v1/discovery/tracks", "/v1/discovery/random"])
def test_retired_v2_never_rebuilds_catalogues(auth_client, monkeypatch, path):
    def forbidden(*_args, **_kwargs):
        raise AssertionError("Retired v2 attempted a catalogue snapshot")
    monkeypatch.setattr(discovery, "_page", forbidden)
    response = auth_client.post(path, json={"sort":"name"})
    assert response.status_code == 426
    assert response.json()["detail"] == "DISCOVERY_CLIENT_UPDATE_REQUIRED"
