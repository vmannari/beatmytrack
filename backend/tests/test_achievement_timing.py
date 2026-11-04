"""BAT01-BAT03: committed race grants and event-driven background wakeups."""
# ruff: noqa: F811 - pytest injects the imported parametrized fixture.
import time
from types import SimpleNamespace

import pytest
from sqlalchemy import select
from test_achievements import collection, course
from test_domains import domain, race, submit, ticket  # noqa: F401

from bmt_backend.achievement_models import AchievementState, CreatorAchievementEvent
from bmt_backend.achievements import drive_idle, process_due, save, state
from bmt_backend.creator_achievements import enqueue
from bmt_backend.track_models import Run, TrackVersion
from bmt_backend.worker import process_one


def desert_course(d):
    version = course(d)
    with d.factory() as session:
        row = session.get(TrackVersion, version["version_id"])
        row.discovery = {**row.discovery, "theme": "desert"}
        session.commit()
    return version


def test_race_and_biome_unlocks_are_readable_at_verification_commit(domain, monkeypatch):
    version = desert_course(domain)
    with domain.factory() as session:
        save(session, state(session, domain.players["Alice"], "race"),
             {"races": 9, "race_desert": 9}, 100)
        session.commit()
    before = collection(domain)["states"]["race"]
    domain.app.state.achievement_check_after = float("inf")

    def forbid_background(*_args, **_kwargs):
        raise AssertionError("Race awards must not depend on background projection")

    monkeypatch.setattr("bmt_backend.achievements.process_due", forbid_background)
    issued = ticket(domain, version, "Alice")
    submitted = submit(domain, issued, "Alice", frames=50)
    assert collection(domain)["states"]["race"] == before
    assert process_one(domain.app)
    completed = domain.client.get("/v1/runs/" + submitted["run_id"],
                                  headers={"x-test-player": domain.players["Alice"]}).json()
    assert completed["status"] == "verified"
    after = collection(domain)["states"]["race"]
    assert after["metrics"]["races"] == after["metrics"]["race_desert"] == 10
    assert {"races/1", "race_desert/1"} <= after["unlocked"].keys()
    assert after["unlocked"]["race_desert/1"] == completed["finished_at"]
    assert collection(domain)["states"]["race"] == after
    race(domain, version, "Alice", frames=45)
    final = collection(domain)["states"]["race"]
    assert final["metrics"]["race_desert"] == 11
    assert final["unlocked"]["race_desert/1"] == after["unlocked"]["race_desert/1"]


def test_failed_finalization_never_exposes_grants_ahead_of_run_commit(domain, monkeypatch):
    version = desert_course(domain)
    with domain.factory() as session:
        save(session, state(session, domain.players["Alice"], "race"), {"race_desert": 9}, 100)
        session.commit()
    before = collection(domain)["states"]["race"]
    submitted = submit(domain, ticket(domain, version, "Alice"), "Alice", frames=50)
    original = save
    generation = domain.app.state.run_signals.work_generation

    def fail_after_grant(*args, **kwargs):
        original(*args, **kwargs)
        raise RuntimeError("injected achievement transaction failure")

    monkeypatch.setattr("bmt_backend.achievements.save", fail_after_grant)
    with pytest.raises(RuntimeError, match="injected achievement transaction failure"):
        process_one(domain.app)
    assert collection(domain)["states"]["race"] == before
    assert domain.app.state.run_signals.work_generation == generation
    with domain.factory() as session:
        assert session.get(Run, submitted["run_id"]).status == "verifying"
    monkeypatch.setattr("bmt_backend.achievements.save", original)
    assert process_one(domain.app)
    after = collection(domain)["states"]["race"]
    assert after["metrics"]["race_desert"] == 10
    assert "race_desert/1" in after["unlocked"]


