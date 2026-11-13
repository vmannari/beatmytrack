"""Restartable SQL settlement. Never called by race acceptance or player HTTP reads."""
from __future__ import annotations

import base64
from collections import defaultdict
from itertools import pairwise

from sqlalchemy import (
    BigInteger,
    Integer,
    case,
    cast,
    delete,
    exists,
    func,
    insert,
    literal,
    select,
    text,
    tuple_,
    update,
)

from .identity_models import Player
from .rivalry_models import RivalryBest, RivalryGroup, RivalryTicket
from .track_models import Run, new_id, now
from .world_ranking_car_rules import POLICY as MULTI_POLICY
from .world_ranking_models import (
    Circuit,
    CircuitEntry,
    RankingArchive,
    RankingAward,
    RankingBranch,
    RankingCareer,
    RankingControl,
    RankingCorrection,
    RankingInput,
    RankingPlace,
    RankingPlayer,
    RankingSnapshot,
    RankingStanding,
    RankingWeeklyWork,
    RankingWork,
)
from .world_ranking_rules import POLICY, RESULT, WEEK, WORLD, season_start, sporting_key


class LeaseLost(RuntimeError):
    pass


class CircuitUnavailable(RuntimeError):
    pass


def _available_versions(db, circuit):
    if circuit.policy != MULTI_POLICY:
        versions = [row["version_id"] for row in circuit.tracks]
        if len(versions) != 5 or len(set(versions)) != 5:
            raise CircuitUnavailable("Invalid pinned Circuit lineup")
        return versions
    from .world_ranking_car_models import CarCircuit
    events = list(db.scalars(select(CarCircuit).where(CarCircuit.circuit_id == circuit.id)))
    if not events:
        raise CircuitUnavailable("Pinned car lineups are unavailable")
    voids = set(db.scalars(select(RankingCorrection.vehicle_id).where(
        RankingCorrection.circuit_id == circuit.id, RankingCorrection.player_key == 0)))
    versions = set()
    for event in events:
        if event.vehicle_id in voids:
            continue
        ids = [row["version_id"] for row in event.tracks]
        if len(ids) != 5 or len(set(ids)) != 5:
            raise CircuitUnavailable("Invalid pinned car lineup")
        versions.update(ids)
    return list(versions)


def _lock(db, identity, token):
    row = db.scalar(select(RankingBranch).where(RankingBranch.id == identity,
        RankingBranch.lease_token == token).with_for_update())
    if row is None:
        raise LeaseLost("Ranking generation lease changed")
    return row


def initialize(factory, launch):
    if not launch:
        return
    with factory() as db:
        control = db.get(RankingControl, 1)
        if control is not None:
            if control.launch_week != launch:
                raise ValueError("World Ranking launch is immutable after initialization")
            return
        # A fresh rollout cannot silently award historical races with old resumes.
        from .rivalry import week_window
        if launch < week_window(now())[0]:
            raise ValueError("Declare a prospective World Ranking launch week")
        from sqlalchemy.dialects.postgresql import insert as pg_insert
        from sqlalchemy.dialects.sqlite import insert as sqlite_insert
        dialect_insert = pg_insert if db.bind.dialect.name == "postgresql" else sqlite_insert
        branch = RankingBranch(next_week=launch)
        db.add(branch)
        db.flush()
        result = db.execute(dialect_insert(RankingControl).values(id=1, launch_week=launch,
            published_id=None, running_branch=branch.id).on_conflict_do_nothing(index_elements=["id"]))
        if result.rowcount:
            db.commit()
        else:
            db.rollback()


def _advance(branch, phase):
    branch.phase, branch.cursor, branch.part = phase, 0, 0


def _delete_batch(db, model, criterion, batch):
    keys = list(model.__table__.primary_key.columns)
    rows = select(*keys).where(criterion).order_by(*keys).limit(batch)
    return db.execute(delete(model).where(tuple_(*keys).in_(rows))).rowcount


