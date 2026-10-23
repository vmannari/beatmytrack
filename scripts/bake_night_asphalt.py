"""Original seamless Night asphalt wear data, baked offline with existing NumPy.

RGB: oxidized binder/exposed aggregate, old tar repairs, fine branching cracks.
48 metre tile, 1024 square, 2x supersampling. No runtime noise or new dependency.
"""
from pathlib import Path
import hashlib
import json
import struct
import zlib

import numpy as np

SIZE, TILE, SEED = 1024, 48.0, 2026101701
N = SIZE * 2
y, x = np.mgrid[:N, :N].astype(np.float32)
x = (x + 0.5) * TILE / N
y = (y + 0.5) * TILE / N
rng = np.random.default_rng(SEED)


def smooth(a, b, value):
    t = np.clip((value - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def noise(period):
    grid = rng.random((period, period), dtype=np.float32)
    px, py = x * period / TILE, y * period / TILE
    ix, iy = np.floor(px).astype(int), np.floor(py).astype(int)
    fx, fy = smooth(0, 1, px % 1), smooth(0, 1, py % 1)
    a = grid[iy % period, ix % period]
    b = grid[iy % period, (ix + 1) % period]
    c = grid[(iy + 1) % period, ix % period]
    d = grid[(iy + 1) % period, (ix + 1) % period]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


# Interlocking faded binder islands rather than whole-surface cloudy stains.
broad, middle, edge = noise(11), noise(39), noise(137)
wear = smooth(0.24, 0.77, broad * 0.56 + middle * 0.31 + edge * 0.13)
repairs = np.zeros_like(x)
for _ in range(38):
    cx, cy = rng.uniform(0, TILE, 2)
    angle = rng.uniform(-np.pi, np.pi)
    dx, dy = (x - cx + TILE / 2) % TILE - TILE / 2, (y - cy + TILE / 2) % TILE - TILE / 2
    u = dx * np.cos(angle) + dy * np.sin(angle)
    v = -dx * np.sin(angle) + dy * np.cos(angle)
    width, length = rng.uniform(0.35, 1.05), rng.uniform(0.6, 1.8)
    border = np.maximum(np.abs(u) - width, np.abs(v) - length)
    border += (edge - 0.5) * 0.16 + (middle - 0.5) * 0.1
    patch = (1 - smooth(-0.025, 0.07, border)) * rng.uniform(0.5, 1.0)
    repairs = np.maximum(repairs, patch)

cracks = np.zeros_like(x)


def segment(a, b, width, strength):
    # Bounded local rasterization, wrapped into the tile at each edge.
    pad = width + 0.065
    lo = np.floor((np.minimum(a, b) - pad) * N / TILE).astype(int)
    hi = np.ceil((np.maximum(a, b) + pad) * N / TILE).astype(int)
    sy, sx = np.mgrid[lo[1]:hi[1] + 1, lo[0]:hi[0] + 1]
    p = np.stack(((sx + 0.5) * TILE / N, (sy + 0.5) * TILE / N), axis=-1)
    ab = b - a
    t = np.clip(np.sum((p - a) * ab, axis=-1) / np.dot(ab, ab), 0, 1)
    distance = np.linalg.norm(p - a - t[..., None] * ab, axis=-1)
    value = (1 - smooth(width * 0.3, width + 0.035, distance)) * strength
    cracks[sy % N, sx % N] = np.maximum(cracks[sy % N, sx % N], value)


def branch(start, angle, count, width, strength):
    points = [start]
    for _ in range(count):
        angle += rng.uniform(-0.55, 0.55)
        end = points[-1] + np.array([np.cos(angle), np.sin(angle)]) * rng.uniform(0.16, 0.48)
        segment(points[-1], end, width * rng.uniform(0.7, 1.2), strength)
        points.append(end)
    return points


for _ in range(64):
    angle = rng.uniform(-np.pi, np.pi)
    points = branch(rng.uniform(0, TILE, 2), angle, int(rng.integers(8, 22)), rng.uniform(0.025, 0.05), 1.0)
    for _ in range(int(rng.integers(1, 4))):
        branch(points[int(rng.integers(1, len(points) - 1))], angle + rng.choice([-1, 1]) * rng.uniform(0.6, 1.4), int(rng.integers(3, 9)), 0.022, 0.7)

# Tar resurfacing covers the older cracks; no painted potholes or fake geometry.
pixels = np.stack((wear, repairs, cracks * (1 - repairs)), axis=-1)
pixels = np.rint(np.clip(pixels.reshape(SIZE, 2, SIZE, 2, 3).mean(axis=(1, 3)), 0, 1) * 255).astype(np.uint8)


def chunk(kind, data):
    return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data) & 0xffffffff)


raw = b''.join(b'\0' + row.tobytes() for row in pixels)
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', SIZE, SIZE, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
path = Path(__file__).resolve().parents[1] / 'game/assets/textures/night_asphalt_wear_v1.png'
path.write_bytes(png)
print(json.dumps({'path': str(path), 'sha256': hashlib.sha256(png).hexdigest(), 'bytes': len(png), 'size': SIZE, 'tile_metres': TILE, 'seed': SEED, 'repair_coverage': float(np.mean(pixels[:, :, 1] > 64)), 'crack_coverage': float(np.mean(pixels[:, :, 2] > 32))}, indent=2))
