"""Boundary-locked original-vertex retessellation, screened against BVH surfaces."""
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import collections
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/car-step10-2026-11-15'
inputs=json.loads((WORK/'retessellation-input.json').read_text())
observations=json.loads((ROOT/'docs/evidence/car-step10-2026-11-15/survey.json').read_text())
scales={}
for row in observations:scales[row['key']]=max(scales.get(row['key'],0),row['maximum_scale'])
output={}
quality={}

def sample_error(points,bvh,limit):
    maximum=0.0
    for point in points:
        hit=bvh.find_nearest(point)
        if hit[0] is None:return math.inf
        maximum=max(maximum,hit[3])
        if maximum>limit:return maximum
    return maximum

for ordinal,(key,piece) in enumerate(inputs.items()):
    surfaces=[];metrics=[]
    for source in piece['surfaces']:
        positions=[Vector(p) for p in source['vertices']]
        normals=[Vector(n) for n in source['normals']]
        faces=[source['indices'][at:at+3] for at in range(0,len(source['indices']),3)]
        identities={};unique=[];aliases=[];remap=[]
        for at,p in enumerate(positions):
            identity=tuple(round(v,7) for v in p)
            if identity not in identities:identities[identity]=len(unique);unique.append(p);aliases.append([])
            remap.append(identities[identity]);aliases[remap[-1]].append(at)
        edges=collections.Counter()
        for face in faces:
            ids=[remap[at] for at in face]
            for a,b in ((ids[0],ids[1]),(ids[1],ids[2]),(ids[2],ids[0])):
                if a!=b:edges[tuple(sorted((a,b)))]+=1
        boundary={at for edge,count in edges.items() if count==1 for at in edge}
        base=bmesh.new();layer=base.verts.layers.int.new('source_position')
        vertices=[]
        for at,p in enumerate(unique):
            v=base.verts.new(p);v[layer]=at;vertices.append(v)
        for face in faces:
            corners=[vertices[remap[at]] for at in face]
            if len(set(corners))!=3:continue
            try:base.faces.new(corners)
            except ValueError:pass
        base.normal_update()
        original_bvh=BVHTree.FromPolygons(positions,faces,all_triangles=True)
        used=set(source['indices'])
        old_samples=[positions[at] for at in used]+[sum((positions[at] for at in face),Vector())/3 for face in faces]
        limit=0.0018/max(0.001,scales[key])
        best=source['indices'];best_error=0.0;best_angle=0
        for angle in [1,4,8,16,30,45]:
            mesh=base.copy();identity=mesh.verts.layers.int['source_position']
            free=[v for v in mesh.verts if v[identity] not in boundary]
            free_edges=[e for e in mesh.edges if all(v[identity] not in boundary for v in e.verts)]
            bmesh.ops.dissolve_limit(mesh,angle_limit=math.radians(angle),use_dissolve_boundaries=False,
                                    verts=free,edges=free_edges,delimit=set())
            bmesh.ops.triangulate(mesh,faces=list(mesh.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
            indices=[]
            for face in mesh.faces:
                outward=-face.normal
                for vertex in face.verts:
                    options=aliases[vertex[identity]]
                    at=max(options,key=lambda index:normals[index].dot(outward))
                    assert (vertex.co-positions[at]).length<0.000001
                    indices.append(at)
            mesh.free()
            if not indices or len(indices)>=len(best):continue
            new_faces=[indices[at:at+3] for at in range(0,len(indices),3)]
            bvh=BVHTree.FromPolygons(positions,new_faces,all_triangles=True)
            error=sample_error(old_samples,bvh,limit)
            if error>limit:continue
            error=max(error,sample_error([sum((positions[at] for at in face),Vector())/3 for face in new_faces],original_bvh,limit))
            if error<=limit:best=indices;best_error=error;best_angle=angle
        surfaces.append(best);metrics.append({'angle':best_angle,'sampled_error':best_error})
        base.free()
    output[key]=surfaces;quality[key]=metrics
    if ordinal%100==0:print('CAR15_LOCKED_SURFACES',ordinal,len(inputs),flush=True)
(WORK/'expanded-retessellated.json').write_text(json.dumps(output,separators=(',',':')))
(WORK/'expanded-retessellated-bvh.json').write_text(json.dumps(quality))
print('CAR15_LOCKED_DONE',len(output),flush=True)
