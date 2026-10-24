"""P1 regressions: open-group indexing, independent creator intake, fair worker turns."""
import json
import os
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from types import SimpleNamespace

import pytest
from alembic import command
from sqlalchemy import func, inspect, select, text
from test_achievements import collection, course
from test_domains import domain as _domain_fixture
from test_domains import race
from test_rivalry import join, seed

from bmt_backend import worker
from bmt_backend.achievement_models import (
    AchievementState,
    CreatorAchievementEvent,
    CreatorAchievementPartition,
)
from bmt_backend.achievements import CATALOG, erase_private, process_due, save, state
from bmt_backend.creator_achievements import BATCH, enqueue, partition_for
from bmt_backend.creator_achievements import process_one as project_creator
from bmt_backend.economy import accept_verified, previous_bests
from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.rivalry import open_group_candidates
from bmt_backend.rivalry_models import RivalryGroup, RivalryMember
from bmt_backend.track_models import OperationState, Run, digest

domain = _domain_fixture


def drain(app):
    for _ in range(200):
        if not process_due(app):
            return
    raise AssertionError("bounded fixture did not drain")


def test_open_group_index_excludes_closed_groups(domain):
    indexes = inspect(domain.app.state.engine).get_indexes("rivalry_groups")
    index = next((item for item in indexes if item["name"] == "ix_rivalry_open_matching"), None)
    assert index is not None
    assert index["column_names"] == ["week_start", "contract_key", "skill_band", "created_at", "id"]
    assert "member_count < 20" in str(next(iter(index["dialect_options"].values())))


def test_creator_plays_and_reach_are_deferred_exactly_once(domain):
    version = course(domain)
    before = collection(domain, "Creator")["states"]["creator"]
    race(domain, version, "Alice", frames=50)
    race(domain, version, "Alice", frames=60)
    race(domain, version, "Bob", frames=50)
    assert collection(domain, "Creator")["states"]["creator"] == before
    drain(domain.app)
    after = collection(domain, "Creator")["states"]["creator"]
    assert after["metrics"]["creator_plays"] == 3
    assert after["metrics"]["creator_reach"] == 2
    drain(domain.app)
    assert collection(domain, "Creator")["states"]["creator"] == after
    assert collection(domain)["states"]["race"]["metrics"]["races"] == 2


def test_busy_foreground_reserves_both_presentation_classes(domain, monkeypatch):
    calls = {key: 0 for key in ("achievements", "news", "histograms", "privacy")}
    def work(key):
        def execute(*args, **kwargs):
            calls[key] += 1
            return True
        return execute
    monkeypatch.setattr(worker, "process_one", lambda *args, **kwargs: True)
    monkeypatch.setattr("bmt_backend.achievements.drive_idle", work("achievements"))
    monkeypatch.setattr("bmt_backend.news.process_requested", work("news"))
    monkeypatch.setattr("bmt_backend.histogram_snapshots.refresh_one", work("histograms"))
    monkeypatch.setattr("bmt_backend.privacy.cleanup_one", work("privacy"))
    for _ in range(128):
        assert worker.process_worker_job(domain.app)
    assert calls == {"achievements": 4, "news": 4, "histograms": 8, "privacy": 8}


def test_idle_roles_and_achievement_roles_are_fair_even_when_all_busy(domain, monkeypatch):
    calls = []
    def work(name):
        return lambda *args, **kwargs: calls.append(name) or True
    monkeypatch.setattr("bmt_backend.achievements.drive_idle", work("achievements"))
    monkeypatch.setattr("bmt_backend.news.process_requested", work("news"))
    monkeypatch.setattr("bmt_backend.lap_bests.backfill_one", lambda *args: {"worked": work("laps")()})
    monkeypatch.setattr("bmt_backend.histogram_snapshots.refresh_one", work("histograms"))
    for _ in range(8):
        assert worker.process_background(domain.app)
    assert calls == ["achievements", "news", "laps", "histograms"] * 2
    calls.clear()
    for role in ("competition", "rarity", "record"):
        monkeypatch.setattr("bmt_backend.achievements.process_" + role, work(role))
    monkeypatch.setattr("bmt_backend.creator_achievements.process_one", work("creator"))
    for _ in range(8):
        assert process_due(domain.app)
    assert calls == ["competition", "rarity", "record", "creator"] * 2


