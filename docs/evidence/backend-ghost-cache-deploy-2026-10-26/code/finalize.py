"""Read-only final acceptance and a code-only deployment evidence bundle."""
from datetime import datetime,timezone
import hashlib
import json
from pathlib import Path
import shutil

from inspect_live import service,WORK,ROOT
from rollout import release,state,verify,unchanged_template,write,OUT

assert state.get('completed') is True
api=service.describe('api',service.n['api'])
before=json.loads((WORK/('before-'+service.n['api']+'.private.json')).read_text())
unchanged_template(before,api)
assert api['status']['latestReadyRevisionName']==state['candidate_revision']
assert api['status']['traffic']==[{'percent':100,'revisionName':state['candidate_revision']}]
assert any(x.get('type')=='Ready' and x.get('status')=='True' for x in api['status']['conditions'])
write(WORK/'after-api.private.json',api)
verify(release['url'],'final-http')
query='resource.type="cloud_run_revision" AND resource.labels.revision_name="'+state['candidate_revision']+'" AND severity>=ERROR'
errors=service.call('logging','read',query,'--limit=100','--format=value(severity)')
observed_errors=errors.splitlines() if errors else []
write(OUT/'revision-error-observation.json',{'checked_utc':datetime.now(timezone.utc).isoformat(),
 'revision':state['candidate_revision'],'severity_at_least':'ERROR','observed_count':len(observed_errors),
 'limit':100,'qualifier':'Point-in-time provider observation; log arrival and later traffic remain outside this check.'})
assert not observed_errors, 'New revision has provider error entries; inspect before declaring acceptance'
cleanup=WORK/'docker-auth.private'
assert not cleanup.exists()
for name in ('inspect_live.py','extract_baseline.py','prepare_release.py','rollout.py','test_ghost_cache_release.py',
             'native_client_gate.py','package_proof.py','finalize.py'):
 target=OUT/'code'/name;target.parent.mkdir(exist_ok=True)
 shutil.copyfile(WORK/name,target)
native=json.loads((OUT/'native-client.json').read_text())
report={'requirements':{'GCD01':'Current identity and compact ghost capabilities deployed',
 'GCD02':'Current authority and backward-compatible ordinary JSON retained',
 'GCD03':'Existing schema, verifier, website, worker and private Studio preserved',
 'GCD04':'Exact-image tests, unchanged-parent failure control and actual Godot client checks',
 'GCD05':'Managed backup, canary, promotion and retained rollback revision'},
 'completed_utc':state['completed_utc'],'verified_utc':datetime.now(timezone.utc).isoformat(),
 'project':'beat-my-track','region':'europe-west1','service':service.n['api'],'url':release['url'],
 'image':state['image'],'revision':state['candidate_revision'],'traffic_percent':100,
 'previous_revision':release['prior_revision'],'previous_image':release['parent'],
 'managed_database_backup_id':state['backup_id'],'schema':'0062_retire_discovery_cache',
 'changed_files':release['changed_files'],'unchanged_existing_package_files':release['unchanged_existing_files'],
 'preserved_resources':state['preserved_resources'],'preserved_canonical_files':165,
 'tests':state['baseline_control'],'native':native,'provider_error_entries_observed':len(observed_errors),
 'commands':['.tools/backend-venv/Scripts/python.exe -X utf8 build/backend-ghost-cache-deploy-2026-10-26/'+name
             for name in ('inspect_live.py','extract_baseline.py','prepare_release.py','rollout.py build','rollout.py test',
                          'native_client_gate.py','rollout.py control','rollout.py push','rollout.py canary',
                          'package_proof.py','rollout.py promote','finalize.py')],
 'initial_attempts':['Default-sandbox cloud inspection could not use the operator environment; the approved scoped inspection succeeded.',
 'An ambiguous preparation anchor was rejected before build or cloud mutation; function-scoped AST comparison corrected preparation.',
 'The initial broad suite reports 80 passed, 2 skipped, 1 failed, 46 deselected. The same downgrade failure reproduces on the exact unchanged parent image.'],
 'remaining_acceptance':['Restart/reload a client containing the existing persistent cache to refresh bootstrap capabilities.',
 'Owner/device gameplay and real player-day transfer savings are unmeasured.',
 'No physical-device attachment check/test, APK, provider sign-in or real purchase was performed.',
 'Packing, archival, retention, provider log sampling and the wider working-tree backend are separate releases.'],
 'operational_artifacts':'Private resource/environment metadata remains in ignored task-owned build storage. Code copies are audit copies; actual entry points used the original build paths.',
 'artifacts':{p.relative_to(OUT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
              for p in sorted(OUT.rglob('*')) if p.is_file() and p.name!='report.json'}}
write(OUT/'report.json',report)
print(json.dumps({k:report[k] for k in ('revision','traffic_percent','schema','provider_error_entries_observed','verified_utc')},indent=2))
