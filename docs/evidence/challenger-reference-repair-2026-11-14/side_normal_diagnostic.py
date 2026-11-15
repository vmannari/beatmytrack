from pathlib import Path
import sys,json,numpy as np
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from challenger_panel_geometry import SurfaceGrid
from challenger_reference_geometry import nose_inverse,nose_corner_field,nose_plan_scale,nose_normals,nose_plan_points,nose_plan_normals,nose_corner_normals,NOSE_PLAN_CENTRE
data=json.loads((ROOT/'build/challenger-reference-repair-2026-11-14/decoded-restoration-final.json').read_text())
profile=json.loads((ROOT/'build/challenger-reference-repair-2026-11-14/converted/reference_profile.json').read_text())
grid=SurfaceGrid(profile['y'],profile['z'],profile['widths'])
def ramp(a,b,x):
    t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
result={}
for tier in ['full','simple']:
    p=np.asarray(data[tier]['body_paint']['points']);original=np.asarray(data[tier]['body_paint']['normals'])
    sign=np.sign(p[:,0]);q=p.copy();q[:,0]=abs(q[:,0])
    pre=q.copy()
    for _ in range(12):pre[:,1:]=q[:,1:]-(nose_corner_field(pre)[0]-pre)[:,1:]
    scale,_=nose_plan_scale(pre[:,2]);pre[:,0]=NOSE_PLAN_CENTRE+(pre[:,0]-NOSE_PLAN_CENTRE)/scale
    pre[:,2]=nose_inverse(pre[:,2],pre[:,0])[0]
    y,z=pre[:,1],pre[:,2];e=.0005
    dy=(grid.at(y+e,z)-grid.at(y-e,z))/(2*e);dz=(grid.at(y,z+e)-grid.at(y,z-e))/(2*e)
    n=np.c_[np.ones(len(p)),-dy,-dz];n/=np.linalg.norm(n,axis=1,keepdims=True)
    n=nose_normals(pre,n);pre[:,2]=-__import__('challenger_reference_geometry').nose_distance(-pre[:,2],pre[:,0])[0]
    n=nose_plan_normals(pre,n);pre=nose_plan_points(pre);n=nose_corner_normals(pre,n);n[:,0]*=sign
    w=ramp(.30,.36,y)*(1-ramp(1.00,1.07,y))*ramp(.64,.76,abs(p[:,0]))*ramp(.15,.65,original[:,0]*sign)
    n=original*(1-w[:,None])+n*w[:,None];n/=np.maximum(np.linalg.norm(n,axis=1,keepdims=True),1e-12)
    result[tier]=n.tolist()
(ROOT/'build/challenger-reference-repair-2026-11-14/side-normal-diagnostic.json').write_text(json.dumps(result,separators=(',',':')))
