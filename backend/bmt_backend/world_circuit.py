"""Freeze official per-car lineups and announce population weights before racing."""
from collections import defaultdict
from types import SimpleNamespace

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from .rivalry_models import RivalryTicket, RivalryWeekPlan
from .track_models import Track, TrackVersion
from .world_ranking_car_models import CarCircuit, CarEntry, CarWeek
from .world_ranking_car_rules import PLAYABLE_CARS, participation
from .world_ranking_car_rules import POLICY as MULTI_POLICY
from .world_ranking_models import Circuit, CircuitEntry, RankingPlayer, RankingSnapshot
from .world_ranking_rules import CAR, POLICY, WEEK


def ensure_circuits(db, app, active, timestamp):
    launch = app.state.settings.world_ranking_launch_week
    if not launch:
        return
    from .rivalry import selected_slots, week_window
    from .rivalry_planning import plan_contract
    start = week_window(timestamp)[0]
    opened = set(db.scalars(select(CarCircuit.circuit_id).join(Circuit).where(CarCircuit.weights_locked.is_(True),
        Circuit.week_start.between(max(start, launch), start+4*WEEK))))
    touched = set()
    for car in PLAYABLE_CARS:
        if car not in active.get("vehicles", {}):
            continue
        contract = plan_contract(active, car)
        plans = db.scalars(select(RivalryWeekPlan).where(RivalryWeekPlan.vehicle_id == car,
            RivalryWeekPlan.contract_key == contract, RivalryWeekPlan.week_start >= max(start, launch),
            RivalryWeekPlan.week_start <= start+4*WEEK).order_by(RivalryWeekPlan.week_start).limit(5))
        for plan in plans:
            circuit = db.scalar(select(Circuit).where(Circuit.week_start == plan.week_start))
            if circuit is not None:
                db.scalar(select(Circuit).where(Circuit.id == circuit.id).with_for_update())
                if db.scalar(select(CarCircuit.vehicle_id).where(CarCircuit.circuit_id == circuit.id,
                        CarCircuit.weights_locked.is_(True)).limit(1)):
                    continue
            # An already opened policy/roster/contract cannot change midweek.
            if circuit is not None and (circuit.original_snapshot is not None or
                    (circuit.policy != MULTI_POLICY and plan.week_start <= timestamp) or circuit.id in opened):
                continue
            ids = [row["version_id"] for row in plan.tracks]
            trusted = list(db.scalars(select(TrackVersion.id).join(Track).where(
                TrackVersion.id.in_(ids), Track.official.is_(True))))
            if len(set(trusted)) != 5:
                continue
            slots = selected_slots(db, SimpleNamespace(app=app), active, car, False,
                timestamp=plan.week_start, use_circuit=False)
            if len(slots) != 5:
                continue
            if circuit is None:
                circuit = Circuit(week_start=plan.week_start, contract_key=contract, policy=MULTI_POLICY, tracks=slots)
                db.add(circuit)
                db.flush()
            elif circuit.policy != MULTI_POLICY:
                circuit.policy = MULTI_POLICY
            event = db.get(CarCircuit, (circuit.id, car))
            if event is None:
                db.add(CarCircuit(circuit_id=circuit.id, vehicle_id=car, contract_key=contract, tracks=slots))
            else:
                event.contract_key, event.tracks = contract, slots
            touched.add(circuit.id)
    db.flush()
    for identity in touched:
        circuit = db.get(Circuit, identity)
        if circuit.week_start <= timestamp:
            lock_weights(db, circuit)
    db.flush()


def lock_weights(db, circuit):
    """First current-week admission freezes the same published history for all cars."""
    db.scalar(select(Circuit).where(Circuit.id == circuit.id).with_for_update())
    events = list(db.scalars(select(CarCircuit).where(CarCircuit.circuit_id == circuit.id)
        .execution_options(populate_existing=True)))
    if any(event.weights_locked for event in events):
        return
    weights = announced_weights(db, circuit)
    for event in events:
        event.participation_bps, event.population_units, event.population_snapshot = weights[event.vehicle_id]
        event.weights_locked = True
    db.flush()


