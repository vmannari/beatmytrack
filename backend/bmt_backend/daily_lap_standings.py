"""Small pages and nearby flying-lap comparisons from the existing snapshot."""
from bisect import bisect_left, bisect_right

from fastapi import HTTPException
from sqlalchemy import select

from .cursors import decode_cursor, encode_cursor
from .identity_models import Player
from .runs import comparison_statements
from .track_models import digest


def build(session, context, population, player, *, limit, cursor, around, candidate, artificial):
    public_id = digest({"version_id": context["version_id"], **context["manifest"]})
    test_id = digest({"version_id": context["version_id"], **context["manifest"], "test_population": True})
    owner = player.id if player else ""
    own = population.own.get(owner) if population.own is not None else None
    anchor = None
    if cursor:
        anchor = decode_cursor(cursor)
        if (anchor.get("generation") != context["generation"] or anchor.get("board") != public_id
                or anchor.get("day") != context["day"] or type(anchor.get("ticks")) is not int
                or not isinstance(anchor.get("player"), str)):
            raise HTTPException(422, "LAP_STANDINGS_CHANGED")
    if population.own is not None:
        ordered = sorted((ticks, identity) for identity, ticks in population.own.items())
        start = bisect_right(ordered, (anchor["ticks"], anchor["player"])) if anchor else 0
        if around and candidate:
            ordered = [row for row in ordered if row[1] != owner]
            start = max(0, bisect_left(ordered, (candidate, ""))-1)
            rows = ordered[start:start+2]
        else:
            rows = ordered[start:start+limit+1]
        identities = {identity for _, identity in rows} | ({owner} if owner else set())
        names = {row.id: row.display_name for row in session.execute(select(Player.id, Player.display_name).where(
            Player.id.in_(identities), Player.disabled.is_(False), Player.deleted_at.is_(None)))}
        raw = [(ticks, identity, names[identity]) for ticks, identity in rows if identity in names]
    else:
        _, laps = comparison_statements(session, [public_id, test_id] if artificial else [public_id],
                                        public_id, test_id, artificial)
        query = select(laps.c.time_ticks, laps.c.player_id, Player.display_name).join(
            Player, Player.id == laps.c.player_id).where(Player.deleted_at.is_(None))
        if owner:
            own = session.scalar(select(laps.c.time_ticks).where(laps.c.player_id == owner))
        if around and candidate:
            before = session.execute(query.where(laps.c.time_ticks < candidate, laps.c.player_id != owner)
                .order_by(laps.c.time_ticks.desc(), laps.c.player_id.desc()).limit(1)).all()
            after = session.execute(query.where(laps.c.time_ticks >= candidate, laps.c.player_id != owner)
                .order_by(laps.c.time_ticks, laps.c.player_id).limit(1)).all()
            raw = before + after
        else:
            if anchor:
                from sqlalchemy import tuple_
                query = query.where(tuple_(laps.c.time_ticks, laps.c.player_id) > (anchor["ticks"], anchor["player"]))
            raw = session.execute(query.order_by(laps.c.time_ticks, laps.c.player_id).limit(limit+1)).all()
        names = dict(session.execute(select(Player.id, Player.display_name).where(Player.id == owner)).all())
    count = population.cumulative[-1]
    leader = population.ticks[0]

    def row(ticks, identity, name):
        faster = population.cumulative[bisect_left(population.ticks, ticks)]
        if around and candidate and identity != owner:
            faster += int(candidate < ticks) - int(own is not None and own < ticks)
        return {"player_id": identity, "display_name": name, "time_ticks": ticks,
                "rank": max(1, 1+faster),
                "gap_ticks": max(0, ticks-leader)}

    items = [row(*item) for item in raw[:limit]]
    comparison = population.position(candidate, own) if candidate else None
    if candidate and comparison is None:
        comparison = {"position": 1, "population": max(1, count), "top_percent": 1, "candidate_ticks": candidate}
    return {**context, "board_id": public_id, "starts_at": context["day"]*86400,
            "population": comparison["population"] if comparison else count,
            "items": items, "player": row(own, owner, names[owner]) if own and owner in names else None,
            "comparison": comparison,
            "next_cursor": encode_cursor({"generation": context["generation"], "board": public_id,
                "day": context["day"], "ticks": raw[limit-1][0], "player": raw[limit-1][1]})
                if not around and len(raw) > limit else None}
