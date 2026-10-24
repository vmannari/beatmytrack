"""Lossless versioned transport for every 120 Hz input, launch marker and rewind."""
import base64
import binascii

from fastapi import HTTPException

MAX_FRAMES = 216000


def unpack_replay(value):
    if value.get("schema") != "bmt-packed-input-v1":
        return value
    count, controls = value.get("frame_count"), value.get("controls")
    if (set(value) - {"schema", "replay_schema", "frame_count", "controls", "rewinds", "race_proof"}
            or type(count) is not int or not 1 <= count <= MAX_FRAMES
            or type(controls) is not str or len(controls) != count * 8
            or value.get("replay_schema") not in ("bmt-replay-v1", "bmt-replay-v2")):
        raise HTTPException(422, "INVALID_PACKED_REPLAY")
    try:
        raw = base64.b64decode(controls, validate=True)
    except (binascii.Error, ValueError):
        raise HTTPException(422, "INVALID_PACKED_REPLAY") from None
    if len(raw) != count * 6:
        raise HTTPException(422, "INVALID_PACKED_REPLAY")
    frames = []
    for offset in range(0, len(raw), 6):
        width, steer, throttle, brake, handbrake, launch = raw[offset:offset+6]
        if (width not in (3, 4, 5) or steer == 255 or (width == 3 and handbrake)
                or (width < 5 and launch) or (width == 5 and (offset != 0 or launch not in (1, 2)))):
            raise HTTPException(422, "INVALID_PACKED_REPLAY")
        frames.append([steer-127, throttle, brake, handbrake, launch][:width])
    replay = {"schema": value["replay_schema"], "frames": frames}
    if "rewinds" in value:
        replay["rewinds"] = value["rewinds"]
    if "race_proof" in value:
        replay["race_proof"] = value["race_proof"]
    return replay
