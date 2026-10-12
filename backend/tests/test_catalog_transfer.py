"""Official track retention without account impersonation or invented results."""
import importlib.util
from copy import deepcopy
from pathlib import Path

import pytest
from sqlalchemy import func, select

from bmt_backend.identity_models import Identity, Player, SessionFamily
from bmt_backend.storage import canonical_json
from bmt_backend.track_models import Track, TrackVersion, digest

spec = importlib.util.spec_from_file_location("catalog_transfer_tests", Path(__file__).parents[1] / "deploy/gcp/catalog_transfer.py")
transfer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transfer)
OWNER = "10000000-0000-4000-8000-000000000001"
TRACK = "20000000-0000-4000-8000-000000000001"
OLD = "30000000-0000-4000-8000-000000000001"
HEAD = "30000000-0000-4000-8000-000000000002"
SOURCE = "http://127.0.0.1:18181"
MANIFEST = {"laps": 5, "tick_rate": 120, "rules_key": "fixture-current", "track_content_hash": "fixture-physical-contract"}


class Verifier:
    def __init__(self):
        self.calls = []

    def validate_track(self, document):
        self.calls.append(document)
        return MANIFEST


def payload():
    old = {"id": "retained", "name": "Old name", "creator": "Beat My Track"}
    head = {"id": "retained", "name": "Kept circuit", "creator": "Beat my track"}
    def version(id, number, doc, manifest):
        return {"id": id, "track_id": TRACK, "number": number, "name": doc["name"],
                "content_hash": digest(doc), "revision_key": digest({"revision": number}),
                "manifest": manifest, "discovery": {"points": [], "theme": "pine"},
                "state": "published", "created_at": number, "published_at": number}
    return {"format": "bmt-catalog-transfer-v1", "source_origin": SOURCE, "transfer_created_at": 1700000000,
            "owners": [{"id": OWNER, "display_name": "Beat my track", "created_at": 1}],
            "tracks": [{"id": TRACK, "owner_id": OWNER, "authoring_id": "retained", "hidden": False,
                        "archived": False, "official": True, "created_at": 1}],
            "versions": [version(OLD, 1, old, {"rules_key": "historical"}), version(HEAD, 2, head, MANIFEST)],
            "objects": {digest(old): old, digest(head): head}}


def run(app, data=None, verifier=None, apply=True):
    return transfer.import_catalog(data or payload(), app.state.session_factory, app.state.blobs,
                                   verifier or Verifier(), confirm_source=SOURCE, apply=apply)


def test_dry_run_validates_only_current_head_without_writing(auth_app, monkeypatch):
    monkeypatch.setattr(auth_app.state.blobs, "put_json", lambda _: pytest.fail("Dry run wrote an object"))
    verifier = Verifier()
    assert run(auth_app, verifier=verifier, apply=False)["status"] == "validated"
    assert len(verifier.calls) == 1 and verifier.calls[0]["name"] == "Kept circuit"
    with auth_app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(Player)) == 0


def test_import_preserves_ids_old_bytes_and_is_idempotent(auth_app):
    first, retry = run(auth_app), run(auth_app)
    assert first["inserted_tracks"] == 1 and first["inserted_versions"] == 2
    assert retry["inserted_tracks"] == retry["inserted_versions"] == 0
    with auth_app.state.session_factory() as session:
        assert session.get(Track, TRACK).owner_id == OWNER
        assert session.scalar(select(func.count()).select_from(Identity)) == 0
        for id in (OLD, HEAD):
            row = session.get(TrackVersion, id)
            assert row.creator_test_run_id is None and row.rating_count == row.verified_finishers == 0
            assert canonical_json(auth_app.state.blobs.get_json(row.content_hash)) == canonical_json(payload()["objects"][row.content_hash])


def test_hash_mismatch_is_rejected_before_mutation(auth_app):
    data = payload()
    key = next(iter(data["objects"]))
    data["objects"][key]["name"] = "Altered immutable source"
    with pytest.raises(ValueError, match="hash mismatch"):
        run(auth_app, data)
    with auth_app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(Track)) == 0


def test_authenticated_owner_is_never_adopted(auth_app, monkeypatch):
    with auth_app.state.session_factory() as session:
        session.add(Player(id=OWNER, display_name="Beat my track"))
        session.flush()
        session.add(Identity(player_id=OWNER, provider="google", subject="isolated-fixture-subject"))
        session.commit()
    monkeypatch.setattr(auth_app.state.blobs, "put_json", lambda _: pytest.fail("Conflict wrote an object"))
    with pytest.raises(RuntimeError, match="authenticated account"):
        run(auth_app)


def test_new_build_adds_a_deterministic_revision_without_changing_original(auth_app):
    data = payload()
    data["versions"][-1]["manifest"] = {**MANIFEST, "rules_key": "fixture-previous"}
    first, retry = run(auth_app, data), run(auth_app, data)
    assert first["compatible_revisions"] == 1 and first["inserted_versions"] == 3
    assert retry["inserted_versions"] == 0
    with auth_app.state.session_factory() as session:
        assert session.get(TrackVersion, HEAD).manifest["rules_key"] == "fixture-previous"
        newest = session.scalar(select(TrackVersion).where(TrackVersion.track_id == TRACK, TrackVersion.number == 3))
        assert newest.manifest == MANIFEST and newest.content_hash == data["versions"][-1]["content_hash"]


def test_unsupported_native_contract_cannot_publish(auth_app):
    class InvalidVerifier(Verifier):
        def validate_track(self, document):
            return {**MANIFEST, "laps": 3}
    with pytest.raises(ValueError, match="unsupported race contract"):
        run(auth_app, verifier=InvalidVerifier())


def test_existing_revision_cannot_be_overwritten(auth_app):
    run(auth_app)
    data = deepcopy(payload())
    data["versions"][-1]["name"] = "Changed published metadata"
    with pytest.raises(RuntimeError, match="immutable revision"):
        run(auth_app, data)
    with auth_app.state.session_factory() as session:
        assert session.get(TrackVersion, HEAD).name == "Kept circuit"


def test_existing_google_account_and_session_survive(auth_app):
    player = "40000000-0000-4000-8000-000000000001"
    with auth_app.state.session_factory() as session:
        session.add(Player(id=player, display_name="Existing cloud racer"))
        session.flush()
        session.add(Identity(player_id=player, provider="google", subject="existing-isolated-subject"))
        family = SessionFamily(player_id=player, expires_at=1900000000, revoked=False)
        session.add(family)
        session.flush()
        family_id = family.id
        session.commit()
    run(auth_app)
    with auth_app.state.session_factory() as session:
        assert session.get(Player, player).display_name == "Existing cloud racer"
        assert not session.get(SessionFamily, family_id).revoked
        assert session.scalar(select(func.count()).select_from(Identity)) == 1
