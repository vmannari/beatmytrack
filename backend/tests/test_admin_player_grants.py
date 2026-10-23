"""Support grants reach ordinary game APIs atomically, without billing or coin charges."""
# ruff: noqa: F401, F811
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from types import SimpleNamespace
from uuid import uuid4

import pytest
from sqlalchemy import func, select
from test_commerce import lab
from test_domains import domain, headers
from test_store_admin import ANALYST, OWNER, store

from bmt_backend import admin_player_grants as grants
from bmt_backend.admin_models import AdminAudit
from bmt_backend.commerce_models import Entitlements, Purchase
from bmt_backend.economy_models import CoinWallet, CosmeticUnlock
from bmt_backend.identity_models import Player
from bmt_backend.resume_models import ResumeGrant, ResumeWallet
from bmt_backend.track_models import now


@pytest.fixture
def durable_store(store, tmp_path):
    """Concurrent SQLite requests need independent connections to one on-disk database."""
    if store.postgres:
        yield store
        return
    import sqlite3

    from fastapi.testclient import TestClient
    from test_domains import FakeVerifier

    from bmt_backend.app import create_app
    from bmt_backend.db import make_engine
    database = tmp_path / "concurrent-grants.sqlite"
    source = store.app.state.engine.raw_connection()
    try:
        with sqlite3.connect(database) as destination:
            source.driver_connection.backup(destination)
    finally:
        source.close()
    engine = make_engine("sqlite:///" + database.as_posix())
    app = create_app(replace(store.app.state.settings, database_url="sqlite:///" + database.as_posix()),
        engine=engine, verifier=FakeVerifier())
    try:
        with TestClient(app) as client:
            yield SimpleNamespace(app=app, client=client, factory=app.state.session_factory, players=store.players)
    finally:
        engine.dispose()


def path(store, player="Alice"):
    return "/v1/admin/players/" + store.players[player]


def draft(product="publishing_slots", quantity=1):
    return {"command_id": str(uuid4()), "product_id": product, "quantity": quantity}


def preview(store, body, auth=OWNER, player="Alice"):
    return store.client.post(path(store, player) + "/grants/preview", headers=auth, json=body)


def command(store, body, player="Alice"):
    response = preview(store, body, player=player)
    assert response.status_code == 200, response.text
    value = response.json()
    return {**body, "preview_at": value["preview_at"], "expected_hash": value["expected_hash"],
        "reason": "Owner support compensation for this player", "acknowledged": True}


def send(store, body, auth=OWNER, player="Alice"):
    return store.client.post(path(store, player) + "/grants/commands", headers=auth, json=body)


def test_inspection_and_preview_are_read_only_and_include_catalogue(store):
    for url in (path(store) + "/support", "/v1/admin/catalogue/players/" + store.players["Alice"]):
        response = store.client.get(url, headers=ANALYST)
        assert response.status_code == 200, response.text
        value = response.json()
        context = value.get("support", value)["grants"]
        assert not context["editable"] and context["owned"] == [] and context["coin_balance"] == 0
        assert {p["id"] for p in context["products"]} == set(grants.PRICES) | set(grants.CATALOG) | {"publishing_slots", "resumes"}
    assert preview(store, draft()).status_code == 200
    with store.factory() as db:
        for model in (Entitlements, CoinWallet, ResumeWallet, CosmeticUnlock, AdminAudit, Purchase):
            assert db.scalar(select(func.count()).select_from(model)) == 0


@pytest.mark.parametrize("product,quantity,slots", [("publishing_slots", 17, 18), ("creator_slot_1", 1, 2),
    ("creator_slots_5", 1, 6), ("creator_slots_10", 1, 11)])
def test_real_slots_without_simulation_or_billing_are_audited_once(store, product, quantity, slots):
    store.app.state.settings = replace(store.app.state.settings, environment="production",
        dev_auth_enabled=False, purchase_simulation_enabled=False, allow_sync_track_validation=False)
    body = command(store, draft(product, quantity))
    first = send(store, body)
    assert first.status_code == 200, first.text
    assert send(store, body).json() == first.json()
    value = store.client.get("/v1/me/entitlements", headers=headers(store, "Alice")).json()
    assert value["publishing_slots"] == slots and not value["purchase_simulation"]
    with store.factory() as db:
        row = db.get(Entitlements, store.players["Alice"])
        assert row.slots == slots and row.simulated_slots == 0
        assert db.scalar(select(func.count()).select_from(Purchase)) == 0
        audit = db.scalar(select(AdminAudit))
        assert audit.action == "player_grant" and audit.entity_id == store.players["Alice"]
        assert audit.after["source"] == "support_grant" and audit.before["slots"] == 1
        assert audit.request_id and audit.reason == body["reason"]
        assert db.scalar(select(func.count()).select_from(AdminAudit)) == 1
    history = store.client.get(path(store) + "/history?all=1&kind=audit", headers=ANALYST).json()
    assert history["items"][0]["record"]["after"]["product_id"] == product
    assert send(store, {**body, "quantity": quantity + 1}).status_code in (409, 422)


@pytest.mark.parametrize("product", ["ad_free_month", "ad_free_forever", "resumes",
    next(key for key in grants.PRICES if key.startswith("kit/")), next(iter(grants.PRICES))])
