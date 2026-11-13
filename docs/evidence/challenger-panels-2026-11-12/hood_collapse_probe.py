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
from mathutils.bvhtree import BVHTree
from mathutils.geometry import delaunay_2d_cdt
sys.path.insert(0,str(Path.cwd()/'scripts'))
import challenger_detail_geometry as exterior_detail
from challenger_panel_geometry import SideSurface, SampledHood

args = sys.argv[sys.argv.index("--")+1:]
source, labels_file, output = map(Path,args[:3])
output.mkdir(parents=True,exist_ok=True)
cached_source=source.suffix.lower()=='.npz'
source_facts=None
if cached_source:
    source_facts=json.loads(source.with_name('source-facts.json').read_text(encoding='utf-8'))
    cached=np.load(source,allow_pickle=False)
    wheel_data={name:np.asarray(value) for name,value in source_facts['source_wheel_centres'].items()}
    original_front=float(np.mean([c[1] for n,c in wheel_data.items() if '.Ft.' in n]))
    original_centre=float(np.mean([c[0] for c in wheel_data.values()]))
    original_z=float(np.mean([c[2] for c in wheel_data.values()]))
    original_scale=np.asarray(source_facts['body_scale_xyz'])
    game_points=cached['co']
    restored=np.c_[original_centre-game_points[:,0]/original_scale[0],(game_points[:,2]+1.28)/original_scale[1]+original_front,(game_points[:,1]-.37)/original_scale[2]+original_z]
    data=bpy.data.meshes.new('RetainedMeasuredBody')
    data.from_pydata(restored.tolist(),[],cached['tri'].tolist());data.update()
    for index in range(int(cached['mi'].max())+1):data.materials.append(bpy.data.materials.new(source_facts['cached_material_names'].get(str(index),'Unused'+str(index))))
    data.polygons.foreach_set('material_index',cached['mi'].astype(np.int32))
    for polygon in data.polygons:polygon.use_smooth=True
    body=bpy.data.objects.new('Hellcat-Body',data);bpy.context.scene.collection.objects.link(body)
else:
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
wheel_centres=wheel_data if cached_source else {name:np.mean([np.array(o.matrix_world@Vector(c)) for c in o.bound_box],axis=0) for name,o in original_wheels.items()}
front_y=float(np.mean([c[1] for n,c in wheel_centres.items() if '.Ft.' in n]))
rear_y=float(np.mean([c[1] for n,c in wheel_centres.items() if '.Bk.' in n]))
centre_x=float(np.mean([c[0] for c in wheel_centres.values()]));wheel_z=float(np.mean([c[2] for c in wheel_centres.values()]))
scale=np.array([1.50,2.56/(rear_y-front_y),0.37/0.26099])

def game(points):
    return np.c_[-(points[:,0]-centre_x)*scale[0],(points[:,2]-wheel_z)*scale[2]+0.37,(points[:,1]-front_y)*scale[1]-1.28]

def blender(points): return np.c_[points[:,0],-points[:,2],points[:,1]]
fitted_body=game(body_world)

survey=json.loads(Path('docs/evidence/challenger-panels-2026-11-12/source-panel-survey.json').read_text())
faces=tri[component==1572];p=fitted_body[faces];n=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]);faces=faces[n[:,1]>.3*np.linalg.norm(n,axis=1)]
points=fitted_body.copy();t=np.clip((-points[:,2]-1.72)/(2.1171-1.72),0,1);points[:,2]-=.14*t*t*(3-2*t)
for target in [3000,3800,5000,6200]:
 used,ids=np.unique(faces.ravel(),return_inverse=True)
 data=bpy.data.meshes.new('Probe');data.from_pydata(points[used],[],ids.reshape(-1,3));data.update()
 obj=bpy.data.objects.new('Probe',data);bpy.context.scene.collection.objects.link(obj);bpy.context.view_layer.objects.active=obj;obj.select_set(True)
 mod=obj.modifiers.new('Collapse','DECIMATE');mod.ratio=target/len(faces);mod.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=mod.name)
 obj.data.calc_loop_triangles();bv=BVHTree.FromPolygons([v.co[:] for v in obj.data.vertices],[t.vertices[:] for t in obj.data.loop_triangles],all_triangles=True)
 errors=[]
 for row in survey['hood']:
  z=row['z'];t=np.clip((-z-1.72)/(2.1171-1.72),0,1);zz=z-.14*t*t*(3-2*t)
  for x,value in zip(survey['hood_x'],row['samples']):
   if value is None:continue
   if any(box[0][0]-.01<x<box[1][0]+.01 and box[0][2]-.01<z<box[1][2]+.01 for box in survey['source_vents']):continue
   hit=bv.ray_cast((x,2,float(zz)),(0,-1,0),3)[0]
   errors.append(abs(hit.y-value) if hit is not None else 1)
 print('HOOD_COLLAPSE',target,len(obj.data.loop_triangles),'max_error',max(errors),'mean_error',float(np.mean(errors)),flush=True)
 bpy.data.objects.remove(obj,do_unlink=True)
