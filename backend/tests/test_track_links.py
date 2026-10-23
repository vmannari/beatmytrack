"""Publication headlines and browser-to-native Free Race links."""
from uuid import uuid4

from sqlalchemy import func, select
from test_domains import domain as domain_fixture
from test_domains import headers, public_course

from bmt_backend import news
from bmt_backend.admin_models import AdminAudit
from bmt_backend.identity_models import Player
from bmt_backend.news_models import NewsItem
from bmt_backend.studio_case_models import StudioCase, StudioQuarantine
from bmt_backend.track_models import Track, TrackVersion

domain = domain_fixture


def test_owner_publication_headline_is_transactional_idempotent_and_private(domain):
    version, _ = public_course(domain)
    version_id = version["version_id"]
    with domain.factory() as session:
        stored = session.get(TrackVersion, version_id)
        track = session.get(Track, stored.track_id)
        creator = session.get(Player, track.owner_id)
        for _ in range(3):
            news.capture_publication(session, stored, track, creator)
        session.commit()
        assert session.scalar(select(func.count()).select_from(NewsItem).where(
            NewsItem.kind == "track_published", NewsItem.version_id == version_id)) == 1
    for name in ["Creator", "Alice"]:
        response = domain.client.get("/v1/news", headers=headers(domain, name))
        assert response.status_code == 200
        stories = [item for item in response.json()["items"] if item["kind"] == "track_published"]
        assert len(stories) == (1 if name == "Creator" else 0)
        if stories:
            assert stories[0]["version_id"] == version_id
            assert stories[0]["track_name"] == version["name"]


def test_track_link_preview_and_metadata_target_the_same_published_version(domain):
    version, _ = public_course(domain)
    version_id = version["version_id"]
    metadata = domain.client.get("/v1/track-versions/" + version_id).json()
    assert metadata["share_url"].endswith("/t/" + version_id)
    page = domain.client.get("/t/" + version_id)
    assert page.status_code == 200
    assert "beatmytrack://track/" + version_id in page.text
    assert "FREE RACE" in page.text
    assert page.headers["cache-control"] == "no-store"
    assert domain.client.get("/t/not-a-version").status_code == 422
    with domain.factory() as session:
        stored = session.get(TrackVersion, version_id)
        stored.name = '<script>alert("track")</script>'
        session.commit()
    assert "<script>" not in domain.client.get("/t/" + version_id).text
    assert "&lt;script&gt;" in domain.client.get("/t/" + version_id).text


def test_track_link_uses_existing_visibility_and_quarantine_rules(domain):
    version, _ = public_course(domain)
    version_id = version["version_id"]
    with domain.factory() as session:
        stored = session.get(TrackVersion, version_id)
        track = session.get(Track, stored.track_id)
        track.hidden = True # Owner-hide links retain access.
        session.commit()
    assert domain.client.get("/t/" + version_id).status_code == 200
    with domain.factory() as session:
        case = StudioCase(title="Track link visibility fixture", track_id=track.id)
        audit = AdminAudit(command_id=str(uuid4()), actor="fixture", action="quarantine",
            entity_id=track.id, reason="fixture", before={}, after={}, request_hash="0"*64,
            request_id=str(uuid4()))
        session.add_all([case, audit])
        session.flush()
        session.add(StudioQuarantine(track_id=track.id, case_id=case.id, audit_id=audit.id))
        session.commit()
    assert domain.client.get("/t/" + version_id).status_code == 404
