"""Independent ray surveys: actual surface positions versus interpolated normals."""
from pathlib import Path
import json
import sys
import numpy as np
from mathutils.bvhtree import BVHTree

ROOT = Path.cwd()
OUT = ROOT / 'docs/evidence/challenger-surface-quality-2026-11-15'
BUILD = ROOT / 'build' / OUT.name
args = sys.argv[sys.argv.index('--') + 1:]
label = args[0]
data = json.loads((BUILD / (label + '.json')).read_text())
result = {}
for tier in ['simple', 'full']:
    row = data[tier]['body_paint']
    p = np.asarray(row['points']); n = np.asarray(row['normals'])
    f = np.asarray(row['indices']).reshape(-1, 3)[:, ::-1]
    tree = BVHTree.FromPolygons(p.tolist(), f.tolist(), all_triangles=True)
    tracks = {}
    for y in [.80, .84, .88, .92, .95]:
        values = []
        for z in np.linspace(-2.14, -.74, 281):
            hit, gn, i, _ = tree.ray_cast((2, y, float(z)), (-1, 0, 0), 2)
            if hit is None:
                values.append(None); continue
            a, b, c = p[f[i]]; u = b-a; v = c-a; w = np.asarray(hit)-a
            gram = np.array([[u@u, u@v], [u@v, v@v]])
            s, t = np.linalg.solve(gram, [w@u, w@v])
            sn = n[f[i]].T @ np.array([1-s-t, s, t]); sn /= np.linalg.norm(sn)
            values.append([float(z), float(hit.x), *sn.tolist(), *list(gn)])
        valid = np.array([v for v in values if v is not None])
        contiguous = [np.array(values[i-1:i+2]) for i in range(1, len(values)-1) if all(v is not None for v in values[i-1:i+2])]
        g = np.array([abs(v[0,1] - 2*v[1,1] + v[2,1])*1000 for v in contiguous])
        angles = np.degrees(np.arccos(np.clip(np.sum(valid[:-1, 2:5]*valid[1:, 2:5], axis=1), -1, 1)))
        tracks[str(y)] = {'coverage': len(valid), 'max_normal_step_deg': float(angles.max()), 'p95_normal_step_deg': float(np.percentile(angles,95)), 'max_second_difference_mm': float(g.max()), 'p95_second_difference_mm': float(np.percentile(g,95))}
    mask = (p[:,0]>.72)&(p[:,1]>.82)&(p[:,1]<1.03)&(p[:,2]>-2.16)&(p[:,2]<-.74)
    positions, inv = np.unique(np.round(p[mask],5), axis=0, return_inverse=True)
    ns = n[mask]; splits = []
    for j in range(len(positions)):
        group = ns[inv==j]
        if len(group)>1:
            splits.append(float(np.degrees(np.arccos(np.clip((group@group.T).min(),-1,1)))))
    result[tier] = {'tracks': tracks, 'upper_wing_normal_splits_over_10_deg': sum(v>10 for v in splits), 'maximum_duplicate_normal_angle_deg': max(splits)}
(OUT / (label + '-diagnosis.json')).write_text(json.dumps(result, indent=2))
print(json.dumps(result), flush=True)
