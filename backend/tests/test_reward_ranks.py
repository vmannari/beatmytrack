"""Exact award equivalence, transactional projection and bounded query work."""
# ruff: noqa: F811 - imported pytest fixture is intentionally named by test args.
import random

import pytest
from alembic import command
from sqlalchemy import delete, event, func, select, text
from test_domains import domain, headers, public_course, race  # noqa: F401

from bmt_backend.economy_models import CoinMilestone, RewardRankCount
from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.reward_ranks import TREE_SIZE, percentile_amount, prefix_nodes
from bmt_backend.track_models import Board, LapPersonalBest, PersonalBest, Run, RunTicket


def oracle(session, board, model, ticks):
    criteria = (model.board_id == board, Player.disabled.is_(False),
                Player.deleted_at.is_(None), Player.is_test_driver.is_(False))
    total = session.scalar(select(func.count()).select_from(model).join(Player).where(*criteria))
    ahead = session.scalar(select(func.count()).select_from(model).join(Player).where(*criteria, model.time_ticks < ticks))
    return next((amount for limit, amount in ((1, 500), (10, 200), (25, 100), (50, 50))
                 if total and (ahead + 1) * 100 <= total * limit), 0)


def assert_exact(session, board):
    for metric, model in (("race", PersonalBest), ("lap", LapPersonalBest)):
        times = list(session.scalars(select(model.time_ticks).where(model.board_id == board)))
        probes = {1, 2, 216000, TREE_SIZE - 1, *times, *(t + 1 for t in times if t + 1 < TREE_SIZE)}
        for ticks in probes:
            assert percentile_amount(session, board, metric, ticks) == oracle(session, board, model, ticks)
        root = session.get(RewardRankCount, (board, metric, TREE_SIZE))
        population = session.scalar(select(func.count()).select_from(model).join(Player).where(
            model.board_id == board, Player.disabled.is_(False), Player.is_test_driver.is_(False),
            Player.deleted_at.is_(None)))
        assert (root.total if root else 0) == population


def field(domain):
    version, board = public_course(domain)
    race(domain, version, "Alice", frames=20)
    race(domain, version, "Bob", frames=30)
    race(domain, version, "Carol", frames=30)
    return version, board


def test_exact_after_ties_improvement_correction_restriction_and_reclassification(domain):
    _, board = field(domain)
    rng = random.Random(12)
    with domain.factory() as session:
        assert_exact(session, board)
        for _ in range(20):
            identity = domain.players[rng.choice(("Alice", "Bob", "Carol"))]
            player = session.get(Player, identity)
            action = rng.randrange(4)
            if action == 0:
                player.disabled = not player.disabled
            elif action == 1:
                player.is_test_driver = not player.is_test_driver
            else:
                model = PersonalBest if action == 2 else LapPersonalBest
                session.get(model, (board, identity)).time_ticks = rng.choice((1, 20, 30, 100, 65536, TREE_SIZE - 1))
            session.flush()
            assert_exact(session, board)
        session.rollback()
        assert_exact(session, board)


def test_deleted_visibility_and_pb_deletes_do_not_double_subtract(domain):
    _, board = field(domain)
    with domain.factory() as session:
        player = session.get(Player, domain.players["Alice"])
        player.deleted_at = 123
        session.flush()
        assert_exact(session, board)
        for model in (PersonalBest, LapPersonalBest):
            session.execute(delete(model).where(model.board_id == board, model.player_id == player.id))
        assert_exact(session, board)
        # Delete an ordinary visible driver's PBs as well.
        for model in (PersonalBest, LapPersonalBest):
            session.execute(delete(model).where(model.board_id == board, model.player_id == domain.players["Bob"]))
        assert_exact(session, board)
        session.rollback()
        assert_exact(session, board)


