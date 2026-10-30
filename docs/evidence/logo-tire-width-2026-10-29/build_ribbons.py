"""Build parallel ribbon outlines from one smooth centerline; no bitmap tracing."""
from pathlib import Path
import math
import re

REPO = Path(__file__).resolve().parents[3]
SOURCE = REPO / "game/assets/menu/logo.svg"


def sample(t):
    u = 1 - t
    shift = 66.4 * 76 / 58.24
    p = [(350-shift, 212), (440-shift, 212), (478-shift, 268.16), (402-shift, 326.4)]
    x = u**3*p[0][0] + 3*u*u*t*p[1][0] + 3*u*t*t*p[2][0] + t**3*p[3][0]
    y = u**3*p[0][1] + 3*u*u*t*p[1][1] + 3*u*t*t*p[2][1] + t**3*p[3][1]
    dx = 3*u*u*(p[1][0]-p[0][0]) + 6*u*t*(p[2][0]-p[1][0]) + 3*t*t*(p[3][0]-p[2][0])
    dy = 3*u*u*(p[1][1]-p[0][1]) + 6*u*t*(p[2][1]-p[1][1]) + 3*t*t*(p[3][1]-p[2][1])
    length = math.hypot(dx, dy)
    return x, y, -dy/length, dx/length


def boundary(offset):
    top = 212 + offset
    points = [(80 + 0.7*top/1.04, top)]
    for i in range(161):
        x, y, nx, ny = sample(i/160)
        points.append((x + nx*offset, y + ny*offset))
    x, y, nx, ny = sample(1)
    x += nx*offset
    y += ny*offset
    # Continue the same tangent; all ribbons end on the existing 520-unit baseline.
    dx, dy = -76, 58.24
    points.append((x + (520-y)*dx/dy, 520))
    return points


def ribbon(offset, width):
    a = boundary(offset-width/2)
    b = list(reversed(boundary(offset+width/2)))
    return "M" + " L".join(f"{x:.3f} {y:.3f}" for x, y in a+b) + "Z"


svg = SOURCE.read_text()
old = re.search(r'  <g id="b-mark".*?</g>', svg, re.S).group()
outer = "M80 0H485C532 0 557 16 589 49L635 98C676 141 673 194 631 232C691 271 704 333 676 397C649 459 590 500 515 500H376"
# The right-hand B edge keeps its silhouette, with a parallel inner edge so the
# second gap cannot pinch to a point where the previous hand-drawn paths merged.
edge = boundary(-148)
original = outer.split("H376")[0]
tokens = re.findall(r"[MHLCZ]|-?\d+(?:\.\d+)?", original)
scaled = []
command = None
index = 0
for token in tokens:
    if token.isalpha():
        command, index = token, 0
        scaled.append(token)
    else:
        value = float(token)
        if command in ("M", "L", "C") and index % 2:
            value *= 1.04
        scaled.append(f"{value:g}")
        index += 1
original = " ".join(scaled)
body = original + " L" + " L".join(f"{x:.3f} {y:.3f}" for x, y in reversed(edge)) + "Z"
new = ('  <g id="b-mark" fill="url(#gold)" transform="translate(8 8)">\n'
       f'    <path id="b-body" d="{body}"/>\n'
       f'    <path id="tire-outer" d="{ribbon(-90,64)}"/>\n'
       f'    <path id="tire-inner" d="{ribbon(0,64)}"/>\n'
       '  </g>')
SOURCE.write_text(svg.replace(old, new))
print("Authored 64-unit parallel ribbons, with a 26-unit gap")
