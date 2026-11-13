"""BWR01-BWR04: avoid repeated work without changing authoritative outcomes."""
# ruff: noqa: F811 - imported parametrized fixtures are injected by pytest.
import copy
import inspect
import json
from dataclasses import FrozenInstanceError
from types import SimpleNamespace

import pytest
from alembic import command
from sqlalchemy import event, select
from test_domains import FakeVerifier, domain, headers, public_course, race, submit  # noqa: F401
from test_non_improving_runs import prepared, replay, submit_hint
from test_packed_storage import packed  # noqa: F401
from test_reward_ranks import field
from test_rivalry import join, rivalry_ticket, seed
from test_test_drivers import KEY, auth, bot_login, drivers, fleet  # noqa: F401

from bmt_backend import reward_rank_cache, storage, test_population_tool
from bmt_backend.economy_models import CoinMilestone
from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.reward_ranks import percentile_amount as exact_amount
from bmt_backend.test_population_batch import ACTIVE, batch_jobs, batch_view, drive_idle
from bmt_backend.track_models import (
    Board,
    LapPersonalBest,
    OperationState,
    PersonalBest,
    Run,
    RunTicket,
    digest,
    now,
)
from bmt_backend.worker import process_one


def count_encodings(monkeypatch):
    calls = []
    original = storage.canonical_json

    def encode(data):
        calls.append(data)
        return original(data)

    monkeypatch.setattr(storage, "canonical_json", encode)
    return calls


def test_prepared_json_is_frozen_and_detached_from_mutable_input(tmp_path, monkeypatch):
    data = {"samples": [[1, 2, 3]], "unicode": "\u00e4"}
    expected = copy.deepcopy(data)
    calls = count_encodings(monkeypatch)
    prepared_body = storage.prepare_json(data)
    assert prepared_body.digest == digest(data)
    data["samples"][0][0] = 99
    assert storage.prepare_json(prepared_body) is prepared_body
    with pytest.raises(FrozenInstanceError):
        prepared_body.digest = "0" * 64
    store = storage.LocalBlobStore(str(tmp_path))
    key = store.put_json(prepared_body)
    assert store.get_json(key) == expected
    assert len(calls) == 1
    store._path(key).write_bytes(b"corrupt")
    with pytest.raises(OSError):
        store.put_json(prepared_body)


@pytest.mark.parametrize("data", [{"x": float("nan")}, {"x": float("inf")}, {"x": "x" * (8*1024*1024)}])
def test_prepared_json_retains_finite_and_size_guards(data):
    with pytest.raises(ValueError):
        storage.prepare_json(data)


@pytest.mark.parametrize("fallback", [False, True])
def test_pinned_packed_and_fallback_encode_once(packed, monkeypatch, fallback):
    store, factory, _ = packed
    if fallback:
        store.settings = SimpleNamespace(object_pack_bytes=8)
    pinned = storage.PinnedBlobStore(store, factory)
    calls = count_encodings(monkeypatch)
    data = {"immutable": [1, 2, 3]}
    key = pinned.put_json(storage.prepare_json(data))
    assert pinned.get_json(key) == data
    assert len(calls) == 1


def test_run_http_encodes_replay_once_and_keeps_upload_retry_identity(domain, monkeypatch):
    version, _ = prepared(domain)
    from test_domains import ticket
    issued = ticket(domain, version, "Alice")
    calls = count_encodings(monkeypatch)
    body = replay()
    first = submit_hint(domain, issued, body, key="bwr-retry").json()
    assert first["status"] == "skipped"
    assert calls == [body]
    again = submit_hint(domain, issued, body, key="bwr-retry").json()
    assert again == first
    assert len(calls) == 2  # One encoding per HTTP attempt; none in nested stores.
    with domain.factory() as session:
        run = session.get(Run, first["run_id"])
        assert run.replay_hash == digest(body)
        assert domain.app.state.blobs.get_json(run.replay_hash) == body


def test_rivalry_uses_one_snapshot_only_when_score_does_not_improve(domain, monkeypatch):
    from bmt_backend import rivalry
    seed(domain)
    group = join(domain)["group_id"]
    calls = []
    original = rivalry.standings_data

    def standings(*args, **kwargs):
        calls.append(inspect.currentframe().f_back.f_code.co_name)
        return original(*args, **kwargs)

    monkeypatch.setattr(rivalry, "standings_data", standings)
    for frames, expected in ((30, 2), (35, 1), (30, 1), (20, 2)):
        issued = rivalry_ticket(domain, group)
        submitted = submit(domain, issued, "Alice", frames=frames)
        calls.clear()
        assert process_one(domain.app)
        # Achievement capture has a separate snapshot; count the score writer's
        # work without changing or disabling that authoritative consumer.
        assert calls.count("accept_verified") == expected
        result = domain.client.get("/v1/rivalry/tickets/"+issued["ticket_id"]+"/result",
                                   headers=headers(domain, "Alice")).json()
        assert result["status"] == "verified"
        outcome = result["outcome"]
        assert outcome["improved"] == (expected == 2)
        if expected == 1:
            assert outcome["before"] == outcome["after"]
            assert outcome["overall_before"] == outcome["overall_after"]
            assert outcome["points_delta"] == 0 and outcome["beaten"] == []
        assert submitted["run_id"]


