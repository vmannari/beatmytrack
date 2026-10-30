"""Persistent rewards/ownership through the real acceptance and HTTP boundaries."""
# ruff: noqa: F811
import json
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest
from sqlalchemy import func, select
from test_domains import domain, headers, publish, race, submit, ticket, upload  # noqa: F401

from bmt_backend.economy import PRICES, accept_verified, locked_wallet, previous_bests
from bmt_backend.economy_models import CoinMilestone, CoinReward, CoinWallet, CosmeticUnlock
from bmt_backend.track_models import Run, now
from bmt_backend.worker import process_one


def wallet(d, player="Creator"):
    response = d.client.get("/v1/economy", headers=headers(d, player))
    assert response.status_code == 200, response.text
    return response.json()


def fund(d, amount=2000, player="Creator"):
    with d.factory() as session:
        value = locked_wallet(session, d.players[player])
        value.balance = amount
        session.commit()


def buy(d, item="livery/apex_twin", key=None, player="Creator", **extra):
    return d.client.post("/v1/economy/purchases", json={"item_id": item, "expected_price":PRICES.get(item,500), **extra},
                         headers=headers(d, player, key))


def test_accepted_races_credit_once_and_only_improvements_earn_pb(domain):
    version = upload(domain)
    first = race(domain, version, frames=30)
    assert wallet(domain)["balance"] == 100  # completion and first track
    receipt = domain.client.get("/v1/economy/rewards/" + first["ticket_id"], headers=headers(domain)).json()
    assert receipt["status"] == "credited" and receipt["amount"] == 100
    with domain.factory() as session:
        run = session.get(Run, first["run_id"])
        accept_verified(session, run, previous_bests(session, run))
        session.commit()
        assert session.scalar(select(func.count()).select_from(CoinReward)) == 1
    assert wallet(domain)["balance"] == 100
    race(domain, version, frames=20)
    assert wallet(domain)["balance"] == 350
    race(domain, version, frames=20)
    assert wallet(domain)["balance"] == 400
    race(domain, version, frames=40)
    assert wallet(domain)["balance"] == 450
    assert wallet(domain, "Alice")["balance"] == 0


def test_pending_rejected_and_other_owner_never_credit(domain):
    version = upload(domain)
    issued = ticket(domain, version)
    submit(domain, issued, steering=-127)
    path = "/v1/economy/rewards/" + issued["ticket_id"]
    assert domain.client.get(path, headers=headers(domain)).json()["status"] == "pending"
    assert domain.client.get(path, headers=headers(domain, "Alice")).status_code == 404
    assert wallet(domain)["balance"] == 0
    assert process_one(domain.app)
    assert domain.client.get(path, headers=headers(domain)).json()["status"] == "unavailable"
    assert wallet(domain)["balance"] == 0
    assert domain.client.get("/v1/economy/rewards/" + str(uuid.uuid4()), headers=headers(domain)).status_code == 404


def test_purchase_is_permanent_idempotent_and_server_priced(domain):
    fund(domain)
    key = str(uuid.uuid4())
    first = buy(domain, key=key)
    assert first.status_code == 200, first.text
    assert first.json()["charged"] == 500
    assert buy(domain, key=key).json() == first.json()
    assert buy(domain).json()["charged"] == 0
    assert wallet(domain)["balance"] == 1500
    assert wallet(domain)["owned"] == ["livery/apex_twin"]
    assert buy(domain, "kit/compact/hood/scoop", key=key).status_code == 409
    assert buy(domain, "kit/compact/hood/scoop").json()["charged"] == 750
    assert wallet(domain)["balance"] == 750
    assert buy(domain, "livery/offset_gt", expected_price=1).json()["detail"] == "COSMETIC_PRICE_CHANGED"
    assert wallet(domain)["balance"] == 750
    assert len(wallet(domain)["owned"]) == 2
    assert wallet(domain, "Alice")["owned"] == []
    for extra in ({"price": 0}, {"balance": 999999}, {"owned": ["livery/offset_gt"]}):
        assert buy(domain, **extra).status_code == 422
    assert buy(domain, "kit/pickup/hood/scoop").status_code == 422
    assert buy(domain, "livery/does_not_exist").status_code == 422
    assert wallet(domain)["balance"] == 750


