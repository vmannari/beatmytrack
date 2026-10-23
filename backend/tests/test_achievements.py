"""Lifetime progression through real transactions, bounded reads and final standings."""
# ruff: noqa: F811
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest
from sqlalchemy import event, func, select
from test_domains import domain, headers, publish, race, submit, ticket, upload  # noqa: F401

from bmt_backend.achievement_models import (
    AchievementCohort,
    AchievementCompetition,
    AchievementCount,
    AchievementFact,
    AchievementRecord,
    AchievementState,
)
from bmt_backend.achievements import CATALOG, consistent, erase_private, process_due, save, state
from bmt_backend.economy import accept_verified, previous_bests
from bmt_backend.identity_models import Player
from bmt_backend.news_models import Friendship
from bmt_backend.track_models import Board, PersonalBest, Run, TrackVersion, now
from bmt_backend.worker import process_one


def collection(d, who="Alice"):
    result = d.client.get("/v1/achievements", headers=headers(d, who))
    assert result.status_code == 200, result.text
    return result.json()


def course(d):
    version = upload(d)
    race(d, version, frames=100)
    publish(d, version)
    with d.factory() as session:
        row = session.get(TrackVersion, version["version_id"])
        row.discovery = {**(row.discovery or {}), "theme": "pine"}
        session.commit()
    return version


def test_catalog_matches_and_precision_has_exact_boundary():
    client = Path(__file__).resolve().parents[2] / "game/persistence/achievement_catalog.json"
    assert json.loads(client.read_text(encoding="utf-8")) == CATALOG
    export = client.parents[1] / "export_presets.cfg"
    assert "persistence/achievement_catalog.json" in export.read_text(encoding="utf-8")
    assert len(CATALOG["families"]) == 40
    assert sum(len(f["tiers"]) for f in CATALOG["families"]) == 130
    assert sum(f["prestige"] for f in CATALOG["families"]) == 10
    assert consistent([98, 100, 100, 100, 102], 2)
    assert not consistent([97, 100, 100, 100, 103], 2)
    assert consistent([99, 100, 100, 100, 101], 1)
    assert not consistent([0, 100, 100, 100, 100], 2)
    assert not consistent([100] * 4, 2)


def test_explicit_reads_are_private_and_do_not_write_or_read_race_history(domain):
    assert collection(domain)["states"] == {}
    statements = []
    def record(_conn, _cursor, statement, _parameters, _context, _many):
        statements.append(statement.lower())
    event.listen(domain.app.state.engine, "before_cursor_execute", record)
    try:
        first = collection(domain)
        assert collection(domain) == first
    finally:
        event.remove(domain.app.state.engine, "before_cursor_execute", record)
    relevant = [sql for sql in statements if "achievement_" in sql]
    assert len(relevant) == 4  # 2 bounded SELECTs per entry.
    assert all(sql.lstrip().startswith("select") for sql in relevant)
    assert not any(" runs " in sql or " personal_bests " in sql for sql in relevant)
    assert first["rarity"]["eligible"] == 0 and first["rarity"]["unlocks"] == {}
    assert domain.client.get("/v1/achievements").status_code == 401
    assert domain.client.post("/v1/achievements", json={"races": 9999}, headers=headers(domain)).status_code == 405


def test_idle_worker_checks_at_most_once_a_minute_when_empty(domain, monkeypatch):
    from bmt_backend.achievements import drive_idle
    stamp = [100.0]
    monkeypatch.setattr("bmt_backend.achievements.time.monotonic", lambda: stamp[0])
    statements = []
    def record(_conn, _cursor, statement, _parameters, _context, _many):
        if "achievement_" in statement:
            statements.append(statement)
    event.listen(domain.app.state.engine, "before_cursor_execute", record)
    try:
        assert not drive_idle(domain.app)
        for _ in range(100):
            assert not drive_idle(domain.app)
        assert len(statements) == 3
        stamp[0] += 60
        assert not drive_idle(domain.app)
        assert len(statements) == 6
    finally:
        event.remove(domain.app.state.engine, "before_cursor_execute", record)


