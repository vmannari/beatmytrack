from pathlib import Path
import sys,json,shutil
import bpy
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from challenger_side_surface import Curve
from challenger_side_finish import finish,shorten,front_z
from types import SimpleNamespace
BUILD=ROOT/'build/challenger-side-proportion-2026-11-15'
OLD=ROOT/'build/challenger-surface-quality-2026-11-15/converted'
DEST=BUILD/'converted-prototype';DEST.mkdir(exist_ok=True)
manifest=json.loads((OLD/'manifest.json').read_text())
shutil.copyfile(OLD/'hood_profile.json',DEST/'hood_profile.json')
contour=json.loads((OLD/'bonnet_contour.json').read_text())
for point in contour['points']:point[2]=float(front_z(point[2]))
(DEST/'bonnet_contour.json').write_text(json.dumps(contour,indent=2))
for tier in ['full','simple']:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(OLD/(tier+'.glb')))
    exports=[o for o in bpy.context.scene.objects if o.type=='MESH']
    side=manifest['tiers'][tier]['clean_panels']['manufactured_exterior']['continuous_side']
    reference=SimpleNamespace(side_crease=Curve(side['crease_z'],side['crease_y']))
    stats=finish(exports,reference,tier=='simple');print('SIDE_PROTOTYPE',tier,json.dumps(stats),flush=True)
    shorten(exports)
    for obj in exports:obj.select_set(True)
    bpy.context.view_layer.objects.active=exports[0]
    bpy.ops.export_scene.gltf(filepath=str(DEST/(tier+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_skins=False,export_yup=True,export_cameras=False,export_lights=False,export_materials='EXPORT',export_extras=False)
    total=0
    for obj in exports:obj.data.calc_loop_triangles();total+=len(obj.data.loop_triangles)
    manifest['tiers'][tier]['triangles']=total
    manifest['tiers'][tier]['clean_panels']['manufactured_exterior']['side_finish']=stats
(DEST/'manifest.json').write_text(json.dumps(manifest,indent=2))
