"""Offline dissolve with complete encoded attribute identities and fixed vertices."""
import bpy
import bmesh
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/car15-2026-11-15'
inputs=json.loads((WORK/'retessellation-input.json').read_text())
output={}
for ordinal,(key,piece) in enumerate(inputs.items()):
    surfaces=[]
    for source in piece['surfaces']:
        mesh=bmesh.new()
        identity=mesh.verts.layers.int.new('original_vertex')
        by_attribute={}
        vertices=[]
        for at,(position,attributes) in enumerate(zip(source['vertices'],source['attributes'])):
            # A position match alone must never weld UV/normal/material seams.
            if attributes not in by_attribute:
                vertex=mesh.verts.new(position)
                vertex[identity]=at
                by_attribute[attributes]=vertex
            vertices.append(by_attribute[attributes])
        for start in range(0,len(source['indices']),3):
            corners=[vertices[i] for i in source['indices'][start:start+3]]
            if len(set(corners))!=3:continue
            try:mesh.faces.new(corners)
            except ValueError:pass
        mesh.normal_update()
        bmesh.ops.dissolve_limit(mesh,angle_limit=math.radians(1),use_dissolve_boundaries=False,
                                verts=list(mesh.verts),edges=list(mesh.edges),delimit=set())
        bmesh.ops.triangulate(mesh,faces=list(mesh.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
        indices=[]
        for face in mesh.faces:
            for vertex in face.verts:
                at=vertex[identity]
                assert sum((a-b)**2 for a,b in zip(vertex.co,source['vertices'][at]))<1e-12
                indices.append(at)
        surfaces.append(indices if indices else source['indices'])
        mesh.free()
    output[key]=surfaces
    if ordinal%100==0:print('CAR15_RETESSELLATE',ordinal,len(inputs),flush=True)
(WORK/'retessellated.json').write_text(json.dumps(output,separators=(',',':')))
print('CAR15_RETESSELLATED',len(output),flush=True)
