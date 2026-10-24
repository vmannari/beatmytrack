"""Exact retry recovery, encrypted erasure and immutable financial outcomes."""
import json

import pytest
from fastapi import HTTPException
from sqlalchemy import func, select
from test_domains import domain as _domain_fixture
from test_domains import headers, public_course, race

from bmt_backend.cost_archives import archive_once, cold_response, decrypt, retry_key
from bmt_backend.economy import accept_verified
from bmt_backend.economy_models import CoinReward, CoinWallet
from bmt_backend.object_models import ArchiveChunk, ArchiveKey, CoinArchiveMetric
from bmt_backend.studio_platform_models import StudioCoinEntry
from bmt_backend.track_models import IdempotencyRecord, Run, commit_response, now, replay_response

archive_domain = _domain_fixture


def insert_retry(app, player_id, *, scope="fixture", value=None, body=None):
    stamp = now()-8*86400
    key = "v2."+str(stamp)+"."+"a"*48
    response = value or {"private": "sensitive retained answer", "amount": 17, "nested": [1, .125, "exact"]}
    request = body or {"operation": "once"}
    with app.state.session_factory() as session:
        commit_response(session, player_id, scope, key, request, response)
        row = session.get(IdempotencyRecord, (player_id, scope, key))
        row.created_at = stamp
        session.commit()
    return scope, key, request, response


def test_retry_is_exact_after_hot_receipt_is_removed(auth_app, sign_in):
    player = sign_in()["player"]["id"]
    scope, key, body, value = insert_retry(auth_app, player)
    assert archive_once(auth_app.state.session_factory, auth_app.state.blobs)
    with auth_app.state.session_factory() as session:
        assert session.get(IdempotencyRecord, (player, scope, key)) is None
        assert replay_response(session, player, scope, key, body) == value
        with pytest.raises(HTTPException) as error:
            replay_response(session, player, scope, key, {"operation": "changed"})
        assert error.value.status_code == 409
    assert not archive_once(auth_app.state.session_factory, auth_app.state.blobs)


def test_cold_retry_cannot_cross_account(auth_app, sign_in):
    alice, bob = sign_in("Alice")["player"]["id"], sign_in("Bob")["player"]["id"]
    scope, key, body, _ = insert_retry(auth_app, alice)
    archive_once(auth_app.state.session_factory, auth_app.state.blobs)
    with auth_app.state.session_factory() as session:
        assert cold_response(session, bob, scope, key, body) is None


def test_archive_bytes_are_encrypted_and_erasure_fails_closed(auth_app, sign_in):
    player = sign_in()["player"]["id"]
    scope, key, body, _ = insert_retry(auth_app, player)
    archive_once(auth_app.state.session_factory, auth_app.state.blobs)
    with auth_app.state.session_factory() as session:
        chunk = session.scalar(select(ArchiveChunk))
        data = auth_app.state.blobs.get_json(chunk.digest)
        assert "sensitive retained answer" not in json.dumps(data)
        assert player not in json.dumps(data)
        session.delete(session.get(ArchiveKey, player))
        session.commit()
    with auth_app.state.session_factory() as session, pytest.raises(HTTPException) as error:
        cold_response(session, player, scope, key, body)
    assert error.value.status_code == 503  # Never interpret an unreadable receipt as a new operation.


def test_lost_archive_ack_preserves_the_hot_answer(auth_app, sign_in, monkeypatch):
    player = sign_in()["player"]["id"]
    scope, key, body, value = insert_retry(auth_app, player)
    put = auth_app.state.blobs.put_json
    def lost(data):
        put(data)
        raise OSError("lost publication reply")
    monkeypatch.setattr(auth_app.state.blobs, "put_json", lost)
    with pytest.raises(OSError):
        archive_once(auth_app.state.session_factory, auth_app.state.blobs)
    with auth_app.state.session_factory() as session:
        assert replay_response(session, player, scope, key, body) == value
        assert session.scalar(select(func.count()).select_from(ArchiveChunk)) == 0


