from pathlib import Path
import datetime,hashlib,json,os,re,shutil,subprocess,zipfile

ROOT=Path.cwd();LAB=ROOT/'build/runtime-loading-fixes-2026-10-27';OUT=ROOT/'docs/evidence/runtime-loading-fixes-2026-10-27'
OUT.mkdir(parents=True,exist_ok=True)

def write_json(path,value):path.write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n',encoding='utf-8',newline='\n')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

# Reconstruct only our App/memory hunks; never replace the owner's working files.
subprocess.run(['python',str(LAB/'task_sources.py'),'--sources-only'],check=True)
production=['game/core/app.gd','game/editor/editor_memory.gd','game/vehicle/skid_trails.gd','game/vehicle/skid_trails.gdshader','game/vehicle/effect_render_preparation.gd','game/vehicle/effect_preparation_pool.gd','game/vehicle/compact_detail.gd','game/vehicle/compact_grille.gd']
new_tests=['game/tests/test_runtime_loading_fixes.gd','game/tests/test_runtime_effect_loading.gd']
for relative in production+new_tests:
    source=ROOT/relative
    if relative in new_tests or relative not in ['game/core/app.gd','game/editor/editor_memory.gd']:
        target=LAB/'task-only-after'/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    uid=source.with_suffix(source.suffix+'.uid')
    if uid.exists() and not (LAB/'before'/(relative+'.txt')).exists():
        target=LAB/'task-only-after'/uid.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(uid,target)

# Explicit directories only: frozen projects have outward read-only junctions.
# Never recursively traverse LAB or copy profiles/credential/configuration data.
for source in LAB.iterdir():
    if source.is_file() and source.suffix in {'.log','.json','.py','.gd'}:
        shutil.copy2(source,OUT/source.name)
for folder in ['before','task-only-after','checks']:
    for source in (LAB/folder).rglob('*'):
        if source.is_file():
            target=OUT/folder/source.relative_to(LAB/folder);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
def result_output(relative):
    if any(part.startswith('fixture-') or part in {'cloud','tracks','recordings','profiles'} for part in relative.parts):return False
    name=relative.name
    return name in {'report.json','resources.json','build-profile.json','profile.json','results.json'} or name.startswith(('load-profile-','focused-','app-effects-'))

for base in [OUT/'outputs',LAB/'checkpoint/after/docs/evidence/runtime-loading-fixes-2026-10-27/outputs']:
    if base.exists():
        for path in base.rglob('*.json'):
            if not result_output(path.relative_to(base)):
                assert path.resolve().is_relative_to(base.resolve())
                path.unlink()
for source in (LAB/'outputs').rglob('*.json'):
    if not result_output(source.relative_to(LAB/'outputs')):continue
    target=OUT/source.relative_to(LAB);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
for label in ['baseline-load','after-load-retry','accepted-load-profile']:
    for source in (LAB/'outputs'/label).rglob('*.png'):
        if source.name!='star_spline_lap-0.png':continue
        target=OUT/source.relative_to(LAB);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
for label in ['front-bumper-native','accepted-front-join']:
    candidates=sorted((LAB/'outputs'/label).rglob('*.png'))
    for source in candidates[:2]:
        target=OUT/source.relative_to(LAB);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)

