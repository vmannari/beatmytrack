"""Support history, reporting boundaries and audited simulation concurrency."""
# ruff: noqa: F811
from dataclasses import replace
from uuid import uuid4

import pytest
from sqlalchemy import func, select, update
from test_commerce import buy, entitlement, lab, publication_status, request_publication  # noqa: F401
from test_domains import domain, headers  # noqa: F401
from test_store_admin import ANALYST, OWNER, configure, store  # noqa: F401

from bmt_backend.admin_models import AdminAudit
from bmt_backend.commerce_models import Entitlements, PublicationSlot, Purchase
from bmt_backend.identity_models import Player
from bmt_backend.publications import process_one as publish_one
from bmt_backend.track_models import now


def workspace(store):
    return "/v1/admin/players/" + store.players["Creator"]


def draft(action="simulate_purchase", **fields):
    return {"command_id": str(uuid4()), "action": action, **fields}


def preview(store, body, auth=OWNER):
    return store.client.post(workspace(store) + "/development/preview", headers=auth, json=body)


def execution(store, body):
    response = preview(store, body)
    assert response.status_code == 200, response.text
    value = response.json()
    return {**body, "preview_at": value["preview_at"], "expected_hash": value["expected_hash"],
        "reason": "Support acceptance development command", "acknowledged": True}


def send(store, body, auth=OWNER):
    return store.client.post(workspace(store) + "/development/commands", headers=auth, json=body)


def test_support_reads_do_not_initialize_or_exclude_artificial_players(store):
    with store.factory() as session:
        player = session.get(Player, store.players["Creator"])
        player.is_test_driver = True
        session.commit()
    response = store.client.get(workspace(store) + "/support", headers=ANALYST)
    assert response.status_code == 200
    data = response.json()
    assert data["effective"]["publishing_slots"] == 1 and not data["initialized"]
    assert data["development_controls"]["eligible"] and not data["development_controls"]["editable"]
    assert data["player"]["is_test_driver"] is True
    assert store.client.get("/v1/admin/overview", headers=OWNER).json()["players"] == 4
    with store.factory() as session:
        assert session.get(Entitlements, store.players["Creator"]) is None
        assert session.scalar(select(func.count()).select_from(AdminAudit)) == 0
    assert store.client.get(workspace(store) + "/support").status_code == 401


def test_development_player_remains_real_without_artificial_flag(store):
    response = store.client.get(workspace(store) + "/support", headers=ANALYST)
    assert response.status_code == 200
    data = response.json()
    assert data["player"]["providers"] == ["development"]
    assert data["player"]["is_test_driver"] is False
    assert data["development_controls"]["eligible"] is True
    assert store.client.get("/v1/admin/overview", headers=OWNER).json()["players"] == 4
    with store.factory() as session:
        assert session.get(Entitlements, store.players["Creator"]) is None


@pytest.mark.parametrize("outcome", ["pending", "declined", "cancelled", "approved"])
def test_preview_and_creation_are_audited_once(store, outcome):
    body = draft(product_id="creator_slots_5", outcome=outcome)
    command = execution(store, body)
    with store.factory() as session:
        assert session.get(Entitlements, store.players["Creator"]) is None
        assert session.scalar(select(func.count()).select_from(Purchase)) == 0
    first = send(store, command)
    assert first.status_code == 200, first.text
    assert send(store, command).json() == first.json()
    assert entitlement(store)["publishing_slots"] == (6 if outcome == "approved" else 1)
    command["reason"] = "Different request with the same identifier"
    assert send(store, command).status_code == 409
    with store.factory() as session:
        orders = list(session.scalars(select(Purchase)))
        audits = list(session.scalars(select(AdminAudit)))
        assert len(orders) == len(audits) == 1
        assert orders[0].provider == "simulation" and orders[0].state == outcome
        assert audits[0].entity_id == store.players["Creator"] and audits[0].request_id
        assert audits[0].before["access"]["simulated_slots"] == 0
        assert audits[0].after["access"]["simulated_slots"] == (5 if outcome == "approved" else 0)