def test_retirement_during_archive_does_not_publish_stale_success(auth_app, sign_in, monkeypatch):
    player = sign_in()["player"]["id"]
    scope, key, body, _ = insert_retry(auth_app, player)
    put = auth_app.state.blobs.put_json
    def retire(data):
        result = put(data)
        with auth_app.state.session_factory() as session:
            session.get(IdempotencyRecord, (player, scope, key)).response = {"retired": True}
            session.commit()
        return result
    monkeypatch.setattr(auth_app.state.blobs, "put_json", retire)
    assert not archive_once(auth_app.state.session_factory, auth_app.state.blobs)
    with auth_app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(ArchiveChunk)) == 0
        with pytest.raises(HTTPException) as error:
            replay_response(session, player, scope, key, body)
    assert error.value.status_code == 410


def test_ciphertext_and_identity_tampering_are_rejected():
    from bmt_backend.cost_archives import encrypt
    secret = b"k"*32
    value = encrypt(secret, "identity", {"response": {"balance": 17}})
    assert decrypt(secret, "identity", value) == {"response": {"balance": 17}}
    with pytest.raises(OSError):
        decrypt(secret, "other-identity", value)
    with pytest.raises(OSError):
        decrypt(b"x"*32, "identity", value)


def test_reward_archive_keeps_exact_answer_and_cannot_mint_again(archive_domain):
    d = archive_domain
    version, _ = public_course(d)
    result = race(d, version, player="Alice", frames=70)
    with d.factory() as session:
        run = session.get(Run, result["run_id"])
        ticket_id = run.ticket_id
        receipt = session.get(CoinReward, run.id)
        expected = {"status": "credited", "amount": receipt.amount, "rows": receipt.rows}
        receipt.created_at = now()-8*86400
        before = session.get(CoinWallet, run.player_id).balance
        session.commit()
    assert archive_once(d.factory, d.app.state.blobs, kind="reward")
    received = d.client.get("/v1/economy/rewards/"+ticket_id, headers=headers(d, "Alice"))
    assert received.status_code == 200, received.text
    assert received.json() == expected
    with d.factory() as session:
        run = session.get(Run, result["run_id"])
        assert run.reward_archive_hash
        assert session.get(CoinReward, run.id) is None
        accept_verified(session, run, (0, 0), incident_free=True)
        session.commit()
        assert session.get(CoinWallet, run.player_id).balance == before
        assert session.get(CoinReward, run.id) is None
        assert session.scalar(select(func.sum(CoinArchiveMetric.amount))) == expected["amount"]
        assert session.scalar(select(StudioCoinEntry.id).where(StudioCoinEntry.reference == "run/"+run.id)) is None


def test_retry_identity_keeps_its_original_timestamp_and_owner():
    key = "v2.1700000000."+"b"*48
    assert retry_key("player", "purchase", key).startswith("1700000000")
    assert retry_key("player", "purchase", key) != retry_key("other", "purchase", key)
    assert retry_key("player", "purchase", "legacy-key") == ""


def test_finance_windows_combine_hot_and_cold_exactly(auth_app, sign_in):
    from types import SimpleNamespace

    from bmt_backend.studio_finance import report
    player_id = sign_in()["player"]["id"]
    with auth_app.state.session_factory() as session:
        session.add_all([CoinArchiveMetric(at=101, kind="earned", amount=17, count=2),
                         CoinArchiveMetric(at=102, kind="earned", amount=25, count=3),
                         CoinArchiveMetric(at=103, kind="earned", amount=999, count=9)])
        session.add(StudioCoinEntry(id="a"*64, player_id=player_id, reference="fixture", kind="earned",
                                   amount=5, detail={}, created_at=102))
        session.commit()
    request = SimpleNamespace(app=auth_app)
    assert report(request, "owner", (101, 103))["coins"] == [{"kind":"earned", "amount":47, "entries":6}]
    assert report(request, "owner", (102, 103))["coins"] == [{"kind":"earned", "amount":30, "entries":4}]
