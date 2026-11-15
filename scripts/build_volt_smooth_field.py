"""VSR01: shared area-weighted normals across adjacent native paint charts."""
from pathlib import Path
import json
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/volt-reflection-smoothing-2026-11-15'
data=json.loads((WORK/'native-field.json').read_text(encoding='utf-8'))
centres=[];vectors=[]
for row in data.values():
    p=np.array(row['positions']);tri=p[np.array(row['indices']).reshape(-1,3)]
    face=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0])
    authored=np.array(row['normals'])[np.array(row['indices']).reshape(-1,3)].mean(axis=1)
    face[np.sum(face*authored,axis=1)<0]*=-1
    centres.append(tri.mean(axis=1));vectors.append(face)
centres=np.concatenate(centres);vectors=np.concatenate(vectors)
result={}
for label,row in data.items():
    points=np.array(row['queries']);normals=[]
    for offset in range(0,len(points),128):
        block=points[offset:offset+128]
        distance=((block[:,None,:]-centres[None,:,:])**2).sum(axis=2)
        weights=np.exp(-distance/(2*0.024**2))
        # Only adjacent outward-facing skin contributes; dark cavities and
        # opposite body halves never participate in this shared paint field.
        allowed=(block[:,0,None]*centres[None,:,0])>=0
        smoothed=(weights*allowed)@vectors
        smoothed/=np.maximum(np.linalg.norm(smoothed,axis=1)[:,None],1e-15)
        normals.extend(smoothed.tolist())
    result[label]=normals
(WORK/'smooth-field.json').write_bytes((json.dumps(result)+'\n').encode('utf-8'))
print('VSR_SHARED_NORMAL_FIELD',len(result),'charts;',len(centres),'native triangles')
