"""Save release evidence and scoped source checkpoints without live mutations."""
import difflib
import hashlib
import json
import shutil
import subprocess
from datetime import datetime,timezone
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/full-backend-deploy-2026-10-23'
WORK=ROOT/'build/full-backend-deploy-2026-10-23'
r=json.loads((OUT/'rollout.json').read_text())
pc=json.loads((OUT/'pc-rollout.json').read_text())
fix=json.loads((OUT/'catalog-fix-rollout.json').read_text())
assert r['completed'] and pc['completed'] and fix['cloud_completed'] and fix['pc_completed']
assert r['candidate_id']==pc['image_id']==fix['image_id']
before=json.loads((OUT/'data-before.json').read_text())
after=json.loads((OUT/'data-after-migration.json').read_text())
pcbefore=json.loads((OUT/'pc-data-before.json').read_text())
pcafter=json.loads((OUT/'pc-data-after-migration.json').read_text())
assert before['tables']==after['tables'] and pcbefore['tables']==pcafter['tables']
http=json.loads((OUT/'discovery-live-http.json').read_text())
pchttp=json.loads((OUT/'pc-live-http.json').read_text())
assert http['public_tracks_seen']==30 and pchttp['public_tracks_seen']==27
core=json.loads((OUT/'core-browser.json').read_text())
assert len(core['core_view_checks'])==16 and not core['javascript_errors'] and not core['write_requests']

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

tools=['full_backend_deploy_20261023.py','release57_cutover.py','release57_catalog_fix.py','release57_pc.py',
       'release57_pc_http.py','release57_status.py','release57_core_browser.py','release57_rehearse.py',
       'release57_scale_seed.py','release57_finalize.py']
audit=OUT/'tools';audit.mkdir(exist_ok=True)
hashes={}
for name in tools:
    source=ROOT/'.tools'/name
    shutil.copyfile(source,audit/name)
    hashes['.tools/'+name]=sha(source)

files=['backend/bmt_backend/discovery_projection.py','backend/deploy/stage_verifier.py',
       'backend/tests/test_discovery_projection.py','backend/tests/test_verifier.py']
baseline=OUT/'checkpoint-baseline';baseline.mkdir(exist_ok=True)
patch=[];checkpoint={}
for name in files:
    current=ROOT/name
    initial=WORK/'frozen'/name
    original=initial.read_text(encoding='utf-8')
    if name.endswith('stage_verifier.py'):
        assert original.count('        "tyre_contacts",\n')==1
        original=original.replace('        "tyre_contacts",\n','',1)
    target=baseline/name;target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(original,encoding='utf-8',newline='\n')
    text=current.read_text(encoding='utf-8')
    patch.extend(difflib.unified_diff(original.splitlines(keepends=True),text.splitlines(keepends=True),fromfile='a/'+name,tofile='b/'+name))
    checkpoint[name]={'before_sha256':sha(target),'after_sha256':sha(current)}
(OUT/'task-source.patch').write_text(''.join(patch),encoding='utf-8',newline='\n')
checked=subprocess.run(['git','apply','--reverse','--check',str(OUT/'task-source.patch')],cwd=ROOT,capture_output=True,text=True)
(OUT/'patch-check.log').write_text(checked.stdout+checked.stderr,encoding='utf-8')
assert checked.returncode==0,'Source patch reverse check failed'
(OUT/'source-checkpoint.json').write_text(json.dumps(checkpoint,indent=2)+'\n')
dependencies=['.tools/full_backend_deploy_20261018.py','.tools/full_backend_pc_20261018.py',
              '.tools/backend_latest_rollout_20261016.py','.tools/backend_studio_rollout_20261011.py',
              'backend/deploy/gcp/staging.py']
