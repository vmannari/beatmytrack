"""Offline Blender planar retessellation; output only original vertex indices."""
import bpy
import bmesh
import json
import math
import sys
import os
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/os.environ.get('BMT_CAR_BUDGET_WORK_DIR','build/car-10k-models-2026-11-14')
sources=json.loads((WORK/'surfaces.json').read_text())
boundaries='--boundaries' in sys.argv
result=json.loads((WORK/'dissolved.json').read_text()) if boundaries else {}
for ordinal,(key,piece) in enumerate(sources.items()):
    if boundaries and not key.startswith(('kart_','forklift_')): continue
    surfaces=[]
    for source in piece['surfaces']:
        positions=[Vector(v) for v in source['vertices']]
        base=bmesh.new()
        vertices=[base.verts.new(v) for v in positions]
        identity=base.loops.layers.int.new('source_vertex_id')
        for at in range(0,len(source['indices']),3):
            ids=source['indices'][at:at+3]
            if len(set(ids))<3:continue
            try: face=base.faces.new([vertices[i] for i in ids])
            except ValueError:continue
            for loop,index in zip(face.loops,ids):loop[identity]=index
        bmesh.ops.remove_doubles(base,verts=list(base.verts),dist=0.000001)
        base.normal_update()
        levels=[{'angle':0,'indices':source['indices']}]
        for angle in [0.5,1,2,4,7,12,20,30]:
            mesh=base.copy();layer=mesh.loops.layers.int['source_vertex_id']
            bmesh.ops.dissolve_limit(mesh,angle_limit=math.radians(angle),
                use_dissolve_boundaries=boundaries and piece['name']!='DriverStaticSuit',verts=list(mesh.verts),edges=list(mesh.edges),delimit=set())
            bmesh.ops.triangulate(mesh,faces=list(mesh.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
            indices=[]
            for face in mesh.faces:
                if len(face.loops)!=3:raise RuntimeError('Non-triangle output')
                for loop in face.loops:
                    index=loop[layer]
                    # Original loop identity must survive retessellation. No
                    # invented positions, normal reconstruction or UV transfer.
                    if (positions[index]-loop.vert.co).length>0.000003:
                        raise RuntimeError(f'Lost original corner identity: {key}')
                    indices.append(index)
            if indices:levels.append({'angle':angle,'indices':indices})
            mesh.free()
        base.free();surfaces.append(levels)
    result[key]=surfaces
    if ordinal%100==0:print('TEN_K_DISSOLVE',ordinal,len(sources),flush=True)
(WORK/('dissolved-boundaries.json' if boundaries else 'dissolved.json')).write_text(json.dumps(result,separators=(',',':')))
print('TEN_K_DISSOLVE_DONE',len(result),flush=True)
