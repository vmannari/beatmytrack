"""CME01-CME05: independent source, hidden-face and distance geometry checks.

Run with the pinned Blender Python for mathutils; no mesh authoring occurs here.
"""
from pathlib import Path
import collections
import json
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'build/car-mechanics-2026-11-17'
OUT = ROOT / 'docs/evidence/car-mechanics-2026-11-17'

def tree(points, indices):
    return BVHTree.FromPolygons([Vector(p) for p in points],
                               [indices[i:i+3] for i in range(0, len(indices), 3)],
                               all_triangles=True)

def upper_bound(points, indices, target, tolerance=.0002):
    """Distance is 1-Lipschitz: centroid distance + enclosing radius is an upper bound."""
    worst = 0.
    vectors = [Vector(p) for p in points]
    def visit(a, b, c, depth=0):
        middle = (a+b+c)/3
        distance = target.find_nearest(middle)[3]
        radius = max((middle-p).length for p in (a,b,c))
        bound = distance+radius
        nonlocal worst
        if bound <= worst: return
        if radius <= tolerance or depth >= 12:
            worst = max(worst, bound)
            return
        # The current measured lower bound prunes almost all flat interior cells.
        worst = max(worst, distance)
        ab, bc, ca = (a+b)/2, (b+c)/2, (c+a)/2
        for triangle in ((a,ab,ca),(ab,b,bc),(ca,bc,c),(ab,bc,ca)):
            visit(*triangle, depth+1)
    for at in range(0,len(indices),3):
        visit(*(vectors[i] for i in indices[at:at+3]))
    return worst

def topology(points, indices):
    ids={}; mapped=[]
    for p in points:
        code=tuple(round(v,6) for v in p)
        if code not in ids: ids[code]=len(ids)
        mapped.append(ids[code])
    edges=collections.Counter(); faces=[]; parents=list(range(len(ids)))
    def root(i):
        while parents[i]!=i:
            parents[i]=parents[parents[i]];i=parents[i]
        return i
    for at in range(0,len(indices),3):
        tri=[mapped[i] for i in indices[at:at+3]]
        if len(set(tri))<3:continue
        faces.append(tri)
        for a,b in zip(tri,tri[1:]+tri[:1]):
            edges[tuple(sorted((a,b)))]+=1;parents[root(a)]=root(b)
    used=set(i for f in faces for i in f)
    return dict(boundaries=sum(v==1 for v in edges.values()),
                nonmanifold=sum(v>2 for v in edges.values()),
                components=len({root(i) for i in used}),
                euler=len(used)-len(edges)+len(faces))

proof=json.loads((WORK/'proof-geometry.json').read_text())
selection=json.loads((OUT/'selected-plan.json').read_text())
review={}
for key,row in proof.items():
    if 'required_bindings' in selection['parts'][key]:
        for sf in row['surfaces']:
            assert sf['before']==sf['after']
            assert sf['before_attributes']==sf['after_attributes']
            before=[sf['before_indices'][i:i+3] for i in range(0,len(sf['before_indices']),3)]
            after=[sf['after_indices'][i:i+3] for i in range(0,len(sf['after_indices']),3)]
            cursor=iter(before)
            assert all(any(t==old for old in cursor) for t in after)
        review[key]=dict(accepted=True, exact_retained_corners=True, kind='certified_hidden')
    else:
        assert len(row['surfaces'])==1
        sf=row['surfaces'][0]
        one=tree(sf['before'],sf['before_indices']);two=tree(sf['after'],sf['after_indices'])
        maximum=max(upper_bound(sf['before'],sf['before_indices'],two,.00005),
                    upper_bound(sf['after'],sf['after_indices'],one,.00005))
        before=topology(sf['before'],sf['before_indices']);after=topology(sf['after'],sf['after_indices'])
        assert before==after,(before,after)
        assert maximum<=.002,maximum
        review[key]=dict(accepted=True, kind='pin', surface_upper_bound_m=maximum, topology=after)
(OUT/'geometry-review.json').write_text(json.dumps(dict(parts=review,rejected=0),indent=2)+'\n')
print('MECHANICS_STATIC',len(review),'passed',flush=True)

distance={}
for key,row in json.loads((WORK/'distance-proof-input.json').read_text()).items():
    one=tree(row['vertices'],row['before']);two=tree(row['vertices'],row['after'])
    maximum=max(upper_bound(row['vertices'],row['before'],two,.0005),
                upper_bound(row['vertices'],row['after'],one,.0005))
    before=topology(row['vertices'],row['before']);after=topology(row['vertices'],row['after'])
    accepted=(maximum<.05 and after['components']==before['components']
              and after['boundaries']<=before['boundaries']
              and after['nonmanifold']<=before['nonmanifold'] and after['euler']==before['euler'])
    distance[key]=dict(accepted=accepted,surface_upper_bound_m=maximum,before_topology=before,
                       after_topology=after, before_triangles=len(row['before'])//3,
                       after_triangles=len(row['after'])//3,resource=row['resource'])
    print('MECHANICS_DISTANCE_PROOF',key,accepted,maximum,before,after,flush=True)
(OUT/'distance-review.json').write_text(json.dumps(distance,indent=2)+'\n')
