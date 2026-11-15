import json,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/car15-2026-11-15'
source_data=json.loads((WORK/'retessellation-input.json').read_text())
targets=json.loads((WORK/'lamp-targets.json').read_text())
output=json.loads((WORK/'remeshed.json').read_text())
def barycentric(p,a,b,c):
    ab=b-a;ac=c-a;ap=p-a
    d00=ab.dot(ab);d01=ab.dot(ac);d11=ac.dot(ac);d20=ap.dot(ab);d21=ap.dot(ac)
    denominator=d00*d11-d01*d01
    if abs(denominator)<1e-25:return [1,0,0]
    v=(d11*d20-d01*d21)/denominator;w=(d00*d21-d01*d20)/denominator
    values=[max(0,1-v-w),max(0,v),max(0,w)];total=sum(values)
    return [x/total for x in values]

for key,target in targets.items():
    surfaces=[]
    for source in source_data[key]['surfaces']:
        positions=[Vector(p) for p in source['vertices']]
        faces=[source['indices'][at:at+3] for at in range(0,len(source['indices']),3)]
        old_tree=BVHTree.FromPolygons(positions,faces,all_triangles=True)
        points=[Vector(p) for p in target['vertices']]
        triangles=[target['indices'][at:at+3] for at in range(0,len(target['indices']),3)]
        maximum=0.0;contact=set()
        # Each corner has an original triangle and barycentric field witness.
        # Flat material/UV seams therefore stay separate from geometric welding.
        vertices=[];normals=[];uv=[];uv2=[];colors=[];tangents=[];indices=[];witnesses=[]
        for tri in triangles:
            face_normal=-(points[tri[1]]-points[tri[0]]).cross(points[tri[2]]-points[tri[0]]).normalized()
            for vertex in tri:
                p=points[vertex];near=old_tree.find_nearest(p)
                hits=old_tree.find_nearest_range(p,near[3]+0.0000001)
                hit=max(hits,key=lambda h:-h[1].dot(face_normal)) if hits else near
                ids=faces[hit[2]];factors=barycentric(hit[0],*(positions[i] for i in ids))
                def field(name,width):
                    return [sum(source[name][i][axis]*weight for i,weight in zip(ids,factors)) for axis in range(width)]
                normal=Vector(field('normals',3)).normalized()
                vertices.append(list(p));normals.append(list(normal));indices.append(len(indices));witnesses.append({'triangle':hit[2],'weights':factors})
                for name,target,width in [('uv',uv,2),('uv2',uv2,2),('colors',colors,4)]:
                    if source[name]:target.append(field(name,width))
                if source['tangents']:
                    tangent=Vector([sum(source['tangents'][i*4+a]*weight for i,weight in zip(ids,factors)) for a in range(3)]).normalized()
                    tangents.extend([*tangent,source['tangents'][ids[max(range(3),key=lambda i:factors[i])]*4+3]])
        surfaces.append({'vertices':vertices,'normals':normals,'uv':uv,'uv2':uv2,'colors':colors,'tangents':tangents,'indices':indices,'witnesses':witnesses,'sampled_error':maximum,'contact_vertices':sorted(contact)})
    output[key]=surfaces
(WORK/'remeshed.json').write_text(json.dumps(output,separators=(',',':')))
print('CAR15_LAMP_FIELDS',len(targets),flush=True)
