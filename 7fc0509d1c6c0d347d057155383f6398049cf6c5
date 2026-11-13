"""Bounded multi-car settlement, sharing the existing lease and publication fence."""
import base64
from collections import defaultdict

from sqlalchemy import BigInteger, Integer, case, cast, func, insert, literal, select

from .identity_models import Player
from .rivalry_models import RivalryBest
from .world_ranking_car_models import (
    CarAward,
    CarCircuit,
    CarEntry,
    CarInput,
    CarPlace,
    CarStanding,
    CarWeek,
    CarWeekly,
    CarWork,
)
from .world_ranking_car_rules import CARS, POLICY, car_key, evidence, overall, strength, update_rating
from .world_ranking_models import (
    Circuit,
    RankingArchive,
    RankingAward,
    RankingCorrection,
    RankingPlayer,
    RankingStanding,
    RankingWork,
)
from .world_ranking_rules import RESULT, WEEK, WORLD, season_start


def _advance(branch, phase):
    branch.phase, branch.cursor, branch.part = phase, 0, 0


def _excluded(db, circuit, car):
    return set(db.scalars(select(RankingCorrection.player_key).where(
        RankingCorrection.circuit_id == circuit.id, RankingCorrection.vehicle_id.in_(("", car)))))


def _seeds(db, previous, keys):
    rows = defaultdict(dict)
    if previous:
        for row in db.scalars(select(CarStanding).where(CarStanding.snapshot_id == previous, CarStanding.player_key.in_(keys))):
            rows[row.player_key][row.vehicle_id] = row
    return rows


