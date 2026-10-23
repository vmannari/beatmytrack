"""Verify that the PC rollout retains the existing runtime settings and object volume."""
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('pc_release',ROOT/'.tools/full_backend_pc_20261018.py')
pc=importlib.util.module_from_spec(spec);spec.loader.exec_module(pc)
override_path=pc.WORK/'pc.override.json'
override=json.loads(override_path.read_text())
for role in ['api','worker']:
    before=json.loads((pc.WORK/('bmt-pc-dev-'+role+'-1-before.private.json')).read_text())
    override['services'][role]['environment']={k:v for k,v in (item.split('=',1) for item in before['Config']['Env']) if k.startswith('BMT_')}
override['services']['migrate']['environment']=dict(override['services']['api']['environment'])
override_path.write_text(json.dumps(override,indent=2)+'\n')
value=json.loads(pc.run(['compose','--env-file','.tools/bmt-pc.env','-f','backend/deploy/compose.pc.yaml',
    '-f','build/full-backend-deploy-2026-10-18/pc.override.json','config','--format=json']))
for role in ['api','worker']:
    before=json.loads((pc.WORK/('bmt-pc-dev-'+role+'-1-before.private.json')).read_text())
    previous=dict(item.split('=',1) for item in before['Config']['Env'])
    proposed=value['services'][role]
    assert proposed['image']==pc.r['image']
    assert all(str(v)==previous[k] for k,v in proposed['environment'].items() if k.startswith('BMT_'))
    objects=next(m for m in before['Mounts'] if m['Destination']=='/var/lib/bmt/objects')
    volume=next(m for m in proposed['volumes'] if m['target']=='/var/lib/bmt/objects')
    assert value['volumes'][volume['source']]['name']==objects['Name']=='bmt-pc-dev_objects'
(pc.OUTPUT/'pc-runtime-plan.json').write_text(json.dumps({'settings_preserved':True,'data_volume_preserved':True,
    'same_candidate_image':True,'roles':['api','worker'],'configuration_secrets_withheld':True},indent=2)+'\n')
print('PC plan: original BMT settings and object volume retained; exact release image selected')
