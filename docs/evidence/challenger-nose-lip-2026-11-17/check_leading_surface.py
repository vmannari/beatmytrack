"""Independent ray surveys of the packed leading strip and front-quarter cracks."""
from pathlib import Path
import json
import sys
import numpy as np
from mathutils.bvhtree import BVHTree

ROOT = Path.cwd()
OUT = ROOT / "docs/evidence/challenger-nose-lip-2026-11-17"
BUILD = ROOT / "build" / OUT.name
label = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "candidate"
before = json.loads((BUILD / "baseline.json").read_text())
after = json.loads((BUILD / (label + ".json")).read_text())
outline = np.asarray(json.loads((BUILD / "before/game/assets/vehicles/challenger_hellcat_v1/bonnet_contour.json").read_text())["points"])[:, [0, 2]]
checks = []
metrics = {}


def tree(rows, names):
    points = []
    faces = []
    for name in names:
        row = rows[name]
        indices = np.asarray(row["indices"]).reshape(-1, 3)
        faces.extend((indices + len(points)).tolist())
        points.extend(row["points"])
    return BVHTree.FromPolygons(points, faces, all_triangles=True),len(rows[names[0]]["indices"])//3


def height(surface, x, z):
    point, *_ = surface[0].ray_cast((float(x), 2, float(z)), (0, -1, 0), 2)
    return None if point is None else float(point.y)


def panel_domain(x, z):
    # Keep the physical shut line out of continuous-surface chord tests.
    a = outline
    b = np.roll(a, -1, axis=0)
    d = b-a
    q = np.array([x, z])
    t = np.clip(np.sum((q-a)*d, axis=1)/np.maximum(np.sum(d*d, axis=1), 1e-20), 0, 1)
    if np.linalg.norm(a+t[:,None]*d-q, axis=1).min() < .002:
        return None
    crossing = ((a[:,1]>z)!=(b[:,1]>z))
    ids = np.flatnonzero(crossing)
    intersections = a[ids,0]+(z-a[ids,1])*(b[ids,0]-a[ids,0])/(b[ids,1]-a[ids,1])
    return bool(np.count_nonzero(intersections>x)%2)


def owner(surface,x,z):
    point,_,index,_ = surface[0].ray_cast((float(x),2,float(z)),(0,-1,0),2)
    return None if point is None else int(index>=surface[1])


for tier in ["simple", "full"]:
    surveys = {}
    for name, data in [("before", before), ("after", after)]:
        top = tree(data[tier], ["body_paint", "hood_paint"])
        dents = []
        heights = []
        worst = None
        backward = []
        for x in np.linspace(-.60, .60, 61):
            for z in np.linspace(-2.025, -1.990, 15):
                h = height(top, x, z)
                heights.append(h)
                for dx, dz in [(.015, 0), (0, .004), (.010, .004)]:
                    values = [height(top, x-dx, z-dz), h, height(top, x+dx, z+dz)]
                    domains = [panel_domain(x-dx,z-dz),panel_domain(x,z),panel_domain(x+dx,z+dz)]
                    owners = [owner(top,x-dx,z-dz),owner(top,x,z),owner(top,x+dx,z+dz)]
                    if None not in values and None not in domains and domains[0] == domains[1] == domains[2] and owners[0] == owners[1] == owners[2]:
                        dents.append(max(0, (values[0] + values[2]) * .5 - values[1]))
                        if worst is None or dents[-1] > worst[-1]: worst = [float(x),float(z),dx,dz,dents[-1]]
                ahead = height(top, x, z-.002)
                if ahead is not None:
                    backward.append(max(0, ahead-h))
        side = tree(data[tier], ["body_paint"])
        misses = []
        raw_misses = 0
        for y in np.arange(.60, .7801, .0015):
            for z in np.arange(-1.965, -1.70, .0015):
                point, *_ = side[0].ray_cast((2, float(y), float(z)), (-1, 0, 0), 2)
                if point is None or point.x < .75:
                    raw_misses += 1
                    # Avoid an exact shared-edge ray's floating-point rejection.
                    nearby = [side[0].ray_cast((2,float(y+dy),float(z+dz)),(-1,0,0),2)[0] for dy,dz in [(-.000002,0),(.000002,0),(0,-.000002),(0,.000002)]]
                    if not any(p is not None and p.x > .75 for p in nearby):
                        misses.append([float(y), float(z)])
        surveys[name] = {
            "leading_samples": len(heights),
            "worst": worst,
            "leading_chord_samples": len(dents),
            "maximum_inward_chord_mm": max(dents) * 1000,
            "maximum_forward_upturn_mm": max(backward) * 1000,
            "maximum_height_metres": max(heights),
            "side_rays": len(np.arange(.60, .7801, .0015)) * len(np.arange(-1.965, -1.70, .0015)),
            "side_misses": len(misses),
            "side_raw_misses": raw_misses,
            "shared_edge_probe_metres": .000002,
            "miss_samples": misses[:12],
        }
    current = surveys["after"]
    checks.extend([
        {"name": tier + " leading strip has dense physical coverage", "pass": current["leading_chord_samples"] > 2000},
        {"name": tier + " leading strip inward chord stays below 0.20mm", "pass": current["maximum_inward_chord_mm"] < .20},
        {"name": tier + " tip turns downward without a local upturn", "pass": current["maximum_forward_upturn_mm"] < .05},
        {"name": tier + " front quarters retain solid paint coverage", "pass": current["side_misses"] == 0},
    ])
    metrics[tier] = surveys
result = {"checks": len(checks), "failures": sum(not row["pass"] for row in checks), "assertions": checks, "metrics": metrics}
(OUT / (label + "-leading.json")).write_text(json.dumps(result, indent=2))
print("CHALLENGER_LEADING_SURFACE", result["checks"], "checks", result["failures"], "failures")
for name, rows in metrics.items():
    print(name, rows)
if result["failures"]:
    raise SystemExit(1)
