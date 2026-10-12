"""Availability enforcement, delivery recovery, redaction and auditable test controls."""
# ruff: noqa: F811
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from uuid import uuid4

import pytest
from sqlalchemy import select
from test_commerce import buy, entitlement, lab  # noqa: F401
from test_domains import domain, headers  # noqa: F401

from bmt_backend.admin_models import AdminAudit
from bmt_backend.commerce_models import Entitlements, ProductControl, Purchase

OWNER = {"Authorization":"Bearer " + "o"*40}
ANALYST = {"Authorization":"Bearer " + "a"*40}


@pytest.fixture
def store(lab):
    lab.app.state.settings = replace(lab.app.state.settings, admin_owner_key="o"*40, admin_analyst_key="a"*40)
    return lab


def configure(store, sku="creator_slot_1", enabled=False, revision=0, command_id=None, auth=OWNER):
    return store.client.post("/v1/admin/products/"+sku, headers=auth, json={
        "command_id":command_id or str(uuid4()),"expected_revision":revision,"enabled":enabled,
        "reason":"Testing item availability","acknowledged":True})


def test_public_catalog_and_admin_authentication(store):
    public = store.client.get("/v1/store/products")
    assert public.status_code == 200 and len(public.json()["products"]) == 5
    assert all(p["enabled"] for p in public.json()["products"])
    assert not public.json()["store_available"]
    for path in ("/v1/admin/products", "/v1/admin/purchases"):
        assert store.client.get(path).status_code == 401
        assert store.client.get(path, headers=headers(store)).status_code == 401
        assert store.client.get(path, headers=ANALYST).status_code == 200
    assert configure(store, auth=ANALYST).status_code == 403


def test_disable_blocks_new_checkout_not_pending_or_owned_access(store):
    pending = buy(store, "creator_slot_1", "pending").json()["purchase"]["id"]
    assert configure(store).status_code == 200
    assert buy(store, "creator_slot_1").status_code == 409
    assert buy(store, "creator_slot_1").json()["detail"] == "PRODUCT_DISABLED"
    assert entitlement(store)["publishing_slots"] == 1
    resolved = store.client.post(f"/v1/development/purchases/{pending}/resolve", headers=headers(store),
        json={"outcome":"approved"})
    assert resolved.status_code == 200 and entitlement(store)["publishing_slots"] == 2
    key = str(uuid4())
    assert buy(store, "ad_free_forever", request_id=key).status_code == 200
    assert configure(store, "ad_free_forever").status_code == 200
    assert buy(store, "ad_free_forever", request_id=key).status_code == 200
    assert entitlement(store)["ad_free_forever"]
    assert configure(store, enabled=True, revision=1).status_code == 200
    assert buy(store, "creator_slot_1").status_code == 200


def test_product_command_idempotence_conflict_and_audit(store):
    key = str(uuid4())
    first = configure(store, command_id=key)
    assert first.status_code == 200
    assert configure(store, command_id=key).json() == first.json()
    assert configure(store, enabled=True, command_id=key).status_code == 409
    assert configure(store, enabled=True, revision=0).status_code == 409
    with store.factory() as session:
        entries = list(session.scalars(select(AdminAudit)))
        assert len(entries) == 1 and entries[0].before == {"enabled":True,"revision":0}
        assert entries[0].after == {"enabled":False,"revision":1}
        assert session.get(ProductControl,"creator_slot_1").revision == 1
    store.app.state.settings = replace(store.app.state.settings, environment="production",
        dev_auth_enabled=False,purchase_simulation_enabled=False,allow_sync_track_validation=False)
    assert configure(store, enabled=True, revision=1).status_code == 403


def test_player_purchase_filters_cursor_bounds_and_read_only_inspection(store):
    for _ in range(6):
        assert buy(store).status_code == 200
    assert buy(store, outcome="pending").status_code == 200
    player = store.players["Creator"]
    base = "/v1/admin/purchases?player_id="+player+"&limit=3"
    first = store.client.get(base, headers=ANALYST).json()
    second = store.client.get(base+"&cursor="+first["next_cursor"], headers=ANALYST).json()
    assert len(first["items"]) == 3 and len(second["items"]) == 3
    assert {p["id"] for p in first["items"]}.isdisjoint(p["id"] for p in second["items"])
    assert all(p["player_id"] == player and p["simulated"] for p in first["items"])
    assert store.client.get(base+"&state=pending&cursor="+first["next_cursor"],headers=OWNER).status_code == 422
    pending = store.client.get(base+"&state=pending",headers=OWNER).json()
    assert len(pending["items"]) == 1
    assert store.client.get("/v1/admin/purchases?limit=101", headers=OWNER).status_code == 422
    assert store.client.get("/v1/admin/purchases?player_id=invalid", headers=OWNER).status_code == 422
    detail = store.client.get("/v1/admin/entities/players/"+player, headers=ANALYST).json()
    assert detail["entitlements"]["simulated_slots"] == 30
    assert "access_token" not in str(detail) and "subject" not in str(detail)
    alice = store.players["Alice"]
    store.client.get("/v1/admin/entities/players/"+alice, headers=ANALYST)
    with store.factory() as session:
        assert session.get(Entitlements, alice) is None
        assert len(list(session.scalars(select(Purchase)))) == 7


def test_disabled_setting_survives_app_restart(store):
    from fastapi.testclient import TestClient

    from bmt_backend.app import create_app
    assert configure(store).status_code == 200
    second = create_app(store.app.state.settings, engine=store.app.state.engine, verifier=store.app.state.verifier)
    with TestClient(second) as client:
        product = next(p for p in client.get("/v1/store/products").json()["products"] if p["id"] == "creator_slot_1")
        assert not product["enabled"] and product["revision"] == 1


def test_concurrent_product_commands_are_serialized_and_same_command_recovers(store):
    if not store.postgres:
        pytest.skip("Production row-lock concurrency is exercised on PostgreSQL")
    key = str(uuid4())
    with ThreadPoolExecutor(max_workers=8) as pool:
        replies = list(pool.map(lambda _: configure(store, command_id=key),range(8)))
    assert all(reply.status_code == 200 for reply in replies)
    assert all(reply.json() == replies[0].json() for reply in replies)
    with store.factory() as session:
        assert session.get(ProductControl,"creator_slot_1").revision == 1
        assert len(list(session.scalars(select(AdminAudit)))) == 1
    with ThreadPoolExecutor(max_workers=2) as pool:
        replies = list(pool.map(lambda _: configure(store, sku="creator_slots_5"),range(2)))
    assert sorted(reply.status_code for reply in replies) == [200,409]
