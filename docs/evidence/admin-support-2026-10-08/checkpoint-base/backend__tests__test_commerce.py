"""Owner purchase rules, durable retries, isolation and publication admission."""
# ruff: noqa: F811
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from datetime import datetime, timezone
from uuid import uuid4

import pytest
from sqlalchemy import func, select
from test_domains import domain, headers, race, upload  # noqa: F401

from bmt_backend.commerce import add_month, lock_entitlements
from bmt_backend.commerce_models import Entitlements, PublicationSlot, Purchase
from bmt_backend.config import Settings
from bmt_backend.identity_models import Identity
from bmt_backend.resume_models import ResumeReceipt, ResumeWallet
from bmt_backend.resumes import grant_verified


@pytest.fixture
def lab(domain):
    domain.app.state.settings = replace(domain.app.state.settings, environment="development",
        dev_auth_enabled=True, dev_auth_key="test-lab-key-" * 4, purchase_simulation_enabled=True)
    with domain.factory() as session:
        session.add(Identity(player_id=domain.players["Creator"], provider="development", subject="developer"))
        session.commit()
    return domain


def buy(lab, product="creator_slots_5", outcome="approved", request_id=None, player="Creator"):
    return lab.client.post("/v1/development/purchases", headers=headers(lab, player),
        json={"product_id": product, "outcome": outcome, "request_id": request_id or str(uuid4())})


def entitlement(lab):
    response = lab.client.get("/v1/me/entitlements", headers=headers(lab))
    assert response.status_code == 200, response.text
    return response.json()


def test_catalog_and_initial_allowance_only_once(lab):
    for _ in range(3):
        assert entitlement(lab)["publishing_slots"] == 1
    result = lab.client.get("/v1/development/purchases", headers=headers(lab)).json()
    assert {p["id"]: p["price_eur"] for p in result["products"]} == {
        "creator_slot_1": "0.99", "creator_slots_5": "3.49", "creator_slots_10": "5.99",
        "ad_free_month": "3.49", "ad_free_forever": "9.99"}
    assert not result["entitlements"]["store_available"]


@pytest.mark.parametrize("product,slots", [("creator_slot_1", 1), ("creator_slots_5", 5), ("creator_slots_10", 10)])
def test_slot_grant_replay_is_permanent_and_repeatable(lab, product, slots):
    key = str(uuid4())
    first = buy(lab, product, request_id=key)
    assert first.status_code == 200
    for _ in range(3):
        assert buy(lab, product, request_id=key).status_code == 200
    assert entitlement(lab)["publishing_slots"] == 1 + slots
    assert buy(lab, product).status_code == 200
    assert entitlement(lab)["publishing_slots"] == 1 + 2 * slots
    with lab.factory() as session:
        assert session.scalar(select(func.count()).select_from(Purchase)) == 2


@pytest.mark.parametrize("outcome", ["declined", "cancelled", "pending"])
def test_nonapproved_purchase_never_grants(lab, outcome):
    result = buy(lab, outcome=outcome)
    assert result.status_code == 200
    assert entitlement(lab)["publishing_slots"] == 1
    identity = result.json()["purchase"]["id"]
    if outcome == "pending":
        for _ in range(3):
            approved = lab.client.post(f"/v1/development/purchases/{identity}/resolve", headers=headers(lab),
                json={"outcome": "approved"})
            assert approved.status_code == 200
        assert entitlement(lab)["publishing_slots"] == 6
        assert lab.client.post(f"/v1/development/purchases/{identity}/resolve", headers=headers(lab),
            json={"outcome": "declined"}).status_code == 409


def test_pending_survives_app_recreation_and_lost_response(lab):
    from fastapi.testclient import TestClient

    from bmt_backend.app import create_app
    from bmt_backend.security import current_player
    key = str(uuid4())
    pending = buy(lab, "ad_free_month", "pending", key).json()["purchase"]["id"]
    clone = create_app(lab.app.state.settings, engine=lab.app.state.engine, verifier=lab.app.state.verifier)
    clone.dependency_overrides[current_player] = lab.app.dependency_overrides[current_player]
    with TestClient(clone) as client:
        response = client.post(f"/v1/development/purchases/{pending}/resolve", headers=headers(lab),
            json={"outcome": "approved"})
        assert response.status_code == 200
        expiry = response.json()["entitlements"]["ad_free_until"]
    assert buy(lab, "ad_free_month", "pending", key).json()["entitlements"]["ad_free_until"] == expiry


