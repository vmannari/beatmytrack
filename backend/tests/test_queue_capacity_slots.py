"""Hard capacity and unrelated transactions through the real queue triggers."""
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from threading import Barrier

import pytest
from alembic import command
from fastapi import HTTPException
from sqlalchemy import select, text
from sqlalchemy.exc import DBAPIError
from test_domains import domain as domain_fixture
from test_domains import headers, public_course, ticket

from bmt_backend import queueing
from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.publication_models import PublicationIntent
from bmt_backend.queueing import admit
from bmt_backend.track_models import (
    QueueCapacity,
    QueuePlayer,
    Run,
    RunTicket,
    Track,
    TrackValidation,
    TrackVersion,
    new_id,
    now,
)

domain = domain_fixture


def pending(session, domain, board_id, owner="Alice", kind="runs"):
    player_id = domain.players[owner]
    if kind == "runs":
        ticket = RunTicket(player_id=player_id, board_id=board_id, expires_at=now() + 3600)
        session.add(ticket)
        session.flush()
        row = Run(ticket_id=ticket.id, player_id=player_id, board_id=board_id, replay_hash="a" * 64)
    elif kind == "publication_intents":
        row = PublicationIntent(player_id=player_id, operation_key=new_id(), request_hash="b" * 64,
            authoring_id=new_id(), name="Queue test", content_hash="c" * 64, replay_hash="d" * 64,
            vehicle_id="compact", contract={})
    else:
        track = Track(owner_id=player_id)
        session.add(track)
        session.flush()
        version = TrackVersion(track_id=track.id, number=1, name="Legacy queue test", content_hash="e" * 64,
                               manifest={}, state="validating")
        session.add(version)
        session.flush()
        row = TrackValidation(version_id=version.id)
    session.add(row)
    session.flush()
    return row


@pytest.mark.parametrize("blocked_kind", ["runs", "publication_intents"])
@pytest.mark.parametrize("operation", ["admit", "complete"])
def test_uncommitted_completion_does_not_block_another_player(domain, blocked_kind, operation):
    if not domain.postgres:
        pytest.skip("Requires PostgreSQL row locks; SQLite has one writer")
    _version, board = public_course(domain)
    with domain.factory() as session:
        held = pending(session, domain, board, kind=blocked_kind)
        other = pending(session, domain, board, owner="Bob")
        held_id = held.id
        other_id = other.id
        session.commit()
    held_model = Run if blocked_kind == "runs" else PublicationIntent
    with domain.factory() as blocker:
        blocker.get(held_model, held_id).status = "failed"
        blocker.flush()  # Keep the actual terminal-state triggers uncommitted.

        def unrelated():
            with domain.factory() as session:
                session.execute(text("SET LOCAL lock_timeout='350ms'"))
                if operation == "admit":
                    admit(session, domain.players["Carol"], 128)
                    pending(session, domain, board, owner="Carol")
                else:
                    session.get(Run, other_id).status = "failed"
                session.commit()
                return True

        with ThreadPoolExecutor(max_workers=1) as pool:
            future = pool.submit(unrelated)
            try:
                assert future.result(timeout=2)
            finally:
                blocker.rollback()
    with domain.factory() as session:
        assert session.get(held_model, held_id).status == "queued"
        assert session.get(QueueCapacity, 1).pending == (3 if operation == "admit" else 1)


@pytest.mark.parametrize("kind", ["runs", "publication_intents", "track_validations"])
def test_slots_follow_pending_lifetime_and_rollback(domain, kind):
    _version, board = public_course(domain)
    with domain.factory() as session:
        admit(session, domain.players["Alice"], 128)
        row = pending(session, domain, board, kind=kind)
        identity = row.version_id if kind == "track_validations" else row.id
        session.commit()
        assert session.get(QueueCapacity, 1).pending == 1
        row.status = "verifying" if kind != "track_validations" else "validating"
        session.flush()
        row.status = "queued"  # Infrastructure retry keeps its existing place.
        session.commit()
        assert session.get(QueueCapacity, 1).pending == 1
        assert session.get(QueuePlayer, domain.players["Alice"]).pending == 1
        row.status = "failed"
        session.flush()
        assert session.scalar(select(QueueCapacity.pending)) == 0
        session.rollback()
        assert session.get(row.__class__, identity).status == "queued"
        assert session.scalar(select(QueueCapacity.pending)) == 1
        row.status = "failed"
        session.commit()
        assert session.scalar(select(QueueCapacity.pending)) == 0
        admit(session, domain.players["Alice"], 128)
        row.status = "queued"  # Explicit retry acquires capacity again.
        session.commit()
        session.delete(row)
        session.commit()
        assert session.scalar(select(QueueCapacity.pending)) == 0
        assert session.get(QueuePlayer, domain.players["Alice"]).pending == 0