def test_failed_cleanup_does_not_consume_other_reserved_turns(domain, monkeypatch, caplog):
    calls = []
    def fail(*args, **kwargs):
        raise RuntimeError("injected housekeeping failure")
    monkeypatch.setattr(worker, "process_one", lambda *args, **kwargs: True)
    monkeypatch.setattr("bmt_backend.privacy.cleanup_one", fail)
    monkeypatch.setattr("bmt_backend.histogram_snapshots.refresh_one", lambda *args, **kwargs: calls.append("histogram"))
    monkeypatch.setattr("bmt_backend.achievements.drive_idle", lambda *args, **kwargs: calls.append("achievement") or True)
    monkeypatch.setattr("bmt_backend.news.process_requested", lambda *args, **kwargs: calls.append("news") or True)
    for _ in range(32):
        assert worker.process_worker_job(domain.app)
    assert calls == ["histogram", "achievement", "histogram", "news"]
    assert caplog.text.count("reserved_background_failed role=privacy") == 2


def test_creator_effects_roll_back_and_permanent_reward_receipt_prevents_replay(domain, monkeypatch):
    version = course(domain)
    owner = domain.players["Creator"]
    fake = SimpleNamespace(id=str(uuid.uuid4()), finished_at=111)
    with domain.factory() as session:
        enqueue(session, fake, owner)
        session.rollback()
        assert session.get(CreatorAchievementEvent, fake.id) is None
    race(domain, version, "Alice", frames=50)
    with domain.factory() as session:
        run_id = session.scalar(select(Run.id).where(Run.player_id == domain.players["Alice"]))
        assert session.get(CreatorAchievementEvent, run_id).reach == 1
    original_save = save
    def fail_after_state_write(*args, **kwargs):
        original_save(*args, **kwargs)
        args[0].flush()
        raise RuntimeError("injected projection failure")
    monkeypatch.setattr("bmt_backend.achievements.save", fail_after_state_write)
    with pytest.raises(RuntimeError, match="injected projection failure"):
        project_creator(domain.app)
    with domain.factory() as session:
        assert session.get(CreatorAchievementEvent, run_id) is not None
        assert session.get(AchievementState, (owner, "creator")).metrics == {"publications": 1}
    monkeypatch.setattr("bmt_backend.achievements.save", original_save)
    assert project_creator(domain.app)
    with domain.factory() as session:
        accepted = session.get(Run, run_id)
        accept_verified(session, accepted, previous_bests(session, accepted))
        session.commit()
        assert session.get(CreatorAchievementEvent, run_id) is None
        assert session.get(AchievementState, (owner, "creator")).metrics["creator_plays"] == 1


def test_creator_batches_preserve_exact_unlock_timestamps_and_bounded_erasure(domain):
    owner = domain.players["Creator"]
    with domain.factory() as session:
        row = state(session, owner, "creator")
        save(session, row, {"creator_plays": 99}, 100)
        for index in range(BATCH + 1):
            enqueue(session, SimpleNamespace(id=str(uuid.uuid4()), finished_at=200 + index), owner)
        session.commit()
    assert project_creator(domain.app)
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(CreatorAchievementEvent)) == 1
        row = session.get(AchievementState, (owner, "creator"))
        assert row.metrics["creator_plays"] == 99 + BATCH
        family = next(f for f in CATALOG["families"] if f["metric"] == "creator_plays")
        for index, threshold in enumerate(family["tiers"]):
            if 100 <= threshold <= 99 + BATCH:
                assert row.unlocked[family["id"] + "/" + str(index + 1)] == 200 + threshold - 100
        # The deletion fence is permanent account state, not a queue tombstone.
        session.get(Player, owner).deleted_at = 999
        for index in range(BATCH):
            session.add(CreatorAchievementEvent(id=str(uuid.uuid4()), creator_id=owner,
                partition=partition_for(owner), stamp=500 + index, reach=0))
        session.commit()
        assert not erase_private(session, owner)
        session.commit()
        assert session.scalar(select(func.count()).select_from(CreatorAchievementEvent)) == 1
        assert erase_private(session, owner)
        session.commit()
        enqueue(session, SimpleNamespace(id=str(uuid.uuid4()), finished_at=1000), owner)
        session.commit()
        assert session.scalar(select(func.count()).select_from(CreatorAchievementEvent)) == 0
        assert session.get(AchievementState, (owner, "creator")) is None


