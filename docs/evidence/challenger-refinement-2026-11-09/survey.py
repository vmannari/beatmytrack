import bpy,json,numpy as np
from pathlib import Path
from mathutils.bvhtree import BVHTree
root=Path(__file__).resolve().parents[3]
bpy.ops.wm.open_mainfile(filepath=r'C:\Users\ville\Downloads\Dodge Challenger HellCat - Rigged.blend',load_ui=False,use_scripts=False)
obj=bpy.data.objects['Hellcat-Body'];mesh=obj.data;mesh.calc_loop_triangles()
labels=np.load(root/'docs/evidence/challenger-hellcat-2026-11-09/components.npz')['labels']
co=np.array([v.co[:] for v in mesh.vertices]);world=np.array(obj.matrix_world);w=co@world[:3,:3].T+world[:3,3]
record=json.loads((root/'game/assets/vehicles/challenger_hellcat_v1/source.json').read_text());centres=np.array(list(record['source_wheel_centres'].values()))
fy=np.array([v for k,v in record['source_wheel_centres'].items() if '.Ft.' in k])[:,1].mean();sx,sz,sy=record['body_scale_xyz']
p=np.c_[-(w[:,0]-centres[:,0].mean())*sx,(w[:,2]-centres[:,2].mean())*sy+.37,(w[:,1]-fy)*sz-1.28]
tri=np.array([t.vertices[:] for t in mesh.loop_triangles]);components=labels[tri[:,0]]
for group,ids in [('bumper',[1624])]:
    faces=tri[np.isin(components,ids)];bvh=BVHTree.FromPolygons(p.tolist(),faces.tolist(),all_triangles=True)
    if group=='bumper':
        for y in [.4,.55,.65,.75,.82]:
            for x in [-.6,0,.6]:
                hit=bvh.ray_cast((x,y,-3),(0,0,1),3)
                print('BUMPER',x,y,None if hit[0] is None else (tuple(hit[0]),tuple(hit[1])),flush=True)
    elif group=='hood':
        for z in np.linspace(-1.95,-.78,9):
            print('HOOD',round(z,3),[None if (hit:=bvh.ray_cast((float(x),2,float(z)),(0,-1,0),3))[0] is None else round(hit[0].y,4) for x in [0,.2,.4,.6,.7]],flush=True)
    else:
        for y in [.31,.4,.6,.8,.9,.98]:
            print('SIDE',y,[None if (hit:=bvh.ray_cast((-2,y,float(z)),(1,0,0),2))[0] is None else round(hit[0].x,4) for z in [-.73,-.69,-.3,.3,.52,.56,.8,1.2,1.4,1.6]],flush=True)
