"""Fast private candidate iteration from the qualified prior conversion."""
from pathlib import Path
import sys, json, shutil
import bpy

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'scripts'))
import challenger_shell_geometry as shell
source=ROOT/'build/challenger-corner-roll-2026-11-13/converted'
destination=ROOT/'build/challenger-surface-simplification-2026-11-14/prototype'
destination.mkdir(parents=True,exist_ok=True)
record=json.loads((source/'manifest.json').read_text())
shutil.copyfile(source/'hood_profile.json',destination/'hood_profile.json')
for tier in ['full','simple']:
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(source/(tier+'.glb')))
    obj=next(o for o in bpy.data.objects if o.type=='MESH' and o.name=='body__paint')
    result=shell.refine(obj,tier=='simple')
    for o in bpy.context.scene.objects:o.hide_set(False);o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(destination/(tier+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_skins=False,export_yup=True)
    total=0
    for o in bpy.context.scene.objects:
        if o.type=='MESH':o.data.calc_loop_triangles();total+=len(o.data.loop_triangles)
    record['tiers'][tier]['triangles']=total
    record['tiers'][tier]['joined_shell']=result
    print('PROTOTYPE',tier,total,result,flush=True)
(destination/'manifest.json').write_text(json.dumps(record,indent=2))
