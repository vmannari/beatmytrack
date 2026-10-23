"""Single-race query bounds, atomic rollback and concurrent wallet receipts."""
# ruff: noqa: F811 - the imported fixture is named by the test arguments.
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace

import pytest
from sqlalchemy import delete, event, func, select
from sqlalchemy.exc import OperationalError
from test_domains import domain, public_course, race, submit, ticket  # noqa: F401

from bmt_backend import economy, studio_finance
from bmt_backend.achievement_models import AchievementState
from bmt_backend.economy_models import CoinMilestone, CoinReward, CoinWallet
from bmt_backend.studio_platform_models import StudioCoinEntry
from bmt_backend.track_models import LapPersonalBest, PersonalBest, Run
from bmt_backend.worker import process_one


def test_repeat_acceptance_reuses_bounded_facts_without_history_or_ledger_reads(domain):
    version, _board = public_course(domain)
    race(domain, version, frames=30)
    submitted = submit(domain, ticket(domain, version), frames=40)
    queries = []

    def record(_conn, _cursor, sql, *_args):
        queries.append(sql)

    event.listen(domain.app.state.engine, 'before_cursor_execute', record)
    try:
        assert process_one(domain.app)
    finally:
        event.remove(domain.app.state.engine, 'before_cursor_execute', record)
    assert len(queries) <= 30, queries
    assert sum('FROM coin_milestones' in sql for sql in queries) == 1
    assert not any('FROM studio_coin_entries' in sql for sql in queries)
    assert not any('FROM rivalry_tickets' in sql or 'FROM challenge_tickets' in sql for sql in queries)
    assert not any('runs.id !=' in sql for sql in queries), 'Repeat races must not inspect old history'
    with domain.factory() as db:
        assert db.get(CoinReward, submitted['run_id']).amount == 50


def test_shared_acceptance_receipt_prevents_duplicate_award_in_same_transaction(domain, monkeypatch):
    version, _ = public_course(domain)
    original = economy.accept_verified

    def repeated(*args, **kwargs):
        original(*args, **kwargs)
        original(*args, **kwargs)

    monkeypatch.setattr(economy, 'accept_verified', repeated)
    accepted = race(domain, version, 'Alice', frames=30)
    with domain.factory() as db:
        reward = db.get(CoinReward, accepted['run_id'])
        wallet = db.get(CoinWallet, domain.players['Alice'])
        assert wallet.balance == reward.amount == 200  # completion + first track + two tiers
        assert wallet.revision == 1
        assert db.get(AchievementState, (domain.players['Alice'], 'race')).metrics['races'] == 1
        entries = db.scalars(select(StudioCoinEntry).where(StudioCoinEntry.player_id == wallet.player_id)).all()
        assert sorted((e.kind, e.amount) for e in entries) == [('earned', 200), ('opening', 0)]


def test_late_ledger_failure_rolls_back_every_projection_and_retries_without_rechecking(domain, monkeypatch):
    version, board = public_course(domain)
    accepted = race(domain, version, 'Alice', frames=40)
    with domain.factory() as db:
        balance = db.get(CoinWallet, domain.players['Alice']).balance
    submitted = submit(domain, ticket(domain, version, 'Alice'), 'Alice', frames=20)
    original = studio_finance.race_coin_entries

    def fail_after_insert(*args, **kwargs):
        original(*args, **kwargs)
        raise OperationalError('Injected after ledger insertion', {}, Exception('Owned fixture'))

    monkeypatch.setattr(studio_finance, 'race_coin_entries', fail_after_insert)
    with pytest.raises(OperationalError):
        process_one(domain.app)
    with domain.factory() as db:
        assert db.get(Run, submitted['run_id']).status == 'verifying'
        assert db.get(CoinReward, submitted['run_id']) is None
        assert db.get(CoinWallet, domain.players['Alice']).balance == balance
        assert db.get(PersonalBest, (board, domain.players['Alice'])).run_id == accepted['run_id']
        assert db.get(LapPersonalBest, (board, domain.players['Alice'])).time_ticks == 40
        assert db.get(AchievementState, (domain.players['Alice'], 'race')).metrics['races'] == 1
        assert db.scalar(select(StudioCoinEntry.id).where(StudioCoinEntry.reference == 'run/' + submitted['run_id'])) is None
    monkeypatch.setattr(studio_finance, 'race_coin_entries', original)

    def forbidden(*_args, **_kwargs):
        raise AssertionError('Finalization retry must use the already checked, fenced result')

    monkeypatch.setattr(domain.app.state.verifier, 'verify_run', forbidden)
    assert process_one(domain.app)
    with domain.factory() as db:
        assert db.get(Run, submitted['run_id']).status == 'verified'
        assert db.get(CoinWallet, domain.players['Alice']).balance == balance + 250
        assert db.get(PersonalBest, (board, domain.players['Alice'])).run_id == submitted['run_id']
        assert db.get(LapPersonalBest, (board, domain.players['Alice'])).time_ticks == 20
        assert db.get(AchievementState, (domain.players['Alice'], 'race')).metrics['races'] == 2


