"""CLV02: conservative offline closed-solid proof and manifest-last publication."""
import hashlib
import json
from pathlib import Path
import sys
import numpy as np
from analyse_car_deep_geometry import geometry, convex_planes, MARGIN
from run_car_detail_reduction import ROOT, OUT, WORK, run

def sources():
    directories=("game/vehicle", "game/resources/cars", "game/assets/vehicles")
    paths=[p for folder in directories for p in (ROOT/folder).rglob("*") if p.is_file()
           and p.suffix in (".gd", ".gdshader", ".res", ".png", ".json", ".tres")
           and not any(x in p.parts for x in ("modular_car_bases_v1", "modular_kits_v1", "car_detail_v1"))]
    paths += [ROOT/name for name in ('game/tests/bake_car_detail_reductions.gd','game/tests/support/car_static_reduction_bake.gd',
                                    'scripts/bake_car_detail_reductions.py','scripts/analyse_car_deep_geometry.py')]
    return {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}

def analyse():
    contexts=json.loads((WORK/'contexts.json').read_text())
    data=(WORK/'geometry.bin').read_bytes()
    candidates=[];common={};report=[]
    for context in contexts.values():
        parts=context['parts']
        for part in parts:
            geometry(part,data)
            part['_protected'] |= part['protected'] or not part['opaque']
        occluders=[(part,planes) for part in parts if (planes:=convex_planes(part)) is not None]
        for part in parts:
            triangles=part['_triangles']
            zero=np.all(np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0])==0,axis=1)
            enclosed=np.zeros(len(triangles),dtype=bool)
            if not part['_protected']:
                minimum=triangles.min(axis=1);maximum=triangles.max(axis=1)
                for other,(normals,distance) in occluders:
                    if other['ordinal']==part['ordinal'] or part['layers']!=other['layers']:continue
                    if part['cast_shadow']!=0 and other['cast_shadow']==0:continue
                    possible=np.flatnonzero(~enclosed & np.all(minimum>other['_low']+MARGIN,axis=1)
                                            & np.all(maximum<other['_high']-MARGIN,axis=1))
                    if not len(possible):continue
                    selected=triangles[possible].reshape(-1,3)
                    inside=np.all(selected@normals.T-distance < -MARGIN,axis=1).reshape(-1,3).all(axis=1)
                    enclosed[possible[inside]]=True
            mask=(zero|enclosed) if not part['_protected'] else np.zeros(len(triangles),dtype=bool)
            # An identical physical piece must keep the same geometry in fixed
            # bases, editable bases and every observed fitted context.
            shared=part['shared']
            common[shared]=common[shared]&mask if shared in common else mask.copy()
            candidates.append((context['code'],context['vehicle'],part,mask))
            report.append({'vehicle':context['vehicle'],'context':context['code'],'part':part['path'],
                           'source':part['source'],'enclosed':int(enclosed.sum()),'zero':int(zero.sum()),'before':len(triangles)})
    proposals={}
    for context,vehicle,part,mask in candidates:
        mask &= common[part['shared']]
        if not mask.any():continue
        surfaces={};offset=0
        for surface,(_,indices) in enumerate(part['_surfaces']):
            selected=np.flatnonzero(mask[offset:offset+len(indices)]).tolist()
            if len(selected)==len(indices) and int(mask.sum())!=len(mask):
                mask[offset:offset+len(indices)]=False
            elif selected:surfaces[str(surface)]=selected
            offset+=len(indices)
        if not mask.any():continue
        proposals.setdefault(context,{})[part['code']]={'before':len(mask),'after':len(mask)-int(mask.sum()),
            'hidden':bool(mask.all()),'surfaces':surfaces}
    (WORK/'proposals.json').write_text(json.dumps(proposals))
    (OUT/'hidden-analysis.json').write_text(json.dumps({'margin_model_metres':MARGIN,'context_count':len(contexts),
        'changed_contexts':len(proposals),'physical_piece_intersection':True,'observations':report},indent=2)+'\n')
    print('Qualified frame contexts:',len(contexts),'changed:',len(proposals),flush=True)

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    before=sources()
    vehicle_args=[value for value in sys.argv[1:] if value.startswith('--vehicles=')]
    stage=WORK/('staged-'+hashlib.sha256(json.dumps(before,sort_keys=True).encode()).hexdigest()[:20])
    stage_arg='res://../'+stage.relative_to(ROOT).as_posix()
    if run('detail-export','res://tests/bake_car_detail_reductions.gd','--headless','--',*vehicle_args):raise RuntimeError('Geometry export failed')
    analyse()
    if run('detail-stage','res://tests/bake_car_detail_reductions.gd','--headless','--','--stage','--stage-dir='+stage_arg,*vehicle_args):raise RuntimeError('Recipe staging failed')
    after=sources();changed=sorted(k for k in before.keys()|after.keys() if before.get(k)!=after.get(k))
    (OUT/'recipe-source-fence.json').write_text(json.dumps({'input_count':len(before),'changed_inputs':changed},indent=2)+'\n')
    if changed:raise RuntimeError('Sources changed; candidates remain private')
    destination=ROOT/'game/assets/vehicles/car_detail_v1';destination.mkdir(parents=True,exist_ok=True)
    staged=list(stage.glob('*'))
    # Immutable mesh payloads precede the frame manifests that make them visible.
    for path in sorted(staged,key=lambda p:p.suffix=='.json'):
        target=destination/path.name
        target.write_bytes(path.read_bytes())
    (OUT/'publication.json').write_text(json.dumps({'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in staged},
        'source_fence_passed':True,'meshes_before_manifests':True},indent=2)+'\n')
    print('Published',len(staged),'guarded recipe/mesh files',flush=True)

if __name__=='__main__':main()
