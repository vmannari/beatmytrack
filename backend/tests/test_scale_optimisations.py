"""Exact wallet/proof semantics and bounded idle schedules across restarts."""
# ruff: noqa: F811 - parametrized fixture imported for pytest.
import base64
import copy
import json
import math
import uuid
from pathlib import Path
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from sqlalchemy import event, select, update
from test_domains import domain, headers, public_course, ticket  # noqa: F401

from bmt_backend import discovery_projection, telemetry_queue
from bmt_backend.discovery_models import DiscoveryChange, DiscoveryPartition
from bmt_backend.economy import balance, locked_wallet
from bmt_backend.economy_models import CoinWallet, CosmeticUnlock
from bmt_backend.identity_models import Player
from bmt_backend.path_wire import RECORD, unpack_path
from bmt_backend.replay_wire import unpack_replay
from bmt_backend.storage import canonical_json
from bmt_backend.studio_platform_models import StudioCoinEntry
from bmt_backend.telemetry_models import ProductEvent
from bmt_backend.telemetry_queue_models import TelemetryCredit
from bmt_backend.track_models import Run, digest, now


def capture(engine):
    statements = []
    def record(_connection, _cursor, sql, *_args):
        statements.append(sql)
    event.listen(engine, "before_cursor_execute", record)
    return statements, record


def test_established_wallet_is_one_coherent_read_without_writes(domain):
    d, identity = domain, domain.players["Alice"]
    with d.factory() as db:
        wallet = locked_wallet(db, identity)
        wallet.balance, wallet.revision = 1700, 12
        db.add(CosmeticUnlock(player_id=identity, item_id="livery/apex_twin", price=500))
        db.commit()
    sql, listener = capture(d.app.state.engine)
    try:
        with d.factory() as db:
            result = balance(db, SimpleNamespace(id=identity))
    finally:
        event.remove(d.app.state.engine, "before_cursor_execute", listener)
    assert len(sql) == 1 and sql[0].lstrip().upper().startswith("SELECT")
    assert result["balance"] == 1700 and result["revision"] == 12
    assert result["owned"] == ["livery/apex_twin"]
    assert d.client.get("/v1/economy", headers=headers(d, "Alice")).json() == result


def test_missing_and_legacy_wallet_reconcile_once_and_restrictions_still_apply(domain):
    d, identity = domain, domain.players["Alice"]
    with d.factory() as db:
        db.add(CoinWallet(player_id=identity, balance=987, revision=9))
        db.commit()
    first = d.client.get("/v1/economy", headers=headers(d, "Alice"))
    assert first.status_code == 200
    assert (first.json()["balance"], first.json()["revision"]) == (987, 9)
    with d.factory() as db:
        opening = db.get(StudioCoinEntry, digest({"player": identity, "reference": "opening"}))
        assert opening.amount == 987 and opening.detail["revision"] == 9
        assert balance(db, SimpleNamespace(id=d.players["Bob"]))["balance"] == 0
    for field, value in (("disabled", True), ("deleted_at", now())):
        with d.factory() as db:
            setattr(db.get(Player, identity), field, value)
            db.flush()
            with pytest.raises(HTTPException) as rejected:
                balance(db, SimpleNamespace(id=identity))
            assert rejected.value.status_code == 401
            db.rollback()


def fixture():
    path = Path(__file__).resolve().parents[2] / "game/tests/fixtures/packed_path_v1.json"
    return json.loads(path.read_text(encoding="utf-8"))


def test_packed_path_has_exact_numeric_types_bits_hash_and_incidents():
    golden = fixture()
    unpacked = unpack_path(golden["packed"])
    assert canonical_json(unpacked) == canonical_json(golden["plain"])
    assert math.copysign(1, unpacked["samples"][2][1]) == -1
    assert type(unpacked["samples"][1][1]) is int
    assert type(unpacked["samples"][0][1]) is float
    assert digest(unpacked) == digest(golden["plain"])
    envelope = {"schema": "bmt-trajectory-v1", "input_count": 12,
                "race_proof": golden["packed"], "rewinds": [], "ghost": {"presentation": "unchanged"}}
    original = copy.deepcopy(envelope)
    decoded = unpack_replay(envelope)
    assert decoded["race_proof"] == golden["plain"] and decoded["ghost"] == envelope["ghost"]
    assert original == envelope


