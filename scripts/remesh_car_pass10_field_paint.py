"""Constrained offline remeshing with original-surface interpolation witnesses."""
import bpy
import sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import collections
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/car-pass10-2026-11-16'
base_inputs=json.loads((WORK/'retessellation-input.json').read_text())
inputs={key+'@field'+str(degrees):dict(piece,source_key=key,field_degrees=degrees) for key,piece in base_inputs.items() if piece['name'] in ['ReferenceHood','ReferenceRearDeck'] for degrees in [1.0,1.5,2.0,2.5,3.0,4.0]}
rows=json.loads((ROOT/'docs/evidence/car-pass10-2026-11-16/survey.json').read_text())
weights=collections.Counter(r['key'] for r in rows if r['mode']=='stock')
scales={}
for row in rows:scales[row['key']]=max(scales.get(row['key'],0),row['maximum_scale'])
sys.path.insert(0,str(ROOT/"scripts"))
from car_pass10_contacts import collect_anchors
contact_anchors=collect_anchors(WORK,rows)
output=json.loads((WORK/"remeshed.json").read_text()) if any(a.startswith("--ratio=") for a in sys.argv) else {}
ratio_override=next((float(a.split("=")[1]) for a in sys.argv if a.startswith("--ratio=")),None)
problem_keys=set(json.loads((WORK/"problem-keys.json").read_text())) if ratio_override is not None else set()

def error(points,tree,limit):
    maximum=0.0
    for p in points:
        hit=tree.find_nearest(p)
        if hit[0] is None:return float('inf')
        maximum=max(maximum,hit[3])
        if maximum>limit:return maximum
    return maximum

def barycentric(p,a,b,c):
    ab=b-a;ac=c-a;ap=p-a
    d00=ab.dot(ab);d01=ab.dot(ac);d11=ac.dot(ac);d20=ap.dot(ab);d21=ap.dot(ac)
    denominator=d00*d11-d01*d01
    if abs(denominator)<1e-25:return [1,0,0]
    v=(d11*d20-d01*d21)/denominator;w=(d00*d21-d01*d20)/denominator
    values=[max(0,1-v-w),max(0,v),max(0,w)];total=sum(values)
    return [x/total for x in values]

