"""Partition receipts, history, expiry and deletion on SQLite and PostgreSQL."""
import time
import uuid

import pytest
from sqlalchemy import func, select, update
from test_discovery_paging import auth_app as auth_app_fixture
from test_discovery_v3 import indexed as indexed_fixture

from bmt_backend.discovery_erasure import erase_private
from bmt_backend.discovery_models import (
    DiscoveryChange,
    DiscoveryDriver,
    DiscoveryEntry,
    DiscoveryHead,
    DiscoveryPartition,
)
from bmt_backend.discovery_projection import partition, settle_for_diagnostics, step
from bmt_backend.identity_models import Player
from bmt_backend.track_models import Board, Run, RunTicket, TrackVersion

auth_app = auth_app_fixture
indexed = indexed_fixture


def test_partition_bounds_cover_hex_ids_under_english_collation(indexed):
    from sqlalchemy import literal, text

    from bmt_backend.discovery_projection import track_range

    with indexed.app.state.session_factory() as db:
        collations = [None]
        if db.bind.dialect.name == "postgresql":
            available = set(db.scalars(text("SELECT collname FROM pg_collation")))
            english = next((name for name in ("en-US-x-icu", "en_US.utf8", "en_US.UTF8") if name in available), None)
            if english is None:
                pytest.skip("PostgreSQL English collation is not installed")
            collations.append(english)
        for collation in collations:
            for prefix in "0123456789abcdef":
                for second in "0123456789abcdef":
                    identity = prefix + second + "000000-0000-4000-8000-000000000000"
                    column = literal(identity)
                    if collation:
                        column = column.collate(collation)
                    for shard in (int(prefix, 16), (int(prefix, 16) + 1) % 16):
                        assert db.scalar(select(track_range(column, shard))) is (shard == int(prefix, 16))


def test_hot_partition_drains_without_waiting_for_empty_partitions(indexed):
    d = indexed
    stamp = int(time.time())
    shard_id = partition(d.tracks[0]["id"])
    with d.app.state.session_factory() as db:
        db.execute(update(DiscoveryPartition).values(checked_at=time.time_ns(),audit_at=stamp+60))
        db.add_all([DiscoveryChange(partition=shard_id,kind="stats",target=d.tracks[0]["id"],
            finished_at=0,created_at=stamp) for _ in range(300)])
        db.commit()
    for remaining in (172,44):
        step(d.app.state.session_factory)
        with d.app.state.session_factory() as db:
            assert db.scalar(select(func.count()).select_from(DiscoveryChange).where(
                DiscoveryChange.processed_at.is_(None))) == remaining
    idle_id = (shard_id+1)%16
    with d.app.state.session_factory() as db:
        db.execute(update(DiscoveryPartition).where(DiscoveryPartition.id == idle_id).values(checked_at=0))
        db.commit()
    step(d.app.state.session_factory)
    with d.app.state.session_factory() as db:
        assert db.get(DiscoveryPartition,idle_id).checked_at > 0


def test_expanding_unicode_names_do_not_poison_a_partition(indexed):
    d = indexed
    with d.app.state.session_factory() as db:
        db.get(Player,d.owner).display_name = "İ"*40
        db.get(TrackVersion,d.versions[0]["id"]).name = "İ"*80
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory)
    with d.app.state.session_factory() as db:
        row = db.scalar(select(DiscoveryEntry).where(DiscoveryEntry.track_id == d.tracks[0]["id"],
            DiscoveryEntry.until.is_(None)))
        assert row.name_key == ("İ"*80).lower() and len(row.name_key) == 160
        assert row.creator_key == ("İ"*40).lower() and len(row.creator_key) == 80


def receipt(d, finished_at, *, identity=None, player=None):
    tid = d.tracks[0]["id"]
    with d.app.state.session_factory() as db:
        event = DiscoveryChange(partition=partition(tid), kind="finish", target=tid,
            player_id=player or d.owner, run_id=str(uuid.uuid4()), finished_at=finished_at,
            created_at=int(time.time()))
        if identity is not None:
            event.id = identity
        db.add(event)
        db.commit()


def state(d):
    with d.app.state.session_factory() as db:
        head = db.get(DiscoveryHead, d.tracks[0]["id"])
        driver = db.get(DiscoveryDriver, (head.track_id, d.owner))
        return head.popularity, driver.last_at if driver else None


def test_receipt_replay_out_of_order_and_refreshed_expiry(indexed):
    d = indexed
    stamp = int(time.time())
    receipt(d, stamp)
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp)
    assert state(d) == (1, stamp)
    refreshed = stamp + 6 * 86400
    receipt(d, refreshed)
    receipt(d, stamp - 10)
    receipt(d, refreshed)
    settle_for_diagnostics(d.app.state.session_factory, clock=refreshed)
    assert state(d) == (1, refreshed)
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp + 7 * 86400 + 1)
    assert state(d) == (1, refreshed)
    settle_for_diagnostics(d.app.state.session_factory, clock=refreshed + 7 * 86400 + 1)
    assert state(d) == (0, None)


