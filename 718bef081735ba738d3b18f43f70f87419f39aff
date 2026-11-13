"""Gift delivery uses the buyer's receipt and the recipient's isolated balance."""
# ruff: noqa: F811
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from datetime import datetime, timezone
from uuid import uuid4

import pytest
from sqlalchemy import select
from test_commerce import lab  # noqa: F401
from test_domains import domain, headers  # noqa: F401

from bmt_backend.commerce_models import Entitlements, Purchase
from bmt_backend.identity_models import Identity, Player, now
from bmt_backend.studio_finance import play_account


@pytest.fixture
def gifts(lab):
    with lab.factory() as db:
        for name in ("Alice", "Bob"):
            db.add(Identity(player_id=lab.players[name], provider="development", subject="gift-"+name))
        db.commit()
    return lab


def gift(lab, *, recipient="Alice", product="creator_slots_5", outcome="approved", key=None, buyer="Creator"):
    return lab.client.post("/v1/development/purchases", headers=headers(lab, buyer), json={
        "request_id": key or str(uuid4()), "product_id": product, "outcome": outcome,
        "recipient_player_id": lab.players.get(recipient, recipient)})


def balances(lab, name):
    with lab.factory() as db:
        row = db.get(Entitlements, lab.players[name])
        return (row.slots, row.simulated_slots) if row else (1, 0)


@pytest.mark.parametrize("product,count", [("creator_slot_1", 1), ("creator_slots_5", 5), ("creator_slots_10", 10)])
def test_gift_grants_recipient_once_and_never_buyer(gifts, product, count):
    key = str(uuid4())
    for _ in range(3):
        response = gift(gifts, product=product, key=key)
        assert response.status_code == 200, response.text
        assert response.json()["purchase"]["recipient_player_id"] == gifts.players["Alice"]
        assert response.json()["entitlements"]["publishing_slots"] == 1
    assert balances(gifts, "Creator") == (1, 0)
    assert balances(gifts, "Alice") == (1, count)
    assert gift(gifts, key=key, product=product, recipient="Bob").status_code == 409
    assert gift(gifts, key=key, product=product, buyer="Bob").status_code == 409


@pytest.mark.parametrize("state", ["pending", "declined", "cancelled"])
def test_unpaid_gift_and_pending_resolution(gifts, state):
    response = gift(gifts, outcome=state)
    assert response.status_code == 200, response.text
    assert balances(gifts, "Alice") == (1, 0)
    identity = response.json()["purchase"]["id"]
    assert gifts.client.post(f"/v1/development/purchases/{identity}/resolve",
        headers=headers(gifts, "Alice"), json={"outcome": "approved"}).status_code == 404
    if state == "pending":
        for _ in range(3):
            result = gifts.client.post(f"/v1/development/purchases/{identity}/resolve",
                headers=headers(gifts), json={"outcome": "approved"})
            assert result.status_code == 200, result.text
        assert balances(gifts, "Alice") == (1, 5)
        assert balances(gifts, "Creator") == (1, 0)


def test_recipient_lookup_and_validation(gifts):
    found = gifts.client.get("/v1/store/gift-recipient?username=%20ALICE%20", headers=headers(gifts))
    assert found.status_code == 200, found.text
    assert found.json() == {"id": gifts.players["Alice"], "display_name": "Alice"}
    for recipient, status in [("Creator", 422), (str(uuid4()), 404), ("x"*36, 422)]:
        assert gift(gifts, recipient=recipient).status_code == status
    assert gift(gifts, product="ad_free_month").status_code == 422
    assert gift(gifts, product="ad_free_forever").status_code == 422
    assert gift(gifts, recipient="Carol").status_code == 409
    with gifts.factory() as db:
        db.get(Player, gifts.players["Alice"]).disabled = True
        db.commit()
    assert gift(gifts).status_code == 404
    assert gifts.client.get("/v1/store/gift-recipient?username=Alice", headers=headers(gifts)).status_code == 404
    assert balances(gifts, "Creator") == (1, 0)


def test_simulation_never_becomes_real_capacity(gifts):
    assert gift(gifts).status_code == 200
    gifts.app.state.settings = replace(gifts.app.state.settings, purchase_simulation_enabled=False)
    response = gifts.client.get("/v1/me/entitlements", headers=headers(gifts, "Alice"))
    assert response.json()["publishing_slots"] == 1
    assert gift(gifts).status_code == 403


