from pathlib import Path
import sys,json,numpy as np
ROOT=Path.cwd();BUILD=ROOT/'build/challenger-continuous-side-2026-11-15'
sys.path.insert(0,str(ROOT/'scripts'))
import challenger_clean_panels as panel
from challenger_side_surface import SharedSide
dense=np.load(ROOT/'art_sources/challenger_hellcat_v1/source-panels.npz')
facts=json.loads((ROOT/'art_sources/challenger_hellcat_v1/source-facts.json').read_text())
paint=next(int(k) for k,v in facts['cached_material_names'].items() if v=='Car Paint')
ids=[1464,1491,1624,1862,4445,2149,3650,3678,6287,6315]
components=np.load(ROOT/'art_sources/challenger_hellcat_v1/components.npz')['labels'][dense['tri'][:,0]]
faces=dense['tri'][(dense['mi']==paint)&np.isin(components,ids)]
hood_faces=dense['tri'][(dense['mi']==paint)&(components==1572)]
field=SharedSide(panel.world(dense['co']),faces,panel.world(dense['co']),hood_faces)
(BUILD/'side-profile.json').write_text(json.dumps(field.stats,indent=2))
data=json.loads((BUILD/'baseline.json').read_text());result={}
for tier in ['full','simple']:
    source=data[tier]['body_paint'];p=np.asarray(source['points']);n=np.asarray(source['normals']);f=np.asarray(source['indices']).reshape(-1,3)[:,::-1]
    v=np.c_[p,n][f];out,stats=field.apply(v)
    print(tier,stats,flush=True)
    result[tier]={'points':out[:,:,:3].reshape(-1,3).tolist(),'normals':out[:,:,3:].reshape(-1,3).tolist(),'indices':np.arange(out.shape[0]*3).reshape(-1,3)[:,::-1].reshape(-1).tolist()}
    # Temporary contour fit, replaced by the exact native producer in final.
    source=data[tier]['body_contour'];p=np.asarray(source['points']);n=np.asarray(source['normals'])
    use=abs(n[:,0])>.98
    p[use,0]=np.sign(p[use,0])*(field.width(p[use,1],p[use,2])+.0018)
    result[tier]['contour_points']=p.tolist()
(BUILD/'candidate-side.json').write_text(json.dumps(result,separators=(',',':')))
