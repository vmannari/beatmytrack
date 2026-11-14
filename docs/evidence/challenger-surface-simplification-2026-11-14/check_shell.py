"""Independent sections of the native, encoded shoulder geometry."""
from pathlib import Path
import json, sys
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build/challenger-surface-simplification-2026-11-14'
sys.path.insert(0,str(ROOT/'scripts'))
from challenger_panel_geometry import SurfaceGrid
from challenger_reference_geometry import ReferenceBody, nose_distance, nose_plan_points, nose_corner_field

profile=json.loads((BUILD/'converted/reference_profile.json').read_text())
class Side:
    centre_x=profile['centre_x']
    grid=SurfaceGrid(profile['y'],profile['z'],profile['widths'])
    def width(self,y,z):return self.grid.at(y,z)
source=np.load(ROOT/'art_sources/challenger_hellcat_v1/source-panels.npz')
labels=np.load(ROOT/'art_sources/challenger_hellcat_v1/components.npz')['labels']
points,tri=source['co'],source['tri']
hood_faces=tri[labels[tri[:,0]]==1572]
p=points[hood_faces];n=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0])
hood_faces=hood_faces[n[:,1]>.3*np.linalg.norm(n,axis=1)]
edges=np.sort(np.concatenate([hood_faces[:,[0,1]],hood_faces[:,[1,2]],hood_faces[:,[2,0]]]),axis=1)
edges,counts=np.unique(edges,axis=0,return_counts=True)
reference=ReferenceBody(Side(),points[np.unique(edges[counts==1])])

def section(tri,normals,y,z,sign):
    a=tri[:,0];u=tri[:,1]-a;v=tri[:,2]-a
    det=u[:,1]*v[:,2]-u[:,2]*v[:,1]
    keep=(abs(det)>1e-13)&(tri[:,:,1].min(1)<=y)&(tri[:,:,1].max(1)>=y)&(tri[:,:,2].min(1)<=z)&(tri[:,:,2].max(1)>=z)
    a,u,v,det,ns=a[keep],u[keep],v[keep],det[keep],normals[keep]
    s=((y-a[:,1])*v[:,2]-(z-a[:,2])*v[:,1])/det
    t=(u[:,1]*(z-a[:,2])-u[:,2]*(y-a[:,1]))/det
    ids=np.flatnonzero((s>=-1e-6)&(t>=-1e-6)&(s+t<=1+1e-6))
    if not len(ids):return None
    x=a[:,0]+u[:,0]*s+v[:,0]*t
    i=ids[np.argmax(x[ids]*sign)]
    normal=ns[i,0]*(1-s[i]-t[i])+ns[i,1]*s[i]+ns[i,2]*t[i]
    return float(x[i]),normal/np.linalg.norm(normal)

stages={stage:json.loads((BUILD/('native-plan-'+stage+'.json')).read_text()) for stage in ['before','candidate']}
checks=0;findings=[];rows=[]
def check(ok,label):
    global checks
    checks+=1
    if not ok:findings.append(label)

for tier in ['simple','full']:
    old=np.asarray(stages['before'][tier]['body_paint']).reshape(-1,3,3)
    new=np.asarray(stages['candidate'][tier]['body_paint']).reshape(-1,3,3)
    check(len(new)<.70*len(old),tier+' painted shell loses at least 30% of triangles')
    check(np.max(abs(old.min((0,1))-new.min((0,1))))<.00001,tier+' minimum silhouette extents retained')
    check(np.max(abs(old.max((0,1))-new.max((0,1))))<.00001,tier+' maximum silhouette extents retained')
    for sign in [-1,1]:
        for offset in [-.010,.012,.035]:
            z=np.linspace(-1.65,1.70,336)
            y=reference.crease(z)+offset
            x=reference.cx+sign*reference.width(y,z)
            guide=np.c_[x,y,z]
            guide[:,2]=-nose_distance(-guide[:,2],guide[:,0])[0]
            guide=nose_corner_field(nose_plan_points(guide))[0]
            measurements={}
            for stage in ['before','candidate']:
                data=stages[stage][tier]
                tris=np.asarray(data['body_paint']).reshape(-1,3,3)
                normals=np.asarray(data['body_paint_normals']).reshape(-1,3,3)
                samples=[section(tris,normals,float(p[1]),float(p[2]),sign) for p in guide]
                missing=sum(p is None for p in samples)
                check(missing==0,f'{tier}/{sign}/{offset}/{stage}: shoulder coverage, missing {missing}')
                if missing:continue
                residual=np.asarray([p[0] for p in samples])-guide[:,0]
                ns=np.asarray([p[1] for p in samples])
                measurements[stage]={'rms_width_error_mm':float(np.sqrt(np.mean(residual**2))*1000),
                                     'max_width_error_mm':float(np.max(abs(residual))*1000),
                                     'normal_second_difference_rms':float(np.sqrt(np.mean(np.diff(ns,n=2,axis=0)**2)))}
            if len(measurements)==2:
                a,b=measurements['before'],measurements['candidate']
                check(b['rms_width_error_mm']<a['rms_width_error_mm']*.65,
                      f'{tier}/{sign}/{offset}: common shoulder profile error falls by at least 35%')
                check(b['max_width_error_mm']<3.0,f'{tier}/{sign}/{offset}: continuous shoulder within 3 mm of intended profile')
            rows.append({'tier':tier,'side':sign,'offset':offset,'measurements':measurements})
    check(stages['before'][tier]['hood_paint']==stages['candidate'][tier]['hood_paint'],tier+' bonnet geometry exact')
receipt={'checks':checks,'failures':len(findings),'findings':findings,'sections':rows}
(OUT/'native-shell-check.json').write_text(json.dumps(receipt,indent=2))
print('NATIVE_SHELL:',checks,'checks,',len(findings),'failures')
print('\n'.join(findings))
sys.exit(1 if findings else 0)