def test_new_creator_work_bypasses_empty_idle_backoff_only_after_commit(domain, monkeypatch):
    owner = domain.players["Creator"]
    with domain.factory() as session:
        save(session, state(session, owner, "creator"), {"creator_plays": 99}, 100)
        session.commit()
    while process_due(domain.app):
        pass
    monotonic = [100.0]
    monkeypatch.setattr("bmt_backend.achievements.time.monotonic", lambda: monotonic[0])
    assert not drive_idle(domain.app)
    assert domain.app.state.achievement_check_after == 160.0
    effect = SimpleNamespace(id="timing-effect", finished_at=200)
    with domain.factory() as session:
        enqueue(session, effect, owner)
        session.rollback()
    monotonic[0] += 1
    assert not drive_idle(domain.app)
    assert domain.app.state.achievement_check_after == 160.0
    with domain.factory() as session:
        enqueue(session, effect, owner)
        session.commit()
    # No 60-second time jump or force=True: ordinary worker handling must see
    # the committed event despite its previous empty-queue cooldown.
    for _ in range(4):
        drive_idle(domain.app)
        monotonic[0] += 1
    after = collection(domain, "Creator")["states"]["creator"]
    assert after["metrics"]["creator_plays"] == 100
    assert "creator_plays/1" in after["unlocked"]
    with domain.factory() as session:
        assert session.get(CreatorAchievementEvent, effect.id) is None
    revision = after["revision"]
    for _ in range(4):
        drive_idle(domain.app)
        monotonic[0] += 1
    assert collection(domain, "Creator")["states"]["creator"]["revision"] == revision


def test_new_publication_rarity_work_bypasses_empty_backoff(domain, monkeypatch):
    from bmt_backend.achievement_models import AchievementCount

    monotonic = [100.0]
    monkeypatch.setattr("bmt_backend.achievements.time.monotonic", lambda: monotonic[0])
    assert not drive_idle(domain.app)
    with domain.factory() as session:
        save(session, state(session, domain.players["Creator"], "creator"), {"publications": 1}, 200)
        session.commit()
    monotonic[0] += 1
    assert drive_idle(domain.app)
    with domain.factory() as session:
        assert not session.get(AchievementState, (domain.players["Creator"], "creator")).rarity_pending
        assert session.scalar(select(AchievementCount.value).where(
            AchievementCount.key == "publications/1")) == 1


def test_cross_process_hint_wakes_creator_work_after_idle_scan(domain):
    if not domain.postgres:
        pytest.skip("Independent PostgreSQL LISTEN/NOTIFY required")
    from bmt_backend.run_signals import RunSignals

    owner = domain.players["Creator"]
    with domain.factory() as session:
        save(session, state(session, owner, "creator"), {"creator_plays": 99}, 100)
        session.commit()
    while process_due(domain.app):
        pass
    listener = RunSignals(domain.app.state.engine)
    worker = SimpleNamespace(state=SimpleNamespace(session_factory=domain.factory, run_signals=listener))
    listener.open()
    try:
        listener.set_idle(True)
        deadline = time.monotonic() + 5
        while not listener.listening and time.monotonic() < deadline:
            time.sleep(0.01)
        assert listener.listening
        assert not drive_idle(worker)
        generation = listener.work_generation
        with domain.factory() as session:
            enqueue(session, SimpleNamespace(id="cross-process-effect", finished_at=200), owner)
            session.commit()
        deadline = time.monotonic() + 5
        while listener.work_generation == generation and time.monotonic() < deadline:
            time.sleep(0.01)
        assert listener.work_generation > generation
        listener.begin_scan()  # Real worker clears its wake event before scanning.
        assert drive_idle(worker)
        after = collection(domain, "Creator")["states"]["creator"]
        assert after["metrics"]["creator_plays"] == 100
    finally:
        listener.close()


def test_lost_hint_retains_durable_fallback(domain, monkeypatch):
    owner = domain.players["Creator"]
    with domain.factory() as session:
        save(session, state(session, owner, "creator"), {"creator_plays": 99}, 100)
        session.commit()
    while process_due(domain.app):
        pass
    monotonic = [100.0]
    monkeypatch.setattr("bmt_backend.achievements.time.monotonic", lambda: monotonic[0])
    assert not drive_idle(domain.app)
    monkeypatch.setattr(domain.app.state.run_signals, "publish", lambda *_args: None)
    with domain.factory() as session:
        enqueue(session, SimpleNamespace(id="lost-hint-effect", finished_at=200), owner)
        session.commit()
    monotonic[0] = 101
    assert not drive_idle(domain.app)
    monotonic[0] = 161
    assert drive_idle(domain.app)
    assert collection(domain, "Creator")["states"]["creator"]["metrics"]["creator_plays"] == 100


