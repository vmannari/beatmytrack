#!/usr/bin/env python3
"""Partial/complete decoder for Slicks 'N' Slide .SS track files.

Decoded from the supplied Slicks 1.29/1.51 track corpus and editor docs.

Version 2 (used by Slicks 1.51 / converted tracks): gameplay/map portion is
fully segmented here: blocks, checkpoints, computer points, panic points,
and start position.

Version 1 (Slicks 1.29): block layout, checkpoints and computer points are
parsed; the final legacy tail is retained raw because its legacy panic/start
encoding has not yet been completely identified.
"""
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any

SIGNATURE = b"\x00\x01SS~"


def be16(b: bytes) -> int:
    return int.from_bytes(b, "big")


def c_string(data: bytes, off: int) -> tuple[str, int]:
    end = data.index(0, off)
    return data[off:end].decode("cp437", errors="replace"), end + 1


def coord3(raw: bytes) -> dict[str, int]:
    """3-byte Slicks coordinate used by route/checkpoint records."""
    return {"x": be16(raw[0:2]), "y": raw[2]}


def parse_block(raw: bytes) -> dict[str, Any]:
    flags = raw[4]
    return {
        "x": be16(raw[0:2]),
        "y": raw[2],
        "block_id": raw[3],
        "rotation": flags & 0x03,
        "flags": flags & 0xFC,
        "raw_flags": flags,
    }


def parse_checkpoint(raw: bytes) -> dict[str, Any]:
    # The editor documentation describes checkpoints as large crossing regions.
    # On disk each checkpoint is two 3-byte screen coordinates.
    return {"a": coord3(raw[0:3]), "b": coord3(raw[3:6])}


def parse_computer_point(raw: bytes) -> dict[str, Any]:
    # Editor docs: define effect area first, then target point.
    return {
        "effect_a": coord3(raw[0:3]),
        "effect_b": coord3(raw[3:6]),
        "target": coord3(raw[6:9]),
        "extra": raw[9],
    }


def parse_panic_point(raw: bytes) -> dict[str, Any]:
    return {"position": coord3(raw[0:3]), "extra": raw[3]}


def parse_v2(data: bytes) -> dict[str, Any]:
    # 0x0008..0x0147: ten 32-byte top-ten entries.
    scores = []
    off = 8
    for _ in range(10):
        r = data[off:off+32]
        name = r[:20].split(b"\0", 1)[0].decode("cp437", errors="replace")
        scores.append({"name": name, "raw_hex": r.hex()})
        off += 32

    # 0x0148..0x0179 is a 50-byte v2 metadata/validation area.
    v2_meta = data[0x148:0x17A]
    off = 0x17A
    author, off = c_string(data, off)
    owner, off = c_string(data, off)

    # Four big-endian words follow the strings. They correlate strongly with
    # editor/user identity rather than track geometry, so keep them neutral.
    editor_id_words = [be16(data[off+i:off+i+2]) for i in range(0, 8, 2)]
    off += 8

    block_count = be16(data[off:off+2]); off += 2
    blocks = []
    for _ in range(block_count):
        blocks.append(parse_block(data[off:off+5]))
        off += 5

    checkpoint_count = be16(data[off:off+2]); off += 2
    checkpoints = []
    for _ in range(checkpoint_count):
        checkpoints.append(parse_checkpoint(data[off:off+6]))
        off += 6

    computer_point_count = be16(data[off:off+2]); off += 2
    computer_points = []
    for _ in range(computer_point_count):
        computer_points.append(parse_computer_point(data[off:off+10]))
        off += 10

    panic_point_count = be16(data[off:off+2]); off += 2
    panic_points = []
    for _ in range(panic_point_count):
        panic_points.append(parse_panic_point(data[off:off+4]))
        off += 4

    start_raw = data[off:off+7]
    if len(start_raw) != 7:
        raise ValueError("Truncated start-position record")
    start = {
        "x": be16(start_raw[0:2]),
        "y": be16(start_raw[2:4]),
        "direction": start_raw[4],
        "reserved": start_raw[5:7].hex(),
    }
    off += 7

    if off != len(data):
        raise ValueError(f"Parser ended at {off}, file size is {len(data)}")

    return {
        "format_version": 2,
        "header_hex": data[:8].hex(),
        "top_ten": scores,
        "v2_metadata_hex": v2_meta.hex(),
        "author": author,
        "owner_or_editor_name": owner,
        "editor_id_words": editor_id_words,
        "block_count": block_count,
        "blocks": blocks,
        "checkpoint_count": checkpoint_count,
        "checkpoints": checkpoints,
        "computer_point_count": computer_point_count,
        "computer_points": computer_points,
        "panic_point_count": panic_point_count,
        "panic_points": panic_points,
        "start": start,
    }