def test_granted_access_is_consumed_by_existing_game_apis(store, product):
    with store.factory() as db:
        db.add(CoinWallet(player_id=store.players["Alice"], balance=1200, revision=4))
        db.commit()
    body = command(store, draft(product, 9 if product == "resumes" else 1))
    first = send(store, body)
    assert first.status_code == 200, first.text
    assert send(store, body).json() == first.json()
    if product in grants.PRICES:
        wallet = store.client.get("/v1/economy", headers=headers(store, "Alice")).json()
        assert wallet["owned"] == [product] and wallet["balance"] == 1200 and wallet["revision"] == 5
        assert preview(store, draft(product)).json()["detail"] == "COSMETIC_ALREADY_OWNED"
        with store.factory() as db:
            assert db.get(CosmeticUnlock, (store.players["Alice"], product)).price == 0
    elif product == "resumes":
        wallet = store.client.get("/v1/resumes", headers=headers(store, "Alice")).json()
        assert wallet["balance"] == 9 and wallet["free"] == 1
        with store.factory() as db:
            assert db.scalar(select(func.count()).select_from(ResumeGrant)) == 1
    else:
        value = store.client.get("/v1/me/entitlements", headers=headers(store, "Alice")).json()
        assert value["ad_free"] and value["free_rewinds"]
        assert value["ad_free_forever"] == (product == "ad_free_forever")
        if product == "ad_free_month":
            assert 27 * 86400 <= value["ad_free_until"] - now() <= 32 * 86400
        else:
            assert preview(store, draft(product)).status_code == 409
    assert store.client.get("/v1/admin/purchases", headers=ANALYST).json()["items"] == []


def test_permissions_validation_and_ineligible_accounts(store):
    body = draft()
    for auth, code in (({}, 401), (headers(store, "Alice"), 401), (ANALYST, 403)):
        assert preview(store, body, auth).status_code == code
    good = command(store, body)
    assert send(store, good, ANALYST).status_code == 403
    for changes in ({"quantity": 0}, {"quantity": -1}, {"quantity": 1001}, {"quantity": True},
                    {"product_id": "coin_balance"}, {"product_id": "ad_free_month", "quantity": 2},
                    {"command_id": "x" * 36}, {"extra": True}):
        assert preview(store, {**body, **changes}).status_code == 422
    assert send(store, {**good, "reason": " " * 8}).status_code == 422
    assert send(store, {**good, "acknowledged": False}).status_code == 422
    assert store.client.post("/v1/admin/players/" + str(uuid4()) + "/grants/preview",
        headers=OWNER, json=body).status_code == 404
    assert preview(store, body, player="Bob").status_code == 200
    with store.factory() as db:
        db.get(Player, store.players["Alice"]).disabled = True
        db.get(Player, store.players["Bob"]).deleted_at = now()
        db.commit()
    assert send(store, good).status_code == 409
    assert preview(store, body, player="Bob").status_code == 409
    assert not store.client.get(path(store) + "/support", headers=OWNER).json()["grants"]["editable"]


def test_stale_preview_expiry_account_binding_and_command_reuse(store, monkeypatch):
    body = command(store, draft(quantity=3))
    assert send(store, body, player="Bob").status_code == 409
    other = command(store, draft(quantity=2))
    assert send(store, other).status_code == 200
    assert send(store, body).json()["detail"] == "STATE_CHANGED_REFRESH_REQUIRED"
    assert send(store, {**other, "reason": "A different support operation"}).json()["detail"] == "COMMAND_ID_REUSED"
    fresh = command(store, draft())
    monkeypatch.setattr(grants, "now", lambda: fresh["preview_at"] + 301)
    assert send(store, fresh).json()["detail"] == "PREVIEW_EXPIRED_REFRESH_REQUIRED"
    # Successful retries remain durable after preview expiry.
    assert send(store, other).status_code == 200


@pytest.mark.parametrize("workers", [2, 8])
def test_concurrent_duplicate_and_competing_previews_do_not_double_grant(durable_store, workers):
    store = durable_store
    from threading import Barrier
    barrier = Barrier(workers)
    body = command(store, draft(quantity=4))
    def deliver(_):
        barrier.wait(timeout=10)
        return send(store, body)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        responses = list(pool.map(deliver, range(workers)))
    assert [r.status_code for r in responses] == [200] * workers
    assert all(response.json() == responses[0].json() for response in responses)
    competing = [command(store, draft(quantity=2)), command(store, draft(quantity=3))]
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(lambda value: send(store, value), competing))
    assert sorted(r.status_code for r in responses) == [200, 409]
    with store.factory() as db:
        assert db.scalar(select(func.count()).select_from(AdminAudit)) == 2
        assert db.get(Entitlements, store.players["Alice"]).slots in (7, 8)


def test_atomic_rollback_on_audit_failure(store):
    from sqlalchemy import event
    def fail(*_args):
        raise RuntimeError("Owned fixture audit failure")
    product = next(key for key in grants.PRICES if key.startswith("kit/"))
    body = command(store, draft(product))
    event.listen(AdminAudit, "before_insert", fail)
    try:
        assert send(store, body).status_code == 500
    finally:
        event.remove(AdminAudit, "before_insert", fail)
    with store.factory() as db:
        assert db.scalar(select(func.count()).select_from(CosmeticUnlock)) == 0
        assert db.get(CoinWallet, store.players["Alice"]) is None
    assert send(store, body).status_code == 200