def test_concurrent_opposite_gifts_and_retries(gifts, tmp_path):
    # StaticPool's single in-memory SQLite connection cannot host concurrent
    # transactions. Use independent connections to a real temporary WAL file.
    from bmt_backend.db import make_engine
    original = gifts.factory
    original_bind = original.kw["bind"]
    file_engine = None
    if not gifts.postgres:
        import sqlite3
        target = tmp_path / "concurrent-gifts.db"
        with gifts.app.state.engine.connect() as source, sqlite3.connect(target) as destination:
            source.connection.driver_connection.backup(destination)
        file_engine = make_engine("sqlite:///"+str(target))
        # Preserve the sessionmaker referenced by auth and request middleware.
        original.configure(bind=file_engine)
    keys = [str(uuid4()), str(uuid4())]
    def send(index):
        return gift(gifts, buyer="Creator" if index % 2 == 0 else "Alice",
            recipient="Alice" if index % 2 == 0 else "Creator", key=keys[index % 2])
    try:
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(send, range(8)))
        assert all(result.status_code == 200 for result in results), [r.text for r in results]
        assert balances(gifts, "Creator") == (1, 5)
        assert balances(gifts, "Alice") == (1, 5)
    finally:
        original.configure(bind=original_bind)
        if file_engine is not None:
            file_engine.dispose()


def test_pending_gift_to_removed_recipient_cannot_grant_but_can_cancel(gifts):
    order = gift(gifts, outcome="pending").json()["purchase"]["id"]
    with gifts.factory() as db:
        db.get(Player, gifts.players["Alice"]).deleted_at = now()
        db.commit()
    endpoint = f"/v1/development/purchases/{order}/resolve"
    assert gifts.client.post(endpoint, headers=headers(gifts), json={"outcome":"approved"}).status_code == 404
    assert gifts.client.post(endpoint, headers=headers(gifts), json={"outcome":"cancelled"}).status_code == 200
    assert balances(gifts, "Alice") == (1, 0)


def test_verified_play_gift_binds_receipt_buyer_and_recipient(gifts):
    gifts.app.state.settings = replace(gifts.app.state.settings, studio_play_package="com.example.fixture")
    class Provider:
        def verify(self, _token):
            return {"obfuscatedExternalAccountId": play_account(gifts.players["Creator"]),
                "purchaseCompletionTime": datetime.fromtimestamp(now(), timezone.utc).isoformat(),
                "purchaseStateContext": {"purchaseState": "PURCHASED"},
                "productLineItem": [{"productId": "creator_slots_5", "productOfferDetails": {
                    "quantity": 1, "refundableQuantity": 1,
                    "consumptionState": "CONSUMPTION_STATE_YET_TO_BE_CONSUMED"}}]}
        def complete(self, *_args):
            pass
    gifts.app.state.studio_play_provider = Provider()
    body = {"product_id":"creator_slots_5", "purchase_token":"gift-fixture-secret-token",
        "recipient_player_id":gifts.players["Alice"]}
    for _ in range(3):
        response = gifts.client.post("/v1/billing/google-play/verify", headers=headers(gifts), json=body)
        assert response.status_code == 200, response.text
        assert "gift-fixture-secret-token" not in response.text
    assert balances(gifts, "Alice") == (6, 0)
    assert balances(gifts, "Creator") == (1, 0)
    for change in [{"recipient_player_id":gifts.players["Bob"]}, {"recipient_player_id":None}]:
        response = gifts.client.post("/v1/billing/google-play/verify", headers=headers(gifts), json=body | change)
        assert response.status_code == 409, response.text
    with gifts.factory() as db:
        order = db.scalar(select(Purchase).where(Purchase.provider == "google_play"))
        assert order.player_id == gifts.players["Creator"]
        assert order.recipient_player_id == gifts.players["Alice"]


def test_admin_approval_previews_and_audits_recipient_balance(gifts):
    from test_admin_support import draft, execution, send

    from bmt_backend.admin_models import AdminAudit
    gifts.app.state.settings = replace(gifts.app.state.settings, admin_owner_key="o"*40)
    pending = gift(gifts, outcome="pending").json()["purchase"]["id"]
    command = execution(gifts, draft("resolve_purchase", purchase_id=pending, outcome="approved"))
    first = send(gifts, command)
    assert first.status_code == 200, first.text
    assert send(gifts, command).json() == first.json()
    assert balances(gifts, "Creator") == (1, 0)
    assert balances(gifts, "Alice") == (1, 5)
    with gifts.factory() as db:
        audit = db.scalar(select(AdminAudit).where(AdminAudit.command_id == command["command_id"]))
        assert audit.after["gift_recipient"]["player_id"] == gifts.players["Alice"]
        assert audit.after["gift_recipient"]["access"]["simulated_slots"] == 5
