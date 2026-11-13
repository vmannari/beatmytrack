"""Blender offline conversion of the owner-supplied CC-BY Hellcat.

Run with factory startup and --disable-autoexec. No embedded scripts, Rigacar,
source textures, studio objects or rig are exported. The source is never saved.
"""
import bpy
import bmesh
import hashlib
import json
import math
import numpy as np
from pathlib import Path
import sys
from mathutils import Vector

args = sys.argv[sys.argv.index("--")+1:]
source, labels_file, output = map(Path,args[:3])
output.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False,use_scripts=False)
body=bpy.data.objects['Hellcat-Body']
labels=np.load(labels_file)['labels']
mesh=body.data;mesh.calc_loop_triangles()
co=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',co);co=co.reshape(-1,3)
tri=np.empty(len(mesh.loop_triangles)*3,dtype=np.int32);mesh.loop_triangles.foreach_get('vertices',tri);tri=tri.reshape(-1,3)
mi=np.empty(len(mesh.loop_triangles),dtype=np.int32);mesh.loop_triangles.foreach_get('material_index',mi)
component=labels[tri[:,0]]
world=np.array(body.matrix_world,dtype=np.float64)
body_world=co@world[:3,:3].T+world[:3,3]
original_wheels={o.name:o for o in bpy.data.objects if o.name.startswith('Hellcat-Wheel.')}
wheel_centres={name:np.mean([np.array(o.matrix_world@Vector(c)) for c in o.bound_box],axis=0) for name,o in original_wheels.items()}
front_y=float(np.mean([c[1] for n,c in wheel_centres.items() if '.Ft.' in n]))
rear_y=float(np.mean([c[1] for n,c in wheel_centres.items() if '.Bk.' in n]))
centre_x=float(np.mean([c[0] for c in wheel_centres.values()]));wheel_z=float(np.mean([c[2] for c in wheel_centres.values()]))
scale=np.array([1.50,2.56/(rear_y-front_y),0.37/0.26099])

def game(points):
    return np.c_[-(points[:,0]-centre_x)*scale[0],(points[:,2]-wheel_z)*scale[2]+0.37,(points[:,1]-front_y)*scale[1]-1.28]

def blender(points): return np.c_[points[:,0],-points[:,2],points[:,1]]
fitted_body=game(body_world)

ROLE={'Car Paint':'paint','Paint':'accent','Basic Glass':'glass','Mirror':'mirror','Matter Black':'dark',
      'Gloss Black':'accent','Chrome':'chrome','Metal09':'dark','Black Metal':'dark',
      'Red Light':'red','White Light':'white','Headlight Glow':'white','Orange Light':'amber',
      'Cranberry Juice':'red','Material':'dark','Rim':'detail','Composite Rubber':'rubber'}
materials={}
for name,color in {'paint':(.55,.04,.025,1),'accent':(.025,.033,.038,1),'glass':(.025,.045,.057,1),
                   'mirror':(.36,.42,.44,1),'dark':(.016,.021,.025,1),'chrome':(.48,.53,.54,1),
                   'red':(.48,.015,.01,1),'white':(.65,.69,.66,1),'amber':(.65,.22,.01,1),
                   'detail':(.40,.44,.45,1),'rubber':(.014,.018,.02,1),'reverse':(.08,.065,.065,1)}.items():
    m=bpy.data.materials.new('BMT_'+name);m.diffuse_color=color;materials[name]=m

all_source=list(bpy.data.objects)
for obj in all_source: obj.hide_render=True;obj.hide_set(True)

record={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(), 'source_triangles':len(tri)+sum(len(o.data.polygons)*2 for o in original_wheels.values()),
        'body_source_triangles':len(tri),'source':str(source),'source_wheel_centres':{k:v.tolist() for k,v in wheel_centres.items()},
        'body_scale_xyz':scale.tolist(),'tiers':{},'removed_components':[],'native_materials_only':True}

def new_piece(name, points, faces, mat_indices, mat_names):
    used,faces=np.unique(np.asarray(faces).ravel(),return_inverse=True)
    data=bpy.data.meshes.new(name);data.from_pydata(blender(points[used]).tolist(),[],faces.reshape(-1,3).tolist());data.update()
    for n in mat_names:data.materials.append(materials[ROLE.get(n,'dark')])
    data.polygons.foreach_set('material_index',np.asarray(mat_indices,dtype=np.int32))
    for p in data.polygons:p.use_smooth=True
    obj=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(obj)
    return obj

