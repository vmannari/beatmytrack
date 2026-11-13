"""A single pass over movement and ordered gate crossings; no game simulation."""
from __future__ import annotations

import json

from .verifier import MAX_FRAMES, VerificationError

SCHEMA = "bmt-trajectory-v1"
CHECKPOINT_LAYOUT_VERSION = 24
GEOMETRY_CACHE_ENTRIES = 64
GEOMETRY_CACHE_BYTES = 8 * 1024 * 1024


def clean_race_report(proof, ticks):
    """Recorded incidents gate a fixed cosmetic bonus after acceptance.

    This follows the lightweight evidence policy, not independent collision
    re-simulation. Missing/malformed reports earn no bonus and cannot invalidate
    a valid trajectory or choose a coin amount.
    """
    report = proof.get("incidents") if type(proof) is dict else None
    return (type(report) is dict and set(report) == {"schema", "ticks", "collision_count", "off_track"}
            and report.get("schema") == "bmt-race-incidents-v1"
            and type(report.get("ticks")) is int and report["ticks"] == ticks and 0 < ticks <= MAX_FRAMES
            and type(report.get("collision_count")) is int and report["collision_count"] == 0
            and type(report.get("off_track")) is bool and not report["off_track"])


def input_count(replay):
    return replay.get("input_count") if replay.get("schema") == SCHEMA else len(replay.get("frames", []))


def duration(replay):
    return input_count(replay) - sum(event["from_tick"]-event["to_tick"] for event in replay.get("rewinds", []))


def prepared_geometry(app, document_hash, document=None):
    """Bounded immutable descriptors, keyed by content and exact verifier build.

    Warm workers need neither the track object nor another SQL descriptor read.
    Keep bytes in the cache so callers own their decoded geometry and cannot
    mutate another race's gates. Cold preparation retains the durable SQL cache.
    """
    from .board_cache import cached as remember
    from .contracts import BUILD_FIELDS, build_contract
    from .storage import canonical_json
    from .track_models import OperationState, digest, now

    active = app.state.verifier.manifest()
    identity = (document_hash, digest(build_contract(active)), CHECKPOINT_LAYOUT_VERSION)
    key = "geom:"+str(CHECKPOINT_LAYOUT_VERSION)+":"+document_hash

    def matches(geometry):
        return (geometry.get("checkpoint_layout_version") == CHECKPOINT_LAYOUT_VERSION
                and all(geometry.get("manifest", {}).get(field) == active[field] for field in BUILD_FIELDS))

    def load(session):
        stored = session.get(OperationState,key)
        if stored is not None and matches(stored.details):
            return canonical_json(stored.details)
        # Release the descriptor read before storage pins, IO or native work.
        session.rollback()
        source = document if document is not None else app.state.blobs.get_json(document_hash)
        geometry = app.state.verifier.race_geometry(source)
        if not matches(geometry):
            from .verifier import VerifierUnavailable
            raise VerifierUnavailable("Prepared geometry differs from verifier build")
        session.merge(OperationState(id=key,updated_at=now(),details=geometry))
        session.commit()
        return canonical_json(geometry)

    with app.state.session_factory() as session:
        encoded = remember(session,identity,lambda: load(session),namespace="verification-geometry",
            max_entries=GEOMETRY_CACHE_ENTRIES,max_weight=GEOMETRY_CACHE_BYTES,weight=len)
    return json.loads(encoded)