def _archive_read(blobs, archive, codec, *, vehicle_id=None):
    payload = blobs.get_json(archive.digest)
    if payload.get("format") != "bmt-ranking-1" or payload.get("count") != archive.count or not 0 < archive.count <= 10000:
        raise ValueError("Invalid ranking archive manifest")
    if vehicle_id is not None and (payload.get("policy") != MULTI_POLICY or payload.get("vehicle_id") != vehicle_id):
        raise ValueError("Ranking archive car identity mismatch")
    data = base64.b64decode(payload["data"], validate=True)
    if len(data) != codec.size * archive.count:
        raise ValueError("Truncated ranking archive")
    rows = list(codec.iter_unpack(data))
    if rows[0][0] != archive.first_key or rows[-1][0] != archive.last_key:
        raise ValueError("Ranking archive key range mismatch")
    if any(a[0] >= b[0] for a, b in pairwise(rows)):
        raise ValueError("Ranking archive order mismatch")
    return rows


def _country(data):
    if isinstance(data, str):
        return data.encode("ascii") if len(data) == 2 else b"\0\0"
    return "" if data == b"\0\0" else data.decode("ascii")


def _corrections(db, circuit):
    return set(db.scalars(select(RankingCorrection.player_key).where(
        RankingCorrection.circuit_id == circuit, RankingCorrection.vehicle_id == "")))


def _freeze(db, branch, snapshot, circuit, batch, blobs):
    excluded = _corrections(db, circuit.id)
    if 0 in excluded:
        snapshot.field_size = 0
        _advance(branch, "track0")
        return
    if branch.mode == "rebuild":
        if circuit.original_snapshot is None:
            raise ValueError("Original Circuit archive is unavailable")
        archive = db.get(RankingArchive, (circuit.original_snapshot, "week", branch.part))
        if archive is None:
            snapshot.field_size = db.scalar(select(func.count()).select_from(RankingInput).where(
                RankingInput.snapshot_id == snapshot.id))
            _advance(branch, "track0")
            return
        db.commit()  # release the connection/transaction before object I/O
        rows = _archive_read(blobs, archive, RESULT)
        branch = _lock(db, branch.id, branch.lease_token)
        values = [{"snapshot_id": snapshot.id, "player_key": r[0],
                   **{f"t{s}": r[s+1] for s in range(5)}, "country": _country(r[8])}
                  for r in rows if r[0] not in excluded]
        if values:
            db.execute(insert(RankingInput), values)
        branch.part += 1
        return
    entries = list(db.execute(select(CircuitEntry.player_key, CircuitEntry.group_id, RankingPlayer.player_id)
        .join(RankingPlayer, RankingPlayer.key == CircuitEntry.player_key)
        .where(CircuitEntry.circuit_id == circuit.id, CircuitEntry.player_key > branch.cursor)
        .order_by(CircuitEntry.player_key).limit(batch)))
    if not entries:
        snapshot.field_size = db.scalar(select(func.count()).select_from(RankingInput).where(RankingInput.snapshot_id == snapshot.id))
        _advance(branch, "track0")
        return
    last = entries[-1].player_key
    columns = [func.max(case((RivalryBest.slot == s, RivalryBest.time_ticks))).label(f"t{s}") for s in range(5)]
    query = select(CircuitEntry.player_key, Player.country_code, *columns).select_from(CircuitEntry)
    query = query.join(RankingPlayer, RankingPlayer.key == CircuitEntry.player_key).join(Player,
        Player.id == RankingPlayer.player_id).join(RivalryBest,
        (RivalryBest.group_id == CircuitEntry.group_id) & (RivalryBest.player_id == Player.id))
    rows = db.execute(query.where(CircuitEntry.circuit_id == circuit.id,
        CircuitEntry.player_key > branch.cursor, CircuitEntry.player_key <= last,
        # Entry already proves a registered human at admission. Later account
        # removal redacts identity; only an audited correction changes results.
        Player.is_test_driver.is_(False)).group_by(CircuitEntry.player_key, Player.country_code)
        .having(func.count(RivalryBest.slot) == 5))
    values = [{"snapshot_id": snapshot.id, "player_key": r[0], "country": r[1],
               **{f"t{s}": r[s+2] for s in range(5)}} for r in rows if r[0] not in excluded]
    if values:
        db.execute(insert(RankingInput), values)
    branch.cursor = last


