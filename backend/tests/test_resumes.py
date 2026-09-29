"""Entitlement boundaries, retries, concurrency, and canonical rewind verification."""

# ruff: noqa: F811 - imported pytest fixtures intentionally share test parameter names.
import copy
import uuid
from concurrent.futures import ThreadPoolExecutor

import pytest
from fastapi import HTTPException
from test_domains import domain, headers, ticket, upload  # noqa: F401
from test_verifier import race_fixture, real_verifier  # noqa: F401

from bmt_backend.resume_models import ResumeWallet
from bmt_backend.resumes import grant_verified
from bmt_backend.verifier import VerificationError, validate_replay


def begin(d, ticket_id=None):
    response = d.client.post("/v1/resume-races", json={"ticket_id": ticket_id}, headers=headers(d))
    assert response.status_code == 201, response.text
    return response.json()["race_id"]


def spend(d, race, ordinal=1, offset=120, source=120, target=0, key=None, player="Creator"):
    return d.client.post(
        f"/v1/resume-races/{race}/resumes",
        headers=headers(d, player, key),
        json={"ordinal": ordinal, "input_offset": offset, "from_tick": source, "to_tick": target},
    )


def grant(d, quantity=10, source="award", identity=None):
    with d.factory() as session:
        result = grant_verified(
            session, d.players["Creator"], source, identity or str(uuid.uuid4()), quantity
        )
        session.commit()
        return result


def test_daily_non_stacking_and_permanent_credits(domain, monkeypatch):
    import bmt_backend.resumes as api

    monkeypatch.setattr(api, "now", lambda: 86400 * 100 + 123)
    race = begin(domain)
    assert grant(domain, 5)["balance"] == 5
    first = spend(domain, race, key="first-resume")
    assert first.status_code == 200, first.text
    assert first.json()["wallet"]["free"] == 0
    assert first.json()["wallet"]["balance"] == 5
    assert spend(domain, race, key="first-resume").json() == first.json()
    assert spend(domain, race, 2, 240, 120, 0).json()["wallet"]["balance"] == 4
    assert spend(domain, race, 3, 360, 120, 0).json()["wallet"]["balance"] == 3
    assert spend(domain, race, 3, 480, 120, 0).status_code == 409
    monkeypatch.setattr(api, "now", lambda: 86400 * 110 + 1)
    wallet = domain.client.get("/v1/resumes", headers=headers(domain)).json()
    assert wallet["free"] == 1 and wallet["balance"] == 3
    assert wallet["reset_at"] == 86400 * 111
    next_race = begin(domain)
    assert spend(domain, next_race).json()["wallet"]["balance"] == 3
    # Clock rollback never replenishes an already consumed day.
    monkeypatch.setattr(api, "now", lambda: 86400 * 109 + 1)
    assert domain.client.get("/v1/resumes", headers=headers(domain)).json()["free"] == 0


def test_grants_are_idempotent_nonexpiring_and_not_client_claimable(domain):
    assert grant(domain, 1, "ad", "ad-completed")["balance"] == 1
    assert grant(domain, 1, "ad", "ad-completed")["balance"] == 1
    for i in range(12):
        grant(domain, 1, "ad", f"ad-{i}")
    assert grant(domain, 8, "purchase", "purchase-token")["balance"] == 21
    with domain.factory() as session, pytest.raises(HTTPException):
        grant_verified(session, domain.players["Alice"], "purchase", "purchase-token", 8)
    assert (
        domain.client.post("/v1/resumes/grant", json={"quantity": 999}, headers=headers(domain)).status_code
        == 404
    )


def test_invalid_or_cross_account_requests_never_spend(domain):
    race = begin(domain)
    assert spend(domain, race, player="Alice").status_code == 404
    assert spend(domain, race, source=2401, offset=2401).status_code == 422
    assert spend(domain, race, source=120, target=120).status_code == 422
    assert spend(domain, race, source=119).status_code == 422
    assert spend(domain, race, ordinal=2).status_code == 409
    assert domain.client.get("/v1/resumes", headers=headers(domain)).json()["free"] == 1
    assert spend(domain, race).status_code == 200
    other = begin(domain)
    assert spend(domain, other).status_code == 409


