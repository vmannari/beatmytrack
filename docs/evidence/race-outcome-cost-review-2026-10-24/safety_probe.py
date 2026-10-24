"""Counterexamples for proposed optimisations; disposable SQLite fixtures only."""
from __future__ import annotations

import json
import logging
import sys
import tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "backend/tests")]
logging.disable(logging.CRITICAL)

from bmt_backend import rivalry
from bmt_backend.challenge_models import ChallengeMember
from bmt_backend.community_models import PlayerBlock
from bmt_backend.economy_models import CoinReward
from bmt_backend.identity_models import Player
from bmt_backend.track_models import LapPersonalBest, PersonalBest, Run
from bmt_backend.worker import process_one
from sqlalchemy import event
from test_challenge_series import create as create_series
from test_challenge_series import race as race_stage
from test_challenges import PosedVerifier, create, join, normal_run
from test_domains import domain, headers, submit
from test_rivalry import join as join_rivalry
from test_rivalry import rivalry_ticket, seed


def week_and_eligibility(d):
    versions = seed(d)
    group = join_rivalry(d)["group_id"]
    join_rivalry(d, "Bob")
    first = rivalry_ticket(d, group)
    # A lifetime PB outside Rivalry is faster than the first weekly result.
    normal_run(d, first["version_id"], frames=10)
    weekly = submit(d, first, "Alice", frames=20)
    assert process_one(d.app)
    value = d.client.get(f"/v1/rivalry/tickets/{first['ticket_id']}/result", headers=headers(d, "Alice")).json()
    assert value["outcome"]["personal_best"] is False
    assert value["outcome"]["improved"] is True
    first_week = {key: value["outcome"][key] for key in ("personal_best", "improved", "points_delta")}

    bob = rivalry_ticket(d, group, "Bob")
    submit(d, bob, "Bob", frames=18)
    assert process_one(d.app)
    slower = rivalry_ticket(d, group)
    submit(d, slower, "Alice", frames=40)
    original = rivalry.standings_data
    calls = 0

    def interpose_visibility(session, current_group):
        nonlocal calls
        result = original(session, current_group)
        calls += 1
        if calls == 1:
            # Deterministically model a visibility change between reads.
            # This is not a PostgreSQL multi-connection concurrency test.
            session.get(Player, d.players["Bob"]).disabled = True
            session.flush()
        return result

    with patch.object(rivalry, "standings_data", interpose_visibility):
        assert process_one(d.app)
    outcome = d.client.get(f"/v1/rivalry/tickets/{slower['ticket_id']}/result", headers=headers(d, "Alice")).json()["outcome"]
    assert not outcome["improved"] and outcome["before"]["rank"] != outcome["after"]["rank"]
    with d.factory() as session:
        session.get(Player, d.players["Bob"]).disabled = False
        session.commit()
    return versions, {"first_weekly_without_lifetime_pb": first_week,
        "eligibility_change_between_reads": {"improved": outcome["improved"],
            "before_rank": outcome["before"]["rank"], "after_rank": outcome["after"]["rank"],
            "points_delta": outcome["points_delta"],
            "limit": "Injected state change in one fixture transaction, not a concurrent PostgreSQL run"},
        "weekly_run_id": weekly["run_id"]}


def lap_and_ghost(d, version):
    normal_run(d, version, "Carol", frames=20)
    original = d.app.state.verifier.verify_run

    def different_laps(*args, **kwargs):
        result = original(*args, **kwargs)
        assert result["time_ticks"] == 120
        result["lap_ticks"] = [50, 10, 20, 20, 20]
        return result

    with patch.object(d.app.state.verifier, "verify_run", different_laps):
        latest = normal_run(d, version, "Carol", frames=24)
    with d.factory() as session:
        run = session.get(Run, latest)
        race = session.get(PersonalBest, (run.board_id, run.player_id))
        lap = session.get(LapPersonalBest, (run.board_id, run.player_id))
        reward = session.get(CoinReward, run.id)
        rows = reward.rows
        assert race.time_ticks == 100 and run.time_ticks == 120 and lap.time_ticks == 10
        assert any(row["title"] == "New lap PB" for row in rows)
    challenge = create(d, version, player="Carol", run_id=latest)
    path = f"/v1/challenges/{challenge['code']}/ghost"
    before = d.client.get(path, headers=headers(d, "Carol"))
    with d.factory() as session:
        run = session.get(Run, latest)
        saved_hash = run.ghost_hash
        run.ghost_hash = None
        session.commit()
    try:
        after = d.client.get(path, headers=headers(d, "Carol"))
        assert before.status_code == 200 and after.status_code == 404
    finally:
        with d.factory() as session:
            session.get(Run, latest).ghost_hash = saved_hash
            session.commit()
    return {"slower_race_lap_pb": {"race_pb_ticks": race.time_ticks, "attempt_ticks": 120,
            "flying_lap_pb_ticks": 10, "lap_pb_reward_present": True},
        "ghost_reader_requires_separate_hash": {"before_status": before.status_code,
            "without_ghost_hash_status": after.status_code}}