def test_owner_limit_survives_unrelated_capacity(domain):
    _version, board = public_course(domain)
    with domain.factory() as session:
        for _ in range(8):
            admit(session, domain.players["Alice"], 128)
            pending(session, domain, board)
        session.commit()
        with pytest.raises(HTTPException) as error:
            admit(session, domain.players["Alice"], 128)
        assert error.value.status_code == 429
        session.rollback()
        admit(session, domain.players["Bob"], 128)
        pending(session, domain, board, owner="Bob")
        session.commit()
        assert session.scalar(select(QueueCapacity.pending)) == 9


def test_database_rejects_over_capacity_and_reuses_released_slot(domain):
    _version, board = public_course(domain)
    with domain.factory() as session:
        admit(session, domain.players["Alice"], 1)
        row = pending(session, domain, board)
        session.commit()
        with pytest.raises(DBAPIError, match="verification_capacity_reached"):
            # Bypass Python's soft check: the database must still enforce the cap.
            pending(session, domain, board, owner="Bob")
        session.rollback()
        row.status = "failed"
        session.commit()
        admit(session, domain.players["Bob"], 1)
        pending(session, domain, board, owner="Bob")
        session.commit()
        assert session.scalar(select(QueueCapacity.pending)) == 1


def test_uncommitted_admission_cannot_oversubscribe_and_http_retry_recovers(domain):
    if not domain.postgres:
        pytest.skip("Requires concurrent transactions")
    version, board = public_course(domain)
    domain.app.state.settings = replace(domain.app.state.settings, max_queued_runs=1)
    issued = ticket(domain, version, "Bob")
    with domain.factory() as session:
        admit(session, domain.players["Alice"], 1)
        session.commit()  # Finish the one-time configuration change first.
    with domain.factory() as blocker:
        admit(blocker, domain.players["Alice"], 1)
        pending(blocker, domain, board)
        key = new_id()
        body = {"ticket_id": issued["ticket_id"],
                "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]] * 20}}
        response = domain.client.post("/v1/runs", json=body, headers=headers(domain, "Bob", key))
        assert response.status_code == 429, response.text
        assert "capacity" in response.json()["detail"]
        blocker.rollback()
    response = domain.client.post("/v1/runs", json=body, headers=headers(domain, "Bob", key))
    assert response.status_code == 202, response.text
    repeated = domain.client.post("/v1/runs", json=body, headers=headers(domain, "Bob", key))
    assert repeated.json() == response.json()
    with domain.factory() as session:
        assert session.scalar(select(QueueCapacity.pending)) == 1
        assert session.get(QueuePlayer, domain.players["Alice"]).pending == 0


@pytest.mark.parametrize("same_owner", [False, True])
def test_simultaneous_admissions_keep_exact_shared_and_player_limits(domain, same_owner):
    if not domain.postgres:
        pytest.skip("Requires concurrent transactions")
    _version, board = public_course(domain)
    maximum, offered = (64, 16) if same_owner else (4, 16)
    names = ["Alice"] * offered
    if not same_owner:
        names = ["Slot driver " + str(i) for i in range(offered)]
        with domain.factory() as session:
            for name in names:
                player = Player(display_name=name)
                session.add(player)
                session.flush()
                domain.players[name] = player.id
            session.commit()
    with domain.factory() as session:
        admit(session, domain.players[names[0]], maximum)
        session.commit()
    barrier = Barrier(8)

    def enter(name):
        barrier.wait(timeout=10)
        try:
            with domain.factory() as session:
                admit(session, domain.players[name], maximum)
                pending(session, domain, board, owner=name)
                session.commit()
            return True
        except HTTPException as error:
            assert error.status_code == 429
        except DBAPIError as error:
            assert queueing.capacity_error(error), str(type(error))
        return False

    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(enter, names))
    expected = 8 if same_owner else maximum
    assert sum(results) == expected
    with domain.factory() as session:
        assert session.scalar(select(QueueCapacity.pending)) == expected
        slots = session.execute(text("SELECT slot FROM queue_reservations")).scalars().all()
        assert len(set(slots)) == expected and all(0 <= slot < maximum for slot in slots)


