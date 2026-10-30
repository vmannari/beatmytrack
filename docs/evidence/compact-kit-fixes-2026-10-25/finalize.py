"""Verify final artifacts and create a scoped checkpoint without the shared index."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[2]
CHECKPOINT=REPO/'build/compact-kit-fixes/checkpoint-repo'
PREFIX='game/assets/vehicles/compact_kits_v1/'
PRODUCTION=['game/vehicle/compact_kits.gd','game/vehicle/compact_body_kits.gd','game/vehicle/compact_hood_kits.gd']

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def git(args,cwd=CHECKPOINT):
    return subprocess.run(['git',*args],cwd=cwd,check=True,capture_output=True).stdout

def main():
    checks={}
    jobs=['source-gl_compatibilityclosed','attachments-gl_compatibility','attachments-mobile','geometrysource-gl_compatibility','geometry-gl_compatibility','construction-gl_compatibility','catalog-gl_compatibility','aero-gl_compatibility','incremental-gl_compatibility','focus-gl_compatibility','speed-gl_compatibility','speed-mobile','parser-gl_compatibility','import-gl_compatibility']
    for job in jobs:
        command=read(ROOT/f'{job}-command.json')
        assert command['exit_code']==0,job
        log=(ROOT/f'{job}.log').read_text(encoding='utf-8-sig')
        result=re.search(r'([A-Z_]+): (\d+) (?:checks|scripts), (\d+) failures',log)
        entry={'command':command,'log':f'{job}.log'}
        if result:
            entry.update(marker=result[1],checks=int(result[2]),failures=int(result[3]))
            assert entry['failures']==0,job
        else: assert job=='import-gl_compatibility',job
        checks[job]=entry
    for renderer,job in [('gl_compatibility','bake'),('mobile','photos')]:
        for category,count in [('hood',2),('aero',1),('body',6)]:
            key=f'{job}-{renderer}-{category}'
            command=read(ROOT/f'{key}-command.json')
            assert command['exit_code']==0,key
            checks[key]={'command':command,'photos_refreshed':count,'log':f'{key}.log'}
    measurements=read(ROOT/'attachments-gl_compatibility/measurements.json')
    assert measurements==read(ROOT/'attachments-mobile/measurements.json')
    assert measurements['checks']==5114 and measurements['failures']==0
    for renderer in ('gl_compatibility','mobile'):
        assert len(list((ROOT/f'attachments-{renderer}').glob('*.png')))==16
    baseline=read(ROOT/'baseline-gl_compatibility/measurements.json')
    assert baseline['checks']==58 and baseline['failures']==54

    before=read(ROOT/'before-hashes.json')
    manifest=read(REPO/(PREFIX+'manifest.json'))
    old_manifest=read(ROOT/'before'/PREFIX/'manifest.json')
    old_keys=old_manifest['meshes']
    changed_keys=[k for k in old_keys if old_keys[k]!=manifest['meshes'][k]]
    added_keys=[k for k in manifest['meshes'] if k not in old_keys]
    assert len(changed_keys)==4 and all('/crowninsert' in k for k in changed_keys)
    assert len(added_keys)==50 and len(manifest['meshes'])==1310
    old_meshes=[p for p in before if p.startswith(PREFIX+'meshes/')]
    exact_meshes=[p for p in old_meshes if sha(REPO/p)==before[p]]
    assert len(exact_meshes)==1256
    old_photos=[p for p in before if '/previews/' in p and p.endswith('.png')]
    changed_photos=[p for p in old_photos if sha(REPO/p)!=before[p]]
    assert len(changed_photos)==18
    protected=['game/vehicle/car_visual.gd','game/vehicle/vehicle_customisation.gd','game/resources/compact_fun.tres','game/ui/car_showroom.gd','game/ui/garage_customisation_camera.gd','game/tests/test_compact_kit_construction.gd','game/tests/test_compact_kit_geometry.gd','game/tests/test_expanded_compact_catalog.gd','game/tests/test_compact_aero_variety.gd']
    for relative in protected: assert sha(REPO/relative)==before[relative],relative
    concurrent=[]
    for relative in ('game/vehicle/vehicle_simulation.gd','game/vehicle/handling_config.gd','AGENTS.md','DEVELOPMENT_STATUS.md'):
        if sha(REPO/relative)!=before[relative]: concurrent.append({'path':relative,'task_start_sha256':before[relative],'current_sha256':sha(REPO/relative),'disposition':'Concurrent work retained and excluded from this task checkpoint.'})

    asset_files=[p for p in (REPO/PREFIX).rglob('*') if p.is_file()]
    assets={p.relative_to(REPO).as_posix():sha(p) for p in sorted(asset_files)}
    (ROOT/'asset-hashes.json').write_text(json.dumps(assets,indent=2)+'\n',encoding='utf-8')
    source_paths=PRODUCTION+protected+['game/tests/test_compact_kit_attachments.gd','game/tests/review_compact_kits.gd','game/tests/test_customisation_carousel.gd','game/tests/test_garage_customisation_speed.gd']
    sources={p:sha(REPO/p) for p in source_paths}
    for relative in source_paths:
        target=ROOT/'final-source'/relative
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(REPO/relative,target)
    (ROOT/'source-hashes.json').write_text(json.dumps(sources,indent=2)+'\n',encoding='utf-8')

    changed_assets=[p for p in assets if p not in before or assets[p]!=before[p]]
    files=PRODUCTION+changed_assets+['game/tests/test_compact_kit_attachments.gd','game/tests/test_compact_kit_attachments.gd.uid','docs/COMPACT_KIT_FIXES_2026_10_25.md']+[f'docs/evidence/compact-kit-fixes-2026-10-25/{p}' for p in ('run.ps1','snapshot.py','gallery.py','finalize.py')]
    CHECKPOINT.mkdir(parents=True,exist_ok=True)
    if not (CHECKPOINT/'.git').exists():
        git(['init','--initial-branch=compact-kit-fixes'])
        git(['config','user.name','Codex'])
        git(['config','user.email','codex@local.invalid'])
        git(['config','core.autocrlf','false'])
        baseline_files=[]
        for relative in files:
            source=ROOT/'before'/relative
            if not source.is_file(): continue
            target=CHECKPOINT/relative
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(source,target)
            baseline_files.append(relative)
        # The new test reuses this unchanged preceding-review diagnostic.
        dependency='game/tests/review_compact_kits.gd'
        target=CHECKPOINT/dependency
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(REPO/dependency,target)
        baseline_files.append(dependency)
        git(['add','--',*baseline_files])
        git(['commit','-m','Preserve exact compact-kit task baseline'])
    base=git(['rev-list','--max-parents=0','HEAD']).decode().strip()
    for relative in files:
        target=CHECKPOINT/relative
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(REPO/relative,target)
    git(['add','--',*files])
    if subprocess.run(['git','diff','--cached','--quiet'],cwd=CHECKPOINT).returncode:
        count=int(git(['rev-list','--count','HEAD']))
        if count==1: git(['commit','-m','Fit compact kit attachments and derive accents from hood triangles'])
        else: git(['commit','--amend','--no-edit'])
    commit=git(['rev-parse','HEAD']).decode().strip()
    patch=git(['diff','--binary',base,'HEAD'])
    (ROOT/'task-only.patch').write_bytes(patch)
    validation=git(['diff','--check',base,'HEAD'])
    validation+=git(['apply','--reverse','--check',str(ROOT/'task-only.patch')],REPO)
    (ROOT/'checkpoint-validation.txt').write_bytes(validation+b'PASS: scoped diff and reverse-application checks\n')
    report={
        'date':'2026-10-25','requirements':{'CKR01':'Fitted roof-lip root','CKR02':'Fitted backing on six arch kits','CKR03':'Actual-triangle hood accents','R01':'Existing outer surfaces, tyre/plate/glass/normal/budget and editing requirements retained','G01':'Scoped baseline/final Git checkpoint and native before/after evidence','Q01':'Local correction complete; owner/device appearance acceptance remains'},
        'checks':checks,'baseline':{'checks':58,'failures':54,'evidence':'baseline-gl_compatibility','source_unchanged_at_baseline':True},
        'measurements':measurements,'native_renderer_measurements_identical':True,
        'catalog':read(ROOT/'catalog-gl_compatibility/catalog.json'),
        'assets':{'total_meshes':1310,'new_meshes':added_keys,'changed_original_meshes':changed_keys,'exact_original_mesh_binaries':1256,'changed_photos':changed_photos,'other_photos_identical':68,'hashes':'asset-hashes.json'},
        'source_hashes':'source-hashes.json','protected_files_unchanged':protected,'concurrent_changes':concurrent,
        'failed_iterations':['Initial insert builder used an untyped ternary array in a typed declaration; corrected after the native error.','First arch backing missed the curved return crest; explicit cross-section stations corrected it.','The first simple backing had insufficient angular sampling; final angular stations match the simple outer flare.','Simple roof seating needed a deeper return to reach its actual coarse triangles.','Four simple backing cap joins exposed float64/float32 endpoint differences; the new backing sampler now gives caps and side rings identical float32 parameters.'],
        'measurement_limits':['Sampled axis clearances in unscaled model metres; not continuous minimum Euclidean distances.','Matched before images use Compatibility; after images are available in both desktop renderers.','Existing 47 stale legacy UI failures are documented by the preceding review; this task keeps those assertions and validates current Parts workflows separately.'],
        'checkpoint':{'path':CHECKPOINT.relative_to(REPO).as_posix(),'base_commit':base,'commit':commit,'files':files,'patch':'task-only.patch','diff_check':'passed','reverse_apply_check':'passed','normal_branch_or_index_modified_by_checkpoint':False},
        'device_attachment_checked':False,'device_test_performed':False,'apk_or_deployment_performed':False,'owner_process_restarted':False,
        'remaining_acceptance':['Client reload of the updated prepared assets.','Owner/device appearance, motion and cost acceptance.']
    }
    evidence=[p for p in ROOT.rglob('*') if p.is_file() and p.name!='report.json' and not any(k in p.parts for k in ('before','final-source'))]
    report['evidence_sha256']={p.relative_to(ROOT).as_posix():sha(p) for p in sorted(evidence)}
    (ROOT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'checkpoint':commit,'changed_files':len(files),'mesh_count':1310,'exact_originals':1256,'photos_refreshed':18,'checks':{j:e.get('checks') for j,e in checks.items() if 'checks' in e}}))

if __name__=='__main__': main()