def test_source_journal_rolls_back_and_metadata_changes_coalesce(indexed):
    d = indexed
    with d.app.state.session_factory() as db:
        before = db.scalar(select(func.count()).select_from(DiscoveryChange))
        db.execute(update(TrackVersion).where(TrackVersion.id == d.versions[0]["id"]).values(name="Rolled back"))
        db.rollback()
        assert db.scalar(select(func.count()).select_from(DiscoveryChange)) == before
        for n in range(10):
            db.execute(update(TrackVersion).where(TrackVersion.id == d.versions[0]["id"])
                .values(rating_sum=4*(n+1), rating_count=n+1))
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory, clock=int(time.time())+61)
    with d.app.state.session_factory() as db:
        rows = list(db.scalars(select(DiscoveryEntry).where(DiscoveryEntry.track_id == d.tracks[0]["id"])
            .order_by(DiscoveryEntry.epoch)))
        assert len(rows) == 2
        assert rows[-1].rating_count == 10 and rows[-1].rating_sum == 40
        assert rows[0].until == rows[-1].epoch
        assert db.scalar(select(func.count()).select_from(DiscoveryEntry)) == 181


def test_finish_counts_are_coalesced_outside_race_transactions(indexed):
    d = indexed
    stamp = int(time.time())
    with d.app.state.session_factory() as db:
        for n in range(10):
            db.execute(update(TrackVersion).where(TrackVersion.id == d.versions[0]["id"])
                .values(verified_finishers=n+1))
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp)
    with d.app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(DiscoveryEntry)) == 180
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp+61)
    with d.app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(DiscoveryEntry)) == 181
        assert db.scalar(select(DiscoveryEntry.finishers).where(DiscoveryEntry.track_id == d.tracks[0]["id"],
            DiscoveryEntry.until.is_(None))) == 10


def test_real_verified_run_journals_only_eligible_board_population(indexed):
    d = indexed
    stamp = int(time.time())
    with d.app.state.session_factory() as db:
        for purpose in ({}, {"purpose":"creator_test"}, {"test_population":True}):
            board = Board(id=uuid.uuid4().hex*2, version_id=d.versions[0]["id"], vehicle_id="compact", manifest=purpose)
            db.add(board)
            db.flush()
            ticket = RunTicket(player_id=d.owner, board_id=board.id, expires_at=stamp+100)
            db.add(ticket)
            db.flush()
            db.add(Run(ticket_id=ticket.id, player_id=d.owner, board_id=board.id, replay_hash="a"*64,
                status="verified", time_ticks=100, lap_ticks=[20]*5, finished_at=stamp))
        db.commit()
        assert db.scalar(select(func.count()).select_from(DiscoveryChange).where(DiscoveryChange.kind == "finish")) == 1
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp+61)
    assert state(d) == (1, stamp)


def test_restriction_recovery_and_deletion_do_not_recreate_private_state(indexed):
    d = indexed
    stamp = int(time.time())
    receipt(d, stamp)
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp)
    with d.app.state.session_factory() as db:
        db.execute(update(Player).where(Player.id == d.owner).values(disabled=True))
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp+1)
    assert state(d)[0] == 0
    with d.app.state.session_factory() as db:
        db.execute(update(Player).where(Player.id == d.owner).values(disabled=False))
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp+2)
    assert state(d)[0] == 1
    with d.app.state.session_factory() as db:
        player = db.get(Player, d.owner)
        player.deleted_at, player.disabled = stamp, True
        db.commit()
    for _ in range(30):
        with d.app.state.session_factory() as db:
            complete = erase_private(db, d.owner, limit=32)
            db.commit()
            if complete:
                break
    else:
        raise AssertionError("Private discovery cleanup did not finish")
    receipt(d, stamp+3)
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp+4)
    assert state(d) == (0, None)
    with d.app.state.session_factory() as db:
        assert not db.scalar(select(DiscoveryEntry.track_id).where(DiscoveryEntry.owner_id == d.owner,
            DiscoveryEntry.creator != "Removed account").limit(1))


def test_independent_partition_lock_does_not_block_other_projection(indexed):
    d = indexed
    if d.app.state.engine.dialect.name != "postgresql":
        import pytest
        pytest.skip("Requires independent PostgreSQL row locks")
    from concurrent.futures import ThreadPoolExecutor
    with d.app.state.session_factory() as locked:
        locked.scalar(select(DiscoveryPartition).where(DiscoveryPartition.id == 0).with_for_update())
        with ThreadPoolExecutor(max_workers=1) as pool:
            future = pool.submit(step, d.app.state.session_factory)
            future.result(timeout=3)
        locked.rollback()


def test_bounded_reconciliation_and_explicit_ledger_repair(indexed):
    from bmt_backend.discovery_projection import repair_track
    d = indexed
    stamp = int(time.time())
    receipt(d, stamp)
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp)
    with d.app.state.session_factory() as db:
        db.execute(update(DiscoveryHead).where(DiscoveryHead.track_id == d.tracks[0]["id"]).values(popularity=99))
        db.execute(update(TrackVersion).where(TrackVersion.id == d.versions[0]["id"]).values(name="Reconciled title"))
        # Simulate losing a metadata notification in an owned diagnostic fixture.
        db.execute(update(DiscoveryChange).where(DiscoveryChange.processed_at.is_(None)).values(processed_at=stamp))
        db.commit()
    assert repair_track(d.app.state.session_factory, d.tracks[0]["id"])
    assert state(d)[0] == 1
    settle_for_diagnostics(d.app.state.session_factory, clock=stamp+121)
    with d.app.state.session_factory() as db:
        assert db.scalar(select(DiscoveryEntry.name).where(DiscoveryEntry.track_id == d.tracks[0]["id"],
            DiscoveryEntry.until.is_(None))) == "Reconciled title"