def test_simulation_closed_to_real_accounts_and_disabled_flag(lab):
    assert buy(lab, player="Alice").status_code == 403
    assert buy(lab, "ad_free_forever").status_code == 200
    assert entitlement(lab)["ad_free"]
    lab.app.state.settings = replace(lab.app.state.settings, purchase_simulation_enabled=False)
    assert buy(lab).status_code == 403
    assert not entitlement(lab)["ad_free"]
    with lab.factory() as session:
        assert session.get(Entitlements, lab.players["Creator"]).simulated_forever
    with pytest.raises(ValueError):
        Settings(purchase_simulation_enabled=True)


def test_tampering_and_account_claim_rejected(lab):
    key = str(uuid4())
    assert buy(lab, request_id=key).status_code == 200
    assert buy(lab, "creator_slot_1", request_id=key).status_code == 409
    with lab.factory() as session:
        session.add(Identity(player_id=lab.players["Alice"], provider="development", subject="other-test"))
        session.commit()
    assert buy(lab, request_id=key, player="Alice").status_code == 409
    assert buy(lab, "unlisted").status_code == 422
    assert buy(lab, request_id="invalid").status_code == 422
    assert entitlement(lab)["publishing_slots"] == 6


@pytest.mark.parametrize("date,expected", [
    ("2026-01-31", "2026-02-28"), ("2028-01-31", "2028-02-29"),
    ("2026-12-31", "2027-01-31"), ("2026-10-06", "2026-11-06")])
def test_calendar_month_rules(date, expected):
    timestamp = int(datetime.fromisoformat(date).replace(tzinfo=timezone.utc).timestamp())
    assert datetime.fromtimestamp(add_month(timestamp), timezone.utc).date().isoformat() == expected


def test_monthly_stacks_expiry_boundary_and_forever(lab, monkeypatch):
    clock = int(datetime(2026, 1, 31, 12, tzinfo=timezone.utc).timestamp())
    monkeypatch.setattr("bmt_backend.commerce.now", lambda: clock)
    assert buy(lab, "ad_free_month").status_code == 200
    assert entitlement(lab)["ad_free_until"] == add_month(clock)
    assert buy(lab, "ad_free_month").status_code == 200
    expiry = add_month(add_month(clock))
    assert entitlement(lab)["ad_free_until"] == expiry
    clock = expiry
    assert not entitlement(lab)["ad_free"]
    assert buy(lab, "ad_free_month").status_code == 200
    assert entitlement(lab)["ad_free_until"] == add_month(clock)
    assert buy(lab, "ad_free_forever").status_code == 200
    clock += 86400 * 400
    assert entitlement(lab)["ad_free"]
    assert buy(lab, "ad_free_month").status_code == 409
    assert buy(lab, "ad_free_forever").status_code == 409


def test_ad_free_rewinds_preserve_banked_daily_and_maximum(lab):
    assert buy(lab, "ad_free_forever").status_code == 200
    with lab.factory() as session:
        grant_verified(session, lab.players["Creator"], "award", "test-award", 7)
        session.commit()
    assert lab.client.get("/v1/resumes", headers=headers(lab)).json()["free_rewinds"]
    race_id = lab.client.post("/v1/resume-races", json={}, headers=headers(lab)).json()["race_id"]
    for ordinal in range(1, 4):
        response = lab.client.post(f"/v1/resume-races/{race_id}/resumes", headers=headers(lab),
            json={"ordinal": ordinal, "input_offset": 120 * ordinal, "from_tick": 120, "to_tick": 0})
        assert response.status_code == 200
        assert response.json()["wallet"]["balance"] == 7
        assert response.json()["wallet"]["free"] == 1
    assert lab.client.post(f"/v1/resume-races/{race_id}/resumes", headers=headers(lab),
        json={"ordinal": 3, "input_offset": 480, "from_tick": 120, "to_tick": 0}).status_code == 409
    with lab.factory() as session:
        assert {r.source for r in session.scalars(select(ResumeReceipt))} == {"ad_free"}
        assert session.get(ResumeWallet, lab.players["Creator"]).free_day == -1


