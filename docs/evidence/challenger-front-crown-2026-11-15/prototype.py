"""Fast source-GLTF prototype; final publication still requires full conversion."""
from pathlib import Path
import sys,json,shutil,importlib.util
import numpy as np
import bpy
ROOT=Path.cwd();OUT=ROOT/'docs/evidence/challenger-front-crown-2026-11-15';BUILD=ROOT/'build'/OUT.name
sys.path.insert(0,str(ROOT/'scripts'))
from challenger_nose_finish import point_map,normal_map
sys.path.insert(0,str(OUT/'rejected-top-sheet'))
from challenger_nose_crown import finish as finish_crown
from challenger_detail_geometry import seat_exhaust
spec=importlib.util.spec_from_file_location('old_nose',BUILD/'before/scripts/challenger_nose_finish.py');old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
SOURCE=ROOT/'build/challenger-exhaust-seat-2026-11-15/converted';DEST=BUILD/'prototype';DEST.mkdir(exist_ok=True)
manifest=json.loads((SOURCE/'manifest.json').read_text())
def inverse(p):
    q=p.copy();e=.000025
    for _ in range(12):
        d=np.zeros(3);d[1]=e
        dy=(old.point_map(q+d)[:,1]-old.point_map(q-d)[:,1])/(2*e)
        q[:,1]-=(old.point_map(q)[:,1]-p[:,1])/dy
        d=np.zeros(3);d[0]=e
        dx=(old.point_map(q+d)[:,0]-old.point_map(q-d)[:,0])/(2*e)
        q[:,0]-=(old.point_map(q)[:,0]-p[:,0])/dx
    assert np.max(abs(old.point_map(q)-p))<1e-7
    return q
for tier in ['full','simple']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE/(tier+'.glb')))
    exports=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for obj in exports:
        mesh=obj.data;p=np.asarray([v.co[:] for v in mesh.vertices])[:,[0,2,1]]*[1,1,-1]
        loops=np.asarray([v.vertex_index for v in mesh.loops]);n=np.asarray([v.vector[:] for v in mesh.corner_normals])[:,[0,2,1]]*[1,1,-1]
        original=inverse(p);e=.000025;columns=[]
        for axis in range(3):
            d=np.zeros(3);d[axis]=e;columns.append((old.point_map(original+d)-old.point_map(original-d))/(2*e))
        # Undo the old inverse-transpose transport, then apply the revised chart.
        a,b,c=[v[loops] for v in columns];pre=np.c_[np.sum(a*n,axis=1),np.sum(b*n,axis=1),np.sum(c*n,axis=1)]
        q=point_map(original);nn=normal_map(original[loops],pre)
        if obj.name in ['body__chrome','body__rubber']:
            stats=manifest['tiers'][tier]['exhaust_attachment'];sel=(q[:,2]>2.10)&(q[:,1]<.53)&(abs(q[:,0])>.30)&(abs(q[:,0])<.75)
            q[sel,1]-=stats['vertical_translation_metres'];q[sel,2]-=stats['longitudinal_translation_metres']
            if obj.name=='body__chrome':
                neck=sel&(abs(q[:,2]-2.145)<.0001)
                for side in [-1,1]:
                    ids=np.flatnonzero(neck&(q[:,0]*side>0));cx=side*.525;dx=q[ids,0]-cx;dy=q[ids,1]-.351
                    outer=(dx/.111)**2+(dy/.039)**2>.95
                    q[ids,0]=cx+dx*np.where(outer,.083/.111,.075/.101)
                    q[ids,1]=.351+.035+dy*np.where(outer,.028/.039,.021/.030);q[ids,2]=1.980
            else:q[sel,2]=2.205
        mesh.vertices.foreach_set('co',(q[:,[0,2,1]]*[1,-1,1]).ravel());mesh.update();mesh.normals_split_custom_set((nn[:,[0,2,1]]*[1,-1,1]).tolist())
    manifest['tiers'][tier]['front_crown']=finish_crown(exports,tier=='simple')
    manifest['tiers'][tier]['exhaust_attachment']=seat_exhaust(exports)
    print('CROWN_PROTOTYPE',tier,manifest['tiers'][tier]['front_crown'],flush=True)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in exports:obj.select_set(True)
    bpy.context.view_layer.objects.active=exports[0]
    bpy.ops.export_scene.gltf(filepath=str(DEST/(tier+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_skins=False,export_yup=True,export_cameras=False,export_lights=False,export_materials='EXPORT',export_extras=False)
    total=0
    for obj in exports:obj.data.calc_loop_triangles();total+=len(obj.data.loop_triangles)
    manifest['tiers'][tier]['triangles']=total
for name in ['hood_profile.json','source-facts.json']:
    if (SOURCE/name).exists():shutil.copyfile(SOURCE/name,DEST/name)
outline=json.loads((SOURCE/'bonnet_contour.json').read_text());outline['points']=point_map(inverse(np.asarray(outline['points']))).tolist();(DEST/'bonnet_contour.json').write_text(json.dumps(outline))
(DEST/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('CROWN_PROTOTYPE_COMPLETE',flush=True)
