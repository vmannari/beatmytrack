"""Publish with real PostgreSQL worker authority, including official creators."""
import uuid
from dataclasses import replace

import pytest
from fastapi import Request
from fastapi.testclient import TestClient
from sqlalchemy import func, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session
from test_cloud_setup import database as _database_fixture
from test_domains import FakeVerifier

from bmt_backend import cloud_setup
from bmt_backend.app import create_app
from bmt_backend.commerce_models import Entitlements, PublicationSlot
from bmt_backend.community import TERMS_VERSION
from bmt_backend.community_models import CommunityAcceptance
from bmt_backend.config import Settings
from bmt_backend.database_privileges import verify_runtime
from bmt_backend.db import make_engine
from bmt_backend.identity_models import Identity, Player
from bmt_backend.publication_models import PublicationIntent
from bmt_backend.publications import process_one
from bmt_backend.security import current_player
from bmt_backend.track_models import Track, TrackVersion

pytestmark = pytest.mark.postgres
database = _database_fixture


@pytest.mark.parametrize("provider,subject,official", [
    ("development", "ordinary-creator", False),
    ("development", "developer", True),
    ("google", "developer", False),
])
@pytest.mark.parametrize("simulation", [False, True])
def test_new_track_publishes_without_worker_identity_reads(database, tmp_path, provider, subject, official, simulation):
    engine, schema, roles, url = database
    cloud_setup.setup(engine, uuid.uuid4().hex, roles, schema)
    peers = {kind: make_engine(make_url(url).set(username=roles[kind], password="isolated-security-test-role")
                              .render_as_string(hide_password=False), schema=schema)
             for kind in ("api", "worker")}
    try:
        for kind, peer in peers.items():
            verify_runtime(peer, Settings(workload_role=kind))
        with Session(engine) as session:
            player = Player(display_name="Publication fixture")
            session.add(player)
            session.flush()
            player_id = player.id
            session.add_all([Identity(player_id=player_id, provider=provider, subject=subject),
                             CommunityAcceptance(player_id=player_id, version=TERMS_VERSION)])
            session.commit()
        with pytest.raises(DBAPIError) as denied, peers["worker"].begin() as db:
            db.execute(text("SELECT id,player_id,provider,subject FROM identities"))
        assert denied.value.orig.sqlstate == "42501"
        with peers["worker"].connect() as db:
            assert db.scalar(text("SELECT bmt_is_official_publisher(:id)"), {"id": player_id}) is official
            assert db.scalar(text("SELECT bmt_is_official_publisher('unknown')")) is False
            assert db.scalar(text("SELECT bmt_has_development_identity(:id)"), {"id": player_id}) is (provider == "development")
        with pytest.raises(DBAPIError) as denied, peers["api"].begin() as db:
            db.execute(text("SELECT bmt_is_official_publisher(:id)"), {"id": player_id})
        assert denied.value.orig.sqlstate == "42501"
        settings = Settings(environment="development" if simulation else "test", local_drafts_only=True,
                            object_dir=str(tmp_path), purchase_simulation_enabled=simulation,
                            dev_auth_enabled=simulation, dev_auth_key="p" * 40 if simulation else "")
        api = create_app(settings, verifier=FakeVerifier(), engine=peers["api"])
        worker = create_app(replace(settings, workload_role="worker"), verifier=FakeVerifier(), engine=peers["worker"])

        def authenticated(_request: Request):
            with Session(peers["api"]) as session:
                player = session.get(Player, player_id)
                session.expunge(player)
                return player

        api.dependency_overrides[current_player] = authenticated
        # Keep normal owner/body validation and storage admission on the API;
        # only canonical physics is supplied by the existing domain fixture.
        document = {"schema": "creator-track-v5", "id": "new_publication", "name": "Permission loop",
                    "shape": "oval", "points": [[0, 0], [20, 0], [20, 20], [0, 20]]}
        manifest = FakeVerifier().validate_track(document)
        from bmt_backend.publications import CONTRACT_FIELDS
        contract = {field: manifest[field] for field in CONTRACT_FIELDS if field != "config_hash"}
        contract["config_hash"] = manifest["vehicles"]["compact"]["config_hash"]
        body = {"name": document["name"], "document": document, "vehicle_id": "compact", "contract": contract,
                "replay": {"schema": "bmt-trajectory-v1", "input_count": 120,
                           "race_proof": {"schema": "bmt-race-path-v1", "samples": [[0, 0, 0, 0], [120, 0, 0, 0]]}}}
        with TestClient(api) as client:
            response = client.post("/v1/publications", json=body, headers={"Idempotency-Key": str(uuid.uuid4())})
            assert response.status_code == 202, response.text
            publication_id = response.json()["publication_id"]
            assert process_one(worker)
            result = client.get("/v1/me/publications/" + publication_id).json()
            assert result["state"] == "published", result
            # A separate request for identical content cannot double consume.
            repeated = client.post("/v1/publications", json=body, headers={"Idempotency-Key": str(uuid.uuid4())})
            assert repeated.status_code == 202, repeated.text
            assert process_one(worker)
            assert client.get("/v1/me/publications/" + repeated.json()["publication_id"]).json()["receipt"] == result["receipt"]
        with Session(engine) as session:
            assert session.scalar(select(Track.official)) is official
            assert session.scalar(select(func.count()).select_from(TrackVersion)) == 1
            assert session.scalar(select(func.count()).select_from(PublicationSlot)) == 1
            free_official = official and not simulation
            assert session.scalar(select(PublicationSlot.source)) == ("official" if free_official else "initial_or_paid")
            assert session.get(Entitlements, player_id).slots == (1 if free_official else 0)
            assert session.get(PublicationIntent, publication_id).status == "published"
    finally:
        for peer in peers.values():
            peer.dispose()
