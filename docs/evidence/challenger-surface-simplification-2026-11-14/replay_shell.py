"""Private iteration from the source-fenced pre-reference conversion buffers."""
from pathlib import Path
import sys, json, shutil
import bpy
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build/challenger-surface-simplification-2026-11-14'
sys.path.insert(0,str(ROOT/'scripts'))
import challenger_shell_geometry as shell
from challenger_reference_geometry import nose_normals,nose_plan_normals,nose_corner_normals
scope={'__file__':str(OUT/'check_shell.py')}
exec((OUT/'check_shell.py').read_text().split('stages=')[0],scope)
# The independent builder above is pure numpy; retain one reference per replay.
reference=scope['reference']
source=BUILD/'converted'
destination=BUILD/'replay'
destination.mkdir(parents=True,exist_ok=True)
record=json.loads((source/'manifest.json').read_text())
shutil.copyfile(source/'hood_profile.json',destination/'hood_profile.json')
for tier in ['full','simple']:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(source/(tier+'.glb')))
    obj=next(o for o in bpy.data.objects if o.type=='MESH' and o.name=='body__paint')
    cached=np.load(source/(tier+'_paint_reference_input.npz'))
    p,f,n=reference.mesh(cached['points'],cached['faces'],cached['normals'])
    p,f,n,strip=shell.shoulder_strip(reference,p,f,n,tier=='simple')
    n=nose_normals(p,n)
    p[:,2]=-scope['nose_distance'](-p[:,2],p[:,0])[0]
    n=nose_plan_normals(p,n);p=scope['nose_plan_points'](p)
    n=nose_corner_normals(p,n);p=scope['nose_corner_field'](p)[0]
    data=bpy.data.meshes.new('ReplayedJoinedShell')
    data.from_pydata((p[:,[0,2,1]]*np.array([1,-1,1])).tolist(),[],f.tolist())
    data.materials.append(obj.data.materials[0]);data.update()
    for polygon in data.polygons:polygon.use_smooth=True
    data.set_sharp_from_angle(angle=np.deg2rad(52))
    data.normals_split_custom_set((n[:,[0,2,1]]*np.array([1,-1,1])).tolist())
    obj.data=data
    result=shell.refine(obj,tier=='simple')
    contour=next(o for o in bpy.data.objects if o.type=='MESH' and o.name=='body__contour')
    fitted=shell.fit_contours(obj,contour)
    for o in bpy.context.scene.objects:o.hide_set(False);o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(destination/(tier+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_skins=False,export_yup=True)
    total=0
    for o in bpy.context.scene.objects:
        if o.type=='MESH':o.data.calc_loop_triangles();total+=len(o.data.loop_triangles)
    record['tiers'][tier].update(triangles=total,joined_shell=result,shoulder_strips=strip,fitted_contour_vertices=fitted)
    print('REPLAY',tier,total,result,flush=True)
(destination/'manifest.json').write_text(json.dumps(record,indent=2))