@pytest.mark.parametrize("capable", [False, True])
def test_driver_adds_hint_only_to_new_recordings_and_freezes_retry_body(tmp_path, capable):
    manifest = FakeVerifier().manifest()
    document = {"shape": "oval"}
    job = {"id": "x", "version_id": "v", "content_hash": digest(document), "attempt": 0}
    plan = {"manifest": manifest, "vehicle_id": "compact", "pace_scales": {}}
    generated = {"manifest": manifest, "time_ticks": 100, "lap_ticks": [20]*5,
                 "replay": replay(), "mistakes": 0}
    del generated["replay"]["claimed_lap_ticks"]
    original = copy.deepcopy(generated)
    api = SimpleNamespace(non_improving_runs=capable, call=lambda *_args: document)
    profile = {"traits": {}}
    path = tmp_path / "plan.json"
    result = test_population_tool.recording(api, plan, job, profile, None, path,
                                            generator=lambda *_args: generated)
    assert ("claimed_lap_ticks" in result["replay"]) is capable
    assert generated == original
    api.non_improving_runs = not capable
    frozen = (tmp_path / "plan-recordings" / "x.json").read_bytes()
    cached = test_population_tool.recording(api, plan, job, profile, None, path,
        generator=lambda *_args: pytest.fail("Frozen recordings must not be regenerated"))
    assert cached == result
    assert (tmp_path / "plan-recordings" / "x.json").read_bytes() == frozen


def test_scheduler_treats_skipped_as_success_without_retry(tmp_path):
    manifest = FakeVerifier().manifest()
    job = {"id":"x", "subject":"bot", "slot":0, "group_id":None,
           "status":"submitted", "run_id":"r", "due":0}
    plan = {"manifest":manifest, "profiles":[], "jobs":[job], "mode":"fill", "ends_at":9999,
            "vehicle_id":"compact", "require_history_completion":True}

    def call(method, route, **kwargs):
        assert method == "GET", "A skipped completion must not be retried"
        if route.startswith("/dev/"):
            return {"manifest":manifest, "server_now":100}
        assert route == "/runs/r"
        return {"status":"skipped", "time_ticks":100, "failure_code":None}

    test_population_tool.tick(SimpleNamespace(call=call), plan, None, tmp_path / "plan.json")
    assert job["status"] == "skipped"
    assert json.loads((tmp_path / "plan.json").read_text())["jobs"][0]["status"] == "skipped"


def test_test_driver_repeated_proof_skips_verifier_and_batch_completes(drivers, monkeypatch):
    p = fleet(drivers, count=1)["profiles"][0]
    login = bot_login(drivers, p)
    version = drivers.client.get("/v1/dev/test-drivers/tracks?vehicle_id=compact",
        headers={"X-Dev-Auth-Key":KEY}).json()["tracks"][0]["version_id"]
    for expected in ("queued", "skipped"):
        issued = drivers.client.post("/v1/run-tickets",json={"version_id":version,
            "vehicle_id":"compact", "test_population":True},headers=auth(login)).json()
        response = drivers.client.post("/v1/runs",json={"ticket_id":issued["ticket_id"],
            "replay":replay()},headers=auth(login))
        assert response.status_code == 202, response.text
        assert response.json()["status"] == expected
        if expected == "queued":
            assert process_one(drivers.app)
            monkeypatch.setattr(drivers.app.state.verifier, "verify_run",
                                lambda *_args, **_kw: pytest.fail("Repeated bot race was verified"))
    # A durable batch must finish when its submitted job completed via the skip.
    run_id = response.json()["run_id"]
    with drivers.factory() as session:
        session.add(OperationState(id=ACTIVE, details={"status":"running", "batch_id":"bwr"}))
        session.add(OperationState(id="test-pop-batch:bwr", details={"batch_id":"bwr", "status":"running",
            "manifest":drivers.app.state.verifier.manifest(), "vehicle_id":"compact", "count":1, "jobs":1,
            "player_ids":[login["player"]["id"]],
            "tracks":[{"name":"Test", "version_id":version}], "cleared_test_records":0, "protected_real_records":0}))
        session.add(OperationState(id="test-pop-job:bwr", details={"batch_id":"bwr", "status":"submitted",
            "slot":0, "player_id":login["player"]["id"], "run_id":run_id, "attempt":0}))
        session.commit()
    monkeypatch.setattr(drivers.app.state, "settings", SimpleNamespace(**{
        **vars(drivers.app.state.settings), "godot_bin":"unused-local-test"}))
    assert drive_idle(drivers.app)
    with drivers.factory() as session:
        view = batch_view(session, "bwr")
        assert view["complete"] and view["status"] == "complete"
        assert view["jobs"] == {"skipped":1}
        assert view["tracks"][0]["completed_players"] == 1 and view["tracks"][0]["verified_players"] == 0
        assert batch_jobs(session, "bwr")[0].details["attempt"] == 0
    from backend.tools.audit_test_population_batch import audit
    report = audit(drivers.app, "bwr")
    assert report["skipped_runs"] == 1 and report["verified_runs"] == 0
    assert report["verified_personal_bests"] == 1


