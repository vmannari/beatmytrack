"""Restore the preferred ribbons; round only their pinched upper return."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent


def mix(a, b, t):
    return tuple(x + (y-x)*t for x, y in zip(a, b))


def split(p, t):
    a, b, c = (mix(p[i], p[i+1], t) for i in range(3))
    d, e = mix(a, b, t), mix(b, c, t)
    f = mix(d, e, t)
    return (p[0], a, d, f), (f, e, c, p[3])


def point(p, t):
    return split(p, t)[0][-1]


def tangent(p, t):
    u = 1-t
    return tuple(3*u*u*(p[1][i]-p[0][i]) + 6*u*t*(p[2][i]-p[1][i]) + 3*t*t*(p[3][i]-p[2][i]) for i in range(2))


def at_y(p, y):
    lo, hi = 0., 1.
    increasing = p[-1][1] > p[0][1]
    for _ in range(60):
        t = (lo+hi)/2
        if (point(p, t)[1] < y) == increasing:
            lo = t
        else:
            hi = t
    return (lo+hi)/2


def cubic(p):
    return "C" + " ".join(f"{x:.6f} {y:.6f}" for x, y in p[1:])


upper_inner = ((310,95),(375,95),(416,125),(422,166))
upper_middle = ((355,110),(438,124),(508,163),(515,222))
# Join the existing union boundary at its exact intersection, preserving its outline.
t, s = .55, .18
for _ in range(30):
    a, b = point(upper_inner,t), point(upper_middle,s)
    da, db = tangent(upper_inner,t), tangent(upper_middle,s)
    ex, ey = a[0]-b[0], a[1]-b[1]
    det = da[1]*db[0]-da[0]*db[1]
    t -= (-ex*db[1]+db[0]*ey)/det
    s -= (da[0]*ey-da[1]*ex)/det
assert 0 < t < 1 and 0 < s < 1
outer_a, _ = split(upper_inner,t)
_, outer_b = split(upper_middle,s)
return_middle = ((366,310),(435,244),(465,209),(432,163))
return_inner = ((422,166),(432,201),(418,230),(389,255))
upper_t = at_y(return_middle,210)
lower_t = at_y(return_inner,230)
unchanged_middle, _ = split(return_middle,upper_t)
_, unchanged_inner = split(return_inner,lower_t)
entry = unchanged_middle[-1]
direction = tangent(return_middle,upper_t)
first = (entry[0]+direction[0]*.10,entry[1]+direction[1]*.10)
exit_point = unchanged_inner[0]
direction = tangent(return_inner,lower_t)
last = (exit_point[0]-direction[0]*.10,exit_point[1]-direction[1]*.10)
combined = (
    "M149 95H310" + cubic(outer_a) + cubic(outer_b) +
    "C521 280 488 320 440 368L278 500H157L366 310" + cubic(unchanged_middle) +
    f"C{first[0]:.6f} {first[1]:.6f} 446.25 189 438 178" +
    "C429 166 414 166 416 180" +
    f"C420 208 {last[0]:.6f} {last[1]:.6f} {exit_point[0]:.6f} {exit_point[1]:.6f}" +
    cubic(unchanged_inner) +
    "L122 500H0L258 242H351C374 242 387 230 387 214C387 198 373 185 351 185H208Z"
)
svg = (ROOT / "preferred.svg").read_text()
group = re.search(r'  <g id="b-mark".*?</g>',svg,re.S).group()
paths = re.findall(r'    <path d="[^"]+"/>',group)
assert len(paths) == 3
corrected = group.replace(paths[1] + "\n" + paths[2], f'    <path d="{combined}"/>')
(ROOT.parents[2] / "game/assets/menu/logo.svg").write_text(svg.replace(group,corrected))
print("Restored preferred silhouette and tails; rounded upper return at y=178..230")
