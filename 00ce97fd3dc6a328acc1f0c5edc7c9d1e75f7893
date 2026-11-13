"""Fresh bounded read sets; only derived presentation bytes may be reused."""
import hashlib
import json

from fastapi import HTTPException
from fastapi.responses import JSONResponse, Response
from sqlalchemy import func, literal, select

from .community import blocked_ids
from .identity_models import Player
from .rivalry_models import RivalryArchivedBest, RivalryBest, RivalryMember, RivalryTicket
from .storage import canonical_json
from .track_models import Run, Track, TrackVersion, digest


def read_snapshot(session, group, player_id, timestamp):
    """Read all mutable inputs in the caller's existing board-read transaction.

    No entity, query result or permission is cached. This also avoids per-track
    version/owner lookups. Plain values define the complete presentation key.
    """
    players = [{"id": pid, "name": name, "is_test_driver": synthetic,
                "country_code": country, "appearances": appearances if deleted is None else {}}
               for pid, name, synthetic, country, appearances, deleted in session.execute(
                   select(Player.id, Player.display_name, Player.is_test_driver, Player.country_code,
                          Player.vehicle_appearances, Player.deleted_at).join(RivalryMember)
                   .where(RivalryMember.group_id == group.id, Player.disabled.is_(False)).order_by(Player.id))]
    model = RivalryArchivedBest if group.archived else RivalryBest
    bests = [{"slot": slot, "id": pid, "ticks": ticks, "run_id": run_id}
             for slot, pid, ticks, run_id in session.execute(
                 select(model.slot, model.player_id, model.time_ticks, getattr(model, "run_id", literal(None)))
                 .where(model.group_id == group.id).order_by(model.slot, model.player_id))]
    blocked = sorted(session.scalars(blocked_ids(session, player_id)))
    pending = session.scalar(select(func.count()).select_from(Run)
        .join(RivalryTicket, RivalryTicket.ticket_id == Run.ticket_id)
        .where(RivalryTicket.group_id == group.id, Run.status.in_(("queued", "verifying"))))
    state = "active" if timestamp < group.ends_at else "settling" if pending else "complete"
    personal_best_slots = []
    if state == "complete":
        personal_best_slots = sorted(session.scalars(select(RivalryTicket.slot)
            .join(Run, Run.ticket_id == RivalryTicket.ticket_id)
            .where(RivalryTicket.group_id == group.id, Run.player_id == player_id, Run.status == "verified",
                   RivalryTicket.outcome["personal_best"].as_boolean().is_(True)).distinct()))
    versions = {vid: {"available": published and not hidden and not disabled,
                      "owner_id": owner_id, "deleted_at": deleted, "content_hash": content_hash,
                      "redacted_track_hash": redacted, "canonical_track_hash": canonical}
                for vid, published, hidden, disabled, owner_id, deleted, content_hash, redacted, canonical
                in session.execute(select(TrackVersion.id, TrackVersion.state == "published", Track.hidden,
                    Player.disabled, Track.owner_id, Player.deleted_at, TrackVersion.content_hash,
                    TrackVersion.redacted_track_hash, TrackVersion.manifest["track_content_hash"].as_string())
                    .select_from(TrackVersion)
                    .join(Track).join(Player, Player.id == Track.owner_id)
                    .where(TrackVersion.id.in_([item["version_id"] for item in group.tracks])))}
    return {"players": players, "bests": bests, "blocked": blocked, "pending": pending,
            "state": state, "personal_best_slots": personal_best_slots, "versions": versions}


def response(request, session, group, player_id, timestamp):
    from .rivalry import snapshot

    facts = read_snapshot(session, group, player_id, timestamp)
    key = ("rivalry", player_id, digest({"facts": facts, "group": {
        "id": group.id, "tracks": group.tracks, "week_start": group.week_start,
        "ends_at": group.ends_at, "vehicle_id": group.vehicle_id, "skill_band": group.skill_band,
        "world_circuit_id": group.world_circuit_id, "test_population": group.test_population,
        "archived": group.archived}}))

    def prepare():
        value = snapshot(session, group, player_id, timestamp, facts=facts)
        return canonical_json({k: v for k, v in value.items() if k not in ("server_now", "remaining_seconds")})

    cache = getattr(request.app.state, "immutable_payloads", None)
    try:
        body = cache.get(key, prepare) if cache is not None else prepare()
    except HTTPException as error:
        if error.status_code != 503:
            raise
        body = prepare()  # An optional representation cache cannot deny a standings read.
    tag = '"' + hashlib.sha256(body).hexdigest() + '"'
    headers = {"ETag": tag, "Cache-Control": "private, no-cache, must-revalidate",
               "Vary": "Authorization, Accept-Encoding", "X-Server-Time": str(timestamp)}
    if request.headers.get("if-none-match") == tag:
        return Response(status_code=304, headers=headers)
    return JSONResponse({**json.loads(body), "server_now": timestamp,
                         "remaining_seconds": max(0, group.ends_at - timestamp)}, headers=headers)
