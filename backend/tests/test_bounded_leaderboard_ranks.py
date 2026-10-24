"""Exact public positions/percentiles and transactional compressed-tree upkeep."""
# ruff: noqa: F811
import random
import uuid

import pytest
from alembic import command
from sqlalchemy import delete, event, func, select, text
from test_domains import domain, headers, public_course  # noqa: F401

from bmt_backend.cursors import encode_cursor
from bmt_backend.economy_models import LeaderboardTieNode
from bmt_backend.identity_models import Player
from bmt_backend.leaderboard_ranks import tied_before, time_counts_many
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.track_models import PersonalBest, Run, RunTicket, now


def add_field(domain, board, count=40, *, identities=None):
    rng = random.Random(948)
    ids = list(identities) if identities is not None else [str(uuid.UUID(int=rng.getrandbits(128))) for _ in range(count)]
    rng.shuffle(ids)
    with domain.factory() as session:
        for index, identity in enumerate(ids):
            session.add(Player(id=identity, display_name=f"Ordinal {index}"))
            session.flush()
            ticket = RunTicket(player_id=identity, board_id=board, expires_at=now()+100)
            session.add(ticket)
            session.flush()
            run = Run(ticket_id=ticket.id, player_id=identity, board_id=board,
                      replay_hash="0"*64, status="verified", time_ticks=150)
            session.add(run)
            session.flush()
            session.add(PersonalBest(board_id=board, player_id=identity, run_id=run.id, time_ticks=150))
        session.commit()
    return ids


def exact(session, board):
    for artificial in (False, True):
        criteria = [PersonalBest.board_id == board, Player.disabled.is_(False)]
        if not artificial:
            criteria.append(Player.is_test_driver.is_(False))
        rows = session.execute(select(PersonalBest.player_id, PersonalBest.time_ticks)
                               .join(Player).where(*criteria)).all()
        for ticks in (1, 149, 150, 151, 300, 2147483647):
            expected = tuple(sum(1 for _, value in rows if predicate(value, ticks))
                             for predicate in (lambda a,b:a<b, lambda a,b:a==b, lambda a,b:a>b))
            assert time_counts_many(session, [(board, ticks)], artificial=artificial)[board] == expected
        if not artificial:
            for identity in [row[0] for row in rows] + ["0"*36, "f"*36, "7"*36]:
                expected = sum(ticks == 150 and pid < identity for pid, ticks in rows)
                assert tied_before(session, board, 150, identity) == expected
                assert tied_before(session, board, 150, identity, inclusive=True) == expected + int((identity,150) in rows)
            node_count = session.scalar(select(func.count()).select_from(LeaderboardTieNode).where(
                LeaderboardTieNode.board_id == board))
            assert len(rows) <= node_count <= 2*len(rows) - 1


def test_exact_random_inserts_ties_visibility_correction_deletes_and_rollback(domain):
    _, board = public_course(domain)
    ids = add_field(domain, board)
    rng = random.Random(927)
    with domain.factory() as session:
        exact(session, board)
        for index, identity in enumerate(ids):
            player = session.get(Player, identity)
            if index % 4 == 0:
                player.disabled = True
            elif index % 4 == 1:
                player.is_test_driver = True
            elif index % 4 == 2:
                session.get(PersonalBest, (board, identity)).time_ticks = rng.choice((1,149,151,2147483647))
            else:
                session.execute(delete(PersonalBest).where(PersonalBest.board_id == board, PersonalBest.player_id == identity))
            session.flush()
            if index % 7 == 0:
                exact(session, board)
        exact(session, board)
        session.rollback()
        exact(session, board)
        # Visibility toggling must restore exact totals and all compressed edges.
        for identity in ids[:10]:
            session.get(Player, identity).disabled = True
        session.flush()
        for identity in ids[:10]:
            session.get(Player, identity).disabled = False
        session.flush()
        exact(session, board)


def test_stale_cursor_and_around_me_keep_exact_absolute_tie_positions(domain):
    _, board = public_course(domain)
    ids = add_field(domain, board, 24)
    ordered = sorted(ids)
    identity = ordered[12]
    around = domain.client.get(f"/v1/boards/{board}/around-me", headers={"x-test-player":identity}).json()
    assert around["player"]["rank"] == 1
    assert around["player"]["position"] == 13
    assert [row["position"] for row in around["items"]] == list(range(10,17))
    stale = encode_cursor({"ticks":150,"player":identity,"board":board,"revision":-1,"position":0})
    page = domain.client.get(f"/v1/boards/{board}", params={"cursor":stale,"limit":3}).json()
    assert [row["player_id"] for row in page["items"]] == ordered[13:16]
    assert [row["position"] for row in page["items"]] == [14,15,16]