@pytest.mark.parametrize("change", [
    {"count": True}, {"count": 1}, {"count": 36013}, {"count": 3.0},
    {"count": 2**60}, {"data": "!" * 88}, {"data": ""}, {"extra": 1},
])
def test_packed_path_rejects_malformed_or_unbounded_envelopes(change):
    with pytest.raises(HTTPException) as rejected:
        unpack_path({**fixture()["packed"], **change})
    assert rejected.value.status_code == 422


@pytest.mark.parametrize("row", [
    (216001, 0., 0., 0), (0, float("nan"), 0., 0), (0, 0., float("inf"), 0),
    (0, 0., 0., 8), (0, 1.5, 0., 2), (0, 0., 1.5, 4), (0, 2.**54, 0., 2),
])
def test_packed_path_checks_each_binary_record(row):
    value = {"schema": "bmt-packed-path-v1", "count": 2,
             "data": base64.b64encode(RECORD.pack(*row) * 2).decode()}
    with pytest.raises(HTTPException):
        unpack_path(value)


def test_packed_and_plain_submissions_share_exact_idempotency_and_storage(domain):
    d = domain
    version, _ = public_course(d)
    issued = ticket(d, version, "Alice")
    golden = fixture()
    envelope = {"schema": "bmt-trajectory-v1", "input_count": 12,
                "race_proof": golden["plain"], "rewinds": []}
    identity = headers(d, "Alice")
    first = d.client.post("/v1/runs", json={"ticket_id": issued["ticket_id"], "replay": envelope}, headers=identity)
    assert first.status_code == 202, first.text
    packed = {**envelope, "race_proof": golden["packed"]}
    retry = d.client.post("/v1/runs", json={"ticket_id": issued["ticket_id"], "replay": packed}, headers=identity)
    assert retry.status_code == 202 and retry.json() == first.json()
    with d.factory() as db:
        run = db.get(Run, first.json()["run_id"])
        assert run.replay_hash == digest(envelope)
        assert canonical_json(d.app.state.blobs.get_json(run.replay_hash)) == canonical_json(envelope)


def test_discovery_idle_does_not_update_partition_and_still_wakes_for_work(domain):
    d, stamp = domain, now()
    discovery_projection.settle_for_diagnostics(d.factory, clock=stamp)
    with d.factory() as db:
        db.execute(update(DiscoveryPartition).values(checked_at=__import__("time").time_ns(), audit_at=stamp + 60))
        db.commit()
    schedule = discovery_projection.DiscoveryMaintenance()
    assert not discovery_projection.step(d.factory, clock=stamp, tick=1, maintenance=schedule)
    sql, listener = capture(d.app.state.engine)
    try:
        assert not discovery_projection.step(d.factory, clock=stamp, tick=2, maintenance=schedule)
    finally:
        event.remove(d.app.state.engine, "before_cursor_execute", listener)
    # PostgreSQL additionally installs the unchanged local statement deadline.
    assert sum(s.lstrip().upper().startswith("SELECT") for s in sql) == 1
    assert not any(s.lstrip().upper().startswith(("UPDATE", "INSERT", "DELETE")) for s in sql)
    with d.factory() as db:
        db.add(DiscoveryChange(partition=0, kind="stats", target=str(uuid.uuid4()), created_at=stamp))
        db.commit()
    assert discovery_projection.step(d.factory, clock=stamp, tick=2.1, maintenance=schedule)
    with d.factory() as db:
        assert db.scalar(select(DiscoveryChange.id).where(DiscoveryChange.processed_at.is_(None))) is None


def test_discovery_global_cleanup_runs_without_a_due_partition(domain):
    d, stamp = domain, now()
    discovery_projection.settle_for_diagnostics(d.factory, clock=stamp)
    with d.factory() as db:
        db.execute(update(DiscoveryPartition).values(checked_at=__import__("time").time_ns(), audit_at=stamp + 60))
        row = DiscoveryChange(partition=0, kind="stats", target=str(uuid.uuid4()), created_at=stamp-122,
                              processed_at=stamp-121)
        db.add(row)
        db.flush()
        identity = row.id
        db.commit()
    schedule = discovery_projection.DiscoveryMaintenance()
    assert discovery_projection.step(d.factory, clock=stamp, tick=1, maintenance=schedule)
    with d.factory() as db:
        assert db.get(DiscoveryChange, identity) is None