@pytest.mark.parametrize("restriction", ["disabled", "is_test_driver"])
def test_creator_restriction_preserves_accepted_effects_but_rejects_new_intake(domain, restriction):
    owner = domain.players["Creator"]
    # Historical published tracks need not already have an achievement state.
    with domain.factory() as session:
        enqueue(session, SimpleNamespace(id=str(uuid.uuid4()), finished_at=123), owner)
        session.commit()
        setattr(session.get(Player, owner), restriction, True)
        session.commit()
        enqueue(session, SimpleNamespace(id=str(uuid.uuid4()), finished_at=124), owner)
        session.commit()
        assert session.scalar(select(func.count()).select_from(CreatorAchievementEvent)) == 1
    assert project_creator(domain.app)
    with domain.factory() as session:
        assert session.get(AchievementState, (owner, "creator")).metrics["creator_plays"] == 1
        assert session.scalar(select(func.count()).select_from(CreatorAchievementEvent)) == 0


def test_migration_refuses_pending_effect_loss_and_roundtrips_when_drained(domain):
    owner = domain.players["Creator"]
    config = configuration(domain.app.state.engine)
    # Only this migration: later concurrently developed migrations are unrelated.
    command.downgrade(config, "0054_priority_scaling")
    with domain.factory() as session:
        enqueue(session, SimpleNamespace(id=str(uuid.uuid4()), finished_at=1), owner)
        session.commit()
    with pytest.raises(RuntimeError, match="Drain creator achievement events"):
        command.downgrade(config, "0053_discovery_short_search")
    assert project_creator(domain.app)
    command.downgrade(config, "0053_discovery_short_search")
    assert "creator_achievement_events" not in inspect(domain.app.state.engine).get_table_names()
    upgrade(domain.app.state.engine)
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(CreatorAchievementPartition)) == 16
        assert session.get(AchievementState, (owner, "creator")).metrics["creator_plays"] == 1


def test_postgres_busy_creator_projection_does_not_block_two_race_acceptances(domain):
    if not domain.postgres:
        pytest.skip("Real independent PostgreSQL transactions required")
    first = course(domain)
    second = {"version_id": seed(domain, 1)[0]}
    owner = domain.players["Creator"]
    with ThreadPoolExecutor(max_workers=2) as pool, domain.factory() as held:
        held.scalar(select(AchievementState).where(AchievementState.player_id == owner,
            AchievementState.scope == "creator").with_for_update())
        # Same partition's reducer lock also remains compatible with intake.
        held.scalar(select(CreatorAchievementPartition).where(
            CreatorAchievementPartition.id == partition_for(owner)).with_for_update(key_share=True))
        # Each simulated worker replica owns its own process-local finalization
        # state, sharing only the actual database/verifier/blob adapters.
        replicas = [SimpleNamespace(**{**vars(domain), "app": SimpleNamespace(state=SimpleNamespace(
            **{**domain.app.state._state, "pending_finalization": None, "worker_id": str(uuid.uuid4())}))})
            for _ in range(2)]
        jobs = [pool.submit(race, replica, version, who, frames=50)
                for replica, version, who in zip(replicas, (first, second), ("Alice", "Bob"), strict=True)]
        try:
            for job in jobs:
                job.result(timeout=6)
        finally:
            held.rollback()
    drain(domain.app)
    metrics = collection(domain, "Creator")["states"]["creator"]["metrics"]
    assert metrics["creator_plays"] == 2 and metrics["creator_reach"] == 1


def test_postgres_busy_creator_reducer_skips_and_retains_effects(domain):
    if not domain.postgres:
        pytest.skip("Real independent PostgreSQL transactions required")
    version = course(domain)
    race(domain, version, "Alice", frames=50)
    owner = domain.players["Creator"]
    with domain.factory() as held:
        held.scalar(select(AchievementState).where(AchievementState.player_id == owner,
            AchievementState.scope == "creator").with_for_update())
        assert not project_creator(domain.app)
        held.rollback()
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(CreatorAchievementEvent)) == 1
    assert project_creator(domain.app)


