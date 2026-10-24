"""Trace selected broad crest windows in the existing dune artwork into UV data.

Image analysis only: no artwork is generated or modified. The runtime repeats
these eight-point emission roots with the terrain's exact world XZ / 28m UVs.
"""
from pathlib import Path
import hashlib
import json
import math
import statistics
import sys
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "game/assets/textures/desert_sand_v2.png"
# Original-art crest windows, expressed in the 1254-square review view.
WINDOWS = [
    ((205, 165), (209, 204)), ((782, 164), (787, 201)),
    ((1047, 247), (1067, 283)), ((195, 446), (191, 480)),
    ((526, 370), (522, 409)), ((797, 437), (824, 457)),
    ((1045, 522), (1057, 552)), ((313, 741), (343, 754)),
    ((653, 798), (667, 838)), ((1076, 730), (1099, 751)),
    ((440, 1069), (425, 1104)), ((123, 1179), (113, 1207)),
    ((663, 1186), (653, 1223)), ((1141, 960), (1141, 995)),
]
LIP_ROOTS = {10: (440, 1069), 11: (152, 1192), 12: (663, 1186), 13: (1141, 960)}
art = Image.open(SOURCE).convert("L").filter(ImageFilter.GaussianBlur(3))
width, height = art.size

def light(uv):
    x = int(round(uv[0] * width)) % width
    y = int(round(uv[1] * height)) % height
    return art.getpixel((x, y)) / 255.0

roots, contrasts, selected_windows = [], [], []
for window_index, (first, last) in enumerate(WINDOWS):
    a, b = [v / 1254.0 for v in first], [v / 1254.0 for v in last]
    length = math.dist(a, b)
    normal = [-(b[1] - a[1]) / length, (b[0] - a[0]) / length]
    row, deltas = [], []
    for step in range(8):
        u = step / 7.0
        at = [a[i] * (1.0 - u) + b[i] * u for i in range(2)]
        choices = []
        for probe in range(97):
            offset = -0.035 + probe * 0.070 / 96
            p = [at[i] + normal[i] * offset for i in range(2)]
            delta = abs(light([p[i] + normal[i] * 0.004 for i in range(2)]) - light([p[i] - normal[i] * 0.004 for i in range(2)]))
            choices.append((delta - abs(offset) * 0.5, delta, p))
        _, delta, point = max(choices, key=lambda choice: choice[0])
        row.append([round(float(v), 7) for v in point])
        deltas.append(delta)
    if window_index in LIP_ROOTS:
        # The softly lit lower crowns have little luminance discontinuity.
        # Pin their artist-reviewed lip rather than snapping onto a dark ripple.
        point = [v / 1254.0 for v in LIP_ROOTS[window_index]]
        row = [[round(v, 7) for v in point] for _ in range(8)]
        deltas = [abs(light([point[i] + normal[i] * 0.004 for i in range(2)]) - light([point[i] - normal[i] * 0.004 for i in range(2)]))] * 8
    elif statistics.mean(deltas) < 0.015:
        continue
    else:
        strong = [i for i, delta in enumerate(deltas) if delta >= 0.01]
        selected = [min(strong, key=lambda j: abs(j - i)) if deltas[i] < 0.01 else i for i in range(8)]
        row = [row[i] for i in selected]
        deltas = [deltas[i] for i in selected]
    roots.append(row)
    selected_windows.append([first, last])
    contrasts.append([round(min(deltas), 5), round(statistics.mean(deltas), 5)])

source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
lines = ["extends RefCounted", "## Generated from the original dune albedo; run scripts/bake_desert_dune_edges.py.",
         f'const SOURCE_SHA256: String = "{source_hash}"', "const TILE: float = 28.0", "const ROOTS: Array[Array] = ["]
for row in roots:
    lines.append("\t[" + ", ".join(f"Vector2({x:.7f}, {y:.7f})" for x, y in row) + "],")
lines.append("]\n")
generated = "\n".join(lines).encode()
target = ROOT / "game/track/desert_dune_edges.gd"
receipt = ROOT / "docs/evidence/desert-dune-edges-2026-10-24/atlas.json"
receipt_bytes = (json.dumps(dict(source_sha256=source_hash, tile_metres=28, windows=selected_windows, lip_roots=LIP_ROOTS, roots=roots, contrast_min_mean=contrasts), indent=2) + "\n").encode()
if "--check" in sys.argv:
    assert target.read_bytes() == generated, "Generated guide data differs"
    assert receipt.read_bytes() == receipt_bytes, "Atlas provenance differs"
else:
    target.write_bytes(generated)
    receipt.write_bytes(receipt_bytes)
print(json.dumps(dict(windows=len(roots), roots=sum(map(len, roots)), contrast_min_mean=contrasts)))
