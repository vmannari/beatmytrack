from pathlib import Path
import json,sys
from types import SimpleNamespace
import numpy as np
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'build/challenger-reference-body-2026-11-13/converted'
sys.path.insert(0,str(ROOT/'scripts'))
from challenger_panel_geometry import SurfaceGrid
from challenger_reference_geometry import ReferenceBody
config=json.loads((OUT/'reference_profile.json').read_text())
grid=SurfaceGrid(config['y'],config['z'],config['widths'])
source=np.load(ROOT/'art_sources/challenger_hellcat_v1/source-panels.npz');p=source['co'];t=source['tri'][source['component']==1572]
tp=p[t];n=np.cross(tp[:,1]-tp[:,0],tp[:,2]-tp[:,0]);t=t[n[:,1]>.3*np.linalg.norm(n,axis=1)]
e=np.sort(np.concatenate([t[:,[0,1]],t[:,[1,2]],t[:,[2,0]]]),axis=1);e,c=np.unique(e,axis=0,return_counts=True)
field=ReferenceBody(SimpleNamespace(centre_x=config['centre_x'],width=grid.at),p[np.unique(e[c==1])])
for tier in ['full','simple']:
    for role in ['paint','contour']:
        data=np.load(OUT/(tier+'_'+role+'_reference_input.npz'))
        points,faces,normals=data['points'],data['faces'],data['normals']
        if role=='paint':points,faces,normals=field.mesh(points,faces,normals)
        else:
            ids=faces.ravel();average=np.zeros_like(points);np.add.at(average,ids,normals)
            average/=np.maximum(np.linalg.norm(average,axis=1,keepdims=True),1e-12)
            points-=average*.0018;points,n=field.apply(points,average,True);normals=n[ids]
        z=points[:,2];s=np.clip((-z-1.72)/.3971,0,1);stretch=1+.14*6*s*(1-s)/.3971
        normals[:,2]/=stretch[faces.ravel()];normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-12)
        points[:,2]-=.14*s*s*(3-2*s)
        vertices=points[faces.ravel()]
        indices=np.arange(len(vertices)).reshape(-1,3)[:,::-1].ravel()
        (OUT/(tier+'_'+role+'_prototype.json')).write_text(json.dumps({'vertices':vertices.tolist(),'normals':normals.tolist(),'indices':indices.tolist()},separators=(',',':')))
print('Reference prototype written')