def test_race_pending_rejected_retries_and_existing_pb_semantics(domain):
    version = course(domain)
    issued = ticket(domain, version, "Alice")
    submit(domain, issued, "Alice", frames=50)
    assert collection(domain)["states"] == {}
    assert process_one(domain.app)
    first = collection(domain)["states"]["race"]
    assert first["metrics"]["races"] == 1
    assert first["metrics"]["tracks"] == 1
    assert first["metrics"]["distance_m"] == 1100
    assert first["metrics"].get("race_pb", 0) == 0
    assert first["metrics"].get("clean", 0) == 0
    assert first["metrics"]["precision"] == 1
    race(domain, version, "Alice", frames=40)
    improved = collection(domain)["states"]["race"]["metrics"]
    assert improved["races"] == 2 and improved["race_pb"] == 1 and improved["lap_pb"] == 1
    assert improved["pb_streak"] == 1 and improved["tracks"] == 1
    race(domain, version, "Alice", frames=40)
    final = collection(domain)["states"]["race"]
    assert final["metrics"]["pb_streak"] == 0 and final["metrics"]["race_pb"] == 1
    with domain.factory() as session:
        accepted = session.scalar(select(Run).where(Run.player_id == domain.players["Alice"]).limit(1))
        accept_verified(session, accepted, previous_bests(session, accepted), incident_free=True)
        session.commit()
    assert collection(domain)["states"]["race"] == final
    issued = ticket(domain, version, "Alice")
    submit(domain, issued, "Alice", steering=-127)
    assert process_one(domain.app)
    assert collection(domain)["states"]["race"] == final
    assert "race" not in collection(domain, "Bob")["states"]


def test_clean_tiers_seasons_and_permanent_streak_unlocks(domain, monkeypatch):
    version = course(domain)
    original = domain.app.state.verifier.verify_run
    clean = [True]
    def verified(*args, **kwargs):
        return {**original(*args, **kwargs), "incident_free": clean[0]}
    monkeypatch.setattr(domain.app.state.verifier, "verify_run", verified)
    for index in range(10):
        with domain.factory() as session:
            row = session.get(TrackVersion, version["version_id"])
            row.discovery = {**row.discovery, "theme": ("pine", "desert", "winter", "storm", "night_city")[index % 5]}
            session.commit()
        race(domain, version, "Alice", frames=50-index)
    result = collection(domain)["states"]["race"]
    for key in ("races/1", "clean/1", "untouchable/1", "perfectionist/1", "seasons/1", "pb_streak/1", "pb_streak/2"):
        assert key in result["unlocked"]
    assert result["metrics"]["clean_streak_best"] == 10 and result["metrics"]["clean_biomes"] == 5
    clean[0] = False
    race(domain, version, "Alice", frames=100)
    after = collection(domain)["states"]["race"]
    assert after["metrics"]["clean_streak"] == 0
    assert after["unlocked"] == result["unlocked"]


def test_creator_completion_and_unique_reach_exclude_owner_and_repeat_racers(domain):
    version = course(domain)
    creator = collection(domain, "Creator")["states"]["creator"]
    assert creator["metrics"]["publications"] == 1 and "publications/1" in creator["unlocked"]
    race(domain, version, "Alice", frames=50)
    race(domain, version, "Alice", frames=60)
    race(domain, version, "Bob", frames=50)
    before = collection(domain, "Creator")["states"]["creator"]["metrics"]
    assert before["creator_plays"] == 3 and before["creator_reach"] == 2
    race(domain, version, "Creator", frames=30)
    assert collection(domain, "Creator")["states"]["creator"]["metrics"] == before
    assert "creator" not in collection(domain)["states"]


def test_distinct_friend_overtakes_require_an_established_record(domain):
    version = course(domain)
    with domain.factory() as session:
        a, b = sorted((domain.players["Alice"], domain.players["Bob"]))
        session.add(Friendship(low_id=a, high_id=b, requested_by=a, accepted=True))
        session.commit()
    race(domain, version, "Bob", frames=50)
    race(domain, version, "Alice", frames=70)
    race(domain, version, "Alice", frames=40)
    assert collection(domain)["states"]["race"]["metrics"]["friends"] == 1
    race(domain, version, "Bob", frames=30)
    race(domain, version, "Alice", frames=20)
    assert collection(domain)["states"]["race"]["metrics"]["friends"] == 1


