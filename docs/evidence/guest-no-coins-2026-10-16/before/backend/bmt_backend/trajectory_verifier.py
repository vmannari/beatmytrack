"""A single pass over movement and ordered gate crossings; no game simulation."""
from __future__ import annotations

from .verifier import MAX_FRAMES, VerificationError

SCHEMA = "bmt-trajectory-v1"


def input_count(replay):
    return replay.get("input_count") if replay.get("schema") == SCHEMA else len(replay.get("frames", []))


def duration(replay):
    return input_count(replay) - sum(event["from_tick"]-event["to_tick"] for event in replay.get("rewinds", []))


def prepared_geometry(app, document_hash, document):
    """Static preparation is cached durably, independent of any submitted race."""
    from .contracts import BUILD_FIELDS
    from .track_models import OperationState, now
    key = "geom:"+document_hash
    with app.state.session_factory() as session:
        cached = session.get(OperationState,key)
        active = app.state.verifier.manifest()
        if (cached is not None and all(cached.details.get("manifest",{}).get(field) == active[field] for field in BUILD_FIELDS)
                and cached.details.get("manifest",{}).get("vehicles") == active.get("vehicles")):
            return cached.details
    geometry = app.state.verifier.race_geometry(document)
    with app.state.session_factory() as session:
        session.merge(OperationState(id=key,updated_at=now(),details=geometry))
        session.commit()
    return geometry


def validate_envelope(replay):
    if (type(replay) is not dict or replay.get("schema") != SCHEMA
            or set(replay)-{"schema", "input_count", "race_proof", "rewinds", "ghost"}
            or type(replay.get("input_count")) is not int or not 1 <= replay["input_count"] <= MAX_FRAMES
            or type(replay.get("race_proof")) is not dict):
        raise VerificationError("Malformed trajectory envelope")
    # Reuse the existing receipt timeline contract without needing control frames.
    offset, tick, receipts = 0, 0, set()
    events = replay.get("rewinds", [])
    if type(events) is not list or len(events) > 3:
        raise VerificationError("Malformed trajectory rewinds")
    for event in events:
        if (type(event) is not dict or set(event) != {"receipt_id", "input_offset", "from_tick", "to_tick"}
                or type(event["receipt_id"]) is not str or len(event["receipt_id"]) != 36
                or event["receipt_id"] in receipts
                or any(type(event[key]) is not int for key in ("input_offset", "from_tick", "to_tick"))
                or not offset < event["input_offset"] < replay["input_count"]
                or event["from_tick"] != tick+event["input_offset"]-offset
                or not 0 <= event["to_tick"] < event["from_tick"]
                or event["from_tick"]-event["to_tick"] > 1200):
            raise VerificationError("Invalid trajectory rewind timeline")
        receipts.add(event["receipt_id"])
        offset, tick = event["input_offset"], event["to_tick"]
    if not 0 < duration(replay) <= MAX_FRAMES:
        raise VerificationError("Invalid trajectory duration")


def check(geometry, proof, ticks, vehicle, *, creator_test=False):
    """Check samples once. Geometry is prepared from the pinned server track."""
    if (type(proof) is not dict or set(proof) != {"schema", "samples"}
            or proof.get("schema") not in ("bmt-race-proof-v1", "bmt-race-path-v1") or type(proof["samples"]) is not list
            or not 2 <= len(proof["samples"]) <= MAX_FRAMES//6+12):
        raise VerificationError("Race trajectory is required")
    samples = proof["samples"]
    width, layer_index = (4,3) if proof["schema"] == "bmt-race-path-v1" else (8,6)
    gates = geometry["gates"]
    start = geometry["creator_start"] if creator_test else geometry["start"]
    limit = geometry["maximum_speed"][vehicle] * 1.1 / 120.0
    extent_x, extent_y = geometry["extent"]
    target_laps = 1 if creator_test else 5
    gate_index, laps, previous_tick, last_lap = 0, 0, -1, 0
    px, py, previous_layer = start
    lap_ticks = []
    nx, ny, origin, sx, sy, side_origin, low, high, expected_layer = gates[0]
    gate_before = nx*px+ny*py+origin
    for sample in samples:
        if (type(sample) is not list or len(sample) != width
                or type(sample[0]) is not int or type(sample[layer_index]) is not int or sample[layer_index] not in (0, 1)):
            raise VerificationError("Malformed trajectory sample")
        tick, x, y, layer = sample[0],sample[1],sample[2],sample[layer_index]
        if (type(x) not in (int, float) or type(y) not in (int, float)
                or not (-extent_x <= x <= extent_x and -extent_y <= y <= extent_y)):
            raise VerificationError("Trajectory is outside the track")
        if previous_tick < 0:
            if tick != 0 or (x-px)**2+(y-py)**2 > 0.15**2 or layer != previous_layer:
                raise VerificationError("Trajectory does not begin at the race start")
        else:
            dt = tick-previous_tick
            if not 1 <= dt <= 6 or tick > ticks or laps == target_laps:
                raise VerificationError("Trajectory timeline is incomplete")
            dx, dy = x-px, y-py
            if dx*dx+dy*dy > (limit*dt+0.05)**2:
                raise VerificationError("Trajectory jumps or exceeds the car speed limit")
            consumed = -1.0
            after = nx*x+ny*y+origin
            while laps < target_laps and gate_before <= 0.0 and after > 0.0:
                fraction = -gate_before/(after-gate_before)
                side = sx*(px+dx*fraction)+sy*(py+dy*fraction)+side_origin
                if (fraction < consumed-0.000001 or not low-0.15 <= side <= high+0.15
                        or expected_layer not in (previous_layer, layer)):
                    break
                consumed = fraction
                gate_index += 1
                if gate_index == len(gates):
                    laps += 1
                    lap_ticks.append(tick-last_lap)
                    last_lap, gate_index = tick, 0
                nx, ny, origin, sx, sy, side_origin, low, high, expected_layer = gates[gate_index]
                gate_before = nx*px+ny*py+origin
                after = nx*x+ny*y+origin
            gate_before = after
        previous_tick, px, py, previous_layer = tick, x, y, layer
    if laps != target_laps or previous_tick != ticks or sum(lap_ticks) != ticks:
        raise VerificationError("Trajectory does not complete the required laps and ordered road gates")
    return {"time_ticks": ticks, "time_ms": round(ticks*1000/120), "lap_ticks": lap_ticks,
            "manifest": geometry["manifest"], "verification_method": "trajectory-v1"}