for ordinal,(proposal,piece) in enumerate(inputs.items()):
    key=piece["source_key"]
    if ratio_override is not None and key not in problem_keys:continue
    if key.split('_')[0] not in ('compact','kart','forklift','electric','hovercraft') or not weights[key]:continue
    if any(term in piece['name'].lower() for term in ('accent','stripe','inlay','decal','sticker','highlight','shine','plate','letter')):continue
    surfaces=[]
    for surface_index,source in enumerate(piece['surfaces']):
        source['indices']=[int(i) for i in source['indices']]
        positions=[Vector(p) for p in source['vertices']]
        faces=[source['indices'][at:at+3] for at in range(0,len(source['indices']),3)]
        old_tree=BVHTree.FromPolygons(positions,faces,all_triangles=True)
        identity={};unique=[];remap=[]
        for p in positions:
            code=tuple(round(v,7) for v in p)
            if code not in identity:identity[code]=len(unique);unique.append(p)
            remap.append(identity[code])
        geo_faces=[[remap[i] for i in face] for face in faces]
        edges=collections.Counter(tuple(sorted(e)) for a,b,c in geo_faces for e in ((a,b),(b,c),(c,a)) if e[0]!=e[1])
        boundary={v for edge,count in edges.items() if count==1 for v in edge}
        contact=contact_anchors[(key,surface_index)]
        anchors=set(boundary)
        field_normals=[Vector(n) for n in source['normals']]
        for face in faces:
            if max(field_normals[face[i]].angle(field_normals[face[(i+1)%3]]) for i in range(3))>piece['field_degrees']*3.141592653589793/180:
                anchors.update(remap[i] for i in face)
        for axis in range(3):
            anchors.add(min(range(len(unique)),key=lambda i:unique[i][axis]));anchors.add(max(range(len(unique)),key=lambda i:unique[i][axis]))
        mesh=bpy.data.meshes.new('source');mesh.from_pydata(unique,[],geo_faces);mesh.update()
        obj=bpy.data.objects.new('candidate',mesh);bpy.context.collection.objects.link(obj)
        group=obj.vertex_groups.new(name='protected');group.add(sorted(anchors),1.0,'REPLACE')
        modifier=obj.modifiers.new('bounded','DECIMATE');modifier.decimate_type='COLLAPSE';modifier.use_collapse_triangulate=True
        modifier.vertex_group=group.name;modifier.vertex_group_factor=1000;modifier.invert_vertex_group=True
        old_samples=[positions[i] for i in set(source['indices'])]+[sum((positions[i] for i in face),Vector())/3 for face in faces]
        limit=0.0005/max(0.001,scales[key])
        best=None
        for ratio in ([ratio_override] if ratio_override is not None else [0.95,0.90,0.85,0.80,0.75,0.70,0.675,0.65,0.625,0.60,0.575,0.55,0.525,0.50,0.475,0.45,0.40,0.35,0.30]):
            modifier.ratio=ratio
            bpy.context.view_layer.update()
            evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());candidate=evaluated.to_mesh()
            candidate.calc_loop_triangles()
            points=[v.co.copy() for v in candidate.vertices]
            triangles=[list(t.vertices) for t in candidate.loop_triangles]
            if len(triangles)>=len(faces):evaluated.to_mesh_clear();continue
            # All authored open boundaries remain exact; group weights alone
            # are not accepted as a proof that the modifier preserved them.
            if any(min((p-unique[i]).length for p in points)>0.0000001 for i in anchors):evaluated.to_mesh_clear();continue
            tree=BVHTree.FromPolygons(points,triangles,all_triangles=True)
            maximum=error(old_samples,tree,limit)
            if maximum<=limit:
                maximum=max(maximum,error(points+[sum((points[i] for i in tri),Vector())/3 for tri in triangles],old_tree,limit))
            if maximum<=limit:
                normals_at=[]
                for p in points:
                    hit=old_tree.find_nearest(p);ids=faces[hit[2]];f=barycentric(hit[0],*(positions[i] for i in ids))
                    normals_at.append(sum((field_normals[i]*v for i,v in zip(ids,f)),Vector()).normalized())
                angular=0
                for tri in triangles:
                    p=sum((points[i] for i in tri),Vector())/3;hit=old_tree.find_nearest(p);ids=faces[hit[2]];f=barycentric(hit[0],*(positions[i] for i in ids))
                    expected=sum((field_normals[i]*v for i,v in zip(ids,f)),Vector()).normalized()
                    actual=sum((normals_at[i] for i in tri),Vector()).normalized()
                    angular=max(angular,actual.angle(expected)*180/3.141592653589793)
                if angular<0.99:best=(points,triangles,maximum)
                print('CP3_FIELD',piece['name'],piece['field_degrees'],ratio,len(triangles),maximum,angular,flush=True)
            evaluated.to_mesh_clear()
        bpy.data.objects.remove(obj,do_unlink=True);bpy.data.meshes.remove(mesh)
        if best is None:
            surfaces.append(None);continue
        points,triangles,maximum=best
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
        surfaces.append({'vertices':vertices,'normals':normals,'uv':uv,'uv2':uv2,'colors':colors,'tangents':tangents,'indices':indices,'witnesses':witnesses,'sampled_error':maximum,'contact_vertices':[]})
    if any(surface is not None for surface in surfaces):output[proposal]=surfaces
    if ordinal%100==0:print('CAR15_REMESH',ordinal,len(inputs),flush=True)
(WORK/'field-paint-remeshed.json').write_text(json.dumps(output,separators=(',',':')))
print('CAR15_REMESH_DONE',len(output),flush=True)