def test_retiring_lap_source_repairs_prefix_counts(domain):
    version, board = field(domain)
    race(domain, version, "Alice", frames=25)
    with domain.factory() as session:
        best = session.get(LapPersonalBest, (board, domain.players["Alice"]))
        session.get(Run, best.run_id).status = "rejected"
        session.flush()
        session.expire_all()
        assert session.get(LapPersonalBest, (board, domain.players["Alice"])).time_ticks == 25
        assert_exact(session, board)
        session.rollback()
        assert_exact(session, board)


def test_migration_backfills_existing_field_and_downgrades_without_changing_receipts(domain):
    _, board = field(domain)
    with domain.factory() as session:
        before = list(session.execute(select(PersonalBest.player_id, PersonalBest.time_ticks, PersonalBest.run_id)
                                      .where(PersonalBest.board_id == board).order_by(PersonalBest.player_id)))
    command.downgrade(configuration(domain.app.state.engine), "0044_telemetry_counter_bigint")
    upgrade(domain.app.state.engine)
    with domain.factory() as session:
        after = list(session.execute(select(PersonalBest.player_id, PersonalBest.time_ticks, PersonalBest.run_id)
                                     .where(PersonalBest.board_id == board).order_by(PersonalBest.player_id)))
        assert after == before
        assert_exact(session, board)


def test_prefix_queries_are_bounded_and_do_not_read_players_or_pbs(domain):
    _, board = field(domain)
    with domain.factory() as session:
        captured = []

        def record(_connection, _cursor, statement, *_args):
            captured.append(statement)

        event.listen(domain.app.state.engine, "before_cursor_execute", record)
        try:
            for metric in ("race", "lap"):
                percentile_amount(session, board, metric, TREE_SIZE - 1)
        finally:
            event.remove(domain.app.state.engine, "before_cursor_execute", record)
        assert len(captured) == 2
        assert all("reward_rank_counts" in sql and " IN (" in sql for sql in captured)
        assert not any("JOIN" in sql or "count(" in sql.lower() or "personal_bests" in sql or "players" in sql for sql in captured)
        # The largest possible prefix reads at most 31 nodes plus its total.
        assert len(prefix_nodes(TREE_SIZE - 1)) + 1 <= 32


def test_race_acceptance_does_not_scan_population(domain):
    version, _board = field(domain)
    captured = []

    def record(_connection, _cursor, statement, *_args):
        captured.append(statement)

    event.listen(domain.app.state.engine, "before_cursor_execute", record)
    try:
        # A slower repeat still receives ordinary rewards and is evaluated
        # against the submitted time, preserving the original candidate policy.
        race(domain, version, "Alice", frames=25)
    finally:
        event.remove(domain.app.state.engine, "before_cursor_execute", record)
    scans = [sql for sql in captured if "count(" in sql.lower()
             and ("FROM personal_bests" in sql or "FROM lap_personal_bests" in sql)]
    assert not scans, scans
    assert sum("FROM reward_rank_counts" in sql for sql in captured) == 2


def test_maximum_tier_skips_rank_reads_but_keeps_ordinary_reward(domain):
    version, board = field(domain)
    with domain.factory() as session:
        for metric in ("race", "lap"):
            old = session.get(CoinMilestone, (domain.players["Alice"], metric + "/" + board))
            if old:
                old.value = 500
            else:
                session.add(CoinMilestone(player_id=domain.players["Alice"], scope=metric + "/" + board, value=500))
        session.commit()
    captured = []

    def record(_connection, _cursor, statement, *_args):
        if statement.lstrip().upper().startswith("SELECT"):
            captured.append(statement)

    event.listen(domain.app.state.engine, "before_cursor_execute", record)
    try:
        result = race(domain, version, "Alice", frames=25)
    finally:
        event.remove(domain.app.state.engine, "before_cursor_execute", record)
    receipt = domain.client.get("/v1/economy/rewards/" + result["ticket_id"], headers=headers(domain, "Alice")).json()
    assert any(row["title"] == "Race completed" for row in receipt["rows"])
    assert not any("percentile" in row["title"] for row in receipt["rows"])
    assert not any("reward_rank_counts" in sql for sql in captured)