def _seed(row, previous, week):
    known = [r for r in previous.values() if r.rated_weeks > 0 and r.last_rated_week >= week - 25 * WEEK]
    own = next((r for r in known if r.vehicle_id == row["vehicle_id"]), None)
    denominator = sum(min(r.rated_weeks, 8) for r in known)
    shared = sum(r.rating * min(r.rated_weeks, 8) for r in known) // denominator if denominator else 1500
    weeks = own.rated_weeks if own else 0
    count = min(weeks, 8)
    # Borrow evidence while a car is provisional. An established specialty must
    # not be repeatedly pulled toward the driver's average in other cars.
    prior = (own.rating * count + shared * (8-count)) // 8 if own else shared
    # A driver first trying a car is not established opposition in that car.
    confidence = min(weeks, 8)
    row.update(rating=prior, rated_weeks=weeks, strength_rating=1500 + (prior - 1500) * confidence // 8)
    return row


def _freeze(db, branch, snapshot, circuit, car, batch, blobs):
    from .world_ranking_build import _archive_read, _country, _lock
    excluded = _excluded(db, circuit, car)
    values = []
    finished = 0 in excluded
    if not finished and branch.mode == "rebuild":
        archive = db.get(RankingArchive, (circuit.original_snapshot, "car" + str(CARS.index(car)), branch.part))
        if archive is None:
            finished = True
        else:
            db.commit()
            packed = _archive_read(blobs, archive, RESULT, vehicle_id=car)
            branch = _lock(db, branch.id, branch.lease_token)
            values = [{"snapshot_id": snapshot.id, "vehicle_id": car, "player_key": r[0],
                       **{f"t{s}": r[s + 1] for s in range(5)}, "country": _country(r[8])}
                      for r in packed if r[0] not in excluded]
            branch.part += 1
    elif not finished:
        entries = list(db.execute(select(CarEntry.player_key, CarEntry.group_id).where(
            CarEntry.circuit_id == circuit.id, CarEntry.vehicle_id == car, CarEntry.player_key > branch.cursor)
            .order_by(CarEntry.player_key).limit(batch)))
        if not entries:
            finished = True
        else:
            last = entries[-1].player_key
            ticks = [func.max(case((RivalryBest.slot == s, RivalryBest.time_ticks))) for s in range(5)]
            rows = db.execute(select(CarEntry.player_key, Player.country_code, *ticks).select_from(CarEntry)
                .join(RankingPlayer, RankingPlayer.key == CarEntry.player_key).join(Player, Player.id == RankingPlayer.player_id)
                .join(RivalryBest, (RivalryBest.group_id == CarEntry.group_id) & (RivalryBest.player_id == Player.id))
                .where(CarEntry.circuit_id == circuit.id, CarEntry.vehicle_id == car,
                    CarEntry.player_key > branch.cursor, CarEntry.player_key <= last, Player.is_test_driver.is_(False))
                .group_by(CarEntry.player_key, Player.country_code).having(func.count(RivalryBest.slot) == 5))
            values = [{"snapshot_id": snapshot.id, "vehicle_id": car, "player_key": r[0], "country": r[1],
                       **{f"t{s}": r[s + 2] for s in range(5)}} for r in rows if r[0] not in excluded]
            branch.cursor = last
    if values:
        seeds = _seeds(db, snapshot.previous_id, [r["player_key"] for r in values])
        db.execute(insert(CarInput), [_seed(r, seeds[r["player_key"]], snapshot.week_start) for r in values])
    if finished:
        event = db.get(CarCircuit, (circuit.id, car))
        size = db.scalar(select(func.count()).select_from(CarInput).where(CarInput.snapshot_id == snapshot.id, CarInput.vehicle_id == car))
        db.add(CarWeek(snapshot_id=snapshot.id, vehicle_id=car, field_size=size,
            participation_bps=event.participation_bps if event else 10000))
        index = CARS.index(car)
        if index + 1 < len(CARS):
            _advance(branch, "m_freeze:" + str(index + 1))
        else:
            snapshot.field_size = db.scalar(select(func.count(func.distinct(CarInput.player_key))).where(CarInput.snapshot_id == snapshot.id))
            _advance(branch, "m_track:0")


def _combine(db, branch, snapshot, batch):
    keys = list(db.scalars(select(CarInput.player_key).where(CarInput.snapshot_id == snapshot.id,
        CarInput.player_key > branch.cursor).distinct().order_by(CarInput.player_key).limit(batch)))
    if not keys:
        _advance(branch, "m_weekly:0")
        return
    places = defaultdict(list)
    for car, key, place in db.execute(select(CarPlace.vehicle_id, CarPlace.player_key, CarPlace.place2).where(
            CarPlace.snapshot_id == snapshot.id, CarPlace.player_key > branch.cursor, CarPlace.player_key <= keys[-1])):
        places[(car, key)].append(place)
    values = []
    for (car, key), ranks in places.items():
        ordered = sorted(ranks)
        if len(ordered) != 5:
            raise ValueError("Incomplete car classification")
        values.append({"snapshot_id": snapshot.id, "vehicle_id": car, "player_key": key,
            "sum2": sum(ordered), **{f"k{s}": ordered[s] for s in range(5)}})
    db.execute(insert(CarWeekly), values)
    branch.cursor = keys[-1]


def _weekly(db, branch, snapshot, circuit, car):
    week = db.get(CarWeek, (snapshot.id, car))
    week.rating_histogram = [list(r) for r in db.execute(select(CarInput.rating, func.count()).where(
        CarInput.snapshot_id == snapshot.id, CarInput.vehicle_id == car).group_by(CarInput.rating))]
    rating_sum = db.scalar(select(func.sum(CarInput.strength_rating)).where(CarInput.snapshot_id == snapshot.id, CarInput.vehicle_id == car)) or 0
    week.strength_bps = strength((rating_sum, week.field_size))
    order = [CarWeekly.sum2, *[getattr(CarWeekly, f"k{s}") for s in range(5)]]
    source = select(CarWeekly.player_key.label("player_key"), func.rank().over(order_by=order).label("place"),
        func.count().over(partition_by=order).label("tied")).where(CarWeekly.snapshot_id == snapshot.id, CarWeekly.vehicle_id == car).subquery()
    # Base awards are unscaled here: the single evidence/strength/participation
    # expression below replaces v1's embedded small-population scaling.
    q = literal(56250000, type_=BigInteger) // (cast(source.c.place, BigInteger) + 96)
    root = func.floor(func.sqrt(q))
    tail = case(((root + 1) * (root + 1) <= q, root + 1), (root * root > q, root - 1), else_=root)
    base = case((source.c.place == 1, 1000), (source.c.place == 2, 850), (source.c.place == 3, 775), else_=tail)
    factor = literal(evidence(week.field_size) * week.strength_bps * week.participation_bps, type_=BigInteger)
    points = cast(base * factor // 1000000000000, Integer)
    points = case((week.field_size < 2, 0), (points < 1, 1), else_=points)
    db.execute(insert(CarAward).from_select(["branch_id", "circuit_id", "vehicle_id", "player_key", "weekly_place", "tie_count", "points", "rating", "rated_weeks"],
        select(literal(branch.id), literal(circuit.id), literal(car), source.c.player_key, source.c.place,
            source.c.tied, points, literal(1500), literal(0))))
    _advance(branch, "m_skills:" + str(CARS.index(car)))


def _skills(db, branch, snapshot, circuit, car, batch):
    rows = list(db.execute(select(CarAward, CarInput).join(CarInput,
        (CarInput.snapshot_id == snapshot.id) & (CarInput.vehicle_id == CarAward.vehicle_id) & (CarInput.player_key == CarAward.player_key))
        .where(CarAward.branch_id == branch.id, CarAward.circuit_id == circuit.id, CarAward.vehicle_id == car,
            CarAward.player_key > branch.cursor).order_by(CarAward.player_key).limit(batch)))
    if not rows:
        _advance(branch, "m_archive:" + str(CARS.index(car)))
        return
    week = db.get(CarWeek, (snapshot.id, car))
    histogram = dict(week.rating_histogram)
    field = week.field_size
    for awarded, seed in rows:
        awarded.rating, awarded.rated_weeks = update_rating(seed.rating, seed.rated_weeks,
            awarded.weekly_place, awarded.tie_count, field, histogram)
    branch.cursor = rows[-1][0].player_key


def _archive(db, branch, snapshot, circuit, car, batch, blobs):
    from .world_ranking_build import _country, _lock
    rows = list(db.execute(select(CarInput, CarAward).join(CarAward,
        (CarAward.branch_id == branch.id) & (CarAward.circuit_id == circuit.id)
        & (CarAward.vehicle_id == CarInput.vehicle_id) & (CarAward.player_key == CarInput.player_key))
        .where(CarInput.snapshot_id == snapshot.id, CarInput.vehicle_id == car, CarInput.player_key > branch.cursor)
        .order_by(CarInput.player_key).limit(batch)))
    if not rows:
        index = CARS.index(car)
        _advance(branch, "m_weekly:" + str(index + 1) if index + 1 < len(CARS) else "m_members")
        return
    packed = [(seed.player_key, *[getattr(seed, f"t{s}") for s in range(5)], result.weekly_place,
        result.points, _country(seed.country)) for seed, result in rows]
    payload = {"format": "bmt-ranking-1", "policy": POLICY, "vehicle_id": car, "count": len(packed),
        "data": base64.b64encode(b"".join(RESULT.pack(*r) for r in packed)).decode("ascii")}
    db.commit()
    digest = blobs.put_json(payload)
    branch = _lock(db, branch.id, branch.lease_token)
    db.add(RankingArchive(snapshot_id=snapshot.id, kind="car" + str(CARS.index(car)), part=branch.part,
        digest=digest, first_key=packed[0][0], last_key=packed[-1][0], count=len(packed)))
    branch.part += 1
    branch.cursor = packed[-1][0]


def _members(db, branch, snapshot, circuit, batch):
    previous = list(db.scalars(select(RankingStanding.player_key).where(RankingStanding.snapshot_id == (snapshot.previous_id or 0),
        RankingStanding.player_key > branch.cursor).order_by(RankingStanding.player_key).limit(batch)))
    # Keep recent ability evidence even when the rolling point total reaches zero.
    skills = list(db.scalars(select(CarStanding.player_key).where(CarStanding.snapshot_id == (snapshot.previous_id or 0),
        CarStanding.player_key > branch.cursor).distinct().order_by(CarStanding.player_key).limit(batch)))
    current = list(db.scalars(select(CarAward.player_key).where(CarAward.branch_id == branch.id, CarAward.circuit_id == circuit.id,
        CarAward.player_key > branch.cursor).distinct().order_by(CarAward.player_key).limit(batch)))
    keys = sorted(set(previous).union(current, skills))[:batch]
    if not keys:
        _advance(branch, "m_countries" if branch.mode == "rebuild" else "m_totals")
        return
    countries = dict(db.execute(select(RankingPlayer.key, Player.country_code).join(Player, Player.id == RankingPlayer.player_id)
        .where(RankingPlayer.key.in_(keys))).all())
    seeds = _seeds(db, snapshot.previous_id, keys)
    current_cars = defaultdict(set)
    for key, car in db.execute(select(CarAward.player_key, CarAward.vehicle_id).where(CarAward.branch_id == branch.id,
            CarAward.circuit_id == circuit.id, CarAward.player_key.in_(keys))):
        current_cars[key].add(car)
    legacy = set(previous) if snapshot.previous_id and not db.scalar(select(CarWeek.snapshot_id).where(CarWeek.snapshot_id == snapshot.previous_id).limit(1)) else set()
    for key in keys:
        db.add(RankingWork(snapshot_id=snapshot.id, player_key=key, country=countries[key], total=0,
            season_points=0, world_key=b"", season_key=b""))
        cars = set(seeds[key]).union(current_cars[key], {"compact"} if key in legacy else set())
        for car in cars:
            old = seeds[key].get(car)
            if old and old.total == 0 and old.last_rated_week < snapshot.week_start - 25 * WEEK and car not in current_cars[key]:
                continue
            db.add(CarWork(snapshot_id=snapshot.id, player_key=key, vehicle_id=car, country=countries[key], total=0,
                season_points=0, world_key=b"", season_key=b"", rating=old.rating if old else 1500,
                rated_weeks=old.rated_weeks if old else 0, last_rated_week=old.last_rated_week if old else 0))
    branch.cursor = keys[-1]


def _countries(db, branch, snapshot, circuit, blobs):
    """A correction preserves the historical country captured in the original publication."""
    from .world_ranking_build import _archive_read, _country, _lock
    archive = db.get(RankingArchive, (circuit.original_snapshot, "world", branch.part))
    if archive is None:
        _advance(branch, "m_totals")
        return
    db.commit()
    rows = _archive_read(blobs, archive, WORLD)
    branch = _lock(db, branch.id, branch.lease_token)
    countries = {r[0]: _country(r[3]) for r in rows}
    members = list(db.scalars(select(RankingWork).where(RankingWork.snapshot_id == snapshot.id,
        RankingWork.player_key.in_(countries))))
    for row in members:
        row.country = countries[row.player_key]
    for row in db.scalars(select(CarWork).where(CarWork.snapshot_id == snapshot.id, CarWork.player_key.in_(countries))):
        row.country = countries[row.player_key]
    branch.part += 1


def _totals(db, branch, snapshot, circuit, control, batch):
    members = list(db.scalars(select(RankingWork).where(RankingWork.snapshot_id == snapshot.id,
        RankingWork.player_key > branch.cursor).order_by(RankingWork.player_key).limit(batch)))
    if not members:
        _advance(branch, "m_standings")
        return
    last = members[-1].player_key
    histories = defaultdict(list)
    window = (snapshot.week_start - 25 * WEEK, snapshot.week_start)
    for pid, car, week, points, place in db.execute(select(CarAward.player_key, CarAward.vehicle_id,
            Circuit.week_start, CarAward.points, CarAward.weekly_place).join(Circuit, Circuit.id == CarAward.circuit_id)
            .where(CarAward.branch_id == branch.id, CarAward.player_key > branch.cursor,
                CarAward.player_key <= last, Circuit.week_start.between(*window))):
        histories[(pid, car)].append((week, points, place))
    # Preserve existing Compact awards across a prospective v1 -> v2 transition.
    for pid, week, points, place in db.execute(select(RankingAward.player_key, Circuit.week_start, RankingAward.points,
            RankingAward.weekly_place).join(Circuit, Circuit.id == RankingAward.circuit_id)
            .where(RankingAward.branch_id == branch.id, RankingAward.player_key > branch.cursor,
                RankingAward.player_key <= last, Circuit.week_start.between(*window))):
        histories[(pid, "compact")].append((week, points, place))
    awards = {(r.player_key, r.vehicle_id): r for r in db.scalars(select(CarAward).where(CarAward.branch_id == branch.id,
        CarAward.circuit_id == circuit.id, CarAward.player_key > branch.cursor, CarAward.player_key <= last))}
    beginning = season_start(snapshot.week_start, control.launch_week)
    competitive = set(db.scalars(select(CarWeek.vehicle_id).where(CarWeek.snapshot_id == snapshot.id, CarWeek.field_size >= 2)))
    cars = defaultdict(list)
    for row in db.scalars(select(CarWork).where(CarWork.snapshot_id == snapshot.id,
            CarWork.player_key > branch.cursor, CarWork.player_key <= last)):
        records = histories[(row.player_key, row.vehicle_id)]
        row.total, row.world_key = car_key(records)
        row.season_points, row.season_key = car_key([r for r in records if r[0] >= beginning], 6)
        result = awards.get((row.player_key, row.vehicle_id))
        if result and result.rated_weeks and row.vehicle_id in competitive:
            row.rating, row.rated_weeks, row.last_rated_week = result.rating, result.rated_weeks, snapshot.week_start
        cars[row.player_key].append(row)
    for member in members:
        rows = cars[member.player_key]
        member.total, member.world_key, _ = overall([(r.vehicle_id, r.total, r.world_key) for r in rows])
        member.season_points, member.season_key, _ = overall([(r.vehicle_id, r.season_points, r.season_key) for r in rows])
    branch.cursor = last


def _standings(db, branch, snapshot):
    # Rank positive points separately; zero-point skill evidence never occupies a place.
    source = select(CarWork.snapshot_id, CarWork.vehicle_id, CarWork.player_key, CarWork.total,
        func.rank().over(partition_by=CarWork.vehicle_id, order_by=CarWork.world_key), CarWork.country,
        case((CarWork.country != "", func.rank().over(partition_by=(CarWork.vehicle_id, CarWork.country), order_by=CarWork.world_key))),
        CarWork.season_points, case((CarWork.season_points > 0, func.rank().over(partition_by=CarWork.vehicle_id, order_by=CarWork.season_key))),
        CarWork.rating, CarWork.rated_weeks, CarWork.last_rated_week).where(CarWork.snapshot_id == snapshot.id, CarWork.total > 0)
    columns = ["snapshot_id", "vehicle_id", "player_key", "total", "world_rank", "country", "country_rank",
        "season_points", "season_rank", "rating", "rated_weeks", "last_rated_week"]
    db.execute(insert(CarStanding).from_select(columns, source))
    zero = select(CarWork.snapshot_id, CarWork.vehicle_id, CarWork.player_key, CarWork.total, literal(None), CarWork.country,
        literal(None), CarWork.season_points, literal(None), CarWork.rating, CarWork.rated_weeks, CarWork.last_rated_week)
    db.execute(insert(CarStanding).from_select(columns, zero.where(CarWork.snapshot_id == snapshot.id, CarWork.total == 0,
        CarWork.last_rated_week >= snapshot.week_start - 25 * WEEK)))
    for week in db.scalars(select(CarWeek).where(CarWeek.snapshot_id == snapshot.id)):
        week.ranked_count = db.scalar(select(func.count()).select_from(CarStanding).where(CarStanding.snapshot_id == snapshot.id,
            CarStanding.vehicle_id == week.vehicle_id, CarStanding.total > 0))
    snapshot.season_qualifying_weeks += int(snapshot.field_size >= 1000)
    from .world_ranking_build import _standings as publish_standings
    publish_standings(db, branch, snapshot)


def advance(db, branch, snapshot, circuit, control, batch, blobs):
    phase, _, argument = branch.phase.partition(":")
    if phase in ("m_combine", "m_members", "m_totals"):
        batch = max(1, batch // len(CARS))  # keep all-car history/model batches within the existing work budget
    car = CARS[int(argument)] if argument else ""
    if phase == "m_freeze":
        _freeze(db, branch, snapshot, circuit, car, batch, blobs)
    elif phase == "m_track":
        slot = int(argument)
        ticks = getattr(CarInput, f"t{slot}")
        place = 2 * func.rank().over(partition_by=CarInput.vehicle_id, order_by=ticks) + func.count().over(partition_by=(CarInput.vehicle_id, ticks)) - 1
        db.execute(insert(CarPlace).from_select(["snapshot_id", "vehicle_id", "slot", "player_key", "place2"],
            select(CarInput.snapshot_id, CarInput.vehicle_id, literal(slot), CarInput.player_key, place).where(CarInput.snapshot_id == snapshot.id)))
        _advance(branch, "m_track:" + str(slot + 1) if slot < 4 else "m_combine")
    elif phase == "m_combine":
        _combine(db, branch, snapshot, batch)
    elif phase == "m_weekly":
        _weekly(db, branch, snapshot, circuit, car)
    elif phase == "m_skills":
        _skills(db, branch, snapshot, circuit, car, batch)
    elif phase == "m_archive":
        _archive(db, branch, snapshot, circuit, car, batch, blobs)
    elif phase == "m_members":
        _members(db, branch, snapshot, circuit, batch)
    elif phase == "m_countries":
        _countries(db, branch, snapshot, circuit, blobs)
    elif phase == "m_totals":
        _totals(db, branch, snapshot, circuit, control, batch)
    elif phase == "m_standings":
        _standings(db, branch, snapshot)
    else:
        raise ValueError("Unknown multi-car phase")
