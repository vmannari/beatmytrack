"""C302: certify covered triangles inside closed opaque meshes using distance balls.

Each proof triangle is enclosed by a ball centred at its centroid with radius at
least its furthest corner. If that ball is strictly inside a closed opaque mesh,
the whole triangle is inside. Subdivision only tightens the proof; it never edits
geometry. Tests use a 0.5 mm burial margin and the same rigid articulation frame.
"""
import collections,json,math
from pathlib import Path
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1];WORK=ROOT/'build/car-mechanics-2026-11-17';OUT=ROOT/'docs/evidence/car-mechanics-2026-11-17'
rows=json.loads((WORK/'visibility-survey.json').read_text());data=json.loads((WORK/'contacts-input.json').read_text());blocked=set()
MARGIN=.0005
def closed(key):
    points=[];faces=[]
    for s in data[key]['surfaces']:
        offset=len(points);points.extend(s['vertices']);faces.extend([[i+offset for i in s['indices'][at:at+3]] for at in range(0,len(s['indices']),3)])
    ids={};mapped=[]
    for p in points:
        code=tuple(round(v,6) for v in p)
        if code not in ids:ids[code]=len(ids)
        mapped.append(ids[code])
    edges=collections.Counter();signed=collections.Counter();volume=0
    for tri in faces:
        a,b,c=[mapped[i] for i in tri]
        if len({a,b,c})<3:continue
        v=[Vector(points[i]) for i in tri];volume+=v[0].dot(v[1].cross(v[2]))
        for one,two in [(a,b),(b,c),(c,a)]:
            edge=tuple(sorted((one,two)));edges[edge]+=1;signed[edge]+=1 if one<two else -1
    return bool(edges) and all(v==2 for v in edges.values()) and not any(signed.values()) and volume < -1e-12
closure={k:closed(k) for k in data}
def transform(row):
    pose=[Vector(p) for p in row['pose']];surfaces=[]
    for s in data[row['key']]['surfaces']:
        surfaces.append([pose[3]+pose[0]*p[0]+pose[1]*p[1]+pose[2]*p[2] for p in s['vertices']])
    return surfaces
def inside(tree,p):
    # Reject ambiguous edge/vertex hits by requiring three independent parity
    # rays to agree, with non-axis directions through the closed manifold.
    for raw in [(1,.173,.317),(.211,1,.419),(.137,.293,1)]:
        direction=Vector(raw).normalized();q=p.copy();hits=0
        for count in range(256):
            hit=tree.ray_cast(q,direction)
            if hit[0] is None:break
            hits+=1;q=hit[0]+direction*.0000001
        else:return False
        if hits%2!=1:return False
    return True
def cover(tree,a,b,c,depth=0):
    p=(a+b+c)/3;radius=max((p-v).length for v in (a,b,c));nearest=tree.find_nearest(p)
    if nearest[0] is None or nearest[3]<=MARGIN:return False
    if nearest[3]>radius+MARGIN:return inside(tree,p)
    if depth>=7:return False
    # Quick rejection before subdividing large proof triangles.
    if depth==0 and any(tree.find_nearest(v)[3]<=MARGIN or not inside(tree,v) for v in (a,b,c)):return False
    ab=(a+b)/2;bc=(b+c)/2;ca=(c+a)/2
    return all(cover(tree,*t,depth+1) for t in [(a,ab,ca),(ab,b,bc),(ca,bc,c),(ab,bc,ca)])
groups=collections.defaultdict(list)
for r in rows:groups[r['vehicle'],r['mode'],r['frame']].append(r)
common={};witnesses=collections.defaultdict(set);records=[]
for ordinal,(frame,parts) in enumerate(groups.items()):
    shapes=[];occluders=[]
    for row in parts:
        surfaces=transform(row);vertices=[p for s in surfaces for p in s];low=np.min([list(p) for p in vertices],axis=0);high=np.max([list(p) for p in vertices],axis=0)
        shape=dict(row=row,surfaces=surfaces,low=low,high=high);shapes.append(shape)
        if row['occluder'] and closure[row['key']]:
            faces=[];points=[]
            for source,positions in zip(data[row['key']]['surfaces'],surfaces):
                offset=len(points);points.extend(positions);faces.extend([[i+offset for i in source['indices'][at:at+3]] for at in range(0,len(source['indices']),3)])
            shape['tree']=BVHTree.FromPolygons(points,faces,all_triangles=True);occluders.append(shape)
    for shape in shapes:
        row=shape['row'];key=row['key']
        if key in blocked or not row['permitted'] or row['blend_shapes'] or not row['occluder']:continue
        found=[];bounds=[]
        for number,(source,positions) in enumerate(zip(data[key]['surfaces'],shape['surfaces'])):
            indices=source['indices'];mask=[]
            for at in range(0,len(indices),3):
                tri=[positions[i] for i in indices[at:at+3]];lo=np.min([list(p) for p in tri],axis=0);hi=np.max([list(p) for p in tri],axis=0);covered=False
                for other in occluders:
                    if other is shape or row['shadow']!=0 and other['row']['shadow']==0:continue
                    if np.any(lo<=other['low']+MARGIN) or np.any(hi>=other['high']-MARGIN):continue
                    if cover(other['tree'],*tri):
                        mask.append(at//3);witnesses[key].add(other['row']['binding']);covered=True;break
            found.append(set(mask))
        if key not in common:common[key]=found
        else:common[key]=[a&b for a,b in zip(common[key],found)]
    print('CP3_OCCLUSION_FRAME',ordinal,len(groups),frame,'closed',len(occluders),flush=True)
result={};pinned=set()
for key,masks in common.items():
    total=sum(len(m) for m in masks)
    if not total:continue
    if any(len(m)==len(s['indices'])//3 for m,s in zip(masks,data[key]['surfaces'])):continue
    result[key]=dict(remove=[sorted(m) for m in masks],required_bindings=sorted(witnesses[key]),removed=total)
    pinned.update(witnesses[key])
binding_sources={r['binding']:r['key'] for r in rows}
pinned_sources={binding_sources[b] for b in pinned}
result={k:v for k,v in result.items() if k not in pinned_sources}
(WORK/'hidden-proposals.json').write_text(json.dumps(result,separators=(',',':')))
stock=collections.Counter(r['key'] for r in rows if r['mode']=='stock')
report=dict(margin_m=MARGIN,source_and_fitted_intersection=True,rigid_frame_only=True,closed_meshes=sum(closure.values()),parts=result,pinned_sources=sorted(pinned_sources),potential_savings={car:sum(v['removed']*stock[k] for k,v in result.items() if k.startswith(car+'_')) for car in ['compact','kart','forklift','electric','hovercraft']})
(OUT/'hidden-proof.json').write_text(json.dumps(report,indent=2)+'\n');print('CP3_HIDDEN_SAVINGS',report['potential_savings'],flush=True)
