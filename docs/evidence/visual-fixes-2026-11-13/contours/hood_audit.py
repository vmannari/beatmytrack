from pathlib import Path
import json,numpy as np
r=Path(__file__).resolve().parent
data=json.loads((r/'hood-arrays.json').read_text())
def mesh(name):
    d=data[name];p=np.array(d['vertices']);f=np.array(d['indices']).reshape(-1,3)
    if not len(f):f=np.arange(len(p)).reshape(-1,3)
    return p,f
hp,hf=mesh('hood');bp,bf=mesh('body')
unique,canonical=np.unique(np.round(hp,6),axis=0,return_inverse=True)
edges=np.sort(np.concatenate([canonical[hf[:,[0,1]]],canonical[hf[:,[1,2]]],canonical[hf[:,[2,0]]]]),axis=1)
edges,counts=np.unique(edges,axis=0,return_counts=True);edges=edges[counts==1]
rows=unique[edges].mean(1);rows=rows[(abs(rows[:,0])>.6)&(rows[:,2]<-.90)]
tri=bp[bf];a=tri[:,0,[0,2]];v0=tri[:,1,[0,2]]-a;v1=tri[:,2,[0,2]]-a
den=v0[:,0]*v1[:,1]-v0[:,1]*v1[:,0]
def height(p):
    v2=p[[0,2]]-a
    u=np.divide(v2[:,0]*v1[:,1]-v2[:,1]*v1[:,0],den,out=np.full(len(den),np.nan),where=abs(den)>1e-16)
    v=np.divide(v0[:,0]*v2[:,1]-v0[:,1]*v2[:,0],den,out=np.full(len(den),np.nan),where=abs(den)>1e-16)
    mask=(u>=-1e-8)&(v>=-1e-8)&(u+v<=1+1e-8)
    ys=tri[:,0,1]+u*(tri[:,1,1]-tri[:,0,1])+v*(tri[:,2,1]-tri[:,0,1])
    return np.max(ys[mask]) if mask.any() else np.nan
for offset in [-.004,-.002,-.001,-.0005,0,.0005,.001,.002,.004]:
    moved=rows.copy();moved[:,0]+=np.sign(moved[:,0])*offset
    gap=np.array([height(p)-p[1] for p in moved]);close=gap[np.isfinite(gap)&(abs(gap)<.05)]
    print(offset,'rows',len(rows),'near',len(close),'range_mm',np.nanpercentile(close*1000,[0,10,50,90,100]) if len(close) else None)
print('row_extent',rows.min(0),rows.max(0))
