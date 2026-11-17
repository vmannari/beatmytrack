"""C302: morph-aware driver prototypes; exact open boundaries and all pose fields."""
import bpy,json,math,collections
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from pathlib import Path
R=Path(__file__).resolve().parents[1];W=R/'build/car-pass10-2026-11-16';O=R/'docs/evidence/car-pass10-2026-11-16'
data=json.loads((W/'driver-candidates.json').read_text());outputs=[]
def bary(p,a,b,c):
    ab=b-a;ac=c-a;ap=p-a;den=ab.dot(ab)*ac.dot(ac)-ab.dot(ac)**2
    if abs(den)<1e-25:return [1,0,0]
    v=(ac.dot(ac)*ap.dot(ab)-ab.dot(ac)*ap.dot(ac))/den;w=(ab.dot(ab)*ap.dot(ac)-ab.dot(ac)*ap.dot(ab))/den
    f=[max(0,1-v-w),max(0,v),max(0,w)];return [x/sum(f) for x in f]
for number,s in enumerate(data['geometry']):
    poses=[[Vector(p) for p in pose] for pose in s['poses']];normal_poses=[[Vector(p) for p in pose] for pose in s['normal_poses']];p=poses[0];faces=[s['indices'][i:i+3] for i in range(0,len(s['indices']),3)]
    identities={};unique=[];remap=[]
    for point in p:
        key=tuple(round(x,7) for x in point)
        if key not in identities:identities[key]=len(unique);unique.append(point)
        remap.append(identities[key])
    geo=[[remap[i] for i in f] for f in faces];edges=collections.Counter(tuple(sorted(e)) for a,b,c in geo for e in [(a,b),(b,c),(c,a)])
    locked={i for edge,count in edges.items() if count==1 for i in edge}
    for axis in range(3):locked.update([min(range(len(unique)),key=lambda i:unique[i][axis]),max(range(len(unique)),key=lambda i:unique[i][axis])])
    mesh=bpy.data.meshes.new('driver');mesh.from_pydata(unique,[],geo);mesh.update();obj=bpy.data.objects.new('driver',mesh);bpy.context.collection.objects.link(obj)
    group=obj.vertex_groups.new(name='boundaries');group.add(sorted(locked),1,'REPLACE');modifier=obj.modifiers.new('bounded','DECIMATE');modifier.decimate_type='COLLAPSE';modifier.use_collapse_triangulate=True;modifier.vertex_group=group.name;modifier.vertex_group_factor=1000;modifier.invert_vertex_group=True
    trees=[BVHTree.FromPolygons(pose,faces,all_triangles=True) for pose in poses]
    options=[]
    for ratio in [.95,.9,.85,.8,.75,.7,.65,.6,.55,.5]:
        modifier.ratio=ratio;bpy.context.view_layer.update();evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());result=evaluated.to_mesh();result.calc_loop_triangles();points=[v.co.copy() for v in result.vertices];triangles=[list(t.vertices) for t in result.loop_triangles]
        if any(min((q-unique[i]).length for q in points)>1e-7 for i in locked):evaluated.to_mesh_clear();continue
        # Field witnesses belong to a surface corner, not just its position.
        # Coincident garment layers and hard glove seams have different normals.
        refs=[];expanded=[]
        for tri in triangles:
            inward=(points[tri[1]]-points[tri[0]]).cross(points[tri[2]]-points[tri[0]]).normalized();indices=[]
            for at in tri:
                q=points[at];near=trees[0].find_nearest(q);hits=trees[0].find_nearest_range(q,near[3]+1e-7)
                hit=max(hits,key=lambda h:h[1].dot(inward)) if hits else near;ids=faces[hit[2]];weights=bary(hit[0],*(p[i] for i in ids))
                indices.append(len(refs));refs.append((ids,weights))
            expanded.append(indices)
        triangles=expanded
        next_poses=[];next_normals=[]
        for pose,normals in zip(poses,normal_poses):
            next_poses.append([sum((pose[i]*f for i,f in zip(ids,weights)),Vector()) for ids,weights in refs])
            next_normals.append([sum((normals[i]*f for i,f in zip(ids,weights)),Vector()).normalized() for ids,weights in refs])
        old_p=list(poses);new_p=list(next_poses);old_n=list(normal_poses);new_n=list(next_normals)
        for side in range(2):
            chain=[0]+list(range(1+side*5,6+side*5))
            for a,b in zip(chain,chain[1:]):
                old_p.append([(x+y)/2 for x,y in zip(poses[a],poses[b])]);new_p.append([(x+y)/2 for x,y in zip(next_poses[a],next_poses[b])]);old_n.append([(x+y).normalized() for x,y in zip(normal_poses[a],normal_poses[b])]);new_n.append([(x+y).normalized() for x,y in zip(next_normals[a],next_normals[b])])
        error=0;angular=0;okay=True
        for old,new,normals,next_normals_at in zip(old_p,new_p,old_n,new_n):
            old_tree=BVHTree.FromPolygons(old,faces,all_triangles=True);new_tree=BVHTree.FromPolygons(new,triangles,all_triangles=True)
            samples=[old[i] for i in set(s['indices'])]+[sum((old[i] for i in f),Vector())/3 for f in faces]
            error=max(error,max(new_tree.find_nearest(q)[3] for q in samples),max(old_tree.find_nearest(q)[3] for q in new))
            if error>.0018:okay=False;break
            for f in triangles:
                q=sum((new[i] for i in f),Vector())/3;near=old_tree.find_nearest(q);inward=(new[f[1]]-new[f[0]]).cross(new[f[2]]-new[f[0]]).normalized();hits=old_tree.find_nearest_range(q,near[3]+1e-7)
                hit=max(hits,key=lambda h:h[1].dot(inward)) if hits else near;ids=faces[hit[2]];weights=bary(hit[0],*(old[i] for i in ids));expected=sum((normals[i]*v for i,v in zip(ids,weights)),Vector()).normalized();actual=sum((next_normals_at[i] for i in f),Vector()).normalized();angular=max(angular,math.degrees(actual.angle(expected)))
            if angular>1:okay=False;break
        print('CP3_MORPH_REMESH',number,ratio,len(faces),len(triangles),error,angular,okay,flush=True)
        if okay:
            options.append(dict(ratio=ratio,poses=[[list(p) for p in pose] for pose in next_poses],normal_poses=[[list(p) for p in pose] for pose in next_normals],uv=[[sum(s['uv'][i][a]*v for i,v in zip(ids,weights)) for a in range(2)] for ids,weights in refs],indices=[i for f in triangles for i in f],references=refs,error=error,normal_error_degrees=angular))
        evaluated.to_mesh_clear()
    outputs.append(options);bpy.data.objects.remove(obj,do_unlink=True);bpy.data.meshes.remove(mesh)
(W/'driver-remeshed.json').write_text(json.dumps(outputs,separators=(',',':')))
print('CP3_MORPH_OPTIONS',[[(o['ratio'],len(o['indices'])//3) for o in group] for group in outputs],flush=True)
