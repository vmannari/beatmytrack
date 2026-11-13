"""Fast local surface iterations from the converter's disposable mesh cache."""
import json,sys
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'scripts'))
from challenger_panel_geometry import PanelJoinFairing
OUT=ROOT/'build/challenger-surface-joins-2026-11-12/converted'
config=json.loads((OUT/'join_fairing.json').read_text())
field=PanelJoinFairing.__new__(PanelJoinFairing)
field.centre_x=config['centre_x'];field.cx=.35;field.cy=.4
field.patches=[(*p[:-1],np.array(p[-1])) for p in config['patches']]
def unwarp(z):
    r=z.copy()
    for _ in range(7):
        t=np.clip((-r-1.72)/.3971,0,1);s=1+.14*6*t*(1-t)/.3971
        r-=(r-.14*t*t*(3-2*t)-z)/s
    return r,s
def warp(points):
    r=points.copy();t=np.clip((-r[:,2]-1.72)/.3971,0,1)
    r[:,2]-=.14*t*t*(3-2*t)
    return r
for tier in ['full','simple']:
    for role in ['paint','contour']:
        data=np.load(OUT/(tier+'_'+role+'_unfaired.npz'))
        points=data['vertices'][:,[0,2,1]]*np.array([1,1,-1])
        points[:,2],stretch=unwarp(points[:,2]);loops=data['loops']
        normals=data['normals'][:,[0,2,1]]*np.array([1,1,-1]);normals[:,2]*=stretch[loops]
        normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-12)
        counts=data['counts']
        if role=='paint':
            points,loops,counts,normals=field.remesh_corners(points,loops,counts,normals,tier=='simple')
            _,stretch=unwarp(warp(points)[:,2])
        average=np.zeros_like(points);np.add.at(average,loops,normals)
        average/=np.maximum(np.linalg.norm(average,axis=1,keepdims=True),1e-12)
        faired,_=field.apply(points,average)
        _,fn=field.apply(points[loops],normals)
        fn[:,2]/=stretch[loops];fn/=np.maximum(np.linalg.norm(fn,axis=1,keepdims=True),1e-12)
        faired=warp(faired)
        indices=[];start=0
        for count in counts:
            for i in range(1,count-1):indices.extend([start+i+1,start+i,start])
            start+=count
        result={'vertices':faired[loops].round(8).tolist(),'normals':fn.round(8).tolist(),'indices':[int(i) for i in indices]}
        (OUT/(tier+'_'+role+'_prototype.json')).write_text(json.dumps(result,separators=(',',':')))
print('Prototype meshes written')
