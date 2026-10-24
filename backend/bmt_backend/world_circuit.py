"""Freeze one public Compact lineup; join work is scoped to the joining account."""
from types import SimpleNamespace

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from .rivalry_models import RivalryTicket, RivalryWeekPlan
from .track_models import Track, TrackVersion
from .world_ranking_models import Circuit, CircuitEntry, RankingPlayer
from .world_ranking_rules import CAR, POLICY, WEEK


def ensure_circuits(db, app, active, timestamp):
    launch = app.state.settings.world_ranking_launch_week
    if not launch or CAR not in active.get("vehicles", {}):
        return
    from .rivalry import selected_slots, week_window
    from .rivalry_planning import plan_contract
    start = week_window(timestamp)[0]
    contract = plan_contract(active, CAR)
    plans = db.scalars(select(RivalryWeekPlan).where(RivalryWeekPlan.vehicle_id == CAR,
        RivalryWeekPlan.contract_key == contract, RivalryWeekPlan.week_start >= max(start, launch),
        RivalryWeekPlan.week_start <= start+4*WEEK).order_by(RivalryWeekPlan.week_start).limit(5))
    for plan in plans:
        circuit = db.scalar(select(Circuit).where(Circuit.week_start == plan.week_start))
        if circuit is not None and plan.week_start <= timestamp:
            continue
        ids = [row["version_id"] for row in plan.tracks]
        # Trusted official launch tracks; do not silently replace a manual plan.
        trusted = list(db.scalars(select(TrackVersion.id).join(Track).where(
            TrackVersion.id.in_(ids), Track.official.is_(True))))
        if len(set(trusted)) != 5:
            continue
        slots = selected_slots(db, SimpleNamespace(app=app), active, CAR, False,
                               timestamp=plan.week_start, use_circuit=False)
        if len(slots) != 5:
            continue
        if circuit is None:
            db.add(Circuit(week_start=plan.week_start, contract_key=contract, policy=POLICY, tracks=slots))
        else:
            circuit.contract_key, circuit.tracks = contract, slots
    db.flush()


def official_circuit(db, group):
    if not group.world_circuit_id or group.test_population or group.vehicle_id != CAR:
        return None
    return db.get(Circuit, group.world_circuit_id)


def enter(db, group, player):
    circuit = official_circuit(db, group)
    if circuit is None or player.is_test_driver or player.disabled or player.needs_username:
        return
    insert = pg_insert if db.bind.dialect.name == "postgresql" else sqlite_insert
    db.execute(insert(RankingPlayer).values(player_id=player.id).on_conflict_do_nothing(index_elements=["player_id"]))
    key = db.scalar(select(RankingPlayer.key).where(RankingPlayer.player_id == player.id))
    db.execute(insert(CircuitEntry).values(circuit_id=circuit.id, player_key=key, group_id=group.id)
        .on_conflict_do_nothing(index_elements=["circuit_id", "player_key"]))


def ticket_is_official(db, ticket_id):
    from .rivalry_models import RivalryGroup
    return db.scalar(select(RivalryGroup.world_circuit_id).join(RivalryTicket,
        RivalryTicket.group_id == RivalryGroup.id).where(RivalryTicket.ticket_id == ticket_id)) is not None