def revisions(session, board):
    return tuple(session.execute(select(Board.stats_revision, Board.lap_revision).where(Board.id == board)).one())


def check(session, domain, board, metric="race", ticks=200, earned=0):
    return reward_rank_cache.percentile_amount(session, domain.players["Alice"], board, metric,
                                               ticks, revisions(session, board), earned)


def rank_reads(domain):
    calls = []

    def record(_connection, _cursor, statement, *_args):
        if statement.lstrip().upper().startswith("SELECT") and "FROM reward_rank_counts" in statement:
            calls.append(statement)

    event.listen(domain.app.state.engine, "before_cursor_execute", record)
    return calls, record


@pytest.mark.parametrize("ticks", [10, 200])
def test_committed_reward_checks_skip_rank_reads_but_faster_candidates_recalculate(domain, ticks):
    _, board = field(domain)
    with domain.factory() as session:
        amount = check(session, domain, board, ticks=ticks)
        session.commit()
    calls, record = rank_reads(domain)
    try:
        with domain.factory() as session:
            assert check(session, domain, board, ticks=ticks+1, earned=amount) == 0
            assert not calls
            check(session, domain, board, ticks=ticks-1, earned=amount)
            assert len(calls) == 1
            if amount:
                check(session, domain, board, ticks=ticks, earned=0)
                assert len(calls) == 2  # A reset milestone cannot suppress a reward.
    finally:
        event.remove(domain.app.state.engine, "before_cursor_execute", record)


@pytest.mark.parametrize("metric,model", [("race",PersonalBest),("lap",LapPersonalBest)])
@pytest.mark.parametrize("change", ["ticks", "delete", "disabled", "is_test_driver", "deleted_at"])
def test_reward_cache_invalidates_every_rank_population_change(domain, metric, model, change):
    _, board = field(domain)
    with domain.factory() as session:
        old_revision = revisions(session, board)
        amount = check(session, domain, board, metric)
        session.commit()
    with domain.factory() as session:
        if change in ("ticks", "delete"):
            best = session.get(model, (board,domain.players["Bob"]))
            if change == "ticks":
                best.time_ticks = 1
            else:
                session.delete(best)
        else:
            setattr(session.get(Player, domain.players["Bob"]), change, 123 if change == "deleted_at" else True)
        session.commit()
    calls, record = rank_reads(domain)
    try:
        with domain.factory() as session:
            assert revisions(session, board) != old_revision
            expected = exact_amount(session, board, metric, 200)
            calls.clear()
            assert check(session, domain, board, metric, earned=amount) == expected
            assert len(calls) == 1
    finally:
        event.remove(domain.app.state.engine, "before_cursor_execute", record)


@pytest.mark.parametrize("nested", [False, True])
def test_rolled_back_checks_are_never_shared_even_if_revision_is_reused(domain, nested):
    _, board = field(domain)
    with domain.factory() as session:
        transaction = session.begin_nested() if nested else session.get_transaction() or session.begin()
        session.get(PersonalBest, (board,domain.players["Bob"])).time_ticks = 1
        session.flush()
        rolled_revision = revisions(session, board)
        check(session, domain, board, ticks=200)
        transaction.rollback()
        if nested:
            session.commit()
    calls, record = rank_reads(domain)
    try:
        with domain.factory() as session:
            session.get(PersonalBest, (board,domain.players["Carol"])).time_ticks = 2
            session.flush()
            assert revisions(session, board) == rolled_revision
            calls.clear()
            assert check(session, domain, board) == exact_amount(session, board, "race", 200)
            assert len(calls) == 2
    finally:
        event.remove(domain.app.state.engine, "before_cursor_execute", record)


