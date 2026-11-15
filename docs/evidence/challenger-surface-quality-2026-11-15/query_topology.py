from pathlib import Path
import json,numpy as np
data=json.loads(Path('build/challenger-surface-quality-2026-11-15/candidate.json').read_text())['simple']['body_paint']
p=np.asarray(data['points']);n=np.asarray(data['normals']);f=np.asarray(data['indices']).reshape(-1,3)
def score(face):
    g=-np.cross(p[face[1]]-p[face[0]],p[face[2]]-p[face[0]]);g/=np.linalg.norm(g)
    return float((n[face]@g).min()),g
edges={}
for i,face in enumerate(f):
    for j in range(3):edges.setdefault(tuple(sorted([face[j],face[(j+1)%3]])),[]).append(i)
for i,face in enumerate(f):
    c=p[face].mean(0);s,g=score(face)
    if not (c[0]>.74 and .85<c[1]<.94 and -2.04<c[2]<-.90 and s<-.02 and g[0]>0):continue
    print('BAD',i,face,c,s,g)
    for j in range(3):
        a,b,cc=face[j],face[(j+1)%3],face[(j+2)%3]
        neighbors=edges[tuple(sorted([a,b]))]
        print('EDGE',a,b,'neighbors',neighbors)
        for other in neighbors:
            if other==i:continue
            d=next(v for v in f[other] if v not in [a,b])
            print('FLIP',other,d,score([cc,a,d]),score([cc,d,b]),'old',score(f[other]))