def test_publication_consumes_once_and_failure_keeps_allowance(lab):
    version = upload(lab)
    path = f"/v1/track-versions/{version['version_id']}/publish"
    assert lab.client.post(path, headers=headers(lab)).status_code == 409
    assert entitlement(lab)["publishing_slots"] == 1
    race(lab, version)
    for _ in range(3):
        assert lab.client.post(path, headers=headers(lab)).status_code == 200
    assert entitlement(lab)["publishing_slots"] == 0
    second = upload(lab, document={"shape": "second"})
    race(lab, second)
    second_path = f"/v1/track-versions/{second['version_id']}/publish"
    assert lab.client.post(second_path, headers=headers(lab)).status_code == 409
    assert buy(lab, "creator_slot_1").status_code == 200
    assert lab.client.post(second_path, headers=headers(lab)).status_code == 200
    assert lab.client.get(f"/v1/track-versions/{version['version_id']}/document").status_code == 200
    assert entitlement(lab)["publishing_slots"] == 0


def test_concurrent_last_slot_cannot_publish_twice(lab):
    if not lab.postgres:
        pytest.skip("Production row-lock admission is tested on PostgreSQL")
    versions = [upload(lab, document={"shape": f"course-{n}"}) for n in range(2)]
    for version in versions:
        race(lab, version)
    with ThreadPoolExecutor(max_workers=2) as pool:
        codes = list(pool.map(lambda v: lab.client.post(f"/v1/track-versions/{v['version_id']}/publish",
            headers=headers(lab)).status_code, versions))
    assert sorted(codes) == [200, 409]
    assert entitlement(lab)["publishing_slots"] == 0
    with lab.factory() as session:
        assert session.scalar(select(func.count()).select_from(PublicationSlot)) == 1


def test_concurrent_same_purchase_grants_once(lab):
    if not lab.postgres:
        pytest.skip("Production replica row locks require PostgreSQL")
    key = str(uuid4())
    with ThreadPoolExecutor(max_workers=8) as pool:
        codes = list(pool.map(lambda _: buy(lab, request_id=key).status_code, range(8)))
    assert codes == [200] * 8
    assert entitlement(lab)["publishing_slots"] == 6


def test_verified_grant_and_commit_rollback_boundary(lab):
    from bmt_backend.commerce import fulfill_verified
    with lab.factory() as session:
        row = lock_entitlements(session, lab.players["Creator"])
        purchase = Purchase(id="google_play:verified-test-only", player_id=row.player_id,
            provider="google_play", product_id="creator_slots_5", state="approved")
        session.add(purchase)
        fulfill_verified(session, row, purchase, verified_at=1700000000)
        session.rollback()  # Database/process failure cannot leave only half the grant.
    assert entitlement(lab)["publishing_slots"] == 1
    with lab.factory() as session:
        assert session.get(Purchase, "google_play:verified-test-only") is None


def test_simulation_expiry_and_reset_preserve_real_resources(lab):
    assert buy(lab, "ad_free_month").status_code == 200
    key = str(uuid4())
    for _ in range(2):
        response = lab.client.post("/v1/development/entitlements/adjust", headers=headers(lab),
            json={"request_id": key, "action": "expire_month"})
        assert response.status_code == 200
        assert not response.json()["entitlements"]["ad_free"]
    assert buy(lab, "ad_free_forever").status_code == 200
    response = lab.client.post("/v1/development/entitlements/adjust", headers=headers(lab),
        json={"request_id": str(uuid4()), "action": "reset_ad_free"})
    assert response.status_code == 200 and not response.json()["entitlements"]["ad_free"]
    assert entitlement(lab)["publishing_slots"] == 1
    with lab.factory() as session:
        row = session.get(Entitlements, lab.players["Creator"])
        row.forever = True
        session.commit()
    assert lab.client.post("/v1/development/entitlements/adjust", headers=headers(lab),
        json={"request_id": str(uuid4()), "action": "reset_ad_free"}).json()["entitlements"]["ad_free"]


