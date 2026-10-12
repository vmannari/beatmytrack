"""Telemetry authority facts commit once with scores/publications, never ahead."""
# ruff: noqa: F811
from dataclasses import replace

import pytest
from sqlalchemy import func, select
from test_domains import domain, headers, publish, race, submit, ticket, upload  # noqa: F401

from bmt_backend.commerce_models import Entitlements, PublicationSlot
from bmt_backend.telemetry_models import ProductEvent
from bmt_backend.track_models import PersonalBest, Run, TrackVersion
from bmt_backend.worker import finalize, process_one


def events(lab, name=None):
    with lab.factory() as session:
        query = select(ProductEvent).where(ProductEvent.source == "server")
        if name:
            query = query.where(ProductEvent.name == name)
        return session.scalars(query).all()


def enabled(lab):
    lab.app.state.settings = replace(lab.app.state.settings, telemetry_enabled=True)


def test_disabled_collection_keeps_existing_racing_and_publishing(domain):
    version = upload(domain)
    result = race(domain, version)
    publish(domain, version)
    assert result["status"] == "verified" and events(domain) == []


def test_accepted_fact_and_publication_are_exactly_once(domain):
    enabled(domain)
    version = upload(domain)
    result = race(domain, version)
    accepted = events(domain, "race_accepted")
    assert len(accepted) == 1 and accepted[0].is_test_driver is False
    assert accepted[0].player_id == domain.players["Creator"]
    assert accepted[0].properties["track_version"] == version["version_id"]
    assert accepted[0].properties["run_id"] == result["run_id"]
    assert accepted[0].properties["lap_count"] == 5
    publish(domain, version)
    for _repeat in range(3):
        publish(domain, version)
    assert len(events(domain, "track_published")) == 1
    assert len(events(domain, "race_accepted")) == 1
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(PublicationSlot)) == 1


def test_outbox_failure_rolls_back_score_and_recovers_cached_proof(domain, monkeypatch):
    from bmt_backend import telemetry
    enabled(domain)
    version = upload(domain)
    issued = ticket(domain, version)
    submitted = submit(domain, issued)
    original = telemetry.append_server_event

    def unavailable(*_args, **_kwargs):
        raise RuntimeError("Injected product outbox failure")

    monkeypatch.setattr(telemetry, "append_server_event", unavailable)
    with pytest.raises(RuntimeError, match="Injected product outbox failure"):
        process_one(domain.app)
    with domain.factory() as session:
        run = session.get(Run, submitted["run_id"])
        assert run.status == "verifying" and run.time_ticks is None
        assert session.scalar(select(func.count()).select_from(PersonalBest)) == 0
        assert session.get(TrackVersion, version["version_id"]).state == "draft"
    assert events(domain) == []
    pending = domain.app.state.pending_finalization
    assert pending is not None
    monkeypatch.setattr(telemetry, "append_server_event", original)
    assert finalize(domain.app, *pending) is True
    assert finalize(domain.app, *pending) is False
    assert len(events(domain, "race_accepted")) == 1
    with domain.factory() as session:
        assert session.get(Run, submitted["run_id"]).status == "verified"
        assert session.scalar(select(func.count()).select_from(PersonalBest)) == 1


def test_publication_outbox_failure_preserves_slot_and_version(domain, monkeypatch):
    from bmt_backend import telemetry
    enabled(domain)
    version = upload(domain)
    race(domain, version)
    original = telemetry.append_server_event

    def unavailable(*_args, **_kwargs):
        raise RuntimeError("Injected publication outbox failure")

    monkeypatch.setattr(telemetry, "append_server_event", unavailable)
    with pytest.raises(RuntimeError, match="Injected publication outbox failure"):
        publish(domain, version)
    with domain.factory() as session:
        assert session.get(TrackVersion, version["version_id"]).state == "tested"
        assert session.scalar(select(func.count()).select_from(PublicationSlot)) == 0
        access = session.get(Entitlements, domain.players["Creator"])
        assert access is None or access.slots == 1
    assert events(domain, "track_published") == []
    monkeypatch.setattr(telemetry, "append_server_event", original)
    publish(domain, version)
    assert len(events(domain, "track_published")) == 1


def test_client_claimed_verified_result_never_creates_authority():
    from bmt_backend.telemetry import ALLOWED, SERVER_NAMES
    assert "race_accepted" in SERVER_NAMES and "race_accepted" not in ALLOWED
    assert "track_published" in SERVER_NAMES and "track_published" not in ALLOWED