def test_migration_preserves_pending_jobs_and_round_trips(domain):
    _version, board = public_course(domain)
    command.downgrade(configuration(domain.app.state.engine), "0045_reward_rank_index")
    with domain.factory() as session:
        for owner, kind in (("Alice", "runs"), ("Bob", "publication_intents"), ("Carol", "track_validations")):
            row = pending(session, domain, board, owner=owner, kind=kind)
            row.status = "validating" if kind == "track_validations" else "verifying"
            row.attempts, row.lease_token, row.lease_until = 2, new_id(), now() + 3600
        session.get(QueuePlayer, domain.players["Alice"]).last_claim_at = 1234567
        session.commit()
        before = session.execute(select(Run.id, Run.status, Run.replay_hash).order_by(Run.id)).all()
        metadata = [session.execute(model.__table__.select()).all()
                    for model in (Run, PublicationIntent, TrackValidation)]
        assert session.get(QueueCapacity, 1).pending == 3
    for _ in range(2):
        upgrade(domain.app.state.engine)
        with domain.factory() as session:
            assert session.execute(select(Run.id, Run.status, Run.replay_hash).order_by(Run.id)).all() == before
            assert session.get(QueueCapacity, 1).pending == 3
            assert [session.execute(model.__table__.select()).all()
                    for model in (Run, PublicationIntent, TrackValidation)] == metadata
            assert session.get(QueuePlayer, domain.players["Alice"]).last_claim_at == 1234567
            slots = session.execute(text("SELECT kind,player_id,slot FROM queue_reservations ORDER BY slot")).all()
            assert {r.kind for r in slots} == {"runs", "publication_intents", "track_validations"}
            assert [r.slot for r in slots] == [0, 1, 2]
            for row in slots:
                assert session.get(QueuePlayer, row.player_id).pending == 1
        command.downgrade(configuration(domain.app.state.engine), "0045_reward_rank_index")
    upgrade(domain.app.state.engine)


def test_old_terminal_job_cannot_release_another_jobs_reused_slot(domain):
    _version, board = public_course(domain)
    with domain.factory() as session:
        admit(session, domain.players["Alice"], 1)
        old = pending(session, domain, board)
        session.commit()
        old.status = "failed"
        session.commit()
        admit(session, domain.players["Bob"], 1)
        pending(session, domain, board, owner="Bob")
        session.commit()
        session.delete(old)
        session.commit()
        assert session.scalar(select(QueueCapacity.pending)) == 1
        assert session.get(QueuePlayer, domain.players["Bob"]).pending == 1


def test_capacity_changes_preserve_occupied_slots_and_hard_limit(domain):
    _version, board = public_course(domain)
    with domain.factory() as session:
        admit(session, domain.players["Alice"], 1)
        first = pending(session, domain, board)
        session.commit()
        admit(session, domain.players["Bob"], 2)
        second = pending(session, domain, board, owner="Bob")
        session.commit()
        with pytest.raises(HTTPException) as error:
            admit(session, domain.players["Carol"], 1)
        assert error.value.status_code == 503
        assert error.value.detail == "QUEUE_CAPACITY_CHANGE_REQUIRES_DRAIN"
        session.rollback()
        assert session.scalar(select(QueueCapacity.pending)) == 2
        first.status = second.status = "failed"
        session.commit()
        admit(session, domain.players["Carol"], 1)
        pending(session, domain, board, owner="Carol")
        session.commit()
        assert session.scalar(select(QueueCapacity.pending)) == 1