@pytest.mark.parametrize("outcome", ["approved", "declined", "cancelled"])
def test_settlement_survives_product_disable_and_uses_original_order(store, outcome):
    pending = buy(store, "creator_slot_1", "pending").json()["purchase"]["id"]
    assert configure(store).status_code == 200
    command = execution(store, draft("resolve_purchase", purchase_id=pending, outcome=outcome))
    first = send(store, command)
    assert first.status_code == 200
    assert send(store, command).json() == first.json()
    assert entitlement(store)["publishing_slots"] == (2 if outcome == "approved" else 1)
    assert preview(store, draft("resolve_purchase", purchase_id=pending, outcome="approved")).status_code == 409


def test_changed_state_and_expired_preview_cannot_overwrite_access(store, monkeypatch):
    body = execution(store, draft("adjust_slots", slots_delta=5))
    assert buy(store, "creator_slot_1").status_code == 200
    assert send(store, body).status_code == 409
    fresh = execution(store, draft("adjust_slots", slots_delta=5))
    monkeypatch.setattr("bmt_backend.admin_purchase_controls.now", lambda: fresh["preview_at"] + 301)
    assert send(store, fresh).status_code == 409
    with store.factory() as session:
        assert session.scalar(select(func.count()).select_from(AdminAudit)) == 0


def test_preview_binds_the_exact_action_and_amount(store):
    command = execution(store, draft("adjust_slots", slots_delta=1))
    assert send(store, {**command, "slots_delta": 10}).status_code == 409
    command = execution(store, draft("expire_month"))
    assert send(store, {**command, "action": "reset_ad_free"}).status_code == 409
    with store.factory() as session:
        assert session.get(Entitlements, store.players["Creator"]) is None
        assert session.scalar(select(func.count()).select_from(AdminAudit)) == 0


def test_slot_and_access_adjustments_preserve_real_access_and_consumption(store):
    intent = request_publication(store)
    assert publish_one(store.app)
    published = publication_status(store, intent["publication_id"])
    assert published["state"] == "published"
    version = published["receipt"]
    assert buy(store, "ad_free_month").status_code == 200
    with store.factory() as session:
        row = session.get(Entitlements, store.players["Creator"])
        row.slots, row.simulated_slots = 7, 3
        row.forever, row.ad_free_until, row.simulated_forever = True, now() + 86400, True
        session.commit()
        real = (row.slots, row.forever, row.ad_free_until)
    for action, fields in [("adjust_slots", {"slots_delta": -2}), ("expire_month", {}), ("reset_ad_free", {})]:
        assert send(store, execution(store, draft(action, **fields))).status_code == 200
    assert preview(store, draft("adjust_slots", slots_delta=-2)).status_code == 422
    with store.factory() as session:
        row = session.get(Entitlements, store.players["Creator"])
        assert (row.slots, row.forever, row.ad_free_until) == real
        assert row.simulated_slots == 1 and not row.simulated_forever
        assert row.simulated_ad_free_until <= now()
        assert session.scalar(select(func.count()).select_from(AdminAudit)) == 3
        assert session.get(PublicationSlot, version["version_id"]) is not None


def test_controls_reject_read_only_real_accounts_and_disabled_configuration(store):
    body = draft(product_id="creator_slot_1", outcome="approved")
    assert preview(store, body, ANALYST).status_code == 403
    command = execution(store, body)
    assert send(store, command, ANALYST).status_code == 403
    url = "/v1/admin/players/" + store.players["Alice"] + "/development/preview"
    assert store.client.post(url, headers=OWNER, json=body).status_code == 403
    for change in ({"purchase_simulation_enabled": False},
        {"environment": "production", "dev_auth_enabled": False, "purchase_simulation_enabled": False,
            "allow_sync_track_validation": False},
        {"dev_auth_enabled": False, "purchase_simulation_enabled": False}):
        old = store.app.state.settings
        store.app.state.settings = replace(old, **change)
        assert preview(store, body).status_code == send(store, command).status_code == 403
        store.app.state.settings = old
    assert send(store, {**command, "reason": " " * 12}).status_code == 422
    assert send(store, {**command, "acknowledged": False}).status_code == 422
    assert preview(store, {**body, "slots_delta": 2}).status_code == 422


