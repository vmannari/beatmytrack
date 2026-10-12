import json
from dataclasses import replace

import pytest
from sqlalchemy import func, select
from test_domains import FakeVerifier

from bmt_backend.commerce import lock_entitlements
from bmt_backend.identity_models import Identity, Player
from bmt_backend.purchase_lab_catalog import CATALOG_PATH, seed_lab_catalog
from bmt_backend.track_models import PersonalBest, Run, Track, TrackVersion


class CatalogVerifier(FakeVerifier):
    def __init__(self):
        self.preparations = 0
        self.rules = "test-rules-1"

    def manifest(self):
        return {**super().manifest(), "rules_key": self.rules}

    def prepare_track(self, document):
        self.preparations += 1
        return document, self.validate_track(document)


def lab(app):
    app.state.settings = replace(app.state.settings, environment="development", dev_auth_enabled=True,
        dev_auth_key="catalog-test-only-"*3, purchase_simulation_enabled=True)
    app.state.verifier = CatalogVerifier()
    return app


def source(tmp_path):
    path = tmp_path / "catalog.json"
    path.write_text(json.dumps({"format":"bmt-purchase-lab-catalog-v1",
        "documents":[{"id":"approved_course","name":"Approved course","creator":"Beat my track"}]}))
    return path


def test_catalog_restart_retains_one_slot_and_has_no_fake_racing(auth_app, auth_client, tmp_path):
    app = lab(auth_app)
    path = source(tmp_path)
    first = seed_lab_catalog(app, catalog_path=path)
    assert first == {"tracks":1,"published":1,"existing":0}
    published = auth_client.get("/v1/tracks").json()["items"]
    assert len(published) == 1 and published[0]["name"] == "Approved course"
    assert seed_lab_catalog(app, catalog_path=path) == {"tracks":1,"published":0,"existing":1}
    assert app.state.verifier.preparations == 1
    with app.state.session_factory() as session:
        owner = session.scalar(select(Player).join(Identity).where(Identity.subject == "developer"))
        row = lock_entitlements(session, owner.id)
        assert row.slots == 1 and row.simulated_slots == 0
        assert session.scalar(select(func.count()).select_from(Run)) == 0
        assert session.scalar(select(func.count()).select_from(PersonalBest)) == 0


def test_new_build_creates_immutable_revision_without_replacing_creator_track(auth_app, tmp_path):
    app = lab(auth_app)
    path = source(tmp_path)
    seed_lab_catalog(app, catalog_path=path)
    with app.state.session_factory() as session:
        owner = session.scalar(select(Player).join(Identity).where(Identity.subject == "developer"))
        own = Track(owner_id=owner.id, authoring_id="approved_course")
        session.add(own)
        session.flush()
        session.add(TrackVersion(track_id=own.id, number=1, name="Player's own draft",
            content_hash="a"*64, manifest={}, state="draft"))
        row = lock_entitlements(session, owner.id)
        row.simulated_slots = 5
        row.simulated_forever = True
        session.commit()
        owner_id = owner.id
        original = session.scalar(select(TrackVersion).where(TrackVersion.state == "published"))
        original_id = original.id
    app.state.verifier.rules = "test-rules-2"
    assert seed_lab_catalog(app, catalog_path=path)["published"] == 1
    with app.state.session_factory() as session:
        assert session.get(TrackVersion, original_id).manifest["rules_key"] == "test-rules-1"
        assert session.scalar(select(func.count()).select_from(TrackVersion)) == 3
        assert session.scalar(select(TrackVersion.name).where(TrackVersion.state == "draft")) == "Player's own draft"
        row = lock_entitlements(session, owner_id)
        assert row.simulated_slots == 5 and row.simulated_forever and row.slots == 1


def test_seeding_rejects_other_backends_and_catalog_contains_public_documents_only(auth_app):
    with pytest.raises(ValueError):
        seed_lab_catalog(auth_app)
    app = lab(auth_app)
    app.state.settings = replace(app.state.settings, database_url="postgresql+psycopg://invalid/test")
    with pytest.raises(ValueError):
        seed_lab_catalog(app)
    bundle = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    assert len(bundle["documents"]) == 27
    assert len({d["id"] for d in bundle["documents"]}) == 27
    assert set(bundle) == {"format","source_sha256","documents"}
    assert all(d["schema"] == "creator-track-v5" for d in bundle["documents"])