def test_postgres_parallel_intake_reduction_and_erasure_remain_exact(domain):
    if not domain.postgres:
        pytest.skip("Real independent PostgreSQL transactions required")
    owner = domain.players["Creator"]
    with domain.factory() as session:
        save(session, state(session, owner, "creator"), {}, 1)
        session.commit()
    def intake():
        for _ in range(10):
            with domain.factory() as session:
                effect = SimpleNamespace(id=str(uuid.uuid4()), finished_at=100)
                enqueue(session, effect, owner)
                enqueue(session, effect, owner)  # same transactional receipt
                session.commit()
    def reduce():
        for _ in range(30):
            project_creator(domain.app)
    with ThreadPoolExecutor(max_workers=6) as pool:
        jobs = [pool.submit(intake) for _ in range(4)] + [pool.submit(reduce) for _ in range(2)]
        for job in jobs:
            job.result(timeout=20)
    drain(domain.app)
    with domain.factory() as session:
        assert session.get(AchievementState, (owner, "creator")).metrics["creator_plays"] == 40
        enqueue(session, SimpleNamespace(id=str(uuid.uuid4()), finished_at=200), owner)
        session.get(Player, owner).deleted_at = 999
        session.commit()
    def erase():
        with domain.factory() as session:
            assert erase_private(session, owner)
            session.commit()
    with ThreadPoolExecutor(max_workers=2) as pool:
        for job in (pool.submit(erase), pool.submit(reduce)):
            job.result(timeout=20)
    with domain.factory() as session:
        assert session.get(AchievementState, (owner, "creator")) is None
        assert session.scalar(select(func.count()).select_from(CreatorAchievementEvent)) == 0


def test_postgres_rivalry_skips_busy_group_and_old_band_lock(domain):
    if not domain.postgres:
        pytest.skip("Real independent PostgreSQL transactions required")
    seed(domain)
    first = join(domain)
    with domain.factory() as session:
        group = session.get(RivalryGroup, first["group_id"])
        old_lock = digest({"week": group.week_start, "contract": group.contract_key, "band": group.skill_band})
        session.add(OperationState(id=old_lock))
        session.add(RivalryGroup(week_start=group.week_start, ends_at=group.ends_at, vehicle_id=group.vehicle_id,
            contract_key=group.contract_key, skill_band=group.skill_band, tracks=group.tracks, member_count=0))
        session.commit()
    with ThreadPoolExecutor(max_workers=1) as pool, domain.factory() as held:
        held.scalar(select(OperationState).where(OperationState.id == old_lock).with_for_update())
        held.scalar(select(RivalryGroup).where(RivalryGroup.id == first["group_id"]).with_for_update())
        job = pool.submit(join, domain, "Bob")
        try:
            second = job.result(timeout=6)
            assert second["group_id"] != first["group_id"]
            third = pool.submit(join, domain, "Carol").result(timeout=6)
            assert third["group_id"] == second["group_id"]
        finally:
            held.rollback()
    with domain.factory() as session:
        for group in session.scalars(select(RivalryGroup)):
            assert 1 <= group.member_count <= 20
            assert session.scalar(select(func.count()).select_from(RivalryMember).where(
                RivalryMember.group_id == group.id)) == group.member_count


def test_matching_plan_uses_partial_index_with_many_closed_groups(domain):
    from sqlalchemy import insert
    with domain.factory() as session:
        session.execute(insert(RivalryGroup), [{"id": str(uuid.uuid4()), "week_start": 1, "ends_at": 2,
            "vehicle_id": "compact", "contract_key": "index-probe", "skill_band": 0, "member_count": 20,
            "tracks": [], "created_at": index} for index in range(100000)])
        session.add(RivalryGroup(id="open", week_start=1, ends_at=2, vehicle_id="compact",
            contract_key="index-probe", skill_band=0, member_count=1, tracks=[], created_at=10001))
        session.commit()
        query = open_group_candidates(1, "index-probe", 0).compile(session.bind, compile_kwargs={"literal_binds": True})
        if domain.postgres:
            session.execute(text("ANALYZE rivalry_groups"))
            plan = session.execute(text("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + str(query))).scalar()
            assert "ix_rivalry_open_matching" in str(plan)
        else:
            plan = session.execute(text("EXPLAIN QUERY PLAN " + str(query))).all()
            assert "ix_rivalry_open_matching" in str(plan)
        assert list(session.scalars(open_group_candidates(1, "index-probe", 0))) == ["open"]
        if folder := os.environ.get("BMT_PRIORITY_EVIDENCE_DIR"):
            result = {"closed_groups": 100000, "open_groups": 1, "query": str(query),
                      "plan": plan if domain.postgres else [list(row) for row in plan]}
            name = "postgres" if domain.postgres else "sqlite"
            (Path(folder) / (name + "-matching-plan.json")).write_text(json.dumps(result, indent=2) + "\n")