def reduce(obj, target):
    obj.hide_set(False);obj.hide_render=False;bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    obj.data.calc_loop_triangles();before=len(obj.data.loop_triangles)
    reference=None
    if before>target:
        reference=obj.copy();reference.data=obj.data.copy();bpy.context.scene.collection.objects.link(reference)
        reference.hide_set(True);reference.hide_render=True
        mod=obj.modifiers.new('Offline silhouette reduction','DECIMATE')
        glass=all(obj.data.materials[p.material_index].name=='BMT_glass' for p in obj.data.polygons)
        if glass:
            mod.decimate_type='DISSOLVE';mod.angle_limit=math.radians(2.0);mod.use_dissolve_boundaries=False
        else:
            mod.ratio=target/float(before);mod.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.set_sharp_from_angle(angle=math.radians(52))
    if reference is not None:
        transfer=obj.modifiers.new('Retain dense surface normals','DATA_TRANSFER');transfer.object=reference
        transfer.use_loop_data=True;transfer.data_types_loops={'CUSTOM_NORMAL'};transfer.loop_mapping='POLYINTERP_NEAREST'
        bpy.ops.object.datalayout_transfer(modifier=transfer.name)
        bpy.ops.object.modifier_apply(modifier=transfer.name)
        bpy.data.objects.remove(reference,do_unlink=True)
    obj.data.calc_loop_triangles();obj.select_set(False)
    return len(obj.data.loop_triangles)

def body_target(key, count, simple):
    explicit={1464:(7000,4000),1491:(2500,1500),1624:(1500,900),1572:(1600,900),2149:(700,350),
              1862:(600,350),4445:(600,350),2790:(900,450)}
    if key in explicit:return explicit[key][1 if simple else 0]
    return min(count,max(40 if simple else 72,int(count*(.018 if simple else .035))))