def test_reward_cache_reduces_real_repeat_race_queries_and_preserves_receipt(domain):
    version, _board = field(domain)
    race(domain, version, "Alice", frames=25)  # First check at this generation.
    calls, record = rank_reads(domain)
    try:
        result = race(domain, version, "Alice", frames=26)
        assert not calls
    finally:
        event.remove(domain.app.state.engine, "before_cursor_execute", record)
    receipt = domain.client.get("/v1/economy/rewards/"+result["ticket_id"],headers=headers(domain,"Alice")).json()
    assert any(row["title"] == "Race completed" and row["amount"] == 50 for row in receipt["rows"])
    assert not any("percentile" in row["title"] for row in receipt["rows"])


def test_reward_cache_is_bounded_per_engine(domain, monkeypatch):
    _, board = field(domain)
    monkeypatch.setattr(reward_rank_cache, "LIMIT", 3)
    with domain.factory() as session:
        for index in range(8):
            reward_rank_cache.percentile_amount(session, str(index), board, "race", 200, revisions(session,board), 0)
        session.commit()
    assert len(reward_rank_cache._caches[domain.app.state.engine]) == 3


def test_new_revision_triggers_round_trip_without_changing_bests_or_rewards(domain):
    _, board = field(domain)
    with domain.factory() as session:
        bests = list(session.execute(select(PersonalBest.player_id, PersonalBest.time_ticks).where(PersonalBest.board_id==board)))
        milestones = list(session.execute(select(CoinMilestone.player_id,CoinMilestone.scope,CoinMilestone.value)))
    command.downgrade(configuration(domain.app.state.engine), "0069_slot_gifts")
    upgrade(domain.app.state.engine)
    with domain.factory() as session:
        assert list(session.execute(select(PersonalBest.player_id, PersonalBest.time_ticks).where(PersonalBest.board_id==board))) == bests
        assert list(session.execute(select(CoinMilestone.player_id,CoinMilestone.scope,CoinMilestone.value))) == milestones


@pytest.mark.parametrize("model", [PersonalBest, LapPersonalBest])
def test_moving_a_best_invalidates_both_old_and_new_boards(domain, model):
    _, board_id = field(domain)
    with domain.factory() as session:
        board = session.get(Board, board_id)
        moved = Board(id="b"*64, version_id=board.version_id, vehicle_id=board.vehicle_id, manifest=board.manifest)
        session.add(moved)
        session.flush()
        before = {bid:revisions(session,bid) for bid in (board_id,moved.id)}
        best = session.get(model, (board_id,domain.players["Alice"]))
        best.board_id = moved.id
        session.flush()
        assert all(revisions(session,bid) != revision for bid,revision in before.items())


def test_rank_generation_is_read_with_counter_snapshot(domain, monkeypatch):
    _, board = field(domain)
    with domain.factory() as session:
        earlier = revisions(session, board)
        session.get(PersonalBest, (board,domain.players["Bob"])).time_ticks = 1
        session.commit()
    # Emulate a committed board change between milestone loading and rank read.
    with domain.factory() as session:
        expected_revision = revisions(session,board)
        assert expected_revision != earlier
        reward_rank_cache.percentile_amount(session,domain.players["Alice"],board,"race",200,earlier,0)
        session.commit()
    assert reward_rank_cache._caches[domain.app.state.engine][(domain.players["Alice"],board,"race")][0] == expected_revision


def test_population_growth_can_award_higher_tiers_without_a_new_pb(domain):
    version, board = field(domain)
    race(domain,version,"Alice",frames=40)  # Warm a zero-tier check at 200 ticks.
    with domain.factory() as session:
        for index in range(16):
            player = Player(display_name="Slower driver "+str(index))
            session.add(player)
            session.flush()
            ticket = RunTicket(player_id=player.id,board_id=board,expires_at=now()+7200)
            session.add(ticket)
            session.flush()
            run = Run(ticket_id=ticket.id,player_id=player.id,board_id=board,replay_hash="f"*64,
                      status="verified",time_ticks=1000,lap_ticks=[200]*5,finished_at=now())
            session.add(run)
            session.flush()
            session.add(PersonalBest(board_id=board,player_id=player.id,run_id=run.id,time_ticks=1000))
        session.commit()
    accepted = race(domain,version,"Alice",frames=40)
    receipt = domain.client.get("/v1/economy/rewards/"+accepted["ticket_id"],headers=headers(domain,"Alice")).json()
    tiers = {row["title"]:row["amount"] for row in receipt["rows"] if "percentile" in row["title"]}
    assert tiers == {"Race percentile tier":100,"Best-lap percentile tier":100}
    with domain.factory() as session:
        assert session.get(PersonalBest,(board,domain.players["Alice"])).time_ticks == 100
        assert session.get(LapPersonalBest,(board,domain.players["Alice"])).time_ticks == 20
