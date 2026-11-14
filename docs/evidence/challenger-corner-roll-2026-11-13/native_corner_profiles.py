"""Trace the actual native triangles, including small bevel triangles.

The physics proxy misses some small faces in this survey. Renderer geometry
and interpolated encoded normals are used directly for the surface checks.
"""
from pathlib import Path
import json
import numpy as np
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build/challenger-corner-roll-2026-11-13'
rows=[]
for stage in ['before','candidate']:
    data=json.loads((BUILD/('native-plan-'+stage+'.json')).read_text())
    for tier in ['simple','full']:
        tri=np.asarray(data[tier]['body_paint']).reshape(-1,3,3)
        normals=np.asarray(data[tier]['body_paint_normals']).reshape(-1,3,3)
        for side in [-1,1]:
            for z in [-2.03,-2.10,-2.15]:
                p,u,v=tri[:,0],tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]
                det=u[:,1]*v[:,2]-u[:,2]*v[:,1]
                valid=(-side*det>1e-14)&(tri[:,:,2].min(1)<=z)&(tri[:,:,2].max(1)>=z)
                p,u,v,det,n=p[valid],u[valid],v[valid],det[valid],normals[valid]
                samples=[]
                for y in np.linspace(.70,.82,241):
                    a=((y-p[:,1])*v[:,2]-(z-p[:,2])*v[:,1])/det
                    b=(u[:,1]*(z-p[:,2])-u[:,2]*(y-p[:,1]))/det
                    hit=(a>=-1e-7)&(b>=-1e-7)&(a+b<=1+1e-7)
                    ids=np.flatnonzero(hit)
                    if not len(ids):continue
                    x=p[:,0]+a*u[:,0]+b*v[:,0]
                    i=ids[np.argmax(side*x[ids])]
                    normal=n[i,0]*(1-a[i]-b[i])+n[i,1]*a[i]+n[i,2]*b[i]
                    normal/=np.linalg.norm(normal)
                    samples.append({'y':float(y),'x':float(x[i]),'angle':float(np.rad2deg(np.arctan2(normal[1],abs(normal[0]))))})
                rows.append(dict(stage=stage,tier=tier,side=side,z=z,samples=samples))
(OUT/'corner-sections.json').write_text(json.dumps(rows))
print('NATIVE_CORNER_PROFILES:',len(rows),'profiles from encoded renderer triangles and normals')