def test_counters_support_population_beyond_integer_range(domain):
    _, board = public_course(domain)
    with domain.factory() as session:
        # Synthetic tied population: exercise BIGINT counters, exact integer
        # threshold arithmetic and sparse prefix reads without billions of rows.
        session.execute(delete(RewardRankCount).where(RewardRankCount.board_id == board))
        nodes = set()
        node = 100
        while node <= TREE_SIZE:
            nodes.add(node)
            node += node & -node
        session.add_all(RewardRankCount(board_id=board, metric="race", node=n, total=5000000000) for n in nodes)
        session.flush()
        assert percentile_amount(session, board, "race", 100) == 500
        assert percentile_amount(session, board, "race", 101) == 0
        session.rollback()


def test_exact_tier_boundaries_for_one_hundred_drivers(domain):
    _, board = public_course(domain)
    with domain.factory() as session:
        for index in range(1, 100):
            player = Player(display_name="Rank boundary " + str(index))
            session.add(player)
            session.flush()
            ticket = RunTicket(player_id=player.id, board_id=board, expires_at=2000000000)
            session.add(ticket)
            session.flush()
            run = Run(player_id=player.id, board_id=board, ticket_id=ticket.id, replay_hash="0"*64,
                      status="verified", time_ticks=1000+index*5, lap_ticks=[200+index]*5, finished_at=1)
            session.add(run)
            session.flush()
            session.add(PersonalBest(board_id=board, player_id=player.id, run_id=run.id, time_ticks=run.time_ticks))
        session.flush()
        for rank, expected in ((1,500),(10,200),(25,100),(50,50),(51,0)):
            ticks = 300 if rank == 1 else 1000+(rank-1)*5
            assert percentile_amount(session, board, "race", ticks) == expected
        assert_exact(session, board)
        session.rollback()


def test_improvement_does_not_rewrite_population_root(domain):
    version, board = field(domain)
    if not domain.postgres:
        pytest.skip("PostgreSQL physical row identity verifies cancelled ancestor writes")
    with domain.factory() as session:
        roots = list(session.execute(text("SELECT metric,ctid::text FROM reward_rank_counts WHERE board_id=:board AND node=:root ORDER BY metric"),
                                     {"board":board,"root":TREE_SIZE}))
    race(domain, version, "Alice", frames=10)
    with domain.factory() as session:
        after = list(session.execute(text("SELECT metric,ctid::text FROM reward_rank_counts WHERE board_id=:board AND node=:root ORDER BY metric"),
                                     {"board":board,"root":TREE_SIZE}))
        assert after == roots
        assert_exact(session, board)


def test_concurrent_pb_writers_keep_both_metric_prefixes_exact(domain):
    if not domain.postgres:
        pytest.skip("Independent concurrent PostgreSQL writer transactions")
    from concurrent.futures import ThreadPoolExecutor
    from threading import Barrier

    _, board = field(domain)
    ready = Barrier(2)

    def improve(name, ticks):
        with domain.factory() as session:
            identity = domain.players[name]
            session.scalar(select(Player).where(Player.id == identity).with_for_update())
            ready.wait(timeout=10)
            # The existing PB triggers acquire Board before prefix counters.
            # Concurrent writers on distinct players must serialize cleanly.
            session.get(PersonalBest, (board, identity)).time_ticks = ticks * 5
            session.flush()
            session.get(LapPersonalBest, (board, identity)).time_ticks = ticks
            session.commit()

    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(improve,"Alice",10), pool.submit(improve,"Bob",15)]
        for future in futures:
            future.result(timeout=15)
    with domain.factory() as session:
        assert session.get(Board, board) is not None
        assert_exact(session, board)


@pytest.mark.parametrize("ticks", [0, -1, TREE_SIZE, True, 1.5])
def test_invalid_tick_domain_fails_explicitly(ticks):
    with pytest.raises(ValueError):
        prefix_nodes(ticks)
