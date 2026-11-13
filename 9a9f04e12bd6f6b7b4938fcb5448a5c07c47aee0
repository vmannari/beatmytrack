"""Deletion disclosure uses private, current balances without granting any resources."""
from dataclasses import replace

from sqlalchemy import select
from test_privacy import auth, deletion_body, web_login

from bmt_backend.commerce_models import Entitlements, Purchase
from bmt_backend.economy_models import CoinWallet, CosmeticUnlock
from bmt_backend.identity_models import Identity
from bmt_backend.resume_models import ResumeWallet
from bmt_backend.track_models import now


def test_preview_requires_auth_and_never_initializes_wallets(auth_app, auth_client, sign_in):
    assert auth_client.get("/v1/privacy/deletion-preview").status_code == 401
    signed = sign_in()
    owner = signed["player"]["id"]
    response = auth_client.get("/v1/privacy/deletion-preview", headers=auth(signed))
    assert response.status_code == 200, response.text
    assert response.headers["cache-control"] == "no-store"
    value = response.json()
    assert value["player_id"] == owner and value["schema_version"] == 1
    assert value["publishing_slots"] == 1
    assert all(value[key] == 0 for key in ("coins", "banked_resumes", "cosmetic_unlocks", "pending_purchases", "ad_free_until"))
    assert value["ad_free"] is False and value["ad_free_forever"] is False
    with auth_app.state.session_factory() as session:
        assert all(session.get(model, owner) is None for model in (Entitlements, CoinWallet, ResumeWallet))


def test_exact_balances_web_parity_and_account_isolation(auth_app, auth_client, sign_in):
    alice, bob = sign_in(), sign_in("bob")
    owner = alice["player"]["id"]
    expiry = now()+365*86400
    with auth_app.state.session_factory() as session:
        session.add(Entitlements(player_id=owner, slots=7, simulated_slots=30, ad_free_until=expiry,
            simulated_ad_free_until=expiry+86400, simulated_forever=True))
        session.add(CoinWallet(player_id=owner, balance=12345))
        session.add(ResumeWallet(player_id=owner, balance=4))
        session.add(CosmeticUnlock(player_id=owner, item_id="fixture-appearance", price=10))
        session.add(Purchase(id="pending-real-fixture", player_id=owner, provider="google_play", product_id="slots_5", state="pending"))
        session.add(Purchase(id="pending-sim-fixture", player_id=owner, provider="simulation", product_id="slots_5", state="pending"))
        session.commit()
    preview = auth_client.get("/v1/privacy/deletion-preview", headers=auth(alice)).json()
    assert preview["publishing_slots"] == 7 and preview["coins"] == 12345
    assert preview["banked_resumes"] == 4 and preview["cosmetic_unlocks"] == 1
    assert preview["pending_purchases"] == 1
    assert preview["ad_free_until"] == expiry and preview["ad_free"] is True and preview["ad_free_forever"] is False
    other = auth_client.get("/v1/privacy/deletion-preview?player_id="+owner, headers=auth(bob)).json()
    assert other["player_id"] == bob["player"]["id"] and other["coins"] == 0 and other["publishing_slots"] == 1
    token = web_login(auth_app, auth_client, "alice")
    web = auth_client.post("/v1/privacy/web-session", json={"token": token}).json()
    assert web["status"] == "ready"
    assert {k: v for k, v in web["deletion_preview"].items() if k != "server_now"} == {k: v for k, v in preview.items() if k != "server_now"}
    # Preview must not consume verification or change deletion's durable retry protocol.
    body = {**deletion_body(), "token": token}
    first = auth_client.post("/v1/privacy/web-delete", json=body)
    assert first.status_code == 202, first.text
    assert auth_client.post("/v1/privacy/web-delete", json=body).json() == first.json()
    assert auth_client.get("/v1/privacy/deletion-preview", headers=auth(alice)).status_code == 401


def test_expired_legacy_and_eligible_simulation(auth_app, auth_client, sign_in):
    signed = sign_in()
    owner = signed["player"]["id"]
    with auth_app.state.session_factory() as session:
        session.add(Entitlements(player_id=owner, slots=0, ad_free_until=now()-1))
        session.commit()
    expired = auth_client.get("/v1/privacy/deletion-preview", headers=auth(signed)).json()
    assert expired["publishing_slots"] == 0 and expired["ad_free"] is False
    with auth_app.state.session_factory() as session:
        row = session.get(Entitlements, owner)
        row.forever = True
        session.commit()
    assert auth_client.get("/v1/privacy/deletion-preview", headers=auth(signed)).json()["ad_free_forever"] is True
    auth_app.state.settings = replace(auth_app.state.settings, environment="development", dev_auth_enabled=True,
        dev_auth_key="fictional-deletion-preview-key-"+"x"*32, purchase_simulation_enabled=True)
    with auth_app.state.session_factory() as session:
        row = session.get(Entitlements, owner)
        row.forever = False
        row.simulated_slots = 3
        row.simulated_forever = True
        session.add(Identity(player_id=owner, provider="development", subject="fixture-dev"))
        session.commit()
    simulated = auth_client.get("/v1/privacy/deletion-preview", headers=auth(signed)).json()
    assert simulated["publishing_slots"] == 3 and simulated["ad_free_forever"] is True
    with auth_app.state.session_factory() as session:
        assert session.scalar(select(Entitlements.slots).where(Entitlements.player_id == owner)) == 0