def validate_envelope(replay):
    if (type(replay) is not dict or replay.get("schema") != SCHEMA
            or set(replay)-{"schema", "input_count", "race_proof", "rewinds", "ghost", "claimed_lap_ticks"}
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
    if "claimed_lap_ticks" in replay:
        laps = replay["claimed_lap_ticks"]
        if (type(laps) is not list or len(laps) != 5
                or any(type(value) is not int or not 0 < value <= MAX_FRAMES for value in laps)
                or sum(laps) != duration(replay)):
            raise VerificationError("Invalid claimed lap timing")


def check(geometry, proof, ticks, vehicle, *, creator_test=False, daily_laps=False):
    """Check samples once. Geometry is prepared from the pinned server track."""
    if (type(proof) is not dict or set(proof) not in ({"schema", "samples"}, {"schema", "samples", "incidents"})
            or proof.get("schema") not in ("bmt-race-proof-v1", "bmt-race-path-v1") or type(proof["samples"]) is not list
            or not 2 <= len(proof["samples"]) <= MAX_FRAMES//6+12):
        raise VerificationError("Race trajectory is required")
    samples = proof["samples"]
    width, layer_index = (4,3) if proof["schema"] == "bmt-race-path-v1" else (8,6)
    gates = geometry["gates"]
    # Rules23 and later supply the complete recovery span. An extra 15 cm can bridge
    # the deliberately separated inside edges of a folded hairpin. Retain
    # historical tolerance for older geometry; allow only numeric roundoff now.
    gate_slack = 0.0001 if geometry["manifest"].get("rules_key") in ("standing-5-road-gates-v23", "standing-5-road-gates-v24") else 0.15
    start = geometry["creator_start"] if creator_test else geometry["start"]
    limit = geometry["maximum_speed"][vehicle] * 1.1 / 120.0
    # The 5 cm allowance belongs to the ordinary six-tick capture interval.
    # Scale it with elapsed time so inserting dense samples cannot buy speed.
    # Cache the six squared bounds instead of exponentiating for every sample.
    distance_limits = (0.0,) + tuple((limit*dt + 0.05*(dt/6))**2 for dt in range(1, 7))
    number_types = (int, float)
    extent_x, extent_y = geometry["extent"]
    target_laps = 1 if creator_test else 10 if daily_laps else 5
    gate_index, laps, previous_tick, last_lap = 0, 0, -1, 0
    px, py, previous_layer = start
    lap_ticks = []
    nx, ny, origin, sx, sy, side_origin, low, high, expected_layer = gates[0]
    gate_before = 0.0
    for sample in samples:
        if (type(sample) is not list or len(sample) != width
                or type(sample[0]) is not int or type(sample[layer_index]) is not int or sample[layer_index] not in (0, 1)):
            raise VerificationError("Malformed trajectory sample")
        tick, x, y, layer = sample[0],sample[1],sample[2],sample[layer_index]
        if (type(x) not in number_types or type(y) not in number_types
                or not (-extent_x <= x <= extent_x and -extent_y <= y <= extent_y)):
            raise VerificationError("Trajectory is outside the track")
        if previous_tick < 0:
            if tick != 0 or (x-px)**2+(y-py)**2 > 0.15**2 or layer != previous_layer:
                raise VerificationError("Trajectory does not begin at the race start")
            # The recorded start may differ within tolerance. Gate crossings
            # must use that actual position, just like every later segment.
            gate_before = nx*x+ny*y+origin
        else:
            dt = tick-previous_tick
            if not 1 <= dt <= 6 or tick > ticks or laps == target_laps:
                raise VerificationError("Trajectory timeline is incomplete")
            dx, dy = x-px, y-py
            if dx*dx+dy*dy > distance_limits[dt]:
                raise VerificationError("Trajectory jumps or exceeds the car speed limit")
            consumed = -1.0
            after = nx*x+ny*y+origin
            while laps < target_laps and gate_before <= 0.0 and after > 0.0:
                fraction = -gate_before/(after-gate_before)
                side = sx*(px+dx*fraction)+sy*(py+dy*fraction)+side_origin
                if (fraction < consumed-0.000001 or not low-gate_slack <= side <= high+gate_slack
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
    if (not (2 <= laps <= 10) if daily_laps else laps != target_laps) or previous_tick != ticks or sum(lap_ticks) != ticks:
        raise VerificationError("Trajectory does not complete the required laps and ordered road gates")
    return {"time_ticks": ticks, "time_ms": round(ticks*1000/120), "lap_ticks": lap_ticks,
            "manifest": geometry["manifest"], "verification_method": "trajectory-v1",
            "incident_free": clean_race_report(proof,ticks)}
