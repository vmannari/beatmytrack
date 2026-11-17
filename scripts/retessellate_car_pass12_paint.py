"""CP202: retain high-gradient paint triangles; simplify only the flatter interior."""
import bmesh
import json
import math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/car-pass12-2026-11-16'
data=json.loads((WORK/'retessellation-input.json').read_text())
output={}
metrics={}
def bary(p,a,b,c):
    ab=b-a;ac=c-a;ap=p-a;den=ab.dot(ab)*ac.dot(ac)-ab.dot(ac)**2
    if abs(den)<1e-25:return [1,0,0]
    v=(ac.dot(ac)*ap.dot(ab)-ab.dot(ac)*ap.dot(ac))/den
    w=(ab.dot(ab)*ap.dot(ac)-ab.dot(ac)*ap.dot(ab))/den
    f=[max(0,1-v-w),max(0,v),max(0,w)];total=sum(f)
    return [x/total for x in f]
for key,piece in data.items():
    if piece['name'] not in ['ReferenceHood','ReferenceRearDeck']:continue
    assert len(piece['surfaces'])==1
    source=piece['surfaces'][0];p=[Vector(v) for v in source['vertices']];n=[Vector(v) for v in source['normals']]
    faces=[source['indices'][i:i+3] for i in range(0,len(source['indices']),3)]
    old=BVHTree.FromPolygons(p,faces,all_triangles=True)
    samples=p+[sum((p[i] for i in f),Vector())/3 for f in faces]
    best=list(source['indices']);measurement={}
    for threshold in [1.0,2.0,4.0]:
        keep={at for at,f in enumerate(faces) if max(math.degrees(n[f[i]].angle(n[f[(i+1)%3]])) for i in range(3))>threshold}
        touched={i for at in keep for i in faces[at]}
        keep.update(at for at,f in enumerate(faces) if any(i in touched for i in f))
        free=[f for at,f in enumerate(faces) if at not in keep]
        base=bmesh.new();layer=base.verts.layers.int.new('source');vertices={}
        for i in sorted({i for f in free for i in f}):
            v=base.verts.new(p[i]);v[layer]=i;vertices[i]=v
        for f in free:base.faces.new([vertices[i] for i in f])
        base.normal_update()
        boundary={v[layer] for v in base.verts if v.is_boundary}
        for angle in [1,4,8,16,30,45]:
            mesh=base.copy();ids=mesh.verts.layers.int['source']
            unlocked=[v for v in mesh.verts if v[ids] not in boundary]
            edges=[e for e in mesh.edges if all(v[ids] not in boundary for v in e.verts)]
            bmesh.ops.dissolve_limit(mesh,angle_limit=math.radians(angle),use_dissolve_boundaries=False,
                                    verts=unlocked,edges=edges,delimit=set())
            bmesh.ops.triangulate(mesh,faces=list(mesh.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
            candidate=[faces[i] for i in sorted(keep)]+[[v[ids] for v in f.verts] for f in mesh.faces]
            mesh.free()
            if len(candidate)*3>=len(best):continue
            tree=BVHTree.FromPolygons(p,candidate,all_triangles=True)
            error=max(tree.find_nearest(point)[3] for point in samples)
            if piece['name']=='ReferenceHood':print('CP2_PAINT_PROBE',threshold,angle,len(candidate),error,flush=True)
            if error>0.0005:continue
            field=0.0
            for f in candidate:
                point=sum((p[i] for i in f),Vector())/3;hit=old.find_nearest(point)
                error=max(error,hit[3]);old_f=faces[hit[2]];weights=bary(hit[0],*(p[i] for i in old_f))
                expected=sum((n[i]*w for i,w in zip(old_f,weights)),Vector()).normalized()
                actual=sum((n[i] for i in f),Vector()).normalized()
                field=max(field,math.degrees(actual.angle(expected)))
            if error<=0.0005 and field<1.0:
                best=[i for f in candidate for i in f];measurement=dict(error_m=error,normal_error_degrees=field,protected_triangles=len(keep))
        base.free()
    output[key]=[best];metrics[key]=measurement
    print('CP2_PAINT',piece['name'],len(source['indices'])//3,'->',len(best)//3,measurement,flush=True)
(WORK/'paint-retessellated.json').write_text(json.dumps(output))
(WORK/'paint-retessellated-metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
