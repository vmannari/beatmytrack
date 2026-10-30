"""Restore the original inner return; correct the circled outer transition."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parent


def mix(a, b, t):
    return tuple(x+(y-x)*t for x,y in zip(a,b))


def split(p, t):
    a,b,c = (mix(p[i],p[i+1],t) for i in range(3))
    d,e = mix(a,b,t),mix(b,c,t)
    f = mix(d,e,t)
    return (p[0],a,d,f),(f,e,c,p[3])


def tangent(p,t):
    u=1-t
    return tuple(3*u*u*(p[1][i]-p[0][i])+6*u*t*(p[2][i]-p[1][i])+3*t*t*(p[3][i]-p[2][i]) for i in range(2))


inner_top = ((310,95),(375,95),(416,125),(422,166))
old_return = ((432,163),(414,142),(387,122),(355,110))
t,s = .22,.75
for _ in range(25):
    a,b = split(old_return,t)[0][-1],split(inner_top,s)[0][-1]
    da,db = tangent(old_return,t),tangent(inner_top,s)
    ex,ey = a[0]-b[0],a[1]-b[1]
    det = da[1]*db[0]-da[0]*db[1]
    t -= (-ex*db[1]+db[0]*ey)/det
    s -= (da[0]*ey-da[1]*ex)/det
assert 0<t<1 and 0<s<1
assert math.dist(split(old_return,t)[0][-1],split(inner_top,s)[0][-1])<1e-8
return_left,_ = split(old_return,t)
_,inner_right = split(inner_top,s)
cubic = lambda p: "C"+" ".join(f"{x:.8f} {y:.8f}" for x,y in p[1:])
# A level lead-in follows the existing upper stripe. One tangent-continuous
# cubic replaces the crossing upper curves that formed the circled shoulder.
outline = (
    "M149 95H395C455 95 508 163 515 222"+
    "C521 280 488 320 440 368L278 500H157L366 310"+
    "C435 244 465 209 432 163"+cubic(return_left)+cubic(inner_right)+
    "C432 201 418 230 389 255L122 500H0L258 242H351"+
    "C374 242 387 230 387 214C387 198 373 185 351 185H208Z"
)
svg = (ROOT/"preferred.svg").read_text()
group = re.search(r'  <g id="b-mark".*?</g>',svg,re.S).group()
paths = re.findall(r'    <path d="[^"]+"/>',group)
assert len(paths)==3
replacement = group.replace(paths[1]+"\n"+paths[2],f'    <path d="{outline}"/>')
(ROOT.parents[2]/"game/assets/menu/logo.svg").write_text(svg.replace(group,replacement))
print("Preferred return and tails restored; circled shoulder replaced by a flat-to-curve transition")
