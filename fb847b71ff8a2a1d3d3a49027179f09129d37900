import bpy
import json
import numpy as np
from pathlib import Path
import sys

source, output = sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.open_mainfile(filepath=source, load_ui=False, use_scripts=False)
obj=bpy.data.objects['Hellcat-Body']; mesh=obj.data
n=len(mesh.vertices); parent=np.arange(n,dtype=np.int32)
def find(a):
    while parent[a]!=a:
        parent[a]=parent[parent[a]]; a=parent[a]
    return a
edges=np.empty(len(mesh.edges)*2,dtype=np.int32);mesh.edges.foreach_get('vertices',edges)
for a,b in edges.reshape(-1,2):
    a,b=find(a),find(b)
    if a!=b: parent[max(a,b)]=min(a,b)
labels=np.array([find(i) for i in range(n)])
co=np.empty(n*3,dtype=np.float32);mesh.vertices.foreach_get('co',co);co=co.reshape(-1,3)
mesh.calc_loop_triangles()
counts={}; mats={}
for t in mesh.loop_triangles:
    key=int(labels[t.vertices[0]]);counts[key]=counts.get(key,0)+1
    d=mats.setdefault(key,{});name=mesh.materials[t.material_index].name
    d[name]=d.get(name,0)+1
rows=[]
for key in sorted(counts,key=counts.get,reverse=True):
    pts=co[labels==key]
    rows.append({'component':key,'triangles':counts[key],'bounds':[pts.min(0).tolist(),pts.max(0).tolist()],
                 'materials':mats[key]})
np.savez_compressed(Path(output).with_suffix('.npz'),labels=labels)
Path(output).write_text(json.dumps({'matrix_world':[list(row) for row in obj.matrix_world], 'components':rows},indent=2),encoding='utf-8')
print('COMPONENTS',len(rows),flush=True)
for row in rows[:60]: print(row,flush=True)
