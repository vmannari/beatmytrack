"""Bounded lossless transport, decoded before trajectory validation and hashing."""
import base64
import binascii
import math
import struct

from fastapi import HTTPException

SCHEMA = "bmt-packed-path-v1"
MAX_SAMPLES = 216000 // 6 + 12
RECORD = struct.Struct("<IddB")


def unpack_path(value):
    if type(value) is not dict or value.get("schema") != SCHEMA:
        return value
    count, data = value.get("count"), value.get("data")
    if (set(value) - {"schema", "count", "data", "incidents"}
            or type(count) is not int or not 2 <= count <= MAX_SAMPLES
            or type(data) is not str or len(data) != 4 * ((count * RECORD.size + 2) // 3)):
        raise HTTPException(422, "INVALID_PACKED_PATH")
    try:
        raw = base64.b64decode(data, validate=True)
    except (binascii.Error, ValueError):
        raise HTTPException(422, "INVALID_PACKED_PATH") from None
    if len(raw) != count * RECORD.size:
        raise HTTPException(422, "INVALID_PACKED_PATH")
    samples = []
    for tick, x, y, metadata in RECORD.iter_unpack(raw):
        layer, integers = metadata & 1, metadata >> 1
        if (tick > 216000 or metadata > 7
                or not math.isfinite(x) or not math.isfinite(y)
                or (integers & 1 and (not x.is_integer() or abs(x) > 2**53))
                or (integers & 2 and (not y.is_integer() or abs(y) > 2**53))):
            raise HTTPException(422, "INVALID_PACKED_PATH")
        # Keep JSON integer-vs-float identity as well as IEEE754 values so the
        # normalized replay has exactly the same existing idempotency digest.
        samples.append([tick, int(x) if integers & 1 else x, int(y) if integers & 2 else y, layer])
    result = {"schema": "bmt-race-path-v1", "samples": samples}
    if "incidents" in value:
        result["incidents"] = value["incidents"]
    return result
