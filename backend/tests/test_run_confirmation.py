"""Durable notification hints and bounded, authorized foreground result waits."""
# ruff: noqa: F811 - imported parametrized fixture is named by test arguments.
import json
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace

import pytest
from sqlalchemy import create_engine, text
from test_domains import domain, headers, public_course, submit, ticket  # noqa: F401

from bmt_backend import runs
from bmt_backend.identity_models import Player
from bmt_backend.run_signals import MAX_PENDING, RunSignals
from bmt_backend.track_models import Run, new_id
from bmt_backend.worker import process_one
from bmt_backend.worker_lifecycle import WorkerControl, run_worker


def until(predicate, timeout=2):
    deadline = time.monotonic() + timeout
    while not predicate():
        assert time.monotonic() < deadline, 'Bounded test condition did not settle'
        time.sleep(0.005)


def pending(domain, player='Alice'):
    version, _ = public_course(domain)
    return submit(domain, ticket(domain, version, player), player)


def wait_read(domain, run_id, player='Alice', duration=2000):
    return domain.client.get('/v1/runs/' + run_id + '/wait', params={'timeout_ms': duration},
        headers=headers(domain, player))


def armed_snapshot(monkeypatch):
    ready = threading.Event()
    original = runs.waiting_run_snapshot

    def read(*args):
        result = original(*args)
        ready.set()  # The short read's connection is already released.
        return result

    monkeypatch.setattr(runs, 'waiting_run_snapshot', read)
    return ready


def test_foreground_wait_delivers_only_committed_result_without_poll_delay(domain, monkeypatch):
    run = pending(domain)
    ready = armed_snapshot(monkeypatch)
    with ThreadPoolExecutor(max_workers=1) as pool:
        response = pool.submit(wait_read, domain, run['run_id'])
        assert ready.wait(2) and not response.done()
        if domain.postgres:
            # One optional notification listener, zero request transactions.
            # LISTEN readiness can legitimately start a second short read.
            until(lambda: domain.app.state.engine.pool.checkedout() <= 1, 0.5)
            assert domain.app.state.engine.pool.checkedout() <= 1
            connection = domain.app.state.run_signals.connection
            if connection is not None:
                assert connection.autocommit and connection.info.transaction_status == 0
        started = time.monotonic()
        assert process_one(domain.app)
        result = response.result(timeout=2)
        assert time.monotonic() - started < 0.8
    assert result.status_code == 200, result.text
    assert result.json()['status'] == 'verified' and result.json()['time_ticks'] == 100
    assert result.json()['ticket_id'] == run['ticket_id']
    assert not domain.app.state.run_signals.watches


def test_wait_timeout_capacity_and_ownership_leave_polling_available(domain, monkeypatch):
    run = pending(domain)
    assert wait_read(domain, run['run_id'], 'Bob', 1500).status_code == 404
    started = time.monotonic()
    result = wait_read(domain, run['run_id'], duration=80)
    assert result.status_code == 200 and result.json()['status'] == 'queued'
    assert time.monotonic() - started < 0.7
    assert not domain.app.state.run_signals.watches
    assert wait_read(domain, run['run_id'], duration=2001).status_code == 422
    ready = armed_snapshot(monkeypatch)
    domain.app.state.run_signals.capacity = 1
    with ThreadPoolExecutor(max_workers=1) as pool:
        first = pool.submit(wait_read, domain, run['run_id'], 'Alice', 500)
        assert ready.wait(2)
        started = time.monotonic()
        second = wait_read(domain, run['run_id'])
        assert time.monotonic() - started < 0.5
        assert second.json()['status'] == 'queued' and len(domain.app.state.run_signals.watches) == 1
        assert first.result(timeout=2).status_code == 200
    assert not domain.app.state.run_signals.watches
    assert domain.client.get('/v1/runs/' + run['run_id'], headers=headers(domain, 'Alice')).json()['status'] == 'queued'


