"""Fast review from the previous converter output; final delivery uses a fresh conversion."""
from pathlib import Path
import json
import sys
import shutil
import bpy
import numpy as np
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from challenger_reference_form import ReferenceForm
from challenger_side_surface import Curve
from challenger_surface_quality import finish
BUILD=ROOT/'build/challenger-surface-quality-2026-11-15'
OLD=ROOT/'build/challenger-reference-form-2026-11-15/converted'
DEST=BUILD/'converted-prototype';DEST.mkdir(exist_ok=True)
manifest=json.loads((OLD/'manifest.json').read_text())
for name in ['hood_profile.json','bonnet_contour.json']:shutil.copyfile(OLD/name,DEST/name)
for tier in ['full','simple']:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(OLD/(tier+'.glb')))
    exports=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
    side=manifest['tiers'][tier]['clean_panels']['manufactured_exterior']['continuous_side']
    reference=ReferenceForm.__new__(ReferenceForm)
    reference.side_crease=Curve(side['crease_z'],side['crease_y'])
    reference.wing_width=Curve(side['z'],side['widths'])
    reference.base=Curve([-2.30,-2.22,-2.10,-1.80,-1.35,-.95,-.72],[.805,.853,.898,.934,.964,.971,.982])
    stats=finish(exports,reference,tier=='simple')
    print('PROTOTYPE_SURFACE',tier,json.dumps(stats),flush=True)
    for obj in exports:obj.select_set(True)
    bpy.context.view_layer.objects.active=exports[0]
    bpy.ops.export_scene.gltf(filepath=str(DEST/(tier+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_skins=False,export_yup=True,export_cameras=False,export_lights=False,export_materials='EXPORT',export_extras=False)
    total=0
    for obj in exports:obj.data.calc_loop_triangles();total+=len(obj.data.loop_triangles)
    manifest['tiers'][tier]['triangles']=total
    manifest['tiers'][tier]['clean_panels']['manufactured_exterior']['reference_form']['surface_quality']=stats
(DEST/'manifest.json').write_text(json.dumps(manifest,indent=2))
