from pathlib import Path
import sys,json,numpy as np
ROOT=Path.cwd();BUILD=ROOT/'build/challenger-reference-form-2026-11-15'
sys.path.insert(0,str(ROOT/'scripts'))
from challenger_reference_form import rebuild
import ast,bpy,math
import challenger_clean_panels as panel
from challenger_exterior_geometry import records
from challenger_side_surface import SharedSide
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt
tree=ast.parse((ROOT/'scripts/prepare_challenger.py').read_text())
for node in tree.body:
    if isinstance(node,ast.FunctionDef) and node.name in ['inside_polygon','lattice']:
        exec(compile(ast.Module(body=[node],type_ignores=[]),'shared-lattice','exec'))
data=json.loads((BUILD/'baseline.json').read_text());result={}
manifest=json.loads((BUILD/'baseline/manifest.json').read_text())
dense=np.load(ROOT/'art_sources/challenger_hellcat_v1/source-panels.npz')
facts=json.loads((ROOT/'art_sources/challenger_hellcat_v1/source-facts.json').read_text())
paint=next(int(k) for k,v in facts['cached_material_names'].items() if v=='Car Paint')
components=np.load(ROOT/'art_sources/challenger_hellcat_v1/components.npz')['labels'][dense['tri'][:,0]]
faces=dense['tri'][(dense['mi']==paint)&np.isin(components,[1464,1491,1624,1862,4445,2149,3650,3678,6287,6315])]
side_field=SharedSide(panel.world(dense['co']),faces)
for tier in ['full','simple']:
    d=data[tier];exports=[]
    for entry in manifest['tiers'][tier]:
        name=entry['group']+'_'+entry['role'];source=d[name]
        p=np.asarray(source['points']);n=np.asarray(source['normals']);f=np.asarray(source['indices']).reshape(-1,3)[:,::-1]
        obj=bpy.data.objects.new(entry['group']+'__'+entry['role'],bpy.data.meshes.new(name));bpy.context.scene.collection.objects.link(obj)
        panel._write(obj,np.c_[p,n][f]);exports.append(obj)
    stats,guide,field=rebuild(exports,lattice,tier=='simple',side_field)
    boundary=guide.boundary();tangent=np.roll(boundary,-1,axis=0)-boundary;tangent[:,1]=0
    tangent/=np.linalg.norm(tangent,axis=1,keepdims=True)
    outward=np.c_[tangent[:,2],np.zeros(len(tangent)),-tangent[:,0]];previous=np.roll(outward,1,axis=0)
    across=(outward+previous)/np.maximum(1+np.sum(outward*previous,axis=1),.01)[:,None]
    for side in [-1,1]:
        q=boundary-across*(.0025+side*.00125)
        hp,hf,_=panel._read(next(o for o in exports if o.name=='hood__paint'))
        (BUILD/'boundary-diagnostic.json').write_text(json.dumps({'boundary':boundary.tolist(),'inset':q.tolist(),'points':hp.tolist(),'faces':hf.tolist()}))
        guide.supported_height(q[:,0],q[:,2])
    result[tier]={}
    for obj in exports:
        name=obj.name.replace('__','_');out=records(obj)
        result[tier][name]={'points':out[:,:,:3].reshape(-1,3).tolist(),'normals':out[:,:,3:].reshape(-1,3).tolist(),'indices':np.arange(out.shape[0]*3).reshape(-1,3)[:,::-1].reshape(-1).tolist()}
        bpy.data.objects.remove(obj,do_unlink=True)
    print(tier,stats,flush=True)
(BUILD/'candidate-form.json').write_text(json.dumps(result,separators=(',',':')))