def test_featured_limit_locked_validation_and_account_scoping(domain):
    version = course(domain)
    race(domain, version, "Alice")
    url = "/v1/achievements/featured"
    assert domain.client.put(url, json={"families": ["races"]}, headers=headers(domain, "Alice")).status_code == 409
    for ids in (["fake"], ["fleet", "fleet"], ["washes"]):
        assert domain.client.put(url, json={"families": ids}, headers=headers(domain, "Alice")).status_code == 422
    assert domain.client.put(url, json={"families": ["fleet"] * 6}, headers=headers(domain, "Alice")).status_code == 422
    good = domain.client.put(url, json={"families": ["fleet", "biomes"]}, headers=headers(domain, "Alice"))
    assert good.status_code == 200 and good.json()["featured"] == ["fleet", "biomes"]
    assert collection(domain)["states"]["race"]["featured"] == ["fleet", "biomes"]
    assert "race" not in collection(domain, "Bob")["states"]
    assert domain.client.put(url, json={"families": ["fleet"], "metrics": {}}, headers=headers(domain, "Alice")).status_code == 422


def test_real_rarity_minimum_and_erasure_are_exact_and_idempotent(domain):
    with domain.factory() as session:
        for index in range(100):
            p = Player(display_name="Eligible"+str(index))
            session.add(p)
            session.flush()
            save(session, state(session, p.id, "race"), {"races": 10 if index == 0 else 1}, now())
        session.commit()
    while process_due(domain.app):
        pass
    result = collection(domain)
    assert result["rarity"]["eligible"] == 100 and result["rarity"]["unlocks"]["races/1"] == 1
    with domain.factory() as session:
        pid = next(row.player_id for row in session.scalars(select(AchievementState)) if "races/1" in row.unlocked)
        erase_private(session, pid)
        erase_private(session, pid)
        session.commit()
        assert session.scalar(select(func.sum(AchievementCount.value)).where(AchievementCount.key == "races/1")) == 0
        assert session.get(AchievementCohort, pid) is None
        assert session.scalar(select(func.count()).select_from(AchievementFact).where(AchievementFact.player_id == pid)) == 0
    assert collection(domain)["rarity"]["eligible"] == 99
    assert collection(domain)["rarity"]["unlocks"] == {}


@pytest.mark.parametrize("participants,tie", [(5, False), (4, False), (5, True)])
def test_finalized_rivalry_participation_pending_runs_ties_and_once(domain, participants, tie):
    from test_rivalry import add_finishes, seed

    from bmt_backend.achievements import schedule
    from bmt_backend.rivalry_models import RivalryBest, RivalryGroup, RivalryMember, RivalryTicket
    from bmt_backend.track_models import RunTicket
    version_id = seed(domain, 1)[0]
    players = add_finishes(domain, version_id, participants)
    stamp = now()
    with domain.factory() as session:
        version = session.get(TrackVersion, version_id)
        board = session.scalar(select(Board).where(Board.version_id == version_id))
        group = RivalryGroup(week_start=stamp-604800, ends_at=stamp-1, vehicle_id="compact", contract_key="test",
            skill_band=0, member_count=participants, tracks=[{"tick_rate":120, "version_id":version.id, "board_id":board.id, "entry":{}}]*5)
        session.add(group)
        session.flush()
        for i, pid in enumerate(players):
            session.add(RivalryMember(group_id=group.id, player_id=pid, week_start=group.week_start, contract_key="test"))
            run = session.scalar(select(Run).where(Run.player_id == pid))
            session.add(RivalryBest(group_id=group.id, player_id=pid, slot=0, run_id=run.id,
                time_ticks=100 if tie and i == 1 else 100+i))
        schedule(session, "rivalry", group.id, stamp-1, {players[0]: True})
        issued = RunTicket(player_id=players[0], board_id=board.id, expires_at=stamp)
        session.add(issued)
        session.flush()
        pending = Run(ticket_id=issued.id, player_id=players[0], board_id=board.id, replay_hash="0"*64, status="queued")
        session.add(pending)
        session.add(RivalryTicket(ticket_id=issued.id, group_id=group.id, slot=1))
        session.commit()
        group_id, pending_id = group.id, pending.id
    assert process_due(domain.app, clock=stamp)
    with domain.factory() as session:
        assert session.get(AchievementState, (players[0], "race")) is None
        session.get(Run, pending_id).status = "rejected"
        session.commit()
    assert process_due(domain.app, clock=stamp+61)
    with domain.factory() as session:
        winner = session.get(AchievementState, (players[0], "race"))
        if participants >= 5 and not tie:
            assert winner.metrics["rivalry_wins"] == 1 and winner.metrics["comeback"] == 1
            assert {"king/1", "comeback/1"}.issubset(winner.unlocked)
        else:
            assert winner is None or (winner.metrics.get("rivalry_wins",0) == 0 and "king/1" not in winner.unlocked)
        assert session.get(AchievementCompetition, ("rivalry", group_id)).done
        last = session.get(AchievementState, (players[-1], "race"))
        assert last is None or last.metrics.get("rivalry_podiums",0) == 0
    for _ in range(10):
        process_due(domain.app, clock=stamp+62)
    with domain.factory() as session:
        winner = session.get(AchievementState, (players[0], "race"))
        assert (winner.metrics.get("rivalry_wins",0) if winner else 0) == int(participants >= 5 and not tie)


