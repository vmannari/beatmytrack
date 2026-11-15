"""Disposable fast shape review from the qualified preceding GLB, never publication."""
import bpy,sys,ast,json,math
from pathlib import Path
import numpy as np
from mathutils import Vector,Matrix
from mathutils.geometry import delaunay_2d_cdt
root=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(root/'scripts'))
import challenger_exterior_geometry as exterior
import challenger_clean_panels as panel
source=root/'build/challenger-panel-corrections-2026-11-14/converted'
dest=root/'build/challenger-reference-repair-2026-11-14/converted-preview';dest.mkdir(exist_ok=True)
parsed=ast.parse((root/'scripts/prepare_challenger.py').read_text())
for node in parsed.body:
    if isinstance(node,ast.FunctionDef) and node.name in ['inside_polygon','lattice']:
        exec(compile(ast.Module(body=[node],type_ignores=[]),'<converter-chart>','exec'))
manifest=json.loads((source/'manifest.json').read_text())
for tier in ['full','simple']:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(source/(tier+'.glb')))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for obj in objects:
        pose=obj.matrix_world.copy();obj.parent=None;obj.matrix_world=Matrix.Identity(4);obj.data.transform(pose)
    stats=exterior.finish(objects,panel.CleanHood(),lattice,tier=='simple')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(dest/(tier+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_skins=False,export_yup=True,export_cameras=False,export_lights=False,export_materials='EXPORT')
    triangles=0
    for obj in objects:obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
    manifest['tiers'][tier]['triangles']=triangles
    manifest['tiers'][tier]['clean_panels']['manufactured_exterior']=stats
    print('PREVIEW',tier,triangles,flush=True)
(dest/'manifest.json').write_text(json.dumps(manifest))
for name in ['hood_profile.json','bonnet_contour.json']:(dest/name).write_bytes((source/name).read_bytes())