# Source-only archives exclude tests, player/user-data directories, SDK settings,
# public assets/imported binary data and native libraries. Those remain read-only
# dependencies of the local regression projects, not part of this patch.
frozen={}
for variant in ['before','after']:
    base=LAB/('frozen-'+variant)/'game';rows=[]
    with zipfile.ZipFile(OUT/('sources-'+variant+'.zip'),'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for folder,dirs,files in os.walk(base):
            dirs[:]=[name for name in dirs if name not in {'assets','platform','android','.godot','music','tests'} and not name.startswith('recordings-')]
            for name in files:
                source=Path(folder)/name
                if source.suffix not in {'.gd','.gdshader','.gdshaderinc','.tscn','.godot'}:continue
                relative=source.relative_to(base).as_posix();archive.write(source,'game/'+relative);rows.append({'path':relative,'sha256':sha(source)})
    frozen[variant]=rows
    write_json(OUT/('executed-sources-'+variant+'.json'),rows)

executions=[]
for path in sorted(LAB.glob('*-execution.json')):
    row=json.loads(path.read_text(encoding='utf-8'));row['receipt']=path.name
    label=row.get('label',path.name.removesuffix('-execution.json'))
    log=LAB/(label+'.log')
    if log.exists():
        text=log.read_text(encoding='utf-8',errors='replace')
        row['assertion_summary']=[line for line in text.splitlines() if re.search(r'(\d+ checks|SCRIPT_PARSE:|TASK_START_CONTRACT)',line)][-2:]
        row['clean_runtime_result']=row.get('exit')==0 and not row.get('runtime_errors',[]) and 'SCRIPT ERROR:' not in text and not any('ERROR:' in line and 'Failed to read the root certificate store.' not in line for line in text.splitlines())
    executions.append(row)

def profile(label):
    files=list((LAB/'outputs'/label).glob('load-profile*.json'))
    return json.loads(files[0].read_text(encoding='utf-8')) if files else None

before=profile('baseline-load');initial=profile('after-load-retry');accepted=profile('accepted-load-profile')
comparison=[]
if before and accepted:
    for a,b in zip(before['loads'],accepted['loads']):
        assert a['source']==b['source'] and a['cycle']==b['cycle']
        comparison.append({'track':Path(a['source']).name,'cycle':a['cycle'],'before_wall_ms':a['wall_ms'],'after_wall_ms':b['wall_ms'],'before_peak_ms':a['max_frame_ms'],'after_peak_ms':b['max_frame_ms'],'effects':b.get('effects',{})})
write_json(OUT/'load-comparison.json',comparison)

source_scope=[]
for relative in production+new_tests:
    path=ROOT/relative;candidate=LAB/'task-only-after'/relative
    source_scope.append({'path':relative,'working_sha256':sha(path),'task_candidate_sha256':sha(candidate),
                         'executed_after_sha256':sha(LAB/'frozen-after'/relative) if (LAB/'frozen-after'/relative).exists() else None})
report=dict(requirements={'RL01':'One original immutable trail Shader, separate materials and state','RL02':'Staged App particle preparation, bounded tree-owned proxy reuse, current source binding and pressure/cancellation cleanup','RL03':'Exact double-precision nose grid, cooperative strips and immutable fitting cache','R01':'Appearance, canonical state and ownership preserved','Q01':'Pinned/native verification, controls and task-only review checkpoint'},
            completed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),date='2026-10-27',engine='4.7.2.stable.official.ed1daf0bf',
            production_scope=source_scope,executions=executions,
            budgets={'particle_proxy_nodes':64,'particle_proxy_estimated_bytes':12*1024*1024,'front_cache_entries':8,'front_cache_estimated_bytes':2*1024*1024},
            source_snapshots={'before':'sources-before.zip','after':'sources-after.zip','scope':'Production source only; public assets/imported/native data shared read-only. Both snapshots include the same owner-corrected dialog.'},
            baseline_profile=before,initial_integration_profile=initial,final_profile=accepted,load_comparison=comparison,
            geometry_signatures={'full':'5503ad3fddc1d2a6b8b43fbad62800ada648a2217605dc56d994ea099b5c82e7','simple':'08fa3912027f0245c609acfea97662b94077f5b5175d2fd1073a641c84cb448c'},
            shader_normalized_sha256='9be740414ed505547513a5830e9f0856fbe6d89bfaee6156aabf1fe13db5d609',
            retained_failures=[
                'First focused headless fixture converted an unset shader default to int; fixed fixture, original attempt retained.',
                'First staged teardown revealed a freed typed-node argument guard; changed only the guard to validate Variant before access.',
                'Initial cache accounting counted shared resources repeatedly and rejected large authored texture families; final admission deduplicates resources with explicit estimates and bounds.',
                'Largest Winter family can evict cache members. Tests require reuse of every admitted node; the all-node identity assertion remains when the whole family fits.',
                'Original dynamic fixture has ten resource parity failures against obsolete October 14 SandDust. Exact task-start/current source hash matches prior audit. Only the fixture input is adapted in evidence; assertions and original readiness deadline remain.',
                'Source-isolated task-start full native dynamic control reproduces 466 checks / 13 failures. Original full failures and partial-readiness canvas error remain.',
                'Two graphical fixtures were initially invoked headless; only exact private command-line-verified owned processes were stopped. Native reruns preserve assertions.',
                'Concurrent JumpProfiles class registration and an undefined PopupStyle reference caused early parser failures. Owner-corrected unowned source was copied only into private frozen snapshots.',
                'First headless preloader run has a dummy texture initialization error with 399 assertions passing; later isolated retry retained separately.',
                'Pinned root import returned zero with locked editor-reload DLL copy errors, isolated Android SDK settings and root certificate warning. No owner process/native binary was changed to bypass it.',
                'All runtime runs report the sandbox root-certificate-store warning. It is not suppressed or reclassified as a clean engine/release result.'
            ],
            scope_preservation={'root_git_staging_commit_merge_reset':False,'owner_process_restart':False,'production_asset_rebake':False,'physics_or_backend_change':False,
                                'note':'Task-only App/EditorMemory candidates use only explicit task hunks. Concurrent editor, jump, terms, model/template and other work is preserved and excluded.'},
            remaining=['Client reload','Cold native/driver first-use work (runtime item 4)','Owner visual/input acceptance','Target Android PSS/frame/first-use/thermal acceptance'],
            not_performed=['Device attachment query or physical-device test','APK/AAB build/install','Real provider sign-in/purchase','Backend/player mutation or deployment','Complete client/backend suite'])
write_json(OUT/'report.json',report)
hashes=[]
for path in sorted(OUT.rglob('*')):
    if path.is_file() and path.name!='artifact-hashes.json':hashes.append({'path':path.relative_to(OUT).as_posix(),'bytes':path.stat().st_size,'sha256':sha(path)})
write_json(OUT/'artifact-hashes.json',hashes)
print(json.dumps({'artifacts':len(hashes),'bytes':sum(row['bytes'] for row in hashes),'executions':len(executions),'final_profile':accepted is not None},indent=2))
