"""Compare lossless encodings on a declared planar projection of the saved path fixture."""
import base64
import gzip
import json
import struct
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def main():
    proof = json.loads((ROOT / ".tools/trajectory-approved-20261009/proof.json").read_text())
    poses = [[r[0], r[1], r[2], r[7], r[3], 0.0, 0.0] for r in proof["samples"]]
    recording = {"ticks": poses[-1][0], "poses": poses}
    raw = json.dumps(recording, separators=(",", ":")).encode()
    started = time.perf_counter()
    binary = b"".join(struct.pack("<7d", *row) for row in poses)
    packed = {"schema": "bmt-packed-ghost-v1", "ticks": recording["ticks"], "count": len(poses),
              "data": base64.b64encode(gzip.compress(binary, compresslevel=3, mtime=0)).decode()}
    packed_raw = json.dumps(packed, separators=(",", ":")).encode()
    (HERE / "ghost-wire-fixture.json").write_text(json.dumps({"original": recording, "packed": packed}, separators=(",", ":")), encoding="utf-8")
    elapsed = (time.perf_counter()-started)*1000
    for index, row in enumerate(poses):
        assert tuple(row) == struct.unpack_from("<7d", binary, index*56)
    baseline = len(gzip.compress(raw, compresslevel=3, mtime=0))
    candidate = len(gzip.compress(packed_raw, compresslevel=3, mtime=0))
    result = {"fixture": "2130-sample five-lap path projected to planar poses; banking zero, not a live/download population sample",
              "samples": len(poses), "gzip_json_wire_bytes": baseline, "gzip_packed_envelope_wire_bytes": candidate,
              "fraction_bytes_saved": 1-candidate/baseline, "single_encoding_ms": elapsed,
              "exact_numeric_roundtrip": True}
    (HERE / "ghost-wire-benchmark.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