def _combine(db, branch, snapshot, batch):
    first = list(db.scalars(select(RankingInput.player_key).where(RankingInput.snapshot_id == snapshot.id,
        RankingInput.player_key > branch.cursor).order_by(RankingInput.player_key).limit(batch)))
    if not first:
        _advance(branch, "weekly")
        return
    places = defaultdict(list)
    for pid, place in db.execute(select(RankingPlace.player_key, RankingPlace.place2).where(
            RankingPlace.snapshot_id == snapshot.id, RankingPlace.player_key > branch.cursor,
            RankingPlace.player_key <= first[-1])):
        places[pid].append(place)
    values = []
    for pid in first:
        ordered = sorted(places[pid])
        if len(ordered) != 5:
            raise ValueError("Incomplete official track classification")
        values.append({"snapshot_id": snapshot.id, "player_key": pid, "sum2": sum(ordered),
                       **{f"k{s}": ordered[s] for s in range(5)}})
    db.execute(insert(RankingWeeklyWork), values)
    branch.cursor = first[-1]


def _weekly(db, branch, snapshot, circuit):
    order = [RankingWeeklyWork.sum2, *[getattr(RankingWeeklyWork, f"k{s}") for s in range(5)]]
    ranked = select(RankingWeeklyWork.player_key.label("player_key"),
        func.rank().over(order_by=order).label("place")).where(RankingWeeklyWork.snapshot_id == snapshot.id).subquery()
    # Compute exact integer square roots with a corrected bounded floating candidate.
    # q <= 562500; the correction checks the integer square on either side.
    scale = min(max(0, snapshot.field_size-1), 127)
    numerator = literal(56250000 * scale * scale, type_=BigInteger)
    q = (numerator // ((cast(ranked.c.place, BigInteger)+96)*127*127)).label("q")
    source = select(ranked.c.player_key, ranked.c.place, q).subquery()
    root = func.floor(func.sqrt(source.c.q))
    tail = case(((root+1)*(root+1) <= source.c.q, root+1), (root*root > source.c.q, root-1), else_=root)
    podium = case((source.c.place == 1, 1000), (source.c.place == 2, 850), else_=775)
    awarded = case((snapshot.field_size < 2, 0),
        (source.c.place <= 3, (podium*scale)//127), else_=tail)
    awarded = case((snapshot.field_size < 2, 0), (awarded < 1, 1), else_=awarded)
    db.execute(insert(RankingAward).from_select(["branch_id", "circuit_id", "player_key", "weekly_place", "points"],
        select(cast(branch.id, Integer), literal(circuit.id), source.c.player_key,
               source.c.place, awarded)))
    _advance(branch, "week_archive")


def _write_archive(db, branch, snapshot, kind, batch, blobs):
    codec = RESULT if kind == "week" else WORLD
    if kind == "week":
        rows = list(db.execute(select(RankingInput, RankingAward.weekly_place, RankingAward.points)
            .join(RankingAward, (RankingAward.player_key == RankingInput.player_key)
                & (RankingAward.circuit_id == snapshot.circuit_id) & (RankingAward.branch_id == branch.id))
            .where(RankingInput.snapshot_id == snapshot.id, RankingInput.player_key > branch.cursor)
            .order_by(RankingInput.player_key).limit(batch)))
        packed = [(r[0].player_key, *[getattr(r[0], f"t{s}") for s in range(5)], r[1], r[2], _country(r[0].country)) for r in rows]
    else:
        rows = list(db.scalars(select(RankingStanding).where(RankingStanding.snapshot_id == snapshot.id,
            RankingStanding.player_key > branch.cursor).order_by(RankingStanding.player_key).limit(batch)))
        packed = [(r.player_key, r.world_rank, r.total, _country(r.country)) for r in rows]
    if not packed:
        _advance(branch, "members" if kind == "week" else "publish")
        return
    body = b"".join(codec.pack(*r) for r in packed)
    archive_policy = db.get(Circuit, snapshot.circuit_id).policy
    db.commit()
    digest = blobs.put_json({"format": "bmt-ranking-1", "policy": archive_policy,
        "count": len(packed), "data": base64.b64encode(body).decode("ascii")})
    branch = _lock(db, branch.id, branch.lease_token)
    db.add(RankingArchive(snapshot_id=snapshot.id, kind=kind, part=branch.part, digest=digest,
        first_key=packed[0][0], last_key=packed[-1][0], count=len(packed)))
    branch.part += 1
    branch.cursor = packed[-1][0]


def _members(db, branch, snapshot, circuit, blobs, batch):
    if branch.mode == "rebuild":
        archive = db.get(RankingArchive, (circuit.original_snapshot, "world", branch.part))
        if archive is not None:
            db.commit()
            values = _archive_read(blobs, archive, WORLD)
            branch = _lock(db, branch.id, branch.lease_token)
            db.execute(insert(RankingWork), [{"snapshot_id": snapshot.id, "player_key": r[0],
                "country": _country(r[3]), "total": 0, "season_points": 0,
                "world_key": b"", "season_key": b""} for r in values])
            branch.part += 1
            return
    else:
        # A positive total comes from the previous published population or a
        # new award. Scan both indexed streams in bounded chunks; expired-only
        # members are discarded by totals. Avoid DISTINCT over 26*N awards.
        previous = list(db.scalars(select(RankingStanding.player_key).where(
            RankingStanding.snapshot_id == (snapshot.previous_id or 0),
            RankingStanding.player_key > branch.cursor).order_by(RankingStanding.player_key).limit(batch)))
        current = list(db.scalars(select(RankingAward.player_key).where(RankingAward.branch_id == branch.id,
            RankingAward.circuit_id == circuit.id, RankingAward.player_key > branch.cursor,
            RankingAward.points > 0).order_by(RankingAward.player_key).limit(batch)))
        members = sorted(set(previous).union(current))[:batch]
        if not members:
            _advance(branch, "totals")
            return
        db.execute(insert(RankingWork).from_select(["snapshot_id", "player_key", "country", "total", "season_points", "world_key", "season_key"],
            select(literal(snapshot.id), RankingPlayer.key, Player.country_code, literal(0), literal(0), literal(b""), literal(b""))
            .join(Player, Player.id == RankingPlayer.player_id).where(RankingPlayer.key.in_(members))))
        branch.cursor = members[-1]
        return
    _advance(branch, "totals")


def _totals(db, branch, snapshot, control, batch):
    members = list(db.scalars(select(RankingWork).where(RankingWork.snapshot_id == snapshot.id,
        RankingWork.player_key > branch.cursor).order_by(RankingWork.player_key).limit(batch)))
    if not members:
        _advance(branch, "standings")
        return
    histories = defaultdict(list)
    for pid, week, award, place in db.execute(select(RankingAward.player_key, Circuit.week_start,
            RankingAward.points, RankingAward.weekly_place).join(Circuit, Circuit.id == RankingAward.circuit_id)
            .where(RankingAward.branch_id == branch.id, Circuit.week_start.between(snapshot.week_start-25*WEEK, snapshot.week_start),
                RankingAward.player_key > branch.cursor, RankingAward.player_key <= members[-1].player_key)):
        histories[pid].append((week, award, place))
    beginning = season_start(snapshot.week_start, control.launch_week)
    for member in members:
        records = histories[member.player_key]
        member.total, member.world_key = sporting_key(records)
        member.season_points, member.season_key = sporting_key([r for r in records if r[0] >= beginning], 6)
    branch.cursor = members[-1].player_key


def _standings(db, branch, snapshot):
    source = select(RankingWork.snapshot_id, RankingWork.player_key, RankingWork.total,
        func.rank().over(order_by=RankingWork.world_key), RankingWork.country,
        case((RankingWork.country != "", func.rank().over(partition_by=RankingWork.country, order_by=RankingWork.world_key))),
        RankingWork.season_points,
        case((RankingWork.season_points > 0, func.rank().over(order_by=RankingWork.season_key))))
    source = source.where(RankingWork.snapshot_id == snapshot.id, RankingWork.total > 0)
    db.execute(insert(RankingStanding).from_select(["snapshot_id", "player_key", "total", "world_rank", "country",
        "country_rank", "season_points", "season_rank"], source))
    snapshot.ranked_count = db.scalar(select(func.count()).select_from(RankingStanding).where(RankingStanding.snapshot_id == snapshot.id))
    _advance(branch, "careers")


def _careers(db, branch, snapshot, control, batch):
    rows = list(db.scalars(select(RankingStanding).where(RankingStanding.snapshot_id == snapshot.id,
        RankingStanding.player_key > branch.cursor).order_by(RankingStanding.player_key).limit(batch)))
    if not rows:
        _advance(branch, "world_archive")
        return
    previous = {}
    for career in db.scalars(select(RankingCareer).where(RankingCareer.branch_id == branch.id,
            RankingCareer.player_key > branch.cursor, RankingCareer.player_key <= rows[-1].player_key,
            RankingCareer.generation < snapshot.id).order_by(RankingCareer.player_key, RankingCareer.generation.desc())):
        previous.setdefault(career.player_key, career)
    winners = set(db.scalars(select(RankingAward.player_key).where(RankingAward.branch_id == branch.id,
        RankingAward.circuit_id == snapshot.circuit_id, RankingAward.weekly_place == 1,
        RankingAward.player_key > branch.cursor, RankingAward.player_key <= rows[-1].player_key)))
    car_wins = {}
    if db.get(Circuit, snapshot.circuit_id).policy == MULTI_POLICY:
        from .world_ranking_car_models import CarAward, CarWeek
        car_wins = dict(db.execute(select(CarAward.player_key, func.count()).join(CarWeek,
            (CarWeek.snapshot_id == snapshot.id) & (CarWeek.vehicle_id == CarAward.vehicle_id)).where(
                CarAward.branch_id == branch.id, CarAward.circuit_id == snapshot.circuit_id,
                CarAward.weekly_place == 1, CarWeek.field_size >= 2,
                CarAward.player_key > branch.cursor, CarAward.player_key <= rows[-1].player_key)
            .group_by(CarAward.player_key)).all())
    prestige = snapshot.field_size >= 1000
    finale = (snapshot.week_start-control.launch_week)//WEEK % 13 == 12 and snapshot.season_qualifying_weeks >= 6
    for standing in rows:
        old = previous.get(standing.player_key)
        peak = old is None or standing.world_rank < old.peak_rank
        db.add(RankingCareer(branch_id=branch.id, player_key=standing.player_key, generation=snapshot.id,
            peak_rank=standing.world_rank if peak else old.peak_rank,
            peak_week=snapshot.week_start if peak else old.peak_week,
            peak_field=snapshot.ranked_count if peak else old.peak_field,
            weeks_top100=(old.weeks_top100 if old else 0)+int(prestige and standing.world_rank <= 100),
            weeks_no1=(old.weeks_no1 if old else 0)+int(prestige and standing.world_rank == 1),
            victories=(old.victories if old else 0)+int(snapshot.field_size >= 2 and standing.player_key in winners)+car_wins.get(standing.player_key, 0),
            season_titles=(old.season_titles if old else 0)+int(finale and standing.season_rank == 1)))
    branch.cursor = rows[-1].player_key


def _publish(db, branch, snapshot, circuit, control):
    snapshot.state = "complete"
    beginning = season_start(snapshot.week_start, control.launch_week)
    snapshot.season_qualifying_weeks = db.scalar(select(func.count()).select_from(RankingSnapshot).where(
        RankingSnapshot.branch_id == branch.id, RankingSnapshot.week_start.between(beginning, snapshot.week_start),
        RankingSnapshot.field_size >= 1000))
    if branch.mode != "rebuild" or snapshot.week_start >= branch.through_week:
        snapshot.published_at = now()
        control.previous_id = control.published_id
        control.published_id = snapshot.id
        branch.mode, branch.through_week = "active", None
    if circuit.original_snapshot is None:
        circuit.original_snapshot = snapshot.id
    branch.last_snapshot = snapshot.id
    _advance(branch, "cleanup0")


def _cleanup(db, branch, snapshot, batch):
    phase = int(branch.phase.removeprefix("cleanup"))
    tables = (RankingInput, RankingPlace, RankingWeeklyWork, RankingWork)
    if phase < len(tables):
        model = tables[phase]
        if not _delete_batch(db, model, model.snapshot_id == snapshot.id, batch):
            _advance(branch, f"cleanup{phase+1}")
        return
    if phase == 4:
        # Keep current/previous windows and one staging recovery week.
        old = select(Circuit.id).where(Circuit.week_start < snapshot.week_start-27*WEEK)
        if not _delete_batch(db, RankingAward, (RankingAward.branch_id == branch.id) & RankingAward.circuit_id.in_(old), batch):
            _advance(branch, "cleanup5")
        return
    if phase == 5:
        keep = [snapshot.id, snapshot.previous_id or 0]
        old = select(RankingSnapshot.id).where(RankingSnapshot.branch_id == branch.id, ~RankingSnapshot.id.in_(keep))
        if not _delete_batch(db, RankingStanding, RankingStanding.snapshot_id.in_(old), batch):
            _advance(branch, "cleanup6")
        return
    if phase == 6:
        # Retain the latest base career at the previous generation plus newer versions.
        from sqlalchemy.orm import aliased
        newer = aliased(RankingCareer)
        stale = (RankingCareer.branch_id == branch.id) & exists(select(newer.player_key).where(
            newer.branch_id == RankingCareer.branch_id, newer.player_key == RankingCareer.player_key,
            newer.generation > RankingCareer.generation, newer.generation <= (snapshot.previous_id or 0)))
        # Retained versions interleave with obsolete versions by player key.
        # Advance across players, rather than rescanning the growing retained
        # prefix on every delete (which would become quadratic at scale).
        keys = list(db.scalars(select(RankingCareer.player_key).where(
            RankingCareer.branch_id == branch.id, RankingCareer.player_key > branch.cursor)
            .distinct().order_by(RankingCareer.player_key).limit(batch)))
        if not keys:
            _advance(branch, "cleanup7")
        elif not _delete_batch(db, RankingCareer, stale & (RankingCareer.player_key > branch.cursor)
                & (RankingCareer.player_key <= keys[-1]), batch):
            branch.cursor = keys[-1]
        return
    if phase == 7:
        if not _delete_batch(db, CircuitEntry, CircuitEntry.circuit_id == snapshot.circuit_id, batch):
            _advance(branch, "cleanup8")
        return
    control = db.get(RankingControl, 1)
    protected = {branch.id}
    for identity in (control.published_id, control.previous_id):
        if identity:
            protected.add(db.get(RankingSnapshot, identity).branch_id)
    if phase == 8:
        old = select(RankingSnapshot.id).where(~RankingSnapshot.branch_id.in_(protected))
        if not _delete_batch(db, RankingStanding, RankingStanding.snapshot_id.in_(old), batch):
            _advance(branch, "cleanup9")
        return
    if phase == 9:
        retired = select(RankingBranch.id).where(~RankingBranch.id.in_(protected))
        if not _delete_batch(db, RankingAward, RankingAward.branch_id.in_(retired), batch):
            _advance(branch, "cleanup10")
        return
    if phase == 10:
        retired = select(RankingBranch.id).where(~RankingBranch.id.in_(protected))
        if not _delete_batch(db, RankingCareer, RankingCareer.branch_id.in_(retired), batch):
            _advance(branch, "cleanup11")
        return
    from .world_ranking_car_models import (
        CarAward,
        CarEntry,
        CarInput,
        CarPlace,
        CarStanding,
        CarWeekly,
        CarWork,
    )
    if 11 <= phase <= 14:
        model = (CarInput, CarPlace, CarWeekly, CarWork)[phase-11]
        if not _delete_batch(db, model, model.snapshot_id == snapshot.id, batch):
            _advance(branch, f"cleanup{phase+1}")
        return
    if phase == 15:
        if not _delete_batch(db, CarEntry, CarEntry.circuit_id == snapshot.circuit_id, batch):
            _advance(branch, "cleanup16")
        return
    if phase == 16:
        keep = [control.published_id or 0, control.previous_id or 0, snapshot.id]
        old = select(RankingSnapshot.id).where(~RankingSnapshot.id.in_(keep))
        # Correction builds need their preceding snapshot until the next week
        # has copied its skills; previous_id is also retained while unpublished.
        if snapshot.previous_id:
            old = old.where(RankingSnapshot.id != snapshot.previous_id)
        if not _delete_batch(db, CarStanding, CarStanding.snapshot_id.in_(old), batch):
            _advance(branch, "cleanup17")
        return
    if phase == 17:
        old = select(Circuit.id).where(Circuit.week_start < snapshot.week_start-27*WEEK)
        retired = select(RankingBranch.id).where(~RankingBranch.id.in_(protected))
        stale = ((CarAward.branch_id == branch.id) & CarAward.circuit_id.in_(old)) | CarAward.branch_id.in_(retired)
        if not _delete_batch(db, CarAward, stale, batch):
            _advance(branch, "cleanup18")
        return
    branch.next_week = snapshot.week_start+WEEK
    branch.snapshot_id = None
    _advance(branch, "idle")


def step(factory, blobs, settings):
    """At most one bounded batch or one bounded global SQL sort. One SQL connection."""
    if not settings.world_ranking_launch_week:
        return False
    initialize(factory, settings.world_ranking_launch_week)
    timestamp, token = now(), new_id()
    with factory() as db:
        # Indexed early exit: let foreground verification catch up before the
        # next batch/sort. Never take a queue/player/group lock for ranking.
        delayed = db.scalar(select(Run.id).where(Run.status == "queued",
            Run.lease_until <= timestamp,
            Run.created_at < timestamp-settings.world_ranking_max_queue_age_seconds).limit(1))
        if delayed:
            return False
        control = db.get(RankingControl, 1)
        branch_id = control.running_branch
        branch = db.get(RankingBranch, branch_id)
        from .rivalry import week_window
        if branch.phase == "idle" and branch.next_week > week_window(timestamp)[0]-WEEK:
            return False
        claimed = db.execute(update(RankingBranch).where(RankingBranch.id == branch_id,
            RankingBranch.lease_until <= timestamp).values(lease_token=token, lease_until=timestamp+120)).rowcount
        db.commit()
    if not claimed:
        return False
    worked = True
    try:
        with factory() as db:
            if db.bind.dialect.name == "postgresql":
                db.execute(text("SET LOCAL work_mem = '16MB'"))
                db.execute(text("SET LOCAL max_parallel_workers_per_gather = 0"))
                db.execute(text(f"SET LOCAL statement_timeout = {int(settings.world_ranking_statement_ms)}"))
                db.execute(text("SET LOCAL lock_timeout = 500"))
            # Same metadata lock order as owner commands; foreground reads use
            # MVCC and never acquire either lock.
            control = db.scalar(select(RankingControl).where(RankingControl.id == 1).with_for_update())
            branch = _lock(db, branch_id, token)
            if control.running_branch != branch_id:
                branch.lease_until = 0
                db.commit()
                return False
            batch = settings.world_ranking_batch_size
            if branch.phase == "idle":
                from .rivalry import week_window
                last = week_window(timestamp)[0]-WEEK
                if branch.next_week > min(last, branch.through_week or last):
                    worked = False
                else:
                    circuit = db.scalar(select(Circuit).where(Circuit.week_start == branch.next_week))
                    if circuit is None:
                        # No official event opened: empty calendar week still advances expiry.
                        previous = db.get(RankingSnapshot, branch.last_snapshot) if branch.last_snapshot else None
                        policy = db.get(Circuit, previous.circuit_id).policy if previous else MULTI_POLICY
                        circuit = Circuit(week_start=branch.next_week, contract_key="", policy=policy, tracks=[])
                        db.add(circuit)
                        db.flush()
                    void = 0 in _corrections(db, circuit.id)
                    if circuit.policy not in (POLICY, MULTI_POLICY):
                        raise ValueError("Unsupported World Ranking policy")
                    if circuit.tracks and not void and branch.mode != "rebuild":
                        from .track_models import Track, TrackVersion
                        versions = _available_versions(db, circuit)
                        available = db.scalar(select(func.count()).select_from(TrackVersion).join(Track)
                            .join(Player, Player.id == Track.owner_id).where(TrackVersion.id.in_(versions),
                                TrackVersion.state == "published", Track.hidden.is_(False),
                                Track.archived.is_(False), Player.disabled.is_(False)))
                        if available != len(set(versions)):
                            raise CircuitUnavailable("Owner-audited whole-week void required")
                    void_cars = select(RankingCorrection.vehicle_id).where(RankingCorrection.circuit_id == circuit.id,
                        RankingCorrection.player_key == 0, RankingCorrection.vehicle_id != "")
                    pending = db.scalar(select(Run.id).join(RivalryTicket, RivalryTicket.ticket_id == Run.ticket_id)
                        .join(RivalryGroup, RivalryGroup.id == RivalryTicket.group_id).where(
                            RivalryGroup.world_circuit_id == circuit.id, ~RivalryGroup.vehicle_id.in_(void_cars),
                            Run.status.in_(("queued", "verifying"))).limit(1))
                    if pending and not void:
                        worked = False
                    else:
                        snapshot = RankingSnapshot(branch_id=branch.id, circuit_id=circuit.id,
                            week_start=circuit.week_start, previous_id=branch.last_snapshot)
                        db.add(snapshot)
                        db.flush()
                        beginning = season_start(snapshot.week_start, control.launch_week)
                        snapshot.season_qualifying_weeks = db.scalar(select(func.count()).select_from(RankingSnapshot).where(
                            RankingSnapshot.branch_id == branch.id, RankingSnapshot.week_start.between(beginning, snapshot.week_start),
                            RankingSnapshot.field_size >= 1000))
                        branch.snapshot_id = snapshot.id
                        _advance(branch, "m_freeze:0" if circuit.policy == MULTI_POLICY else "freeze")
            else:
                snapshot = db.get(RankingSnapshot, branch.snapshot_id)
                circuit = db.get(Circuit, snapshot.circuit_id)
                if branch.phase.startswith("m_"):
                    from .world_ranking_cars import advance
                    advance(db, branch, snapshot, circuit, control, batch, blobs)
                elif branch.phase == "freeze":
                    _freeze(db, branch, snapshot, circuit, batch, blobs)
                elif branch.phase.startswith("track"):
                    slot = int(branch.phase[-1])
                    ticks = getattr(RankingInput, f"t{slot}")
                    place = 2*func.rank().over(order_by=ticks)+func.count().over(partition_by=ticks)-1
                    db.execute(insert(RankingPlace).from_select(["snapshot_id", "slot", "player_key", "place2"],
                        select(RankingInput.snapshot_id, literal(slot), RankingInput.player_key, place)
                        .where(RankingInput.snapshot_id == snapshot.id)))
                    _advance(branch, f"track{slot+1}" if slot < 4 else "combine")
                elif branch.phase == "combine":
                    _combine(db, branch, snapshot, batch)
                elif branch.phase == "weekly":
                    _weekly(db, branch, snapshot, circuit)
                elif branch.phase == "week_archive":
                    _write_archive(db, branch, snapshot, "week", batch, blobs)
                elif branch.phase == "members":
                    _members(db, branch, snapshot, circuit, blobs, batch)
                elif branch.phase == "totals":
                    _totals(db, branch, snapshot, control, batch)
                elif branch.phase == "standings":
                    snapshot.season_qualifying_weeks += int(snapshot.field_size >= 1000)
                    _standings(db, branch, snapshot)
                elif branch.phase == "careers":
                    _careers(db, branch, snapshot, control, batch)
                elif branch.phase == "world_archive":
                    _write_archive(db, branch, snapshot, "world", batch, blobs)
                elif branch.phase == "publish":
                    _publish(db, branch, snapshot, circuit, control)
                elif branch.phase.startswith("cleanup"):
                    _cleanup(db, branch, snapshot, batch)
                else:
                    raise ValueError("Unknown ranking settlement phase")
            db.flush()
            # An object-I/O phase rechecked its fence after releasing the transaction.
            branch = _lock(db, branch_id, token)
            branch.lease_until, branch.failure = 0, ""
            db.commit()
    except Exception as exc:
        with factory() as db:
            db.execute(update(RankingBranch).where(RankingBranch.id == branch_id, RankingBranch.lease_token == token)
                .values(lease_until=now()+5, failure=type(exc).__name__+": "+str(exc)[:120]))
            db.commit()
        raise
    return worked