def test_notification_cannot_forge_acceptance_and_lost_hint_has_periodic_recovery(domain, monkeypatch):
    run = pending(domain)
    ready = armed_snapshot(monkeypatch)
    signals = domain.app.state.run_signals
    with ThreadPoolExecutor(max_workers=1) as pool:
        response = pool.submit(wait_read, domain, run['run_id'])
        assert ready.wait(2)
        signals._receive(SimpleNamespace(payload=json.dumps({'done': [run['run_id']], 'status': 'verified'})))
        time.sleep(0.06)
        assert not response.done()
        # Drop local and remote hints for the actual completion.
        monkeypatch.setattr(signals, 'publish', lambda *_args: None)
        started = time.monotonic()
        assert process_one(domain.app)
        assert response.result(timeout=2).json()['status'] == 'verified'
        assert time.monotonic() - started < 1.5
    assert not signals.watches


def test_account_restriction_during_wait_is_rechecked_before_return(domain, monkeypatch):
    run = pending(domain)
    ready = armed_snapshot(monkeypatch)
    with ThreadPoolExecutor(max_workers=1) as pool:
        response = pool.submit(wait_read, domain, run['run_id'])
        assert ready.wait(2)
        with domain.factory() as db:
            db.get(Player, domain.players['Alice']).disabled = True
            db.commit()
        domain.app.state.run_signals.publish(run_ids=[run['run_id']])
        assert response.result(timeout=2).status_code == 401
    assert not domain.app.state.run_signals.watches


def test_run_hints_are_commit_only_including_nested_transactions(domain, monkeypatch):
    run = pending(domain)
    published = []
    monkeypatch.setattr(domain.app.state.run_signals, 'publish', lambda *values: published.append(values))
    with domain.factory() as db:
        db.get(Run, run['run_id']).status = 'failed'
        db.flush()
        db.rollback()
    assert not published
    with domain.factory() as db:
        with db.begin_nested():
            db.get(Run, run['run_id']).status = 'failed'
            db.flush()
        assert not published, 'Releasing a savepoint cannot announce an uncommitted result'
        db.commit()
    assert len(published) == 1 and published[0][1] == {run['run_id']}


def test_listener_failure_cannot_fail_an_already_committed_result(domain, monkeypatch):
    run = pending(domain)

    def broken(*_args):
        raise RuntimeError('Injected hint transport failure')

    monkeypatch.setattr(domain.app.state.run_signals, 'publish', broken)
    assert process_one(domain.app)
    with domain.factory() as db:
        assert db.get(Run, run['run_id']).status == 'verified'


@pytest.mark.parametrize('restriction', ['family', 'token', 'expiry'])
def test_real_session_revocation_during_wait_never_returns_a_stale_receipt(auth_app, auth_client, sign_in, monkeypatch, restriction):
    from test_privacy import auth, seed

    from bmt_backend.identity_models import SessionFamily, SessionToken
    from bmt_backend.security import digest
    from bmt_backend.track_models import now
    signed = sign_in('Waiting driver', analytics=False)
    _, _, run_id, *_ = seed(auth_app, signed)
    with auth_app.state.session_factory() as db:
        db.get(Run, run_id).status = 'queued'
        db.commit()
    ready = armed_snapshot(monkeypatch)
    with ThreadPoolExecutor(max_workers=1) as pool:
        response = pool.submit(auth_client.get, '/v1/runs/' + run_id + '/wait', headers=auth(signed))
        assert ready.wait(2)
        with auth_app.state.session_factory() as db:
            from sqlalchemy import select
            token = db.scalar(select(SessionToken).where(SessionToken.access_hash == digest(signed['access_token'])))
            if restriction == 'family':
                db.get(SessionFamily, token.family_id).revoked = True
            elif restriction == 'token':
                token.consumed = True
            else:
                token.access_expires_at = now() - 1
            db.commit()
        auth_app.state.run_signals.publish(run_ids=[run_id])
        assert response.result(timeout=2).status_code == 401
    assert not auth_app.state.run_signals.watches