result={
    'written_at_utc':datetime.now(timezone.utc).isoformat(),
    'authorization':'Owner requested necessary migrations to latest version and deployment.',
    'scope':'Existing retained cloud staging API/worker/five owned job definitions and PC API/worker. No new recurring instance.',
    'status':'Backend deployment complete; broad Studio analytics require separately approved reporting replica.',
    'project':'beat-my-track','region':'europe-west1','url':r['url'],
    'schema_before':r['schema_before'],'schema_after':r['schema'],
    'image':r['image'],'image_id':r['candidate_id'],'api_revision':r['canary_revision'],'worker_revision':fix['worker_revision'],
    'owned_runtime_targets':r['targets'],'worker_instances':r['worker_instances_before'],
    'backup':{'managed_sql_backup_id':r['backup_id'],'quiesced':r['backup_quiesced'],'pc':pc['backup'],
              'private_backup_directory':'build/full-backend-deploy-2026-10-23/pc-backup'},
    'preservation':{'cloud_tables_exact':len(before['tables']),'cloud_rows_exact':sum(v['rows'] for v in before['tables'].values()),
                    'pc_tables_exact':len(pcbefore['tables']),'pc_rows_exact':sum(v['rows'] for v in pcbefore['tables'].values()),
                    'comparison_point':'After migration and before matching workers resume normal derived projections/retention.',
                    'cloud_invalid_indexes':after['invalid_indexes'],'track_revisions_inserted':0},
    'validation':{'release_gate':'release-gate.json','original_postgres_discovery':'59pass/2skip',
                  'final_english_collation_postgres':'60pass/2skip','native_storage_smoke':r['native_storage_smoke'],
                  'core_browser_views':len(core['core_view_checks']),'core_browser_errors':0,'write_requests':0,
                  'cloud_public_tracks':http['public_tracks_seen'],'pc_public_tracks':pchttp['public_tracks_seen'],
                  'cloud_cursor_pages':http['cursor_pages'],'pc_cursor_pages':pchttp['cursor_pages'],
                  'legacy_discovery':'426 requires matching v3 client'},
    'collation_correction':r['catalog_collation_fix'],
    'catalog_coverage_restored_by':'Normal bounded worker source audit; no manual account/projection/queue mutation.',
    'replica':{'status':'approval_pending_not_created','plan':'reporting-replica-plan.json',
               'broad_report_status':503,'reason':'STUDIO_ANALYSIS_REPLICA_NOT_CONFIGURED; no primary fallback enabled'},
    'automatic_review':{'action':'Optional complete cloud database export to separate private storage prefix',
                        'outcome':'Rejected before execution; not retried or bypassed',
                        'reason':'Sensitive account payload and separate destination were not specifically authorized by deployment request',
                        'alternative':'Managed Cloud SQL backup, existing local backup restore and aggregate-only synthetic migration rehearsal'},
    'temporary_tags_removed':r['temporary_tags_removed'],'deployment_lock_removed':True,
    'completed_at_utc':r['completed_utc'],'tool_hashes':hashes,'operational_dependency_hashes':{name:sha(ROOT/name) for name in dependencies},
    'source_checkpoint':'source-checkpoint.json','task_patch':'task-source.patch','task_patch_reverse_check':True,
    'limits':['Retained staging allocation; no million-DAU/500-million-account or cloud latency certification.',
              'Broad Studio reporting standby requires explicit cost/activation decision.',
              'Initial exact-image suite445pass/4fail/82skip; historical adapter fixed/rechecked, legacy irreversible rollback and SQLite plan limitations retained in release gate.',
              'Public-edge/client-IP/WAF capacity and full disaster restore acceptance remain.',
              'No phone attachment check, device test, client APK, real account grant/charge or population job execution.'],
}
(OUT/'report.json').write_text(json.dumps(result,indent=2)+'\n')
(OUT/'completion.json').write_text(json.dumps({key:result[key] for key in ['status','url','schema_after','image','api_revision','worker_revision','completed_at_utc','replica']},indent=2)+'\n')
summary=('2026-10-23 DEP57/R01/Q01: Owner-authorized cloud API93-gap/worker39-rcp/all five existing jobs and PC API/worker now use complete imagec126c96c at schema57. Fresh quiesced managed SQL backup1792748184984 and private PC DB/object backups succeed; all293786 cloud/7301 PC original rows across99 tables each remain exact through migration. Final English-collation PostgreSQL60pass/2skip, native/storage, full30cloud/27PC catalogue traversals and16 core Edge views pass. Canonical package adds missing tyre_contacts; adjacent hex bounds repair en_US.UTF8 catalogue omission through bounded audit without another migration. Initial gate/legacy rollback/SQLite planner limitations are retained. Broad Studio analytics deliberately503 without a dedicated standby; US$50-70/month replica plan awaits owner approval and no new recurring instance exists. Commands, corrections, receipts and task-only checkpoint: docs/LATEST_BACKEND_DEPLOY_2026_10_23.md and docs/evidence/full-backend-deploy-2026-10-23/report.json. Existing retained settings/data and concurrent work remain. No phone/device/APK, account grant/charge, manual queue/population mutation or DAU certification.\n\n')
for relative in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    path=ROOT/relative;old=path.read_bytes()
    if b'DEP57/R01/Q01' not in old:
        prefix=('## Latest backend schema57 deployment override (2026-10-23)\n' if relative=='AGENTS.md' else '')+summary
        path.write_bytes(prefix.encode('utf-8')+old)
print(json.dumps({'report':str(OUT/'report.json'),'cloud_rows_preserved':result['preservation']['cloud_rows_exact'],
                  'pc_rows_preserved':result['preservation']['pc_rows_exact'],'patch_reverse_check':True,'reporting_replica':'approval_pending'}))
