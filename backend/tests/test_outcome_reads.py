"""Completion read savings retain exact effects, current authority and old clients."""
# ruff: noqa: F811 - parametrized fixture imported for pytest.
from sqlalchemy import event, select
from sqlalchemy.exc import OperationalError
from test_challenge_series import create as create_series
from test_challenges import create, join, normal_run, setup
from test_domains import domain, headers, public_course, race, submit, ticket  # noqa: F401
from test_rivalry import seed

from bmt_backend.community_models import PlayerBlock
from bmt_backend.economy_models import CoinMilestone, CoinReward, CoinWallet
from bmt_backend.news_models import NewsItem
from bmt_backend.track_models import LapPersonalBest, PersonalBest, Run, TrackVersion
from bmt_backend.worker import process_one


def read(d, run_id, *, completion=True, player="Alice"):
    return d.client.get(f"/v1/runs/{run_id}", params={"completion": completion}, headers=headers(d, player))


def queued_challenge(d):
    version = setup(d)
    normal_run(d, version)
    challenge = create(d, version, attempt_limit=3)
    join(d, challenge["code"])
    issued = d.client.post(f"/v1/challenges/{challenge['code']}/tickets", headers=headers(d, "Bob"))
    assert issued.status_code == 201
    run = submit(d, issued.json(), "Bob", frames=30)
    return challenge, issued.json(), run


def test_slow_news_gate_saves_only_candidate_read_and_keeps_lap_sources(domain, monkeypatch):
    d = domain
    version, board = public_course(d)
    race(d, version, "Alice", frames=20)
    queries = []

    def capture(_connection, _cursor, sql, *_args):
        queries.append(sql)

    event.listen(d.app.state.engine, "before_cursor_execute", capture)
    try:
        slow = race(d, version, "Alice", frames=30)
    finally:
        event.remove(d.app.state.engine, "before_cursor_execute", capture)
    assert not any("UNION ALL" in sql and "lap_personal_bests.run_id" in sql for sql in queries)
    with d.factory() as session:
        assert session.get(CoinReward, slow["run_id"]).amount == 50
        assert session.get(PersonalBest, (board, d.players["Alice"])).time_ticks == 100
    original = d.app.state.verifier.verify_run

    def flying(*args, **kwargs):
        result = original(*args, **kwargs)
        result["lap_ticks"] = [50, 10, 20, 20, 20]
        return result

    monkeypatch.setattr(d.app.state.verifier, "verify_run", flying)
    newer = race(d, version, "Alice", frames=24)
    with d.factory() as session:
        assert session.get(LapPersonalBest, (board, d.players["Alice"])).run_id == newer["run_id"]
        assert any(item.details.get("metric") == "lap" and item.details.get("time_ticks") == 10
                   for item in session.scalars(select(NewsItem).where(NewsItem.board_id == board)))


def test_completion_is_opt_in_pending_is_cheap_and_reads_never_reaward(domain):
    d = domain
    version, _ = public_course(d)
    accepted = submit(d, ticket(d, version, "Alice"), "Alice")
    assert "completion" not in read(d, accepted["run_id"]).json()
    assert process_one(d.app)
    assert "completion" not in read(d, accepted["run_id"], completion=False).json()
    with d.factory() as session:
        wallet = session.get(CoinWallet, d.players["Alice"])
        before = wallet.balance, wallet.revision
    for _ in range(3):
        response = read(d, accepted["run_id"])
        assert response.status_code == 200
        value = response.json()["completion"]
        assert value["version"] == 1 and value["reward"]["status"] == "credited"
        assert (value["wallet"]["balance"], value["wallet"]["revision"]) == before
    with d.factory() as session:
        wallet = session.get(CoinWallet, d.players["Alice"])
        assert (wallet.balance, wallet.revision) == before
    assert read(d, accepted["run_id"], player="Bob").status_code == 404


def test_completion_batch_shares_wallet_and_matches_single_wait_and_recovery(domain):
    d = domain
    version, _ = public_course(d)
    values = [race(d, version, "Alice", frames=frames) for frames in (20, 30)]
    response = d.client.get("/v1/runs/status", params=[("completion", "true"), *[("ids", v["run_id"]) for v in values]],
                            headers=headers(d, "Alice"))
    assert response.status_code == 200
    batch = response.json()
    assert "completion_wallet" in batch and len(batch["items"]) == 2
    assert all("wallet" not in v["completion"] for v in batch["items"])
    for value in values:
        run_id = value["run_id"]
        expected = read(d, run_id).json()
        wait = d.client.get(f"/v1/runs/{run_id}/wait", params={"completion": True, "timeout_ms": 0}, headers=headers(d, "Alice"))
        recovery = d.client.get(f"/v1/run-tickets/{expected['ticket_id']}/submission", params={"completion": True}, headers=headers(d, "Alice"))
        assert wait.json()["completion"] == recovery.json()["run"]["completion"] == expected["completion"]
        assert expected["completion"]["wallet"] == batch["completion_wallet"]


def test_optional_receipt_failure_and_archival_do_not_hide_result(domain, monkeypatch):
    d = domain
    version, _ = public_course(d)
    value = race(d, version, "Alice")

    def fail(_connection, _cursor, sql, *_args):
        if "FROM coin_rewards" in sql:
            raise OperationalError("owned optional read failure", {}, Exception("fixture"))

    event.listen(d.app.state.engine, "before_cursor_execute", fail)
    try:
        response = read(d, value["run_id"])
    finally:
        event.remove(d.app.state.engine, "before_cursor_execute", fail)
    assert response.status_code == 200 and response.json()["status"] == "verified"
    assert "completion" not in response.json()
    with d.factory() as session:
        session.get(Run, value["run_id"]).reward_archive_hash = "a" * 64
        session.delete(session.get(CoinReward, value["run_id"]))
        session.commit()

    def forbidden(*_args):
        raise AssertionError("Completion must leave cold archive I/O to the independent fallback")

    monkeypatch.setattr(d.app.state.blobs, "get_json", forbidden)
    response = read(d, value["run_id"])
    assert response.status_code == 200 and response.json()["completion"]["reward"] is None