def test_submission_requires_exact_race_receipts(domain):
    issued = ticket(domain, upload(domain))
    race = begin(domain, issued["ticket_id"])
    assert begin(domain, issued["ticket_id"]) == race
    receipt = spend(domain, race).json()["receipt_id"]
    frames = [[0, 255, 0]] * 300
    replay = {
        "schema": "bmt-replay-v2",
        "frames": frames,
        "rewinds": [{"receipt_id": receipt, "input_offset": 120, "from_tick": 120, "to_tick": 0}],
    }

    def submit(value, tid=issued["ticket_id"]):
        return domain.client.post(
            "/v1/runs", headers=headers(domain), json={"ticket_id": tid, "replay": value}
        )

    assert submit({"schema": "bmt-replay-v1", "frames": frames}).status_code == 422
    forged = copy.deepcopy(replay)
    forged["rewinds"][0]["to_tick"] = 1
    assert submit(forged).status_code == 422
    other = ticket(domain, upload(domain))
    assert submit(replay, other["ticket_id"]).status_code == 422
    assert submit(replay).status_code == 202
    assert spend(domain, race, 2, 240, 120, 0).status_code == 409


def test_postgres_daily_and_race_limit_are_serialized(domain):
    if not domain.postgres:
        pytest.skip("Row lock concurrency requires PostgreSQL")
    races = [begin(domain) for _ in range(6)]
    with ThreadPoolExecutor(max_workers=6) as pool:
        codes = list(pool.map(lambda race: spend(domain, race).status_code, races))
    assert codes.count(200) == 1 and codes.count(409) == 5
    grant(domain, 20)
    race = begin(domain)
    for ordinal in range(1, 4):
        with ThreadPoolExecutor(max_workers=6) as pool:
            codes = list(
                pool.map(lambda _, n=ordinal: spend(domain, race, n, n * 120, 120, 0).status_code, range(6))
            )
        assert codes.count(200) == 1 and codes.count(409) == 5
    with domain.factory() as session:
        assert session.get(ResumeWallet, domain.players["Creator"]).balance == 17


def rewind_fixture(original):
    frames = original["frames"]
    # Three branches, including return to race start and a full 20-second rewind.
    first, second, third = 120, 3000, 4200
    return {
        "schema": "bmt-replay-v2",
        "frames": frames[:first] + frames[:second] + frames[600:third] + frames[3600:],
        "rewinds": [
            {"receipt_id": str(uuid.uuid4()), "input_offset": first, "from_tick": first, "to_tick": 0},
            {
                "receipt_id": str(uuid.uuid4()),
                "input_offset": first + second,
                "from_tick": second,
                "to_tick": 600,
            },
            {
                "receipt_id": str(uuid.uuid4()),
                "input_offset": first + second + third - 600,
                "from_tick": third,
                "to_tick": 3600,
            },
        ],
    }


def test_canonical_three_rewinds_keep_original_verified_time(real_verifier, race_fixture):
    replay = rewind_fixture(race_fixture["replay"])
    result = real_verifier.verify_run(race_fixture["document"], replay, "compact")
    original = real_verifier.verify_run(race_fixture["document"], race_fixture["replay"], "compact")
    assert result == original


@pytest.mark.parametrize("mutation", ["too_far", "four", "duplicate", "offset", "tick", "fraction", "extra"])
def test_replay_rejects_invalid_rewind_contract(race_fixture, mutation):
    replay = rewind_fixture(race_fixture["replay"])
    if mutation == "too_far":
        replay["rewinds"][1]["to_tick"] = 599
    elif mutation == "four":
        replay["rewinds"].append(replay["rewinds"][-1])
    elif mutation == "duplicate":
        replay["rewinds"][1]["receipt_id"] = replay["rewinds"][0]["receipt_id"]
    elif mutation == "offset":
        replay["rewinds"][0]["input_offset"] = len(replay["frames"])
    elif mutation == "tick":
        replay["rewinds"][0]["from_tick"] = 119
    elif mutation == "fraction":
        replay["rewinds"][0]["to_tick"] = 0.5
    else:
        replay["rewinds"][0]["state"] = {}
    with pytest.raises(VerificationError):
        validate_replay(replay)