for simple in [False,True]:
    tier='simple' if simple else 'full';pieces=[];groups={};statistics=[]
    bpy.ops.object.select_all(action='DESELECT')
    for key in np.unique(component):
        mask=component==key;faces=tri[mask];indices=mi[mask];count=len(faces)
        names={mesh.materials[int(i)].name for i in np.unique(indices)}
        pts=co[np.unique(faces)];low,high=pts.min(0),pts.max(0)
        badge=any(n.startswith('SVGMat') for n in names) or int(key) in [415457,417915]
        badge=badge or (names=={'Black Metal'} and low[1]>1.28 and max(abs(low[0]),abs(high[0]))<.16)
        tiny=count<20
        interior=int(key) in [0,732]
        if badge or tiny or interior:
            if not simple:record['removed_components'].append({'component':int(key),'triangles':count,'reason':'cabin floor' if interior else 'badge geometry' if badge else 'micro grille/hidden detail'})
            continue
        group='hood' if int(key) in [1572,321860,323444,323460] else 'aero' if int(key)==297986 else 'body'
        if names=={'Red Light'}:group='tail_left' if (low[0]+high[0])*0.5>centre_x else 'tail_right'
        if names in [{'White Light'},{'Headlight Glow'}] and high[1]<0:group='head_left' if (low[0]+high[0])*0.5>centre_x else 'head_right'
        material_names=[m.name for m in mesh.materials]
        if int(key)==436063:
            group='head_right';material_names=['Headlight Glow' if m=='Gloss Black' else m for m in material_names]
        points=fitted_body
        if names=={'Basic Glass'}:
            # Seal tiny source panel gaps with an opaque pane overlap, tucked
            # behind the surrounding pillars. No cabin shell or interior ships.
            vertices=np.unique(faces);points=fitted_body.copy();window=points[vertices]
            centre=window.mean(0);delta=window-centre
            normal=np.linalg.svd(delta,full_matrices=False)[2][-1]
            if np.dot(normal,np.array([0,1.05,.25])-centre)<0:normal=-normal
            planar=delta-np.outer(delta@normal,normal)
            points[vertices]=window+planar*.02+normal*.003
        obj=new_piece(group+'_'+str(key),points,faces,indices,material_names)
        after=reduce(obj,body_target(int(key),count,simple));pieces.append(obj)
        groups[obj.name]=group;statistics.append({'component':int(key),'group':group,'before':count,'after':after})
    # Source wheels are measured above for fitting. The runtime builds exact
    # round tyres and five-spoke rims, avoiding fragile subpixel source details.
    # A low-cost glazing backing closes small gaps in the source's window/pillar
    # junctions. It contains no seats, dashboard, steering, cabin floor or rig.
    glass_faces=tri[np.array([mesh.materials[int(i)].name=='Basic Glass' for i in mi])]
    window_points=fitted_body[np.unique(glass_faces)]
    bm=bmesh.new()
    for point in blender(window_points):bm.verts.new(point)
    bm.verts.ensure_lookup_table()
    bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
    loose=[v for v in bm.verts if not v.link_faces]
    if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
    data=bpy.data.meshes.new('OpaqueGlazingBacking');bm.to_mesh(data);bm.free();data.materials.append(materials['glass'])
    obj=bpy.data.objects.new('OpaqueGlazingBacking',data);bpy.context.scene.collection.objects.link(obj)
    after=reduce(obj,160 if simple else 320);pieces.append(obj);groups[obj.name]='window_seal'
    statistics.append({'group':'window_seal','after':after,'purpose':'opaque glazing backing; no interior contents'})
    # Group per articulation and material. No skinning, constraints or rig ships.
    buckets={}
    for obj in pieces:
        for polygon in obj.data.polygons:
            role=obj.data.materials[polygon.material_index].name.removeprefix('BMT_')
            if groups[obj.name]=='body' and role=='white':role='reverse'
            buckets.setdefault((groups[obj.name],role),[]).append((obj,polygon.index))
    exports=[]
    for (group,role),polygons in buckets.items():
        vertices=[];faces=[];lookup={};normals=[]
        for obj,index in polygons:
            polygon=obj.data.polygons[index];face=[]
            for loop,vi in zip(polygon.loop_indices,polygon.vertices):
                identity=(obj.name,vi)
                if identity not in lookup:lookup[identity]=len(vertices);vertices.append(tuple(obj.data.vertices[vi].co))
                face.append(lookup[identity])
                normals.append(tuple(obj.data.corner_normals[loop].vector))
            faces.append(face)
        data=bpy.data.meshes.new(group+'__'+role);data.from_pydata(vertices,[],faces);data.materials.append(materials[role]);data.update()
        for polygon in data.polygons:polygon.use_smooth=True
        data.set_sharp_from_angle(angle=math.radians(52))
        data.normals_split_custom_set(normals)
        obj=bpy.data.objects.new(group+'__'+role,data);bpy.context.scene.collection.objects.link(obj);exports.append(obj)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in pieces:obj.hide_set(True);obj.hide_render=True
    for obj in exports:obj.select_set(True)
    bpy.context.view_layer.objects.active=exports[0]
    bpy.ops.export_scene.gltf(filepath=str(output/(tier+'.glb')),export_format='GLB',use_selection=True,
        export_animations=False,export_skins=False,export_yup=True,export_cameras=False,export_lights=False,
        export_materials='EXPORT',export_extras=False)
    total=sum(row['after'] for row in statistics)
    record['tiers'][tier]={'triangles':total,'surfaces':len(exports),'parts':statistics}
    print('CHALLENGER_EXPORT',tier,total,len(exports),flush=True)
    for obj in exports:obj.hide_set(True);obj.hide_render=True;obj.name='ARCHIVE_'+tier+'_'+obj.name
for o in original_wheels.values():o.data.calc_loop_triangles()
record['source_triangles']=len(tri)+sum(len(o.data.loop_triangles) for o in original_wheels.values())
record['wheel_geometry']='Native round tyres and five-spoke/custom rims; source wheel centres retained as alignment reference.'
record['opaque_glazing']='Boundary-preserving dissolve, 2% pane overlap and an opaque low-poly glazing backing close source pillar gaps. No cabin contents or rig.'
(output/'manifest.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print('CHALLENGER_PREPARED',output,flush=True)
