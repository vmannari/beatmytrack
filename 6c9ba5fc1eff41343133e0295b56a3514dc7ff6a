"""Bounded profile breakdowns from one published multi-car generation."""
from collections import defaultdict

from fastapi import HTTPException
from sqlalchemy import select

from .community import blocked_ids
from .identity_models import Player
from .world_ranking_car_models import CarAward, CarStanding
from .world_ranking_car_rules import CARS, car_key, histories_at_risk, overall
from .world_ranking_models import (
    Circuit,
    RankingAward,
    RankingCareer,
    RankingPlayer,
    RankingSnapshot,
    RankingStanding,
)
from .world_ranking_rules import WEEK, counting


def profile(db, control, snapshot, player_id, viewer, launch, vehicle_id):
    from .world_ranking import _metadata
    result = _metadata(db, control, snapshot, launch, vehicle_id)
    result.pop("items")
    result.update(world_rank=None, country_rank=None, points=0, movement=None, results=[], cars=[],
        career={}, points_at_risk=0, earned=0, net_change=0, season_points=0, season_rank=None)
    target = db.get(Player, player_id)
    if target is None or target.disabled or target.deleted_at is not None or target.is_test_driver:
        raise HTTPException(404, "Player unavailable")
    if player_id in set(db.scalars(blocked_ids(db, viewer))):
        raise HTTPException(403, "PLAYER_BLOCKED")
    key = db.scalar(select(RankingPlayer.key).where(RankingPlayer.player_id == player_id))
    if key is None:
        result["state"] = "unranked"
        return result
    window = (snapshot.week_start - 25 * WEEK, snapshot.week_start)
    records = defaultdict(list)
    for car, week, points, place in db.execute(select(CarAward.vehicle_id, Circuit.week_start, CarAward.points, CarAward.weekly_place)
            .join(Circuit, Circuit.id == CarAward.circuit_id).where(CarAward.branch_id == snapshot.branch_id,
                CarAward.player_key == key, Circuit.week_start.between(*window))
            .order_by(Circuit.week_start.desc(), CarAward.vehicle_id).limit(26 * len(CARS))):
        records[car].append((week, points, place))
    for week, points, place in db.execute(select(Circuit.week_start, RankingAward.points, RankingAward.weekly_place)
            .join(RankingAward, RankingAward.circuit_id == Circuit.id).where(RankingAward.branch_id == snapshot.branch_id,
                RankingAward.player_key == key, Circuit.week_start.between(*window)).limit(26)):
        records["compact"].append((week, points, place))
    rows = list(db.scalars(select(CarStanding).where(CarStanding.snapshot_id == snapshot.id,
        CarStanding.player_key == key).limit(len(CARS))))
    score_rows = [(r.vehicle_id, r.total, car_key(records[r.vehicle_id])[1]) for r in rows]
    _, _, contributions = overall(score_rows)
    weights = {r["vehicle_id"]: r["weight"] for r in contributions}
    for row in sorted(rows, key=lambda r: (-r.total, r.vehicle_id)):
        result["cars"].append({"vehicle_id": row.vehicle_id, "points": row.total, "world_rank": row.world_rank,
            "season_points": row.season_points, "season_rank": row.season_rank,
            "counting_weight": weights.get(row.vehicle_id, 0),
            "contribution_hundredths": row.total * weights.get(row.vehicle_id, 0)})
    model = RankingStanding if vehicle_id == "overall" else CarStanding
    identity = (snapshot.id, key) if vehicle_id == "overall" else (snapshot.id, vehicle_id, key)
    standing = db.get(model, identity)
    if standing and standing.world_rank is not None:
        result.update(world_rank=standing.world_rank, country_rank=standing.country_rank, points=standing.total,
            season_points=standing.season_points, season_rank=standing.season_rank, country=standing.country)
    else:
        result["state"] = "unranked"
    if vehicle_id != "overall":
        history = records[vehicle_id]
        chosen = counting(history)
        result["results"] = [{"week_start": w, "points": p, "weekly_place": place, "counting": (w, p, place) in chosen}
            for w, p, place in sorted(history, reverse=True)]
        result["earned"] = next((r[1] for r in history if r[0] == snapshot.week_start), 0)
        result["points_at_risk"] = histories_at_risk(history, snapshot.week_start)
    else:
        expired = [(car, *car_key([r for r in history if r[0] > window[0]])) for car, history in records.items()]
        result["points_at_risk"] = max(0, result["points"] - overall(expired)[0])
        result["earned"] = sum(next((r[1] for r in history if r[0] == snapshot.week_start), 0) * weights.get(car, 0)
            for car, history in records.items()) // 100
        career = db.scalar(select(RankingCareer).where(RankingCareer.branch_id == snapshot.branch_id,
            RankingCareer.player_key == key, RankingCareer.generation <= snapshot.id)
            .order_by(RankingCareer.generation.desc()).limit(1))
        if career:
            result["career"] = {name: getattr(career, name) for name in
                ("peak_rank", "peak_week", "peak_field", "weeks_top100", "weeks_no1", "victories", "season_titles")}
    previous_identity = (control.previous_id, key) if vehicle_id == "overall" else (control.previous_id, vehicle_id, key)
    previous = db.get(model, previous_identity) if control.previous_id else None
    if previous is None and vehicle_id == "compact" and control.previous_id:
        old_snapshot = db.get(RankingSnapshot, control.previous_id)
        if db.get(Circuit, old_snapshot.circuit_id).policy == "compact-circuit-v1":
            previous = db.get(RankingStanding, (control.previous_id, key))
    result["net_change"] = result["points"] - (previous.total if previous else 0)
    if previous and previous.world_rank is not None and standing and standing.world_rank is not None:
        result["movement"] = previous.world_rank - standing.world_rank
    return result
