"""Bounded multi-track stages. One invitation, membership and reward identity."""
from fastapi import HTTPException
from sqlalchemy import select, update

from .challenge_models import ChallengeMember, ChallengeStage, ChallengeStageMember, ChallengeStageTicket
from .identity_models import Player
from .track_models import Board, Track, TrackVersion


def stages(session, challenge):
    return session.scalars(select(ChallengeStage).where(
        ChallengeStage.challenge_id == challenge.id).order_by(ChallengeStage.ordinal)).all()


def check_tracks(session, challenge, player_id="", request=None):
    from .challenges import compatible
    from .community import check_creator
    from .tracks import published_version
    pinned_stages = stages(session, challenge)
    if len(pinned_stages) != challenge.track_count:
        raise HTTPException(404, "Challenge tracks unavailable")
    for stage in pinned_stages:
        board = session.get(Board, stage.board_id)
        version = published_version(session, board.version_id)
        track = session.get(Track, version.track_id)
        if track.hidden or track.archived:
            raise HTTPException(404, "Challenge track unavailable")
        check_creator(session, player_id, track.owner_id)
        if request:
            compatible(request, board.manifest)


def add_member(session, challenge, player_id, source=None):
    for stage in stages(session, challenge):
        opening = source if stage.ordinal == 0 else None
        session.add(ChallengeStageMember(challenge_id=challenge.id, ordinal=stage.ordinal, player_id=player_id,
            attempts_used=1 if opening else 0, run_id=opening.id if opening else None,
            time_ticks=opening.time_ticks if opening else None))
    session.flush()


def decorate(session, request, challenge, value, player_id):
    from .tracks import track_payload
    members = session.execute(select(ChallengeStageMember, Player).join(Player).where(
        ChallengeStageMember.challenge_id == challenge.id)).all()
    all_members = [row for row, _ in members]
    players = {player.id: player for _, player in members}
    value["stages"] = []
    for stage in stages(session, challenge):
        board = session.get(Board, stage.board_id)
        version = session.get(TrackVersion, board.version_id)
        track = session.get(Track, version.track_id)
        own = next((row for row in all_members if row.ordinal == stage.ordinal and row.player_id == player_id), None)
        times = sorted(row.time_ticks for row in all_members if row.ordinal == stage.ordinal and row.time_ticks is not None
                       and not players[row.player_id].disabled and not players[row.player_id].is_test_driver)
        rows = []
        for row in all_members:
            player = players[row.player_id]
            if row.ordinal != stage.ordinal or player.disabled or player.is_test_driver:
                continue
            rows.append({"id": player.id, "name": player.display_name, "ticks": row.time_ticks, "run_id": row.run_id,
                "ms": round(row.time_ticks*1000/board.manifest["tick_rate"]) if row.time_ticks else None,
                "rank": 1+sum(t < row.time_ticks for t in times) if row.time_ticks else None})
        value["stages"].append({"index": stage.ordinal, "manifest": board.manifest,
            "entry": track_payload(version, track, session.get(Player, track.owner_id).display_name,
                                   request.app.state.settings.public_base_url),
            "attempt_limit": challenge.attempt_limit, "attempts_used": own.attempts_used if own else 0,
            "attempts_remaining": (challenge.attempt_limit-(own.attempts_used if own else 0)
                                   if challenge.attempt_limit is not None else None),
            "standings": sorted(rows, key=lambda row: (row["ticks"] is None, row["ticks"] or 0, row["id"]))})
    for row in value["standings"]:
        row["completed_tracks"] = sum(m.time_ticks is not None for m in all_members if m.player_id == row["id"])
    # Top-level budget is total starts across the series; each stage retains its own budget.
    member = session.get(ChallengeMember, (challenge.id, player_id)) if player_id else None
    limit = challenge.attempt_limit * challenge.track_count if challenge.attempt_limit is not None else None
    used = member.attempts_used if member else 0
    value.update(attempt_limit=limit, attempts_used=used,
                 attempts_remaining=limit-used if limit is not None else None, scoring="total_best_time")
    return value


def reserve(session, challenge, player_id, ordinal):
    stage = session.get(ChallengeStage, (challenge.id, ordinal))
    if stage is None:
        raise HTTPException(422, "Choose one of the challenge tracks")
    reservation = update(ChallengeStageMember).where(
        ChallengeStageMember.challenge_id == challenge.id, ChallengeStageMember.ordinal == ordinal,
        ChallengeStageMember.player_id == player_id)
    if challenge.attempt_limit is not None:
        reservation = reservation.where(ChallengeStageMember.attempts_used < challenge.attempt_limit)
    reserved = session.execute(reservation.values(attempts_used=ChallengeStageMember.attempts_used+1)).rowcount
    if not reserved:
        raise HTTPException(409, "No tries remaining on this track")
    return session.get(Board, stage.board_id), session.get(ChallengeStageMember, (challenge.id, ordinal, player_id))


def accept(session, challenge, binding, run, member):
    stage_ticket = session.get(ChallengeStageTicket, run.ticket_id)
    stage = session.get(ChallengeStage, (challenge.id, stage_ticket.ordinal)) if stage_ticket else None
    own = session.get(ChallengeStageMember, (challenge.id, stage.ordinal, run.player_id)) if stage else None
    if own is None or stage.board_id != run.board_id:
        binding.outcome = {"counted": False}
        return
    prior = own.time_ticks
    improved = run.status != "skipped" and (prior is None or run.time_ticks < prior)
    if improved:
        own.time_ticks, own.run_id = run.time_ticks, run.id
    session.flush()
    bests = session.scalars(select(ChallengeStageMember).where(
        ChallengeStageMember.challenge_id == challenge.id, ChallengeStageMember.player_id == run.player_id)).all()
    if run.status != "skipped" and all(row.time_ticks is not None for row in bests) and len(bests) == challenge.track_count:
        member.time_ticks = sum(row.time_ticks for row in bests)
        member.run_id = run.id
    session.flush()
    from .challenges import standings
    rows = standings(session, challenge)
    aggregate = next(row for row in rows if row["id"] == run.player_id)
    board = session.get(Board, stage.board_id)
    binding.outcome = {"counted": True, "improved": improved, "before_ticks": prior, "after": aggregate,
        "stage_index": stage.ordinal, "completed_tracks": sum(row.time_ticks is not None for row in bests),
        "ms": round(run.time_ticks*1000/board.manifest["tick_rate"]), "gap_ms": None,
        "beaten": aggregate["ticks"] is not None and any(row["ticks"] is not None and row["id"] != run.player_id for row in rows)
                  and all(row["ticks"] is None or row["id"] == run.player_id or aggregate["ticks"] < row["ticks"] for row in rows)}
