"""Bounded read-only competition provenance; never invokes verification or scoring writes."""
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request
from sqlalchemy import select, text

from .admin import Access
from .challenge_models import Challenge, ChallengeMember, ChallengeTicket
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .rivalry import POINTS, rankings
from .rivalry_models import RivalryArchivedBest, RivalryBest, RivalryGroup, RivalryMember, RivalryTicket
from .studio import pinned_manifest
from .track_models import Board, Run, RunTicket, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["studio competitions"])


def snapshot(session):
    if session.bind.dialect.name == "postgresql":
        session.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY"))
    else:
        session.execute(text("BEGIN"))


def record(row, fields):
    return {field: getattr(row, field) for field in fields}


@router.get("/v1/admin/competitions")
def list_competitions(request: Request, role: Access, kind: str = "rivalry", limit: int = Query(50, ge=1, le=100)):
    if kind not in ("rivalry", "challenge"):
        raise HTTPException(422, "INVALID_COMPETITION_KIND")
    model, fields = ((RivalryGroup, ("id", "week_start", "ends_at", "vehicle_id", "member_count", "archived"))
        if kind == "rivalry" else (Challenge, ("id", "mode", "created_at", "ends_at", "member_count", "cancelled")))
    with request.app.state.session_factory() as session:
        rows = session.scalars(select(model).order_by(model.created_at.desc(), model.id).limit(limit + 1)).all()
        return {"kind": kind, "items": [record(row, fields) for row in rows[:limit]], "has_more": len(rows) > limit, "role": role}


def proof(run, player_id, board, ticket):
    problems = []
    if run is None:
        return ["SOURCE_RUN_UNAVAILABLE"]
    if run.status != "verified":
        problems.append("SOURCE_NOT_VERIFIED")
    if run.player_id != player_id or board is None or run.board_id != board.id:
        problems.append("SOURCE_CONTRACT_MISMATCH")
    if ticket is None or ticket.player_id != player_id or ticket.board_id != run.board_id:
        problems.append("SOURCE_TICKET_MISMATCH")
    if type(run.time_ticks) is not int or run.time_ticks <= 0:
        problems.append("SOURCE_TIME_UNAVAILABLE")
    return problems


