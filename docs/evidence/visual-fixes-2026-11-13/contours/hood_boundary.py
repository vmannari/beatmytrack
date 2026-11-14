exec((__import__('pathlib').Path(__file__).with_name('hood_audit.py')).read_text().split('for offset in ')[0])
center=np.array([.005,-1.4]);angles=np.unique(np.arctan2(unique[:,2]-center[1],unique[:,0]-center[0]))
e0=unique[edges[:,0]][:,[0,2]];delta=unique[edges[:,1]][:,[0,2]]-e0
p=[]
for angle in angles:
    d=np.array([np.cos(angle),np.sin(angle)]);v=e0-center
    den=d[0]*delta[:,1]-d[1]*delta[:,0]
    t=np.divide(v[:,0]*delta[:,1]-v[:,1]*delta[:,0],den,out=np.full(len(den),-1.),where=abs(den)>1e-12)
    u=np.divide(v[:,0]*d[1]-v[:,1]*d[0],den,out=np.full(len(den),-1.),where=abs(den)>1e-12)
    mask=(t>0)&(u>=-1e-7)&(u<=1+1e-7)
    selected=np.argmax(np.where(mask,t,-1))
    if t[selected]<0:continue
    point=unique[edges[selected,0]]+(unique[edges[selected,1]]-unique[edges[selected,0]])*u[selected]
    if not p or np.linalg.norm(point-p[-1])>1e-6:p.append(point)
p=np.asarray(p)
print('outline',len(p),np.linalg.norm(p-np.roll(p,1,axis=0),axis=1).sum(),flush=True)
def reduce(tolerance):
    pts=np.vstack([p,p[0]]);keep={0,len(p)};stack=[(0,len(p)//2),(len(p)//2,len(p))];keep.add(len(p)//2)
    while stack:
        a,b=stack.pop()
        if b-a<2:continue
        chord=pts[b]-pts[a];q=pts[a+1:b]-pts[a]
        u=np.clip(q@chord/(chord@chord),0,1)
        errors=np.linalg.norm(q-u[:,None]*chord,axis=1);worst=int(np.argmax(errors))
        if errors[worst]>tolerance:
            at=a+1+worst;keep.add(at);stack.extend([(a,at),(at,b)])
    return sorted(keep)[:-1]
low,high=0.,.02
for i in range(30):
    mid=(low+high)*.5
    if len(reduce(mid))>100:low=mid
    else:high=mid
keep=reduce(high)
print('budget',len(keep),'error_mm',high*1000,flush=True)
(r/'hood-outline.json').write_text(json.dumps(p[keep].tolist(),indent=2))
