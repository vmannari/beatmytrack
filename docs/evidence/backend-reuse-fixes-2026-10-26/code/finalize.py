"""Final read-only live acceptance and task-only source/evidence checkpoint."""
import ast
from datetime import datetime,timezone
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET

from inspect_live import service,WORK,ROOT
from rollout import release,state,verify,unchanged_template,write,OUT

assert state.get('completed') is True
api=service.describe('api',service.n['api'])
before=json.loads((WORK/('before-'+service.n['api']+'.private.json')).read_text())
unchanged_template(before,api)
assert api['status']['latestReadyRevisionName']==state['candidate_revision']
assert api['status']['traffic']==[{'percent':100,'revisionName':state['candidate_revision']}]
assert any(c.get('type')=='Ready' and c.get('status')=='True' for c in api['status']['conditions'])
write(WORK/'after-api.private.json',api)
verify(release['url'],'final-http')
errors=service.call('logging','read','resource.type="cloud_run_revision" AND resource.labels.revision_name="'+state['candidate_revision']+'" AND severity>=ERROR',
 '--limit=100','--format=value(severity)')
assert not errors, 'Inspect revision errors before final acceptance'
write(OUT/'final-acceptance.json',{'checked_utc':datetime.now(timezone.utc).isoformat(),
 'revision':state['candidate_revision'],'traffic_percent':100,'schema':'0062_retire_discovery_cache',
 'new_capabilities':release['new_capabilities'],'provider_error_entries_observed':0,
 'error_observation_qualifier':'Point-in-time provider log observation, not sustained traffic acceptance.'})

for name in ('inspect_live.py','extract_baseline.py','prepare_release.py','rollout.py','postgres_gate.py','package_proof.py',
             'native_client_gate.py','native_completion_gate.py','measure.py','finalize.py'):
 target=OUT/'code'/name;target.parent.mkdir(exist_ok=True);shutil.copyfile(WORK/name,target)
for source,name in ((WORK/'retained.xml','initial-retained-tests.xml'),(WORK/'retained-final.xml','source-retained-tests.xml'),
 (WORK/'focused.xml','source-focused-tests.xml'),(WORK/'native-focused.stdout.log','native-focused.stdout.log'),
 (WORK/'native-focused.stderr.log','native-focused.stderr.log'),(WORK/'native-retained.json','native-retained.json')):
 shutil.copyfile(source,OUT/name)
for name in ('test_cost_downloads.gd','test_instant_comparisons.gd'):
 for suffix in ('stdout','stderr'):shutil.copyfile(WORK/(name+'.'+suffix+'.log'),OUT/(name+'.'+suffix+'.log'))

changed=['backend/bmt_backend/rivalry.py','backend/bmt_backend/completion_reads.py',
 'game/backend/cosmetic_economy.gd','game/backend/comparison_preloader.gd',
 'backend/bmt_backend/rivalry_reads.py','backend/tests/test_backend_reuse.py',
 'game/tests/test_backend_reuse.gd','game/tests/test_backend_reuse.gd.uid',
 'game/tests/test_completion_receipts_http.gd','game/tests/test_completion_receipts_http.gd.uid']
patch=[]
for name in changed:
 old_path=WORK/'before'/name
 old=old_path.read_bytes().decode('utf-8').splitlines(keepends=True) if old_path.exists() else []
 new=(ROOT/name).read_bytes().decode('utf-8').splitlines(keepends=True)
 patch.extend(difflib.unified_diff(old,new,fromfile='a/'+name if old else '/dev/null',tofile='b/'+name))
checkpoint=OUT/'scoped-source.patch';checkpoint.write_text(''.join(patch),encoding='utf-8',newline='')
check=subprocess.run(['git','apply','--reverse','--check',str(checkpoint)],cwd=ROOT,capture_output=True,text=True)
assert check.returncode==0,check.stderr
overlay=[]
for name in release['changed_files']:
 old_path=WORK/'baseline/bmt_backend'/name
 old=old_path.read_bytes().decode('utf-8').splitlines(keepends=True) if old_path.exists() else []
 new=(WORK/'release/bmt_backend'/name).read_bytes().decode('utf-8').splitlines(keepends=True)
 overlay.extend(difflib.unified_diff(old,new,fromfile='a/bmt_backend/'+name if old else '/dev/null',tofile='b/bmt_backend/'+name))