def announced_weights(db, circuit):
    """Read-only announcement; first admission stores these exact opening-time inputs."""
    history = defaultdict(dict)
    published = db.scalar(select(RankingSnapshot).where(RankingSnapshot.published_at <= circuit.week_start)
        .order_by(RankingSnapshot.published_at.desc(), RankingSnapshot.id.desc()).limit(1))
    if published:
        for car, week, count in db.execute(select(CarWeek.vehicle_id, RankingSnapshot.week_start, CarWeek.field_size)
                .join(RankingSnapshot, RankingSnapshot.id == CarWeek.snapshot_id)
                .where(RankingSnapshot.branch_id == published.branch_id,
                    RankingSnapshot.week_start.between(circuit.week_start-8*WEEK, min(circuit.week_start-WEEK, published.week_start)))):
            history[car][week] = count
        for week, count in db.execute(select(RankingSnapshot.week_start, RankingSnapshot.field_size)
                .join(Circuit, Circuit.id == RankingSnapshot.circuit_id).where(RankingSnapshot.branch_id == published.branch_id,
                    Circuit.policy == POLICY, RankingSnapshot.week_start.between(circuit.week_start-8*WEEK,
                        min(circuit.week_start-WEEK, published.week_start)))):
            history["compact"][week] = count
    return {event.vehicle_id: (event.participation_bps, event.population_units, event.population_snapshot) if event.weights_locked else (*participation([
        history[event.vehicle_id].get(circuit.week_start-(8-i)*WEEK, 0) for i in range(8)]), published.id if published else None)
        for event in db.scalars(select(CarCircuit).where(CarCircuit.circuit_id == circuit.id))}


def car_event(db, circuit, vehicle):
    if circuit.policy == POLICY:
        return circuit if vehicle == CAR else None
    return db.get(CarCircuit, (circuit.id, vehicle)) if circuit.policy == MULTI_POLICY else None


def official_circuit(db, group):
    if not group.world_circuit_id or group.test_population:
        return None
    circuit = db.get(Circuit, group.world_circuit_id)
    event = car_event(db, circuit, group.vehicle_id) if circuit else None
    if event is None or group.contract_key != event.contract_key:
        return None
    if [r["board_id"] for r in group.tracks] != [r["board_id"] for r in event.tracks]:
        return None
    return circuit


def enter(db, group, player):
    circuit = official_circuit(db, group)
    if circuit is None or player.is_test_driver or player.disabled or player.needs_username:
        return
    insert = pg_insert if db.bind.dialect.name == "postgresql" else sqlite_insert
    db.execute(insert(RankingPlayer).values(player_id=player.id).on_conflict_do_nothing(index_elements=["player_id"]))
    key = db.scalar(select(RankingPlayer.key).where(RankingPlayer.player_id == player.id))
    if circuit.policy == MULTI_POLICY:
        db.execute(insert(CarEntry).values(circuit_id=circuit.id, vehicle_id=group.vehicle_id, player_key=key, group_id=group.id)
            .on_conflict_do_nothing(index_elements=["circuit_id", "vehicle_id", "player_key"]))
    else:
        db.execute(insert(CircuitEntry).values(circuit_id=circuit.id, player_key=key, group_id=group.id)
            .on_conflict_do_nothing(index_elements=["circuit_id", "player_key"]))


def ticket_is_official(db, ticket_id):
    from .rivalry_models import RivalryGroup
    group = db.scalar(select(RivalryGroup).join(RivalryTicket,
        RivalryTicket.group_id == RivalryGroup.id).where(RivalryTicket.ticket_id == ticket_id))
    return group is not None and official_circuit(db, group) is not None