def parse_v1(data: bytes) -> dict[str, Any]:
    # v1.29: ten 29-byte top-ten entries begin at offset 6.
    scores = []
    off = 6
    for _ in range(10):
        r = data[off:off+29]
        # Legacy name field is shorter; preserve the record raw as well.
        name = r[:10].split(b"\0", 1)[0].decode("cp437", errors="replace")
        scores.append({"name": name, "raw_hex": r.hex()})
        off += 29

    # All supplied 1.29 files put the author at 0x131 (305).
    off = 0x131
    author, off = c_string(data, off)
    owner, off = c_string(data, off)
    editor_id_words = [be16(data[off+i:off+i+2]) for i in range(0, 8, 2)]
    off += 8

    block_count = be16(data[off:off+2]); off += 2
    blocks = []
    for _ in range(block_count):
        blocks.append(parse_block(data[off:off+5]))
        off += 5

    # The v1.29 gameplay tail uses a different legacy representation.
    # Keep it intact until its checkpoint/route/panic/start sub-layout is fully
    # verified. The complete visual block layout above is already decoded.
    legacy_tail = data[off:]

    return {
        "format_version": 1,
        "header_hex": data[:6].hex(),
        "top_ten": scores,
        "author": author,
        "owner_or_editor_name": owner,
        "editor_id_words": editor_id_words,
        "block_count": block_count,
        "blocks": blocks,
        "legacy_tail_hex": legacy_tail.hex(),
    }


def parse_ss(path: str | Path) -> dict[str, Any]:
    path = Path(path)
    data = path.read_bytes()
    if len(data) < 6 or data[:5] != SIGNATURE:
        raise ValueError("Not a recognized Slicks 'N' Slide .SS file")
    version = data[5]
    if version == 2:
        result = parse_v2(data)
    elif version == 1:
        result = parse_v1(data)
    else:
        raise ValueError(f"Unsupported .SS format version: {version}")
    result["file"] = path.name
    result["file_size"] = len(data)
    return result


def main() -> None:
    ap = argparse.ArgumentParser(description="Decode Slicks 'N' Slide .SS tracks")
    ap.add_argument("track", type=Path)
    ap.add_argument("-o", "--output", type=Path, help="Write JSON here")
    ap.add_argument("--summary", action="store_true", help="Print only summary")
    args = ap.parse_args()

    d = parse_ss(args.track)
    if args.summary:
        s = {k: d[k] for k in (
            "file", "file_size", "format_version", "author", "owner_or_editor_name",
            "block_count", "checkpoint_count", "computer_point_count"
        ) if k in d}
        if "panic_point_count" in d:
            s["panic_point_count"] = d["panic_point_count"]
            s["start"] = d["start"]
        text = json.dumps(s, indent=2, ensure_ascii=False)
    else:
        text = json.dumps(d, indent=2, ensure_ascii=False)

    if args.output:
        args.output.write_text(text + "\n", encoding="utf-8")
    else:
        print(text)


if __name__ == "__main__":
    main()