def pending_authority(d, version):
    normal_run(d, version)
    challenge = create(d, version)
    join(d, challenge["code"])
    issued = d.client.post(f"/v1/challenges/{challenge['code']}/tickets", headers=headers(d, "Bob"))
    assert issued.status_code == 201
    submit(d, issued.json(), "Bob", frames=30)
    path = f"/v1/challenge-results/{issued.json()['ticket_id']}"
    before = d.client.get(path, headers=headers(d, "Bob"))
    with d.factory() as session:
        session.add(PlayerBlock(player_id=d.players["Bob"], blocked_id=d.players["Alice"]))
        session.commit()
    after = d.client.get(path, headers=headers(d, "Bob"))
    assert before.status_code == 200 and after.status_code == 403
    return {"pending_block_check": {"before_status": before.status_code, "after_block_status": after.status_code}}


def series_reference(d, versions):
    response = create_series(d, versions[:3])
    assert response.status_code == 201, response.text
    challenge = response.json()
    join(d, challenge["code"])
    for index in range(3):
        race_stage(d, challenge["code"], index, frames=20 + index)
    with d.factory() as session:
        member = session.get(ChallengeMember, (challenge["id"], d.players["Bob"]))
        previous = member.run_id
        total = member.time_ticks
    issued = d.client.post(f"/v1/challenges/{challenge['code']}/tickets?stage=0", headers=headers(d, "Bob"))
    assert issued.status_code == 201
    submitted = submit(d, issued.json(), "Bob", frames=40)
    statements = []

    def capture(_connection, _cursor, sql, *_args):
        if sql.lstrip().upper().startswith("UPDATE CHALLENGE_MEMBERS "):
            statements.append(sql)

    event.listen(d.app.state.engine, "before_cursor_execute", capture)
    try:
        assert process_one(d.app)
    finally:
        event.remove(d.app.state.engine, "before_cursor_execute", capture)
    with d.factory() as session:
        member = session.get(ChallengeMember, (challenge["id"], d.players["Bob"]))
        assert member.time_ticks == total == 315
        assert member.run_id != previous and member.run_id == submitted["run_id"]
    assert statements and all("time_ticks" not in sql for sql in statements)
    return {"series_slower_attempt": {"total_ticks_unchanged": total,
        "representative_run_changed": True, "member_update_sql": statements,
        "aggregate_time_column_written": False}}


def main():
    results = {}
    for name, callback in (("rivalry", week_and_eligibility), ("lap_and_ghost", lap_and_ghost),
            ("pending_authority", pending_authority), ("series_reference", series_reference)):
        with tempfile.TemporaryDirectory(prefix="bmt-safety-review-") as folder:
            fixture = domain.__wrapped__(Path(folder), SimpleNamespace(param="sqlite"))
            d = next(fixture)
            d.app.state.verifier = PosedVerifier()
            try:
                if name == "rivalry":
                    _, value = callback(d)
                else:
                    versions = seed(d, 3)
                    value = callback(d, versions if name == "series_reference" else versions[0])
                results.update(value)
            finally:
                fixture.close()
    results["limits"] = ["Disposable SQLite and controlled verifier fixtures only",
        "No implementation or production concurrency certification", "No device checks, tests or deployment"]
    Path(__file__).with_name("safety-probe-results.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