def test_legacy_history_without_marker_is_checked_once_and_never_reawarded(domain):
    version, _board = public_course(domain)
    with domain.factory() as db:
        db.execute(delete(CoinMilestone).where(CoinMilestone.player_id == domain.players['Creator'],
            CoinMilestone.scope == 'track/' + version['track_id']))
        db.commit()
    accepted = race(domain, version, frames=60)
    with domain.factory() as db:
        assert db.get(CoinReward, accepted['run_id']).amount == 50
        assert db.get(CoinMilestone, (domain.players['Creator'], 'track/' + version['track_id'])).value == 1


@pytest.mark.parametrize('initial', [650, economy.MAX_BALANCE - 10])
def test_race_ledger_preserves_legacy_opening_balance_and_wallet_capacity(domain, initial):
    version, _ = public_course(domain)
    player = domain.players['Alice']
    with domain.factory() as db:
        db.add(CoinWallet(player_id=player, balance=initial, revision=4))
        db.commit()
    first = race(domain, version, 'Alice', frames=30)
    second = race(domain, version, 'Alice', frames=30)
    with domain.factory() as db:
        wallet = db.get(CoinWallet, player)
        entries = db.scalars(select(StudioCoinEntry).where(StudioCoinEntry.player_id == player)).all()
        opening = next(row for row in entries if row.kind == 'opening')
        assert opening.amount == initial and opening.detail == {'revision': 4}
        assert wallet.balance == min(economy.MAX_BALANCE, initial + 250)
        assert wallet.revision == 6
        assert len(entries) == 3
        assert sum(row.amount for row in entries) == wallet.balance
        first_amount = min(200, economy.MAX_BALANCE - initial)
        assert db.get(CoinReward, first['run_id']).amount == first_amount
        assert db.get(CoinReward, second['run_id']).amount == min(50, economy.MAX_BALANCE - initial - first_amount)


def test_parallel_workers_preserve_same_player_balance_and_one_time_rewards(domain, monkeypatch):
    if not domain.postgres:
        pytest.skip('Independent PostgreSQL transactions exercise the shared Player lock')
    version, board = public_course(domain)
    submitted = [submit(domain, ticket(domain, version, 'Alice'), 'Alice', frames=30) for _ in range(2)]
    barrier = threading.Barrier(2)
    original = domain.app.state.verifier.verify_run

    def together(*args, **kwargs):
        result = original(*args, **kwargs)
        barrier.wait(timeout=5)
        return result

    monkeypatch.setattr(domain.app.state.verifier, 'verify_run', together)
    # Distinct worker states share only the engine/session factory and verifier.
    workers = [SimpleNamespace(state=SimpleNamespace(**domain.app.state._state)) for _ in range(2)]
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(process_one, app) for app in workers]
        assert all(job.result(timeout=10) for job in futures)
    with domain.factory() as db:
        rewards = [db.get(CoinReward, row['run_id']) for row in submitted]
        assert sorted(row.amount for row in rewards) == [50, 200]
        wallet = db.get(CoinWallet, domain.players['Alice'])
        assert wallet.balance == 250 and wallet.revision == 2
        assert db.get(PersonalBest, (board, wallet.player_id)).time_ticks == 150
        assert db.get(LapPersonalBest, (board, wallet.player_id)).time_ticks == 30
        assert db.get(AchievementState, (wallet.player_id, 'race')).metrics['races'] == 2
        assert db.scalar(select(func.count()).select_from(StudioCoinEntry).where(
            StudioCoinEntry.player_id == wallet.player_id)) == 3


def test_account_disabled_during_checker_wait_is_rejected_before_any_award(domain, monkeypatch):
    if not domain.postgres:
        pytest.skip('PostgreSQL account mutation while verification has no DB transaction')
    from bmt_backend.identity_models import Player
    version, _ = public_course(domain)
    submitted = submit(domain, ticket(domain, version, 'Alice'), 'Alice', frames=30)
    original = domain.app.state.verifier.verify_run

    def restrict(*args, **kwargs):
        result = original(*args, **kwargs)
        with domain.factory() as db:
            db.get(Player, domain.players['Alice']).disabled = True
            db.commit()
        return result

    monkeypatch.setattr(domain.app.state.verifier, 'verify_run', restrict)
    started = time.monotonic()
    assert process_one(domain.app)
    assert time.monotonic() - started < 5
    with domain.factory() as db:
        assert db.get(Run, submitted['run_id']).failure_code == 'account_disabled'
        assert db.get(CoinWallet, domain.players['Alice']) is None
        assert db.get(CoinReward, submitted['run_id']) is None