def test_bounded_read_sql_has_no_population_aggregate_or_frequency_scan(domain):
    _, board = public_course(domain)
    ids = add_field(domain, board)
    captured = []
    def record(_c,_cur,statement,*_args):
        captured.append(statement)
    event.listen(domain.app.state.engine,"before_cursor_execute",record)
    try:
        with domain.factory() as session:
            time_counts_many(session, [(board, 150)])
            tied_before(session, board, 150, sorted(ids)[20])
    finally:
        event.remove(domain.app.state.engine,"before_cursor_execute",record)
    assert len(captured) == 3
    assert not any("personal_bests" in sql or "board_time_counts" in sql or "players" in sql for sql in captured)
    assert " IN (" in captured[0] and "parent IN (" in captured[1]
    if not domain.postgres:
        with domain.factory() as session:
            assert session.scalar(text("SELECT COUNT(*) FROM leaderboard_tie_work")) == 0


def test_rank_migration_seeds_existing_pbs_and_reverses_only_its_schema(domain):
    _, board = public_course(domain)
    add_field(domain, board, 16)
    # Never cross the separately irreversible telemetry protocol cutover0051.
    command.downgrade(configuration(domain.app.state.engine), "0054_priority_scaling")
    upgrade(domain.app.state.engine)
    with domain.factory() as session:
        exact(session, board)


def test_prefix_ids_short_stale_cursors_and_leaf_branch_collapse(domain):
    _, board = public_course(domain)
    ids = add_field(domain, board, identities=["a", "aa", "aaa", "ab", "b", "ba", "bac", "bb", "a"*35, "a"*36])
    with domain.factory() as session:
        exact(session, board)
        # Some stale cursors point to an internal prefix with no matching leaf.
        for cursor in ("", "b", "bax", "a"*34):
            expected = sum(identity <= cursor for identity in ids)
            assert tied_before(session, board, 150, cursor, inclusive=True) == expected
        for identity in sorted(ids, reverse=True):
            session.execute(delete(PersonalBest).where(PersonalBest.board_id == board, PersonalBest.player_id == identity))
            exact(session, board)


def test_visible_windows_limit_keys_before_joining_hidden_pbs(domain):
    from bmt_backend.runs import population_window
    _, board = public_course(domain)
    ids = add_field(domain, board, 80)
    with domain.factory() as session:
        for identity in ids[:70]:
            session.get(Player, identity).disabled = True
        for identity in ids[70:75]:
            session.get(Player, identity).is_test_driver = True
        session.commit()
        rows = session.execute(population_window(board, 3)).mappings().all()
        assert [row["player_id"] for row in rows] == sorted(ids[75:])[:3]
        statement = str(population_window(board, 3).compile(session.bind, compile_kwargs={"literal_binds":True}))
        if domain.postgres:
            # Small fixture may prefer a sequential scan. Disabling it reveals
            # the exact partial-index path used for a populated production tree.
            session.execute(text("SET LOCAL enable_seqscan=off"))
            plan = "\n".join(session.scalars(text("EXPLAIN " + statement)))
        else:
            plan = "\n".join(row[3] for row in session.execute(text("EXPLAIN QUERY PLAN " + statement)))
        assert "ix_leaderboard_visible_order" in plan
        assert "LIMIT" in statement.upper()


def test_concurrent_tie_moves_visibility_changes_and_deletion_are_exact(domain):
    if not domain.postgres:
        pytest.skip("Independent PostgreSQL writers exercise board/tree lock ordering")
    from concurrent.futures import ThreadPoolExecutor
    from threading import Barrier
    _, board = public_course(domain)
    ids = add_field(domain, board, 30)
    for action in ("join_tie", "leave_tie", "hide", "show", "delete"):
        ready = Barrier(2)
        def change(identity, operation, ready=ready):
            with domain.factory() as session:
                player = session.scalar(select(Player).where(Player.id == identity).with_for_update())
                ready.wait(timeout=10)
                best = session.get(PersonalBest, (board, identity))
                if operation == "join_tie":
                    best.time_ticks = 149
                elif operation == "leave_tie":
                    best.time_ticks = 150
                elif operation == "hide":
                    player.disabled = True
                elif operation == "show":
                    player.disabled = False
                else:
                    session.delete(best)
                session.commit()
        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(change, identity, action) for identity in ids[:2]]
            for future in futures:
                future.result(timeout=15)
        with domain.factory() as session:
            exact(session, board)