@router.get("/v1/admin/competitions/{kind}/{identity}")
def inspect_competition(kind: str, identity: UUID, request: Request, role: Access):
    if kind not in ("rivalry", "challenge"):
        raise HTTPException(422, "INVALID_COMPETITION_KIND")
    with request.app.state.session_factory() as session:
        snapshot(session)
        entity = session.get(RivalryGroup if kind == "rivalry" else Challenge, str(identity))
        if entity is None:
            raise HTTPException(404, "COMPETITION_NOT_FOUND")
        member_model = RivalryMember if kind == "rivalry" else ChallengeMember
        member_field = member_model.group_id if kind == "rivalry" else member_model.challenge_id
        members = session.execute(select(member_model, Player).join(Player).where(member_field == entity.id)
            .order_by(Player.id).limit(201)).all()
        if len(members) > 200:
            raise HTTPException(409, "COMPETITION_ROSTER_EXCEEDS_INSPECTION_BUDGET")
        if kind == "rivalry":
            if not isinstance(entity.tracks, list) or len(entity.tracks) > 5:
                raise HTTPException(409, "INVALID_PINNED_TRACK_LIST")
            best_model = RivalryArchivedBest if entity.archived else RivalryBest
            bests = list(session.scalars(select(best_model).where(best_model.group_id == entity.id).limit(1001)))
            slots = entity.tracks
            definition = record(entity, ("id", "week_start", "ends_at", "contract_key", "skill_band", "vehicle_id", "archived", "test_population"))
        else:
            bests = [member for member, _player in members if member.time_ticks is not None]
            board = session.get(Board, entity.board_id)
            if board is None:
                raise HTTPException(409, "PINNED_BOARD_UNAVAILABLE")
            slots = [{"board_id": board.id, "version_id": board.version_id, "tick_rate": board.manifest.get("tick_rate")}]
            definition = record(entity, ("id", "board_id", "mode", "ends_at", "cancelled", "target_run_id", "target_ticks"))
            definition.update(attempt_limit=getattr(entity, "attempt_limit", None),
                attempt_limit_available=hasattr(entity, "attempt_limit"))
        if len(bests) > 1000:
            raise HTTPException(409, "COMPETITION_RESULTS_EXCEED_INSPECTION_BUDGET")
        run_ids = {getattr(best, "run_id", None) for best in bests} - {None}
        if kind == "challenge" and entity.target_run_id:
            run_ids.add(entity.target_run_id)
        runs = {row.id: row for row in session.scalars(select(Run).where(Run.id.in_(run_ids)))} if run_ids else {}
        tickets = {row.id: row for row in session.scalars(select(RunTicket).where(RunTicket.id.in_(
            [run.ticket_id for run in runs.values()]))) } if runs else {}
        ticket_model = RivalryTicket if kind == "rivalry" else ChallengeTicket
        bindings = {row.ticket_id: row for row in session.scalars(select(ticket_model).where(
            ticket_model.ticket_id.in_(tickets)))} if tickets else {}
        board_ids = {slot.get("board_id") for slot in slots} | {run.board_id for run in runs.values()}
        boards = {row.id: row for row in session.scalars(select(Board).where(Board.id.in_(board_ids - {None})))}
        roster = {player.id: {"player_id": player.id, "name": player.display_name, "is_test_driver": player.is_test_driver,
            "disabled": player.disabled, "pre_round_skill": getattr(member, "skill", None),
            "attempts_used": getattr(member, "attempts_used", None), "joined_at": member.joined_at,
            "points": 0, "eligible_results": 0} for member, player in members}
        results = []
        for slot_index, slot in enumerate(slots):
            rows = []
            for best in bests:
                if getattr(best, "slot", 0) != slot_index:
                    continue
                player = roster.get(best.player_id)
                if player is None:
                    continue
                run = runs.get(getattr(best, "run_id", None))
                board = boards.get(run.board_id) if run else boards.get(slot.get("board_id"))
                problems = proof(run, best.player_id, board, tickets.get(run.ticket_id) if run else None)
                if board and (board.version_id != slot.get("version_id") or board.id != slot.get("board_id")
                        or kind == "rivalry" and board.vehicle_id != entity.vehicle_id):
                    problems.append("PINNED_VERSION_MISMATCH")
                binding = bindings.get(run.ticket_id) if run else None
                seeded_target = kind == "challenge" and best.player_id == entity.creator_id and run and run.id == entity.target_run_id
                if run and not seeded_target and (binding is None or
                        (kind == "rivalry" and (binding.group_id != entity.id or binding.slot != slot_index)) or
                        (kind == "challenge" and binding.challenge_id != entity.id)):
                    problems.append("COMPETITION_TICKET_MISMATCH")
                if run and not seeded_target and not (getattr(entity, "week_start", entity.created_at) <= run.created_at < entity.ends_at):
                    problems.append("SUBMISSION_OUTSIDE_COMPETITION_WINDOW")
                if run and run.time_ticks != best.time_ticks:
                    problems.append("STORED_BEST_DIFFERS_FROM_SOURCE")
                if player["disabled"] or player["is_test_driver"] and (kind == "challenge" or not entity.test_population):
                    problems.append("PLAYER_NOT_COMPETITIVELY_ELIGIBLE")
                tick_rate = board.manifest.get("tick_rate") if board else None
                if type(tick_rate) is not int or not 0 < tick_rate <= 1000:
                    problems.append("PINNED_TICK_RATE_UNAVAILABLE")
                elif kind == "rivalry" and tick_rate != slot.get("tick_rate"):
                    problems.append("PINNED_TICK_RATE_MISMATCH")
                rows.append({"id": best.player_id, "player_id": best.player_id, "slot": slot_index, "run_id": getattr(best, "run_id", None),
                    "stored_ticks": best.time_ticks, "ticks": run.time_ticks if not problems else None,
                    "seconds": run.time_ticks / tick_rate if not problems and type(tick_rate) is int and tick_rate > 0 else None,
                    "provenance": "accepted_run" if not problems else "unavailable_or_inconsistent",
                    "problems": problems, "evidence_route": "/v1/admin/studio/races/" + run.id if run else None,
                    "manifest": pinned_manifest(board)})
            eligible = [row for row in rows if row["ticks"] is not None]
            rankings(eligible, "ticks")
            stored = [{"id": row["player_id"], "ticks": row["stored_ticks"]} for row in rows
                if not roster[row["player_id"]]["disabled"] and type(row["stored_ticks"]) is int and row["stored_ticks"] > 0]
            rankings(stored, "ticks")
            stored_ranks = {row["id"]: row["rank"] for row in stored}
            for row in rows:
                row.setdefault("rank", None)
                row["rank_from_stored_bests"] = stored_ranks.get(row["player_id"])
                stored_rank = row["rank_from_stored_bests"]
                row["points_from_stored_bests"] = POINTS[stored_rank - 1] if kind == "rivalry" and stored_rank and stored_rank <= len(POINTS) else 0
                row["points"] = POINTS[row["rank"] - 1] if kind == "rivalry" and row["rank"] and row["rank"] <= len(POINTS) else 0
                roster[row["player_id"]]["points"] += row["points"]
                roster[row["player_id"]]["eligible_results"] += int(row["ticks"] is not None)
            results.extend(rows)
        ticket_field = ticket_model.group_id if kind == "rivalry" else ticket_model.challenge_id
        attempts = session.execute(select(Run.status).join(ticket_model, ticket_model.ticket_id == Run.ticket_id)
            .where(ticket_field == entity.id).order_by(Run.created_at, Run.id).limit(501)).all()
        counts = {}
        for (state,) in attempts[:500]:
            counts[state] = counts.get(state, 0) + 1
        target = None
        if kind == "challenge" and entity.target_run_id:
            run = runs.get(entity.target_run_id)
            target = {"run_id": entity.target_run_id, "stored_ticks": entity.target_ticks,
                "problems": proof(run, entity.creator_id, boards.get(entity.board_id), tickets.get(run.ticket_id) if run else None)}
            if entity.mode == "beat" and run and run.time_ticks != entity.target_ticks:
                target["problems"].append("STORED_TARGET_DIFFERS_FROM_SOURCE")
        return {"kind": kind, "definition": definition, "roster": list(roster.values()), "results": results,
            "slot_count": len(slots), "slots": [{"slot": index, **{field: value for field, value in slot.items()
                if field in ("version_id", "board_id", "tick_rate", "name") and type(value) in (str, int)}} for index, slot in enumerate(slots)],
            "target": target, "points_policy": list(POINTS) if kind == "rivalry" else None,
            "attempt_states": counts, "attempts_truncated": len(attempts) > 500,
            "as_of": now(), "role": role, "read_only": True,
            "limits": ["Ranks/points recomputed from linked accepted evidence; inconsistencies do not mutate official results.",
                "Archived timing without a retained run cannot prove original acceptance.",
                "Ghosts and attempt count do not confer score eligibility; no verifier or proof-object reads.",
                "Reward delivery is unavailable; no progression reward is inferred."]}
