from sqlalchemy import select

from bmt_backend.identity_models import Identity, Player
from bmt_backend.official_tracks import OFFICIAL_NAME, seed_documents
from bmt_backend.track_models import Track, TrackVersion


class AcceptTracks:
    def prepare_track(self, document):
        assert document["creator"] == OFFICIAL_NAME
        return document, {"laps": 5, "tick_rate": 120, "track_content_hash": "canonical"}


def test_official_seed_is_owned_published_and_idempotent(auth_app):
    with auth_app.state.session_factory() as session:
        owner = Player(display_name=OFFICIAL_NAME)
        session.add(owner)
        session.flush()
        session.add(Identity(player_id=owner.id, provider="development", subject="developer"))
        session.commit()

    document = {"schema": "creator-track-v5", "id": "track_seed", "name": "Infinity", "creator": ""}
    first = seed_documents(
        auth_app.state.session_factory, auth_app.state.blobs, AcceptTracks(), [document]
    )
    second = seed_documents(
        auth_app.state.session_factory, auth_app.state.blobs, AcceptTracks(), [document]
    )
    assert first[0]["status"] == "published"
    assert second == [{**first[0], "status": "existing"}]

    with auth_app.state.session_factory() as session:
        versions = session.scalars(select(TrackVersion)).all()
        assert len(versions) == 1
        version = versions[0]
        track = session.get(Track, version.track_id)
        assert version.state == "published"
        assert version.creator_test_run_id is None
        assert track.owner_id == owner.id
        stored = auth_app.state.blobs.get_json(version.content_hash)
        assert stored["creator"] == OFFICIAL_NAME


def test_official_seed_requires_fixed_account(auth_app):
    try:
        seed_documents(auth_app.state.session_factory, auth_app.state.blobs, AcceptTracks(), [])
    except RuntimeError as error:
        assert str(error) == f"Active {OFFICIAL_NAME} development account not found"
    else:
        raise AssertionError("missing official owner was accepted")


def test_official_restore_renames_legacy_owner_and_keeps_track_uid(auth_app):
    with auth_app.state.session_factory() as session:
        owner = Player(display_name="Beat My Track")
        session.add(owner)
        session.flush()
        session.add(Identity(player_id=owner.id, provider="development", subject="developer"))
        track = Track(owner_id=owner.id, authoring_id="track_restored")
        session.add(track)
        session.flush()
        original = {"id": "track_restored", "name": "Knot", "creator": "Beat My Track"}
        old_hash = auth_app.state.blobs.put_json(original)
        version = TrackVersion(
            track_id=track.id, number=1, name="Knot", content_hash=old_hash,
            manifest={}, revision_key="old", discovery={}, state="published",
        )
        session.add(version)
        session.commit()
        track_id, owner_id = track.id, owner.id

    restored = seed_documents(
        auth_app.state.session_factory, auth_app.state.blobs, AcceptTracks(), [original]
    )
    retried = seed_documents(
        auth_app.state.session_factory, auth_app.state.blobs, AcceptTracks(), [original]
    )
    assert retried == [{**restored[0], "status": "existing"}]
    with auth_app.state.session_factory() as session:
        assert session.get(Player, owner_id).display_name == "Beat my track"
        assert len(session.scalars(select(Track)).all()) == 1
        versions = session.scalars(select(TrackVersion).order_by(TrackVersion.number)).all()
        assert len(versions) == 2
        assert all(v.track_id == track_id for v in versions)
        assert all(v.creator_test_run_id is None for v in versions)
        assert auth_app.state.blobs.get_json(old_hash) == original
        assert auth_app.state.blobs.get_json(versions[1].content_hash)["creator"] == "Beat my track"
