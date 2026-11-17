"""CP302: qualify the same index stream through every steering target and midpoint."""
import json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'build/car-pass10-2026-11-16'
OUT = ROOT / 'docs/evidence/car-pass10-2026-11-16'
data = json.loads((WORK / 'driver-candidates.json').read_text())
results = []
for option in data['options']:
    maximum = 0.0
    tests = 0
    for number, surface in enumerate(data['geometry']):
        authored = [[Vector(p) for p in pose] for pose in surface['poses']]
        poses = list(authored)
        for direction in range(2):
            chain = [authored[0]] + authored[1+direction*5:6+direction*5]
            poses.extend([(a+b)/2 for a, b in zip(one, two)] for one, two in zip(chain, chain[1:]))
        old = [surface['indices'][i:i+3] for i in range(0, len(surface['indices']), 3)]
        indices = option['indices'][number]
        new = [indices[i:i+3] for i in range(0, len(indices), 3)]
        for pose in poses:
            old_tree = BVHTree.FromPolygons(pose, old, all_triangles=True)
            new_tree = BVHTree.FromPolygons(pose, new, all_triangles=True)
            before = [pose[i] for i in set(surface['indices'])] + [sum((pose[i] for i in f), Vector())/3 for f in old]
            after = [pose[i] for i in set(indices)] + [sum((pose[i] for i in f), Vector())/3 for f in new]
            error = max(max(new_tree.find_nearest(p)[3] for p in before), max(old_tree.find_nearest(p)[3] for p in after))
            maximum = max(maximum, error)
            tests += 1
    results.append(dict(file=option['file'], before=option['before'], after=option['after'],
                        maximum_sampled_deviation_m=maximum, pose_surfaces=tests, accepted=maximum<=0.002))
    print('CP3_DRIVER_REVIEW', results[-1], flush=True)
(OUT / 'driver-geometry-review.json').write_text(json.dumps(results, indent=2)+'\n')
