"""Independent native-to-original geometry survey, run inside pinned Blender."""
from pathlib import Path
import sys,json,math
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT=Path.cwd();OUT=ROOT/'docs/evidence/challenger-reference-repair-2026-11-14'
sys.path.insert(0,str(ROOT/'scripts'))
from challenger_clean_panels import world
args=sys.argv[sys.argv.index('--')+1:];input_path=Path(args[0]);label=args[1]
dense=np.load(ROOT/'art_sources/challenger_hellcat_v1/source-panels.npz')
labels=np.load(ROOT/'art_sources/challenger_hellcat_v1/components.npz')['labels']
facts=json.loads((ROOT/'art_sources/challenger_hellcat_v1/source-facts.json').read_text())
paint=int(next(i for i,n in facts['cached_material_names'].items() if n=='Car Paint'))
components=labels[dense['tri'][:,0]];source_points=world(dense['co'])
body_ids=[1464,1491,1624,1862,4445,2149,3650,3678,6287,6315]
selections={'body_paint':dense['tri'][(dense['mi']==paint)&np.isin(components,body_ids)],
            'hood_paint':dense['tri'][(dense['mi']==paint)&(components==1572)]}
references={name:BVHTree.FromPolygons(source_points.tolist(),faces.tolist(),all_triangles=True) for name,faces in selections.items()}
data=json.loads(input_path.read_text());checks=[];metrics={}
def check(ok,name):checks.append({'pass':bool(ok),'name':name})
for tier in ['simple','full']:
    row={}
    for name in ['body_paint','hood_paint']:
        mesh=data[tier][name];points=np.asarray(mesh['points']);faces=np.asarray(mesh['indices']).reshape(-1,3)
        right=points[points[:,0]>.002]
        errors=np.array([references[name].find_nearest(Vector(p))[3] for p in right])*1000
        survey={'vertices':len(right),'maximum_mm':float(errors.max()),'p95_mm':float(np.percentile(errors,95)),'mean_mm':float(errors.mean())}
        row[name]=survey
        check(len(right)>500,tier+' '+name+' surveys the actual original exterior')
        check(float(errors.max())<(3.5 if name=='body_paint' else 1.0),tier+' '+name+' maximum source deviation remains bounded')
        check(float(np.percentile(errors,95))<(1.0 if name=='body_paint' else .5),tier+' '+name+' 95th-percentile source deviation remains sub-millimetre')
        check(np.isfinite(points).all(),tier+' '+name+' finite native positions')
        normals=np.asarray(mesh['normals']);triangles=points[faces]
        geometric=-np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0])
        area=np.linalg.norm(geometric,axis=1);geometric/=np.maximum(area[:,None],1e-12)
        shading=normals[faces].mean(1);shading/=np.maximum(np.linalg.norm(shading,axis=1,keepdims=True),1e-12)
        bad=(area>.00005)&(np.sum(geometric*shading,axis=1)<-.05)
        survey['inward_macro_face_normals']=int(bad.sum())
        check(not bad.any(),tier+' '+name+' visible-size faces retain outward shading normals')
        if name=='body_paint':
            e=np.sort(np.concatenate([selections[name][:,[0,1]],selections[name][:,[1,2]],selections[name][:,[2,0]]]),axis=1)
            unique,count=np.unique(e,axis=0,return_counts=True);boundary=source_points[np.unique(unique[count==1])]
            boundary=boundary[boundary[:,0]>.002]
            # Joined source seams can become the interior of larger triangles.
            # Compare their physical surface position, not sampling density.
            native=BVHTree.FromPolygons(points.tolist(),faces.tolist(),all_triangles=True)
            distances=np.array([native.find_nearest(Vector(p))[3] for p in boundary])*1000
            row['factory_boundaries']={'vertices':len(boundary),'maximum_mm':float(distances.max()),'p95_mm':float(np.percentile(distances,95))}
            check(len(boundary)>2500,tier+' original panel-edge control remains comprehensive')
            check(float(distances.max())<1.7,tier+' original boundary stays within the 1.5 mm source weld plus native precision')
            for region,ys,zs in [('nose',[.60,.70,.80],np.linspace(-2.24,-1.72,53)),
                                 ('cowl',[.900,.930,.960],np.linspace(-.90,-.74,25)),
                                 ('rear',[.850,.900,.940],np.linspace(1.75,2.15,41))]:
                errors=[]
                for y in ys:
                    for z in zs:
                        expected,n,*_=references[name].ray_cast((2,float(y),float(z)),(-1,0,0),4)
                        if expected is None or expected.x<.65 or n.x<.6:continue
                        actual,*_=native.ray_cast((2,float(y),float(z)),(-1,0,0),4)
                        check(actual is not None,tier+' '+region+' retains original supported surface')
                        if actual is not None:errors.append(abs(expected.x-actual.x)*1000)
                row[region]={'samples':len(errors),'maximum_width_error_mm':max(errors,default=1000)}
                check(len(errors)>=8,tier+' '+region+' has original-source section controls')
                check(bool(errors) and max(errors)<4.5,tier+' '+region+' follows the original width profile')
    metrics[tier]=row
failed=[c['name'] for c in checks if not c['pass']]
result={'checks':len(checks),'failures':len(failed),'metrics':metrics,'failed':failed,'native_input':str(input_path)}
(OUT/('factory-shape-'+label+'.json')).write_text(json.dumps(result,indent=2))
print('FACTORY_SHAPE',len(checks),'checks,',len(failed),'failures',flush=True)
for name in failed:print('FAIL',name,flush=True)
if failed:raise RuntimeError('Original Challenger geometry survey failed')
