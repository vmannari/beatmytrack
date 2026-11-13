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

from mathutils.bvhtree import BVHTree
hood_faces=tri[component==1572];p=fitted_body[hood_faces];n=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]);hood_faces=hood_faces[n[:,1]>.3*np.linalg.norm(n,axis=1)]
hb=BVHTree.FromPolygons(fitted_body.tolist(),hood_faces.tolist(),all_triangles=True)
sb=BVHTree.FromPolygons(fitted_body.tolist(),tri[np.isin(component,[1464,1491,1862,4445])].tolist(),all_triangles=True)
hood=[]
for z in [-1.94,-1.85,-1.73,-1.60,-1.45,-1.25,-1.05,-.85]:
 row={'z':z,'samples':[]}
 for x in [0,.1,.2,.28,.34,.4,.48,.56,.64,.70]:
  hit=hb.ray_cast((x,2,z),(0,-1,0),3)[0];row['samples'].append(None if hit is None else round(hit.y,5))
 hood.append(row)
side=[]
for z in [-1.8,-1.5,-1.1,-.7,-.2,.3,.7,1.1,1.5,1.9]:
 row={'z':z,'samples':[]}
 for y in [.32,.4,.5,.65,.75,.82,.88,.93,.98,1.03,1.08]:
  hit=sb.ray_cast((-2,y,z),(1,0,0),2)[0];row['samples'].append(None if hit is None else round(-hit.x,5))
 side.append(row)
Path('docs/evidence/challenger-panels-2026-11-12/source-panel-survey.json').write_text(json.dumps({'hood_x':[0,.1,.2,.28,.34,.4,.48,.56,.64,.70],'hood':hood,'side_y':[.32,.4,.5,.65,.75,.82,.88,.93,.98,1.03,1.08],'side':side},indent=2),encoding='utf-8')
np.savez_compressed(output/'source-panels.npz',co=fitted_body,tri=tri,component=component,mi=mi)
mask=np.isin(component,[1464,1491,1624,2149,1862,4445,2790,1572])&np.array([mesh.materials[int(i)].name=='Car Paint' for i in mi])
points=fitted_body.copy();t=np.clip((-points[:,2]-1.72)/(2.1171-1.72),0,1);points[:,2]-=.14*t*t*(3-2*t)
faces=tri[mask];used,indices=np.unique(faces.ravel(),return_inverse=True)
data=bpy.data.meshes.new('ReferencePaint');data.from_pydata(blender(points[used]),[],indices.reshape(-1,3));data.update()
mat=bpy.data.materials.new('ReferencePaint');mat.diffuse_color=(.55,.04,.025,1);data.materials.append(mat)
for poly in data.polygons:poly.use_smooth=True
data.set_sharp_from_angle(angle=math.radians(52))
obj=bpy.data.objects.new('ReferencePaint',data);bpy.context.scene.collection.objects.link(obj)
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
bpy.ops.export_scene.gltf(filepath=str(output/'reference.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=False,export_materials='EXPORT')
print('SOURCE_PANEL_REFERENCE',len(faces),flush=True)
