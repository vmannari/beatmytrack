"""Render the replacement bonnet quickly before the complete source conversion."""
from pathlib import Path
import ast,json,math,sys
import bpy
import numpy as np
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt

ROOT=Path.cwd();OUT=ROOT/'build/challenger-hood-redesign-2026-11-16'
sys.path.insert(0,str(ROOT/'scripts'))
import challenger_clean_panels as panel
from challenger_reference_form import ReferenceForm,front_scale
from challenger_side_surface import Curve
from challenger_hood_geometry import rebuild,strip_legacy_trim
from challenger_exterior_geometry import records
from challenger_side_finish import shorten
from challenger_nose_finish import finish, point_map
from challenger_hood_geometry import finish_seams
from challenger_side_finish import front_z
import importlib.util
spec=importlib.util.spec_from_file_location("old_nose",OUT/"before/scripts/challenger_nose_finish.py")
old_nose=importlib.util.module_from_spec(spec);spec.loader.exec_module(old_nose)
import challenger_nose_finish as new_nose
def correct_old(row):
    q=np.asarray(row["points"]);normal=np.asarray(row["normals"]);p=q.copy()
    for _ in range(24):p+=q-old_nose.point_map(p)
    columns=[]
    for axis in range(3):
        delta=np.zeros(3);delta[axis]=.000025
        columns.append((old_nose.point_map(p+delta)-old_nose.point_map(p-delta))/.00005)
    jacobian=np.stack(columns,axis=2)
    original_normal=np.einsum("nij,ni->nj",jacobian,normal)
    original_normal/=np.linalg.norm(original_normal,axis=1)[:,None]
    return new_nose.point_map(p),new_nose.normal_map(p,original_normal)

source=ast.parse((ROOT/'scripts/prepare_challenger.py').read_text())
functions=[node for node in source.body if isinstance(node,ast.FunctionDef) and node.name in ['inside_polygon','lattice']]
exec(compile(ast.Module(body=functions,type_ignores=[]),'existing_converter_lattice','exec'))
field=ReferenceForm.__new__(ReferenceForm)
field.base=Curve([-2.30,-2.22,-2.10,-1.80,-1.35,-.95,-.72],[.805,.853,.898,.934,.964,.971,.982])
class PanelSeat(panel.CleanHood):
    def width(self,v):return .730+.025*np.asarray(v)+.008*np.sin(np.pi*np.asarray(v))
    def front(self,u):return -2.170+.020*np.asarray(u)**4
    def rear(self,u):return -.990+.225*np.asarray(u)**2
    def height(self,x,z):return field.height(np.asarray(x)/front_scale(z),z)
seat=PanelSeat();baseline=json.loads((OUT/'baseline.json').read_text());result={}
for tier in ['simple','full']:
    exports=[]
    for role in ['paint','dark']:
        obj=bpy.data.objects.new('hood__'+role,bpy.data.meshes.new('ReplacementHood'))
        bpy.context.scene.collection.objects.link(obj);exports.append(obj)
    hood=rebuild(exports,seat,lattice,tier=='simple')
    shorten(exports);finish(exports)
    row=baseline[tier]['body_paint']
    points,normals=correct_old(row);faces=np.asarray(row['indices']).reshape(-1,3)[:,::-1]
    body=bpy.data.objects.new('body__paint',bpy.data.meshes.new('SeamBankPreview'));bpy.context.scene.collection.objects.link(body)
    panel._write(body,np.concatenate([points[faces],normals[faces]],axis=2))
    exports.append(body)
    row=baseline[tier]['body_dark'];p=np.asarray(row['points']);n=np.asarray(row['normals']);f=np.asarray(row['indices']).reshape(-1,3)[:,::-1]
    values=strip_legacy_trim(np.concatenate([p[f],n[f]],axis=2),'body_dark',seat)
    dark=bpy.data.objects.new('body__dark',bpy.data.meshes.new('CarrierPreview'));bpy.context.scene.collection.objects.link(dark);panel._write(dark,values);exports.append(dark)
    boundary=hood.boundary();boundary[:,2]=front_z(boundary[:,2]);boundary=point_map(boundary)
    if '--no-seams' not in sys.argv:
        print('SEAM_BANK',tier,finish_seams(exports,boundary,tier=='simple'),flush=True)
    result[tier]={}
    row=baseline[tier]['body_contour'];points,normals=correct_old(row)
    result[tier]['body_contour']={'points':points.tolist(),'normals':normals.tolist(),'indices':row['indices']}
    def packet(values):
        flat=values.reshape(-1,6)
        return {'points':flat[:,:3].tolist(),'normals':flat[:,3:].tolist(),
                'indices':np.arange(len(flat)).reshape(-1,3)[:,::-1].ravel().tolist()}
    for obj in exports:result[tier][obj.name.replace('__','_')]=packet(records(obj))
    for kind in ['body_red','body_accent','body_metal']:
        if kind not in baseline[tier]:continue
        row=baseline[tier][kind]
        if kind=='body_dark':p,n=np.asarray(row['points']),np.asarray(row['normals'])
        else:p,n=np.asarray(row['points']),np.asarray(row['normals'])
        f=np.asarray(row['indices']).reshape(-1,3)[:,::-1]
        values=np.concatenate([p[f],n[f]],axis=2)
        result[tier][kind]=packet(strip_legacy_trim(values,kind,seat))
    print('REPLACEMENT_HOOD',tier,hood.stats,flush=True)
    for obj in exports:bpy.data.objects.remove(obj,do_unlink=True)
(OUT/'prototype.json').write_text(json.dumps(result,separators=(',',':')))