def test_real_purchase_and_cross_player_order_cannot_be_resolved(store):
    with store.factory() as session:
        for identity, provider, owner in [("real-provider-order", "google_play", "Creator"),
            ("another-player-order", "simulation", "Alice")]:
            session.add(Purchase(id=identity, player_id=store.players[owner], provider=provider,
                product_id="creator_slot_1", state="pending"))
        session.commit()
    for identity in ("real-provider-order", "another-player-order"):
        assert preview(store, draft("resolve_purchase", purchase_id=identity, outcome="approved")).status_code == 404


def test_history_keyset_dates_scope_and_redaction(store):
    for _ in range(7):
        assert send(store, execution(store, draft(product_id="creator_slot_1", outcome="approved"))).status_code == 200
    # Deliberately tie every timestamp; wall-clock second boundaries must not
    # decide whether cursor order and exclusive range checks pass.
    with store.factory() as session:
        session.execute(update(Purchase).values(created_at=1700000000))
        session.execute(update(AdminAudit).values(created_at=1700000000))
        session.commit()
    url = workspace(store) + "/history?limit=3"
    seen, cursor = [], None
    while True:
        response = store.client.get(url + ("&cursor=" + cursor if cursor else ""), headers=ANALYST)
        assert response.status_code == 200, response.text
        data = response.json()
        seen += [(item["kind"], item["id"]) for item in data["items"]]
        cursor = data["next_cursor"]
        if not cursor:
            break
        assert store.client.get(url + "&kind=purchase&cursor=" + cursor, headers=ANALYST).status_code == 422
    assert len(seen) == len(set(seen)) == 14
    first = store.client.get(url + "&kind=purchase", headers=OWNER).json()["items"][0]
    start = first["created_at"]
    inside = store.client.get(url + f"&since={start}&until={start+1}&kind=purchase", headers=ANALYST)
    assert inside.status_code == 200 and inside.json()["items"]
    assert not store.client.get(url + f"&since={start-1}&until={start}", headers=ANALYST).json()["items"]
    exported = store.client.get(url + "&download=true", headers=ANALYST)
    assert exported.headers["content-disposition"].startswith("attachment;")
    assert "developer" not in exported.text and "lease_token" not in exported.text and "request_hash" not in exported.text
    audit = store.client.get(url + "&kind=audit", headers=OWNER).json()["items"][0]
    query = audit["record"]["command_id"]
    assert len(store.client.get(url + "&q=" + query, headers=ANALYST).json()["items"]) == 1


def test_reporting_range_is_shared_and_boundaries_are_exclusive(store):
    start = now()
    assert buy(store, "creator_slot_1").status_code == 200
    for path in ("overview", "entities/players", "purchases"):
        endpoint = "/v1/admin/" + path
        assert store.client.get(endpoint + f"?since={start}", headers=ANALYST).status_code == 422
        assert store.client.get(endpoint + f"?since={start}&until={start}", headers=ANALYST).status_code == 422
        assert store.client.get(endpoint + "?since=0&until=7776001", headers=ANALYST).status_code == 422
    response = store.client.get("/v1/admin/overview?days=90", headers=OWNER).json()
    assert response["until"] // 86400 - response["since"] // 86400 in (89, 90)
    assert store.client.get(f"/v1/admin/purchases?since={start-1}&until={start}", headers=OWNER).json()["items"] == []


def test_concurrent_duplicate_admin_purchase_grants_once(store):
    if not store.postgres:
        pytest.skip("Requires PostgreSQL row locks")
    from concurrent.futures import ThreadPoolExecutor
    from threading import Barrier
    body = execution(store, draft(product_id="creator_slot_1", outcome="approved"))
    barrier = Barrier(8)
    def deliver():
        barrier.wait(timeout=15)
        return send(store, body)
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(lambda _index: deliver(), range(8)))
    assert [response.status_code for response in results] == [200] * 8
    assert all(response.json() == results[0].json() for response in results)
    with store.factory() as session:
        assert session.get(Entitlements, store.players["Creator"]).simulated_slots == 1
        assert session.scalar(select(func.count()).select_from(Purchase)) == 1
        assert session.scalar(select(func.count()).select_from(AdminAudit)) == 1