def test_insufficient_exact_and_last_coin_balance(domain):
    fund(domain, 499)
    assert buy(domain).json()["detail"] == "INSUFFICIENT_COINS"
    assert wallet(domain)["owned"] == [] and wallet(domain)["balance"] == 499
    fund(domain, 500)
    assert buy(domain).json()["wallet"]["balance"] == 0
    assert buy(domain, "livery/offset_gt").status_code == 409
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(CosmeticUnlock)) == 1
        assert session.get(CoinWallet, domain.players["Creator"]).balance == 0


def test_parallel_purchases_cannot_double_spend(domain):
    if not domain.postgres:
        pytest.skip("StaticPool fixture shares one SQLite connection; PostgreSQL exercises row locks")
    fund(domain, 750)
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(lambda item: buy(domain, item),
            ["kit/compact/hood/scoop", "kit/compact/hood/dome"]))
    assert sorted(response.status_code for response in responses) == [200, 409]
    assert wallet(domain)["balance"] == 0 and len(wallet(domain)["owned"]) == 1
    fund(domain, 1000)
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(lambda _: buy(domain), range(2)))
    assert [response.status_code for response in responses] == [200, 200]
    assert sum(response.json()["charged"] for response in responses) == 500
    assert wallet(domain)["balance"] == 500


def test_percentile_tiers_only_pay_for_new_thresholds(domain):
    version = upload(domain)
    race(domain, version, frames=80)
    publish(domain, version)
    race(domain, version, "Alice", frames=50)
    race(domain, version, "Bob", frames=60)
    first = race(domain, version, frames=40)
    path = "/v1/economy/rewards/" + first["ticket_id"]
    rows = domain.client.get(path, headers=headers(domain)).json()["rows"]
    assert [row["amount"] for row in rows if "percentile" in row["title"]] == [50, 50]
    second = race(domain, version, frames=30)
    rows = domain.client.get("/v1/economy/rewards/" + second["ticket_id"], headers=headers(domain)).json()["rows"]
    assert not any("percentile" in row["title"] for row in rows)


def test_catalog_matches_shipped_liveries_and_parts():
    root = Path(__file__).resolve().parents[2]
    patterns = json.loads((root / "game/assets/liveries/catalog.json").read_text())
    assert {"livery/" + pattern["id"] for pattern in patterns} == {item for item in PRICES if item.startswith("livery/")}
    assert len({item for item in PRICES if not item.startswith("kit/kart/")}) == 87
    catalog = json.loads((root / "backend/bmt_backend/vehicle_appearance_catalog.json").read_text())
    expected_kart = {f"kit/kart/{category}/{option}" for category, options in catalog["kart_parts"].items() for option in options if option != "stock"}
    assert {item for item in PRICES if item.startswith("kit/kart/")} == expected_kart
    assert len(expected_kart) == 28
    assert all(PRICES[item] == 750 for item in expected_kart)


def test_history_retention_keeps_balance_unlocks_and_reward_receipts(domain):
    from bmt_backend.maintenance import retain
    version = upload(domain)
    race(domain, version, frames=30)
    race(domain, version, frames=20)
    old = race(domain, version, frames=40)
    before = wallet(domain)
    with domain.factory() as session:
        session.get(Run, old["run_id"]).finished_at = now() - 100 * 86400
        session.commit()
    result = retain(domain.factory, domain.app.state.blobs, days=90, apply=True, online=True)
    assert result["runs"] == 1
    assert wallet(domain) == before
    with domain.factory() as session:
        assert session.get(Run, old["run_id"]) is None
        assert session.get(CoinReward, old["run_id"]).amount == 50


def test_account_removal_erases_coin_data_without_changing_v1_stage_order(auth_app, auth_client, sign_in):
    from test_privacy import auth, deletion_body, drain, seed
    signed = sign_in()
    _, _, run_id, *_ = seed(auth_app, signed)
    player_id = signed["player"]["id"]
    with auth_app.state.session_factory() as session:
        value = locked_wallet(session, player_id)
        value.balance = 50
        session.add(CoinReward(run_id=run_id, player_id=player_id, amount=50, rows=[]))
        session.add(CoinMilestone(player_id=player_id, scope="fixture", value=1))
        session.add(CosmeticUnlock(player_id=player_id, item_id="livery/apex_twin", price=500))
        session.commit()
    response = auth_client.post("/v1/privacy/account-deletion", json=deletion_body(), headers=auth(signed))
    assert response.status_code == 202, response.text
    drain(auth_app)
    with auth_app.state.session_factory() as session:
        for model in (CoinWallet, CoinReward, CoinMilestone, CosmeticUnlock):
            assert session.scalar(select(func.count()).select_from(model)) == 0