def test_record_continuity_requires_real_population_and_loses_on_tie(domain):
    from test_rivalry import add_finishes, seed

    from bmt_backend.achievements import observe_record
    version_id = seed(domain, 1)[0]
    players = add_finishes(domain, version_id, 10)
    stamp = now()
    with domain.factory() as session:
        board = session.scalar(select(Board).where(Board.version_id == version_id))
        observe_record(session, board.id, stamp)
        session.commit()
        board_id = board.id
        assert session.get(AchievementRecord, board.id).since == stamp
        pb = session.get(PersonalBest, (board_id, players[0]))
        pb.time_ticks -= 1
        session.flush()
        observe_record(session, board_id, stamp+100)
        session.commit()
        assert session.get(AchievementRecord, board_id).since == stamp
    assert not process_due(domain.app, clock=stamp+30*86400-1)
    assert process_due(domain.app, clock=stamp+30*86400)
    with domain.factory() as session:
        assert "unbeaten/1" in session.get(AchievementState,(players[0],"race")).unlocked
        session.get(PersonalBest,(board_id,players[1])).time_ticks = 99
        session.flush()
        observe_record(session,board_id,stamp+30*86400+1)
        session.commit()
        assert session.get(AchievementRecord, board_id) is None


def test_parallel_cross_creator_projections_and_rarity_coalescing(domain):
    if domain.app.state.engine.dialect.name != "postgresql":
        pytest.skip("Real row-lock concurrency requires isolated PostgreSQL")
    alice, bob = domain.players["Alice"], domain.players["Bob"]
    def update_pair(own, creator):
        for _ in range(8):
            with domain.factory() as session:
                row = state(session, own, "race")
                save(session, row, {"races": row.metrics.get("races",0)+1}, now())
                row = state(session, creator, "creator")
                save(session, row, {"creator_plays": row.metrics.get("creator_plays",0)+1}, now())
                session.commit()
    with ThreadPoolExecutor(max_workers=2) as pool:
        jobs = [pool.submit(update_pair, alice, bob), pool.submit(update_pair, bob, alice)]
        for job in jobs:
            job.result(timeout=25)
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(AchievementCount)) == 0
        for pid in (alice, bob):
            assert session.get(AchievementState,(pid,"race")).metrics["races"] == 8
            assert session.get(AchievementState,(pid,"creator")).metrics["creator_plays"] == 8
    def project():
        for _ in range(8):
            if not process_due(domain.app):
                break
    with ThreadPoolExecutor(max_workers=2) as pool:
        for job in [pool.submit(project),pool.submit(project)]:
            job.result(timeout=25)
    assert collection(domain)["rarity"]["eligible"] == 2
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(AchievementState)
            .where(AchievementState.rarity_pending.is_(True))) == 0


def test_challenge_wins_wait_for_final_standings_and_underdog_uses_prior_pb(domain):
    from test_challenges import attempt, create, join, normal_run, setup

    from bmt_backend.challenge_models import Challenge
    version = setup(domain)
    normal_run(domain, version, "Alice", frames=30)
    normal_run(domain, version, "Bob", frames=50)
    contest = create(domain, version, "Alice")
    join(domain, contest["code"], "Bob")
    attempt(domain, contest["code"], "Bob", frames=20)
    result = collection(domain, "Bob")["states"]["race"]
    assert result["metrics"]["odds"] == 1 and "odds/1" in result["unlocked"]
    assert result["metrics"].get("challenge_wins", 0) == 0
    with domain.factory() as session:
        challenge = session.get(Challenge, contest["id"])
        end = challenge.ends_at
    for _ in range(8):
        process_due(domain.app, clock=end)
    result = collection(domain, "Bob")["states"]["race"]
    assert result["metrics"]["challenge_wins"] == 1 and "challenge_wins/1" in result["unlocked"]
    for _ in range(5):
        process_due(domain.app, clock=end+1)
    assert collection(domain, "Bob")["states"]["race"]["metrics"]["challenge_wins"] == 1
