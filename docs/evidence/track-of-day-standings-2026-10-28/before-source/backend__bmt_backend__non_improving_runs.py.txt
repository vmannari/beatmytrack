"""Negative-only result hints: unverified completions never publish a best."""
from sqlalchemy import select

from .challenge_models import (
    Challenge,
    ChallengeMember,
    ChallengeStageMember,
    ChallengeStageTicket,
    ChallengeTicket,
)
from .rivalry_models import RivalryBest, RivalryGroup, RivalryTicket
from .track_models import LapPersonalBest, PersonalBest, Run, now
from .trajectory_verifier import clean_race_report, duration


def candidate(replay):
    """A small client hint may discard its own score, never authorize one.

    Old recordings without lap summaries retain normal verification. Validate
    endpoints in constant time; intentionally do not walk the recorded path.
    """
    if replay.get("schema") != "bmt-trajectory-v1" or "claimed_lap_ticks" not in replay:
        return None
    proof = replay["race_proof"]
    schema = proof.get("schema")
    width = 4 if schema == "bmt-race-path-v1" else 8 if schema == "bmt-race-proof-v1" else 0
    samples = proof.get("samples")
    ticks = duration(replay)
    if (set(proof) not in ({"schema","samples"}, {"schema","samples","incidents"})
            or not width or type(samples) is not list or not 2 <= len(samples) <= 216000//6+12
            or any(type(row) is not list or len(row) != width or type(row[0]) is not int
                   for row in (samples[0], samples[-1]))
            or samples[0][0] != 0 or samples[-1][0] != ticks):
        return None
    return ticks, replay["claimed_lap_ticks"]


def no_improvement(session, ticket, board, result):
    """Caller holds Player. Lock existing bests against concurrent resets.

    Daily Free Race and Track of the Day use the ordinary pinned board. Weekly
    and Challenge bests are separate: a global PB cannot stand in for them.
    Missing/uncertain facts always leave the race on the verification path.
    """
    if result is None or board.manifest.get("purpose") == "creator_test":
        return False
    ticks, laps = result
    bests = session.execute(select(PersonalBest.time_ticks, LapPersonalBest.time_ticks)
        .join(LapPersonalBest, (LapPersonalBest.board_id == PersonalBest.board_id)
              & (LapPersonalBest.player_id == PersonalBest.player_id))
        .where(PersonalBest.board_id == board.id, PersonalBest.player_id == ticket.player_id)
        .with_for_update(read=True, of=(PersonalBest, LapPersonalBest))).first()
    if bests is None or ticks < bests[0] or min(laps[1:]) < bests[1]:
        return False
    rivalry = session.get(RivalryTicket, ticket.id)
    if rivalry is not None:
        group = session.scalar(select(RivalryGroup).where(RivalryGroup.id == rivalry.group_id).with_for_update())
        best = session.get(RivalryBest, (rivalry.group_id, ticket.player_id, rivalry.slot))
        if group is None or best is None or ticks < best.time_ticks:
            return False
    binding = session.get(ChallengeTicket, ticket.id)
    if binding is not None:
        challenge = session.scalar(select(Challenge).where(Challenge.id == binding.challenge_id).with_for_update())
        if challenge is None:
            return False
        if challenge.is_series:
            stage = session.get(ChallengeStageTicket, ticket.id)
            best = session.get(ChallengeStageMember, (challenge.id, stage.ordinal, ticket.player_id)) if stage else None
        else:
            best = session.get(ChallengeMember, (challenge.id, ticket.player_id))
        if best is None or best.time_ticks is None or ticks < best.time_ticks:
            return False
    return True


def complete(session, ticket, board, replay_hash, replay, result, *, run=None):
    """No queue reservation, geometry, trajectory check, ghost or PB write."""
    from .challenges import accept_verified as challenge_outcome
    from .economy import accept_verified as award_completion
    from .race_acceptance import Acceptance
    from .rivalry import accept_verified as rivalry_outcome

    ticks, laps = result
    if run is None:
        run = Run(ticket_id=ticket.id, player_id=ticket.player_id, board_id=board.id,
                  replay_hash=replay_hash, attempts=0)
        session.add(run)
    else:
        run.attempts = max(0, run.attempts-1)  # This claim did not invoke verification.
    run.status, run.time_ticks, run.lap_ticks = "skipped", ticks, laps
    run.finished_at, run.failure_code, run.lease_token, run.lease_until = now(), None, None, 0
    session.flush()  # Verified-only SQL projections do not consume this status.
    acceptance = Acceptance.load(session, run)
    rivalry_outcome(session, run, acceptance=acceptance)
    challenge_outcome(session, run, acceptance=acceptance)
    award_completion(session, run, acceptance.previous, acceptance=acceptance,
                     incident_free=clean_race_report(replay["race_proof"], ticks))
    return run


def skip_claimed(app, run_id, token, replay):
    """A queued improvement may become redundant before its worker runs."""
    from .identity_models import Player
    from .track_models import Board, OperationState, RunTicket

    result = candidate(replay)
    if result is None:
        return False
    with app.state.session_factory() as session:
        player_id = session.scalar(select(Run.player_id).where(Run.id == run_id))
        player = session.scalar(select(Player).where(Player.id == player_id).with_for_update())
        run = session.scalar(select(Run).where(Run.id == run_id).with_for_update())
        if (player is None or player.disabled or player.deleted_at is not None or run is None
                or run.status != "verifying" or run.lease_token != token or run.lease_until <= now()):
            return False
        board = session.get(Board, run.board_id)
        if (player.is_test_driver or board.manifest.get("test_population")) and not app.state.settings.test_drivers_enabled:
            return False
        ticket = session.get(RunTicket, run.ticket_id)
        if not no_improvement(session, ticket, board, result):
            return False
        if session.get(OperationState, "verify:"+run.id) is not None:
            return False  # Explicit competitive reuse must check the original path.
        complete(session, ticket, board, run.replay_hash, replay, result, run=run)
        session.commit()
        return True
