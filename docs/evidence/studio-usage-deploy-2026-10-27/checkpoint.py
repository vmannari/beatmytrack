"""Binary-inclusive deployment review checkpoint; no main-index staging/commit."""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
WORK=ROOT/'build/studio-usage-deploy-2026-10-27'
DOCS=['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','backend/README.md','docs/STUDIO_USAGE_COSTS_2026_10_27.md']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args):
    return subprocess.run(args,cwd=ROOT,capture_output=True,check=False)


def main():
    state=json.loads((WORK/'state.private.json').read_text())
    assert state.get('complete') and state.get('probe_passed') and state.get('tests_passed')
    deployment=json.loads((OUT/'deployment.json').read_text())
    probe=json.loads((OUT/'live-probe.json').read_text())
    billing=json.loads((OUT/'billing-connection.json').read_text())
    old=json.loads((ROOT/'docs/evidence/studio-usage-costs-2026-10-27/report.json').read_text())
    runtime={n:h for n,h in old['files'].items() if n.startswith('backend/bmt_backend/')}
    assert all(sha(ROOT/n)==h for n,h in runtime.items())
    pressure=[{k:r[k] for k in ('label','current','peak','limit','unit','status','observed_at')}
        for r in probe['resources'] if r['status'] in ('critical','warning')]
    report={'requirements':['UCD01','UCD02','UCD03','UCD04','UCD05','R01','Q01'],
        'status':'deployed; provider billing-table delivery pending','deployment':deployment,
        'owner_authorization':'yes, deploy; owner subsequently confirms detailed billing export enabled',
        'source_isolation':{'base_image':state['base_image'],'unchanged_original_files':331,
            'modified_original_files':7,'new_runtime_files':4,'total_package_files':342,
            'canonical_files_exact':164,'physics':'arcade-planar-0.75','vehicle_count':7,
            'runtime_sources_unchanged_since_implementation':runtime},
        'validation':{'exact_image':{'passed':91,'deselected_legacy_fixture':1,'evidence':'exact-image-tests.xml'},
            'live_report':{'resources':len(probe['resources']),'endpoints':probe['endpoint_rows'],'ville_account_found':True,
                'private_player_rows_or_ids_exported':False,'activity':probe['activity'],'evidence':'live-probe.json'},
            'live_browser':json.loads((OUT/'live-browser.json').read_text()),
            'canonical':{'exact':True,'evidence':'canonical-preservation.json'},
            'helper_lint':'reviewed deployment helper sources pass; exact shipped probe retained separately',
            'local_proxy':json.loads((OUT/'local-proxy.json').read_text())},
        'billing':billing,'resource_pressure_snapshot':pressure,
        'boundaries':{'schema_migration':False,'api_worker_existing_jobs_modified':False,
            'resource_sizes_modified':False,'studio_invoker_policy_modified':False,'owner_process_restarted':False,
            'private_game_record_hash_export':False,'physical_device_attachment_check_or_test':False,
            'apk':False,'purchase':False,'main_index_staging_commit_merge':False},
        'initial_attempts':['probe log ingestion delay','initial endpoint source unavailable; later original-settings recheck passes',
            'Jobs PATCH updateMask rejected400; documented update succeeds'],
        'remaining':['provider first detailed table/data and real cost calibration','owner authenticated workflow acceptance',
            'representative load and worker CPU/memory pressure acceptance'],
        'commands':{'entrypoint':'.tools/backend-secure-venv/Scripts/python.exe -X utf8 build/studio-usage-deploy-2026-10-27/deploy.py <stage>',
            'stages':['inspect','build','test','connections','push','canary','probe','probe-result','billing-check','promote','finish'],
            'additional':['offline parent/candidate canonical comparison','read-only same-identity source diagnostic and original-program recheck',
                '.tools/backend-venv/Scripts/python.exe -X utf8 build/studio-usage-deploy-2026-10-27/check_live_browser.py']},
        'checkpoint':{'patch':'scoped-change.patch','verification':'checkpoint-verification.json','binary_inclusive':True}}
    (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    before,after=WORK/'checkpoint-before',WORK/'checkpoint-after'
    for name in DOCS:
        content=(ROOT/name).read_text(encoding='utf-8')
        start=content.index('<!-- STUDIO-USAGE-DEPLOY-20261027 -->')
        end=content.index('<!-- /STUDIO-USAGE-DEPLOY-20261027 -->',start)+len('<!-- /STUDIO-USAGE-DEPLOY-20261027 -->')
        if content[end:end+2]=='\n\n':end+=2
        target=before/name;target.parent.mkdir(parents=True,exist_ok=True)
        target.write_text(content[:start]+content[end:],encoding='utf-8',newline='\n')
    files=DOCS+['docs/STUDIO_USAGE_DEPLOY_2026_10_27.md']
    files += [p.relative_to(ROOT).as_posix() for p in OUT.rglob('*') if p.is_file()
        and p.name not in ('scoped-change.patch','checkpoint-verification.json','checkpoint-errors.txt')]
    for name in files:
        target=after/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((ROOT/name).read_bytes())
    a,b=before.relative_to(ROOT).as_posix(),after.relative_to(ROOT).as_posix()
    diff=run(['git','diff','--no-index','--binary','--',a,b]);assert diff.returncode in (0,1)
    patch=diff.stdout
    for prefix in (a,b):
        for side in ('a/','b/'):
            patch=patch.replace((side+prefix+'/').encode(),side.encode())
    target=OUT/'scoped-change.patch';target.write_bytes(patch)
    relative=target.relative_to(ROOT).as_posix()
    forward=run(['git','apply','--check','--directory='+a,relative])
    reverse=run(['git','apply','--check','--reverse',relative])
    receipt={'forward_check':forward.returncode==0,'reverse_check':reverse.returncode==0,
        'patch_bytes':len(patch),'patch_sha256':sha(target),'scoped_files':len(files),'main_index_unchanged_by_script':True}
    (OUT/'checkpoint-verification.json').write_text(json.dumps(receipt,indent=2)+'\n')
    if forward.returncode or reverse.returncode:
        (OUT/'checkpoint-errors.txt').write_bytes(forward.stderr+reverse.stderr)
        raise RuntimeError('Review checkpoint errors')
    print(json.dumps(receipt))


if __name__=='__main__':
    main()