def test_pending_hints_are_bounded_and_do_not_contain_player_or_result_data(auth_app, monkeypatch):
    signals = RunSignals(SimpleNamespace(dialect=SimpleNamespace(name='postgresql')))
    signals.open()
    monkeypatch.setattr(signals, '_start', lambda: None)
    signals.publish(True, [new_id() for _ in range(1000)])
    assert signals.pending_work and len(signals.pending) == MAX_PENDING
    signals.close()
    assert not signals.pending and not signals.pending_work


def test_idle_worker_wakes_after_check_without_waiting_for_idle_interval(auth_app, monkeypatch):
    idle, done = threading.Event(), threading.Event()
    control = WorkerControl()
    calls = []
    signals = auth_app.state.run_signals

    def job(_app):
        calls.append(True)
        if len(calls) == 1:
            idle.set()
            return False
        assert not signals.idle_worker, 'Foreground work releases the idle listener pool slot'
        done.set()
        control.request_stop()
        return True

    with ThreadPoolExecutor(max_workers=1) as pool:
        worker = pool.submit(run_worker, auth_app, job, control=control, install_signals=False, idle_seconds=5)
        assert idle.wait(2)
        started = time.monotonic()
        signals.publish(work=True)
        assert done.wait(0.5)
        worker.result(timeout=2)
        assert time.monotonic() - started < 0.8
    assert len(calls) == 2


def peer_signals(domain):
    with domain.app.state.engine.connect() as db:
        schema = db.scalar(text('SELECT current_schema()'))
    peer = create_engine(domain.app.state.engine.url, hide_parameters=True,
        pool_size=2, max_overflow=0, connect_args={'options': '-c search_path=' + schema, 'connect_timeout': 3})
    signals = RunSignals(peer)
    signals.open()
    signals.set_idle(True)
    until(lambda: signals.listening)
    return peer, signals


def test_postgres_independent_process_connection_wakes_and_reconnects(domain):
    if not domain.postgres:
        pytest.skip('Requires real PostgreSQL LISTEN/NOTIFY sessions')
    pending(domain)
    peer, remote = peer_signals(domain)
    try:
        remote.worker.clear()
        domain.app.state.run_signals.publish(work=True)
        assert remote.worker.wait(0.7)
        old_pid = remote.connection.info.backend_pid
        with domain.app.state.engine.begin() as db:
            assert db.scalar(text('SELECT pg_terminate_backend(:pid)'), {'pid': old_pid})
        until(lambda: remote.listening and remote.connection is not None and remote.connection.info.backend_pid != old_pid, 3)
        remote.worker.clear()
        domain.app.state.run_signals.publish(work=True)
        assert remote.worker.wait(0.7)
        assert peer.pool.checkedout() == 1
        remote.set_idle(False)
        until(lambda: peer.pool.checkedout() == 0)
    finally:
        remote.close()
        peer.dispose()


def test_postgres_foreground_wait_receives_remote_completion(domain, monkeypatch):
    if not domain.postgres:
        pytest.skip('Requires independent PostgreSQL notification connections')
    run = pending(domain)
    peer, remote = peer_signals(domain)
    ready = armed_snapshot(monkeypatch)
    original_deliver = domain.app.state.run_signals._deliver
    # The main app must learn the update from PostgreSQL, never a local callback.
    monkeypatch.setattr(domain.app.state.run_signals, 'publish', lambda *_args: None)
    try:
        with ThreadPoolExecutor(max_workers=1) as pool:
            response = pool.submit(wait_read, domain, run['run_id'])
            assert ready.wait(2)
            until(lambda: domain.app.state.run_signals.listening)
            assert process_one(domain.app)
            started = time.monotonic()
            remote.publish(run_ids=[run['run_id']])
            assert response.result(timeout=2).json()['status'] == 'verified'
            assert time.monotonic() - started < 0.7
    finally:
        monkeypatch.setattr(domain.app.state.run_signals, '_deliver', original_deliver)
        remote.close()
        peer.dispose()