def test_catalog_recovers_old_pending_and_is_bounded(lab):
    pending = [buy(lab, outcome="pending").json()["purchase"]["id"] for _ in range(20)]
    assert buy(lab, outcome="pending").status_code == 409
    for _ in range(22):
        assert buy(lab, outcome="declined").status_code == 200
    catalog = lab.client.get("/v1/development/purchases", headers=headers(lab)).json()
    assert len(catalog["purchases"]) == 40
    assert {p["id"] for p in catalog["purchases"] if p["state"] == "pending"} == set(pending)


def test_ad_free_recovery_never_mints_credit(lab):
    assert buy(lab, "ad_free_forever").status_code == 200
    begin_key, consume_key = str(uuid4()), str(uuid4())
    race_id = lab.client.post("/v1/resume-races", json={}, headers=headers(lab, key=begin_key)).json()["race_id"]
    selection = {"ordinal": 1, "input_offset": 120, "from_tick": 120, "to_tick": 0, "recovery": "v1"}
    consumed = lab.client.post(f"/v1/resume-races/{race_id}/resumes", headers=headers(lab, key=consume_key),
        json=selection)
    assert consumed.status_code == 200
    for _ in range(2):
        recovered = lab.client.post("/v1/resume-recovery", headers=headers(lab), json={
            "begin_key": begin_key, "consume_key": consume_key, "race_id": race_id,
            "selection": selection, "action": "abandon"})
        assert recovered.status_code == 200
        assert recovered.json()["wallet"]["balance"] == 0
        assert recovered.json()["wallet"]["free"] == 1


def test_existing_publications_are_grandfathered_without_new_initial_reward(tmp_path):
    from alembic import command

    from bmt_backend.db import make_engine, make_session_factory
    from bmt_backend.identity_models import Player
    from bmt_backend.migrate import configuration, upgrade
    from bmt_backend.track_models import Track, TrackVersion
    engine = make_engine("sqlite:///" + (tmp_path / "legacy.sqlite").as_posix())
    command.upgrade(configuration(engine), "0015_exception_recovery")
    factory = make_session_factory(engine)
    with factory() as session:
        owner = Player(display_name="Legacy creator")
        newcomer = Player(display_name="New creator")
        session.add_all([owner, newcomer])
        session.flush()
        track = Track(owner_id=owner.id)
        session.add(track)
        session.flush()
        for number in range(1, 4):
            session.add(TrackVersion(track_id=track.id, number=number, name="Old link",
                content_hash="a" * 64, manifest={}, state="published", published_at=1700000000))
        session.commit()
        owner_id, new_id = owner.id, newcomer.id
    upgrade(engine)
    with factory() as session:
        assert session.get(Entitlements, owner_id).slots == 0
        assert session.get(Entitlements, new_id).slots == 1
        assert session.scalar(select(func.count()).select_from(PublicationSlot)) == 3
        assert session.scalar(select(func.count()).select_from(TrackVersion)) == 3
    engine.dispose()


def test_load_tool_refuses_cloud_and_credentials_in_url():
    from bmt_backend.commerce_loadtest import run
    for url in ("https://example.com", "http://127.0.0.1@evil.example", "http://user:secret@127.0.0.1:18182"):
        with pytest.raises(ValueError):
            run(url, "unused")


def test_pending_month_approved_after_forever_is_fulfilled_once(lab):
    pending = buy(lab, "ad_free_month", "pending").json()["purchase"]["id"]
    assert buy(lab, "ad_free_forever").status_code == 200
    first = lab.client.post(f"/v1/development/purchases/{pending}/resolve", headers=headers(lab),
        json={"outcome": "approved"})
    assert first.status_code == 200
    assert first.json()["entitlements"]["ad_free_forever"]
    expiry = first.json()["entitlements"]["ad_free_until"]
    assert lab.client.post(f"/v1/development/purchases/{pending}/resolve", headers=headers(lab),
        json={"outcome": "approved"}).json()["entitlements"]["ad_free_until"] == expiry
