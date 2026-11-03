"""Deployment must make actual published heads raceable without relabelling history."""
# ruff: noqa: F811 - parametrized fixture is intentionally imported.
from copy import deepcopy

import pytest
from sqlalchemy import func, select
from test_domains import domain, public_course, race  # noqa: F401

from bmt_backend.catalog_builds import apply_refresh, check_catalog, plan_refresh, published_heads
from bmt_backend.discovery_models import DiscoveryDay
from bmt_backend.track_models import Board, PersonalBest, Run, Track, TrackVersion, now


def stale(domain):
    version, board = public_course(domain)
    race(domain,version,"Alice",frames=20)
    with domain.factory() as session:
        head = session.get(TrackVersion,version["version_id"])
        head.manifest = {**head.manifest,"physics_version":"older-build"}
        session.commit()
    return version,board


def test_health_manifest_alone_cannot_pass_catalogue_compatibility(domain):
    stale(domain)
    with domain.factory() as session, pytest.raises(RuntimeError,match="published track contracts"):
        check_catalog(session,domain.app.state.verifier.manifest())


def test_refresh_adds_current_revision_and_retains_old_records(domain):
    version,board = stale(domain)
    with domain.factory() as session:
        old = session.get(TrackVersion,version["version_id"])
        original = deepcopy(old.manifest)
        old_board = deepcopy(session.get(Board,board).manifest)
        best = session.get(PersonalBest,(board,domain.players["Alice"]))
        old_source = best.run_id
        run_count = session.scalar(select(func.count()).select_from(Run))
        plan = plan_refresh(session,domain.app.state.blobs,domain.app.state.verifier)
        ids = apply_refresh(session,plan)
        session.commit()
        assert len(ids) == 1
        current = session.get(TrackVersion,ids[0])
        assert current.number == old.number+1 and current.content_hash == old.content_hash
        assert current.name == old.name and current.discovery == old.discovery
        assert current.rating_count == current.verified_finishers == 0
        assert session.get(TrackVersion,old.id).manifest == original
        assert session.get(Board,board).manifest == old_board
        assert session.get(PersonalBest,(board,domain.players["Alice"])).run_id == old_source
        assert session.scalar(select(func.count()).select_from(Run)) == run_count
        assert check_catalog(session,domain.app.state.verifier.manifest())["compatible_tracks"] == 1
        assert plan_refresh(session,domain.app.state.blobs,domain.app.state.verifier) == []


def test_refresh_advances_today_discovery_without_changing_selection(domain):
    version, _ = stale(domain)
    with domain.factory() as session:
        old = session.get(TrackVersion, version["version_id"])
        day = now() // 86400
        original = [{"track_id": old.track_id, "version_id": old.id, "reason": "ranked"},
                    {"track_id": "other", "version_id": "other-version", "reason": "fresh"}]
        session.add(DiscoveryDay(day=day, policy="test", shard=0, cursor="", pools={},
                                 items=deepcopy(original), published_at=now()))
        session.flush()
        new_id = apply_refresh(session, plan_refresh(session, domain.app.state.blobs,
                                                     domain.app.state.verifier))[0]
        session.commit()
        assert session.get(DiscoveryDay, day).items == [
            {**original[0], "version_id": new_id}, original[1]]
        assert session.get(TrackVersion, old.id) is not None


def test_refresh_rejects_mismatched_discovery_pin_atomically(domain):
    version, _ = stale(domain)
    with domain.factory() as session:
        day = now() // 86400
        session.add(DiscoveryDay(day=day, policy="test", shard=0, cursor="", pools={},
            items=[{"track_id": "wrong", "version_id": version["version_id"]}], published_at=now()))
        session.commit()
        plan = plan_refresh(session, domain.app.state.blobs, domain.app.state.verifier)
        with pytest.raises(RuntimeError, match="track/version mismatch"):
            apply_refresh(session, plan)
        session.rollback()
        assert len(published_heads(session)) == 1
        assert session.get(DiscoveryDay, day).items[0]["version_id"] == version["version_id"]


def test_refresh_waits_for_in_progress_daily_selection(domain):
    stale(domain)
    with domain.factory() as session:
        session.add(DiscoveryDay(day=now() // 86400, policy="test", shard=0, cursor="",
                                 pools={"ranked": []}, items=[], published_at=0))
        session.commit()
        plan = plan_refresh(session, domain.app.state.blobs, domain.app.state.verifier)
        with pytest.raises(RuntimeError, match="being prepared"):
            apply_refresh(session, plan)
        session.rollback()
        assert len(published_heads(session)) == 1


def test_refresh_rechecks_head_and_rolls_back_without_partial_changes(domain):
    version,_ = stale(domain)
    with domain.factory() as session:
        plan = plan_refresh(session,domain.app.state.blobs,domain.app.state.verifier)
        session.get(TrackVersion,version["version_id"]).manifest = {"changed":True}
        session.flush()
        with pytest.raises(RuntimeError,match="head changed"):
            apply_refresh(session,plan)
        session.rollback()
        assert len(published_heads(session)) == 1
        assert session.scalar(select(func.count()).select_from(TrackVersion)) == 1


def test_refresh_rejects_geometry_changes(domain,monkeypatch):
    stale(domain)
    verifier = domain.app.state.verifier
    original = verifier.validate_track
    monkeypatch.setattr(verifier,"validate_track",lambda doc:{**original(doc),"route_length":9999})
    with domain.factory() as session, pytest.raises(RuntimeError,match="geometry changed"):
        plan_refresh(session,domain.app.state.blobs,verifier)


def test_hidden_tracks_remain_outside_catalogue_refresh(domain):
    version,_ = stale(domain)
    with domain.factory() as session:
        head = session.get(TrackVersion,version["version_id"])
        session.get(Track,head.track_id).hidden = True
        session.commit()
        assert plan_refresh(session,domain.app.state.blobs,domain.app.state.verifier) == []
