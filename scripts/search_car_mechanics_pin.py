import numpy as np,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
g=json.loads((root/'build/car-mechanics-2026-11-17/geometry.json').read_text())
k=next(k for k in g if k.startswith('forklift_8e7e'))
v=np.array(g[k]['surfaces'][0]['vertices'])[:,[0,2]]
v=np.unique(np.round(v,8),axis=0);v=v[np.linalg.norm(v,axis=1)>.008]
v=v[np.argsort(np.arctan2(v[:,1],v[:,0]))]
lo=v.min(axis=0);hi=v.max(axis=0)
def dist(p,q):
 a=q;b=np.roll(q,-1,axis=0);e=b-a
 t=np.clip(((p[:,None]-a)*e).sum(axis=2)/(e*e).sum(axis=1),0,1)
 return np.sqrt(((p[:,None]-a-t[:,:,None]*e)**2).sum(axis=2).min(axis=1)).max()
def sample(q):return np.concatenate([q*(1-t)+np.roll(q,-1,axis=0)*t for t in np.linspace(0,1,9)])
s=sample(v);best=(1,None)
for phase in np.linspace(0,np.pi*2/5,181):
 raw=np.stack((np.sin(np.arange(5)*np.pi*2/5+phase),np.cos(np.arange(5)*np.pi*2/5+phase)),axis=1)
 for xfill in np.linspace(.92,1,5):
  for zfill in np.linspace(.90,1,11):
   extent=(hi-lo)*np.array([xfill,zfill]);q=(raw-raw.min(axis=0))/(raw.max(axis=0)-raw.min(axis=0))*extent-extent/2
   error=max(dist(s,q),dist(sample(q),v))
   if error<best[0]:best=(float(error),dict(phase=float(phase),xfill=float(xfill),zfill=float(zfill),points=q.tolist()))
print(best)
(root/'build/car-mechanics-2026-11-17/pin-profile.json').write_text(json.dumps(best[1]))