def test_requires_authentication(auth_client):
    assert auth_client.get("/v1/economy").status_code == 401
    assert auth_client.post("/v1/economy/purchases", json={"item_id": "livery/apex_twin"},
                            headers={"Idempotency-Key": str(uuid.uuid4())}).status_code == 401


def test_registered_clean_race_bonus_is_fixed_verified_and_idempotent(domain, monkeypatch):
    original = domain.app.state.verifier.verify_run
    marker = {"incident_free": True}

    def verified(*args, **kwargs):
        return {**original(*args, **kwargs), **marker}

    monkeypatch.setattr(domain.app.state.verifier, "verify_run", verified)
    assert domain.client.get("/v1/bootstrap").json()["race_incident_rewards_version"] == 1
    version = upload(domain)
    first = race(domain, version, frames=30)
    receipt = domain.client.get("/v1/economy/rewards/" + first["ticket_id"], headers=headers(domain)).json()
    assert receipt["amount"] == 300  # completion 50 + first track 50 + clean 200
    assert [row["amount"] for row in receipt["rows"] if row["title"] == "Clean race"] == [200]
    with domain.factory() as session:
        run = session.get(Run, first["run_id"])
        accept_verified(session, run, previous_bests(session, run), incident_free=True)
        session.commit()
    assert wallet(domain)["balance"] == 300
    marker["incident_free"] = False
    race(domain, version, frames=30)
    assert wallet(domain)["balance"] == 350
    marker["incident_free"] = "true"
    race(domain, version, frames=30)
    assert wallet(domain)["balance"] == 400  # non-boolean verifier values cannot grant a bonus
    assert wallet(domain, "Alice")["balance"] == 0


def test_clean_report_follows_accepted_trajectory_without_changing_timing():
    from bmt_backend.trajectory_verifier import check
    from bmt_backend.verifier import VerificationError

    geometry = {"start": [0, 0, 0], "extent": [10, 10], "manifest": {},
                "maximum_speed": {"compact": 120},
                "gates": [[1, 0, -1, 0, 1, 0, -10, 10, 0], [-1, 0, -1, 0, 1, 0, -10, 10, 0]]}
    proof = {"schema": "bmt-race-path-v1", "samples": [[0, 0, 0, 0]] +
             [[index * 6, 2 if index % 2 else -2, 0, 0] for index in range(1, 11)]}
    baseline = check(geometry, proof, 60, "compact")
    assert not baseline["incident_free"]
    report = {"schema": "bmt-race-incidents-v1", "ticks": 60, "collision_count": 0, "off_track": False}
    clean = check(geometry, {**proof, "incidents": report}, 60, "compact")
    assert clean == {**baseline, "incident_free": True}
    for bad in (None, {}, {**report, "collision_count": 1}, {**report, "off_track": True},
                {**report, "ticks": 59}, {**report, "ticks": True}, {**report, "collision_count": False},
                {**report, "off_track": 0}, {**report, "amount": 999999}, {**report, "schema": "unknown"}):
        result = check(geometry, {**proof, "incidents": bad}, 60, "compact")
        assert result == baseline  # no clean bonus, while valid score acceptance is unchanged
    with pytest.raises(VerificationError):
        check(geometry, {**proof, "samples": proof["samples"][:-1], "incidents": report}, 60, "compact")


def test_incident_metadata_survives_replay_wire():
    from bmt_backend.replay_wire import unpack_replay
    from bmt_backend.verifier import validate_replay

    proof = {"schema": "bmt-race-proof-v1", "samples": [[0, 0, 0, 0, 0, 0, 0, 0], [6, 1, 0, 0, 0, 0, 0, 0]],
             "incidents": {"schema": "bmt-race-incidents-v1", "ticks": 6, "collision_count": 0, "off_track": False}}
    replay = {"schema": "bmt-replay-v1", "frames": [[0, 0, 0]] * 6, "race_proof": proof}
    validate_replay(replay)
    assert unpack_replay(replay)["race_proof"] == proof
