from pathlib import Path
import sys,json,shutil,bpy
root=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(root/'scripts'))
from challenger_rear_surface import refine
out=root/'build/challenger-rear-surface-2026-11-17/converted'
out.mkdir(exist_ok=True)
previous=root/'build/challenger-nose-lip-2026-11-17/converted'
manifest=json.loads((previous/'manifest.json').read_text())
profile=None
for tier in ['full','simple']:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(previous/(tier+'.glb')))
 exports=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
 print('IMPORTED',tier,[obj.name for obj in exports],flush=True)
 profile,stats=refine(exports,tier=='simple',profile)
 manifest['tiers'][tier]['rear_surface']=stats
 total=0
 for obj in exports:
  obj.data.calc_loop_triangles();total+=len(obj.data.loop_triangles)
 manifest['tiers'][tier]['triangles']=total
 print('REAR_PROTO',tier,total,stats,flush=True)
 bpy.ops.object.select_all(action='DESELECT')
 for obj in exports:obj.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(out/(tier+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_skins=False,export_yup=True,export_cameras=False,export_lights=False,export_materials='EXPORT',export_extras=False)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2))
(out/'rear-profile.json').write_text(json.dumps(profile,indent=2))
for name in ['hood_profile.json','bonnet_contour.json']:
 shutil.copyfile(previous/name,out/name)