def test_skipped_non_improving_races_are_excluded_rather_than_deferred(domain):
    from test_non_improving_runs import prepared, submit_hint

    version, _ = prepared(domain)
    before = collection(domain)["states"]["race"]
    response = submit_hint(domain, ticket(domain, version, "Alice"))
    assert response.status_code == 202 and response.json()["status"] == "skipped"
    assert collection(domain)["states"]["race"] == before
    while process_due(domain.app):
        pass
    assert collection(domain)["states"]["race"] == before


@pytest.mark.parametrize("kind", ["competition", "record"])
def test_known_deadline_is_not_delayed_by_empty_backoff(domain, monkeypatch, kind):
    from bmt_backend.achievement_models import AchievementCompetition, AchievementRecord
    from bmt_backend.achievements import schedule
    from bmt_backend.track_models import Board

    version = course(domain)
    while process_due(domain.app):
        pass
    monotonic = [100.0]
    monkeypatch.setattr("bmt_backend.achievements.time.monotonic", lambda: monotonic[0])
    monkeypatch.setattr("bmt_backend.achievements.now", lambda: int(monotonic[0]))
    with domain.factory() as session:
        if kind == "competition":
            schedule(session, "challenge", "removed-fixture", 102)
        else:
            board = session.scalar(select(Board).where(Board.version_id == version["version_id"]))
            board_id = board.id
            session.add(AchievementRecord(board_id=board_id, player_id=domain.players["Creator"],
                                          ticks=1, since=0, due_at=102))
        session.commit()
    assert not drive_idle(domain.app)
    assert domain.app.state.achievement_check_after == 102.0
    monotonic[0] = 101
    assert not drive_idle(domain.app)
    monotonic[0] = 102
    assert drive_idle(domain.app)
    with domain.factory() as session:
        if kind == "competition":
            assert session.get(AchievementCompetition, ("challenge", "removed-fixture")).done
        else:
            assert session.get(AchievementRecord, board_id) is None


def test_pending_competition_rechecks_at_normal_worker_cadence(domain, monkeypatch):
    from test_achievements import test_finalized_rivalry_participation_pending_runs_ties_and_once

    from bmt_backend.achievements import finalize_competition

    waits = []

    def observe(session, job, stamp):
        finalize_competition(session, job, stamp)
        if not job.done:
            waits.append(job.due_at - stamp)

    monkeypatch.setattr("bmt_backend.achievements.finalize_competition", observe)
    test_finalized_rivalry_participation_pending_runs_ties_and_once(domain, 5, False)
    assert waits == [1]


def test_remote_hint_survives_worker_clearing_its_wake_event(monkeypatch):
    from bmt_backend.run_signals import RunSignals

    signals = RunSignals(SimpleNamespace(dialect=SimpleNamespace(name="sqlite")))
    app = SimpleNamespace(state=SimpleNamespace(run_signals=signals))
    calls = []
    monkeypatch.setattr("bmt_backend.achievements.process_due", lambda _app: calls.append(True) or False)
    assert not drive_idle(app)
    signals._receive(SimpleNamespace(payload='{"work":true,"done":[]}'))
    assert signals.worker.is_set()
    signals.begin_scan()
    assert not signals.worker.is_set()
    assert not drive_idle(app)
    assert len(calls) == 2


def test_hint_arriving_during_empty_scan_is_not_consumed_by_that_scan(monkeypatch):
    signals = SimpleNamespace(work_generation=0)
    app = SimpleNamespace(state=SimpleNamespace(run_signals=signals))
    calls = []

    def scan(_app):
        calls.append(True)
        if len(calls) == 1:
            signals.work_generation += 1
        return False

    monkeypatch.setattr("bmt_backend.achievements.process_due", scan)
    assert not drive_idle(app)
    assert not drive_idle(app)
    assert len(calls) == 2