def test_telemetry_empty_checks_are_coalesced_and_late_legacy_receipts_recover(domain):
    d, schedule = domain, telemetry_queue.PreparationSchedule()
    assert schedule.step(d.factory, tick=1) == 0
    sql, listener = capture(d.app.state.engine)
    try:
        assert schedule.step(d.factory, tick=2) == 0
    finally:
        event.remove(d.app.state.engine, "before_cursor_execute", listener)
    assert sql == []
    identity = str(uuid.uuid4())
    with d.factory() as db:
        db.add(ProductEvent(id=identity, player_id=d.players["Alice"], source="server", name="race_accepted",
                            occurred_at=now(), received_at=now(), payload_hash="fixture", properties={}))
        db.commit()
    assert schedule.step(d.factory, tick=6) == 1
    with d.factory() as db:
        assert db.get(ProductEvent, identity).partition_id is not None
    # New process always checks immediately, independently of old local deadlines.
    assert telemetry_queue.PreparationSchedule().step(d.factory, tick=0) == 0


def test_busy_legacy_queue_and_failed_transactions_are_not_marked_ready(monkeypatch):
    calls = []
    def busy(*_args, **_kwargs):
        calls.append(1)
        return 0, False
    monkeypatch.setattr(telemetry_queue, "prepare", busy)
    schedule = telemetry_queue.PreparationSchedule()
    assert schedule.step(None, tick=1) == schedule.step(None, tick=1.1) == 0
    assert len(calls) == 2
    def failure(*_args, **_kwargs):
        raise RuntimeError("rollback")
    monkeypatch.setattr(telemetry_queue, "prepare", failure)
    with pytest.raises(RuntimeError):
        schedule.step(None, tick=2)
    assert schedule.next_at == 1.1


def test_legacy_client_waits_for_credit_without_suppressing_server_recovery(domain):
    d, stamp = domain, now()
    client_id, server_id = str(uuid.uuid4()), str(uuid.uuid4())
    with d.factory() as db:
        telemetry_queue.activate(db)
        db.execute(update(TelemetryCredit).values(free=0))
        for identity, source in ((client_id, "client"), (server_id, "server")):
            db.add(ProductEvent(id=identity, player_id=d.players["Alice"], source=source, name="menu_ready",
                                occurred_at=stamp, received_at=stamp, payload_hash="fixture", properties={}))
        db.commit()
    schedule = telemetry_queue.PreparationSchedule()
    assert schedule.step(d.factory, tick=1) == 1
    assert schedule.next_at == 1  # Remaining client receipt is not an empty-ready queue.
    with d.factory() as db:
        assert db.get(ProductEvent, server_id).partition_id is not None
        assert db.get(ProductEvent, client_id).partition_id is None
        db.execute(update(TelemetryCredit).where(TelemetryCredit.id == 0).values(free=1))
        db.commit()
    assert schedule.step(d.factory, tick=1.1) == 1
    with d.factory() as db:
        assert db.get(ProductEvent, client_id).partition_id is not None
    assert schedule.next_at == 6.1


def test_discovery_failure_does_not_defer_uncommitted_maintenance(domain, monkeypatch):
    d = domain
    discovery_projection.settle_for_diagnostics(d.factory)
    original = discovery_projection.cleanup
    def fail(*_args):
        raise RuntimeError("rollback cleanup")
    monkeypatch.setattr(discovery_projection, "cleanup", fail)
    schedule = discovery_projection.DiscoveryMaintenance()
    with pytest.raises(RuntimeError):
        discovery_projection.step(d.factory, tick=1, maintenance=schedule)
    assert "storage" not in schedule.next_at and "cleanup" not in schedule.next_at
    monkeypatch.setattr(discovery_projection, "cleanup", original)
    discovery_projection.step(d.factory, tick=1.1, maintenance=schedule)
    assert schedule.next_at["cleanup"] == 6.1
