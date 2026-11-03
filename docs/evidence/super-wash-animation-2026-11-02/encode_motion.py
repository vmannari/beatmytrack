"""Lossless APNG from the actual native frames; no image library required."""
from pathlib import Path
import struct
import zlib

HERE = Path(__file__).parent


def parse(path):
    source = path.read_bytes()
    assert source[:8] == b"\x89PNG\r\n\x1a\n"
    parts, offset = [], 8
    while offset < len(source):
        size = struct.unpack(">I", source[offset:offset+4])[0]
        kind = source[offset+4:offset+8]
        data = source[offset+8:offset+8+size]
        assert struct.unpack(">I", source[offset+8+size:offset+12+size])[0] == zlib.crc32(kind+data) & 0xffffffff
        parts.append((kind, data))
        offset += size+12
    return parts


def chunk(kind, data):
    return struct.pack(">I", len(data))+kind+data+struct.pack(">I", zlib.crc32(kind+data) & 0xffffffff)


paths = sorted((HERE / "gl_compatibility/motion").glob("frame-*.png"))
assert len(paths) == 55
first = parse(paths[0])
header = next(data for kind, data in first if kind == b"IHDR")
width, height = struct.unpack(">II", header[:8])
result = bytearray(b"\x89PNG\r\n\x1a\n")+chunk(b"IHDR", header)
for kind, data in first:
    if kind not in (b"IHDR", b"IDAT", b"IEND"):
        result += chunk(kind, data)
result += chunk(b"acTL", struct.pack(">II", len(paths), 0))
sequence = 0
for index, path in enumerate(paths):
    parts = parse(path)
    assert next(data for kind, data in parts if kind == b"IHDR") == header
    result += chunk(b"fcTL", struct.pack(">IIIIIHHBB", sequence, width, height, 0, 0, 1, 15, 0, 0))
    sequence += 1
    for kind, data in parts:
        if kind != b"IDAT":
            continue
        if index == 0:
            result += chunk(b"IDAT", data)
        else:
            result += chunk(b"fdAT", struct.pack(">I", sequence)+data)
            sequence += 1
result += chunk(b"IEND", b"")
target = HERE / "super-wash-animation.png"
target.write_bytes(result)
print(f"{target.name}: {width}x{height}, {len(paths)} actual frames, {len(result)} bytes; stepped 15 Hz, not a performance measurement")