overlay_path=OUT/'deployed-overlay.patch';overlay_path.write_text(''.join(overlay),encoding='utf-8',newline='')
check=subprocess.run(['git','apply','--reverse','--check','--directory=build/backend-reuse-fixes-2026-10-26/release',str(overlay_path)],cwd=ROOT,capture_output=True,text=True)
assert check.returncode==0,check.stderr
assert not (WORK/'docker-auth.private').exists()
pg=json.loads((OUT/'postgres-gate.json').read_text());assert pg['exit_code']==0 and pg['owned_fixture_removed']

def junit(path):
 cases=ET.parse(path).findall('.//testcase')
 return {'passed':sum(c.find('failure') is None and c.find('error') is None and c.find('skipped') is None for c in cases),
   'failed':sum(c.find('failure') is not None or c.find('error') is not None for c in cases),
   'skipped':sum(c.find('skipped') is not None for c in cases)}
gates={name:junit(OUT/file) for name,file in (('exact_image','exact-image-tests.xml'),('postgres','postgres-tests.xml'),
 ('source_retained','source-retained-tests.xml'),('source_focused','source-focused-tests.xml'))}
assert all(v['failed']==0 for v in gates.values())
report={'requirements':{'BRF01':'Compatible preview reuse enabled with current metadata and full fallback',
 'BRF02':'15-second wallet freshness, forced activity refresh, exact pending retry and coherent server read',
 'BRF03':'Optional single/batch/wait/recovery receipt enrichment avoids reward/wallet follow-up calls',
 'BRF04':'Two speculative targets with foreground bypass and scoped local use counters',
 'BRF05':'Batched fresh Rivalry input reads and bounded derived-byte reuse',
 'BRF06':'Exact-image/PostgreSQL/native acceptance and backed-up canary rollout'},
 'completed_utc':state['completed_utc'],'verified_utc':datetime.now(timezone.utc).isoformat(),
 'image':state['image'],'revision':state['candidate_revision'],'url':release['url'],'traffic_percent':100,
 'backup_id':state['backup_id'],'schema':'0062_retire_discovery_cache','previous_revision':release['prior_revision'],
 'preserved_resources':state['preserved_resources'],'changed_source_files':changed,'deployed_api_files':release['changed_files'],
 'source_sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in changed},
 'gates':gates,'native_checks':{'focused_wallet_prefetch':17,'actual_receipt_http':10,'retained_ghost_http':21,
 'retained_cost_downloads':122,'retained_instant_comparisons':25},
 'initial_failures':['Initial new-test fixture used the group-view query budget for current; the test now measures the original reviewed current endpoint and retains its eight-SELECT bound.',
 'Initial fixture assumed group pins contained a manifest; it now uses the existing board_manifest helper.',
 'Retained tests caught a second clock binding at week boundaries (7 failures); using the existing Rivalry clock corrected all 61 selected checks. Original JUnit is retained.',
 'Ruff removed unused test imports and sorted imports; assertions were not weakened.'],
 'known_exclusion':'The pre-existing additive_attempt_migration downgrade guard was deselected from exact-image read-only release tests; it reproduces on unchanged previous images and migrations are byte-identical.',
 'commands':['.tools/backend-venv/Scripts/python.exe -X utf8 build/backend-reuse-fixes-2026-10-26/'+s for s in (
 'inspect_live.py','extract_baseline.py','prepare_release.py','rollout.py build','rollout.py test','postgres_gate.py',
 'package_proof.py','native_client_gate.py','native_completion_gate.py','measure.py','rollout.py push','rollout.py canary','rollout.py promote','finalize.py')],
 'checkpoint_reverse_check_passed':True,'provider_error_entries_observed':0,
 'limits':['Client changes require game reload/rebuild. No owner process was restarted or APK exported.',
 'No physical-device attachment check/test, real purchase or provider sign-in was performed.',
 'Cloud checks use public discovery reads/temporary cursors and unauthenticated status denial; no player/score/reward records were created.',
 'Local statement counts and prefetch-call counts do not establish production latency, hit rates or invoice savings.',
 'A source-only working-tree schema69 release, packing, archives, retention and physics changes remain separate.'],
 'artifacts':{p.relative_to(OUT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.rglob('*')) if p.is_file() and p.name!='report.json'}}
write(OUT/'report.json',report)
print(json.dumps({'completed':True,'revision':state['candidate_revision'],'gates':gates,'native_checks':report['native_checks'],
 'scoped_patch_reverse_check':True,'provider_errors_observed':0},indent=2))
