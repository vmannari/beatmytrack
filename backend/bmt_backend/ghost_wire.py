"""Optional exact Float64 presentation encoding; scores/proofs are untouched."""
import base64
import gzip
import struct

from .storage import canonical_json
from .verifier import validate_ghost


def compact(recording):
    validate_ghost(recording, recording["ticks"])
    body = b"".join(struct.pack("<7d", *row) for row in recording["poses"])
    value = {"schema": "bmt-packed-ghost-v1", "ticks": recording["ticks"], "count": len(recording["poses"]),
             "data": base64.b64encode(gzip.compress(body, compresslevel=3, mtime=0)).decode("ascii")}
    def wire(data):
        raw = canonical_json(data)
        return len(gzip.compress(raw, compresslevel=3, mtime=0)) if len(raw) >= 1024 else len(raw)
    # Do not increase transfers for tiny or unusually compressible JSON ghosts.
    return value if wire(value) < .95*wire(recording) else recording