def test_missing_receipt_does_not_infer_unavailable_from_an_older_run_snapshot(domain):
    d = domain
    version, _ = public_course(d)
    value = race(d, version, "Alice")
    # Model the mixed view possible when archival commits between the run and
    # receipt reads: no hot receipt, while the observed run has no archive hint.
    with d.factory() as session:
        assert session.get(Run, value["run_id"]).reward_archive_hash is None
        session.delete(session.get(CoinReward, value["run_id"]))
        session.commit()
    response = read(d, value["run_id"])
    assert response.status_code == 200 and response.json()["status"] == "verified"
    assert response.json()["completion"]["reward"] is None


def test_compact_pending_retains_authority_budgets_and_full_terminal(domain):
    d = domain
    _challenge, issued, _ = queued_challenge(d)
    path = f"/v1/challenge-results/{issued['ticket_id']}"
    full = d.client.get(path, headers=headers(d, "Bob"))
    slim = d.client.get(path, params={"compact": True}, headers=headers(d, "Bob"))
    assert full.status_code == slim.status_code == 200
    assert "challenge" in full.json() and "challenge" not in slim.json()
    pending = slim.json()["challenge_pending"]
    assert pending["attempts_used"] == 1 and pending["attempts_remaining"] == 2
    assert len(slim.content) < len(full.content)
    with d.factory() as session:
        block = PlayerBlock(player_id=d.players["Bob"], blocked_id=d.players["Alice"])
        session.add(block)
        session.commit()
    assert d.client.get(path, params={"compact": True}, headers=headers(d, "Bob")).status_code == 403
    with d.factory() as session:
        session.delete(session.get(PlayerBlock, (d.players["Bob"], d.players["Alice"])))
        session.commit()
    assert process_one(d.app)
    terminal = d.client.get(path, params={"compact": True}, headers=headers(d, "Bob"))
    assert terminal.json()["status"] == "verified" and "challenge" in terminal.json()


def test_terminal_challenge_enrichment_obeys_blocks_without_hiding_run(domain):
    d = domain
    challenge, _issued, queued = queued_challenge(d)
    assert process_one(d.app)
    response = read(d, queued["run_id"], player="Bob")
    extra = response.json()["completion"]
    assert extra["challenge_result"]["challenge"]["code"] == challenge["code"]
    assert extra["challenge_result"]["outcome"]["counted"]
    with d.factory() as session:
        session.add(PlayerBlock(player_id=d.players["Bob"], blocked_id=d.players["Alice"]))
        session.commit()
    response = read(d, queued["run_id"], player="Bob")
    assert response.status_code == 200 and response.json()["status"] == "verified"
    assert "challenge_result" not in response.json()["completion"]
    assert response.json()["completion"]["reward"]["status"] == "credited"


def test_series_compact_tracks_and_changed_visibility_are_current(domain):
    d = domain
    versions = seed(d, 3)
    response = create_series(d, versions)
    assert response.status_code == 201
    challenge = response.json()
    join(d, challenge["code"])
    issued = d.client.post(f"/v1/challenges/{challenge['code']}/tickets?stage=2", headers=headers(d, "Bob"))
    assert issued.status_code == 201
    path = f"/v1/challenge-results/{issued.json()['ticket_id']}"
    pending = d.client.get(path, params={"compact": True}, headers=headers(d, "Bob")).json()["challenge_pending"]
    assert pending["attempts_used"] == 1 and pending["attempts_remaining"] == 8
    assert next(row for row in pending["stages"] if row["index"] == 2)["attempts_remaining"] == 2
    with d.factory() as session:
        version = session.get(TrackVersion, versions[1])
        from bmt_backend.track_models import Track
        session.get(Track, version.track_id).hidden = True
        session.commit()
    assert d.client.get(path, params={"compact": True}, headers=headers(d, "Bob")).status_code == 404


def test_compact_pending_retains_midnight_expiry_and_cancellation(domain, monkeypatch):
    from bmt_backend import challenges
    from bmt_backend.challenge_models import Challenge
    d = domain
    value, issued, _run = queued_challenge(d)
    stamp = challenges.now()
    with d.factory() as session:
        session.add(CoinMilestone(player_id=d.players["Bob"], scope="challenge/day/" + str(stamp // 86400), value=3))
        session.commit()
    path = f"/v1/challenge-results/{issued['ticket_id']}?compact=true"
    def pending():
        response = d.client.get(path, headers=headers(d, "Bob"))
        assert response.status_code == 200
        return response.json()["challenge_pending"]
    assert pending()["rewards"]["remaining_today"] == 0
    monkeypatch.setattr(challenges, "now", lambda: (stamp // 86400 + 1) * 86400)
    assert pending()["rewards"]["remaining_today"] == 3
    with d.factory() as session:
        session.get(Challenge, value["id"]).cancelled = True
        session.commit()
    assert pending()["state"] == "cancelled"
    with d.factory() as session:
        challenge = session.get(Challenge, value["id"])
        challenge.cancelled = False
        end = challenge.ends_at
        session.commit()
    monkeypatch.setattr(challenges, "now", lambda: end + 1)
    expired = pending()
    assert expired["state"] == "settling" and expired["remaining_seconds"] == 0
