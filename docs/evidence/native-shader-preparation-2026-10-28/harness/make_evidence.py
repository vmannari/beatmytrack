from datetime import datetime,timezone
from pathlib import Path
import hashlib,json,re,shutil,zipfile

LAB=Path(__file__).resolve().parent;ROOT=LAB.parent.parent
DEST=ROOT/'docs/evidence/native-shader-preparation-2026-10-28';DEST.mkdir(parents=True,exist_ok=True)
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def copy(path,target):
    to=DEST/target;to.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,to)

runtime=['game/ui/garage_preloaded_studio.gd','game/vehicle/compact_detail.gd','game/vehicle/compact_rear_design.gd']
regressions=['game/tests/test_garage_warm_scheduling.gd','game/tests/test_compact_rear_preparation.gd']
receipts=[]
for path in sorted(LAB.glob('*-execution.json')):
    receipt=read(path);receipt['receipt_file']=path.name
    receipts.append(receipt)
    copy(path,Path('runs')/path.name)
for path in sorted(LAB.glob('*.log')):copy(path,Path('runs')/path.name)
for path in sorted((LAB/'checks').glob('*.gd')):copy(path,Path('executed-fixtures')/path.name)
for pattern in ['*.py','*.hpp','*.cpp','*.gd','*.gdextension','*.ps1']:
    for path in sorted(LAB.glob(pattern)):copy(path,Path('harness')/path.name)
for name in ['program-analysis.json','program-pixels.json','final-bridge-pixels.json','scheduling-pixels.json','source-start.json']:
    copy(LAB/name,name)
for path in sorted((LAB/'outputs').rglob('*')):
    if path.is_file() and path.suffix in ['.json','.png']:copy(path,Path('test-output')/path.relative_to(LAB/'outputs'))
for path in sorted((LAB/'programs').glob('*/*')):
    if path.parent.name.startswith('binaries-') or path.parent.name.startswith('bootstrap-') or path.parent.name.startswith('jobs'):continue
    if path.is_file() and path.suffix in ['.json','.png','.log']:copy(path,Path('native-cases')/path.relative_to(LAB/'programs'))
for path in sorted((LAB/'race-trace').iterdir()):
    if path.is_file():copy(path,Path('race-trace')/path.name)
for name in runtime:
    copy(LAB/'before'/name,Path('before')/name)
for path in (LAB/'generated-before').rglob('*'):
    if path.is_file():copy(path,Path('generated-before')/path.relative_to(LAB/'generated-before'))
copy(LAB/'programs/context-migration.json','context-migration.json')

zip_path=DEST/'captured-program-jobs.zip'
with zipfile.ZipFile(zip_path,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
    for path in sorted((LAB/'programs/jobs-context').glob('*.job')):archive.write(path,path.name)
jobs=[dict(name=p.name,bytes=p.stat().st_size,sha256=sha(p)) for p in sorted((LAB/'programs/jobs-context').glob('*.job'))]
assert len(jobs)==192 and all(p['sha256']==p['name'].removesuffix('.job') for p in jobs)

programs=read(LAB/'program-analysis.json')
matched=next(p for p in programs if p['label']=='import-context-input')
assert matched['native']['imports']==192 and matched['native']['misses']==0
assert matched['input']['posts']==matched['input']['responses']==263 and matched['input']['pairing_valid']
assert read(LAB/'program-pixels.json')['changed_pixels']==0
attribution=read(LAB/'race-trace/attribution.json')
assert attribution['largest_frames'][0]['native_covered_percent']>98
selected={
    'scheduling-headless-final':('GARAGE_WARM_SCHEDULING',16),
    'scheduling-native-final':('GARAGE_WARM_SCHEDULING',16),
    'rear-fixed':('COMPACT_REAR_PREPARATION',14),
    'rear-compatibility':('COMPACT_REAR_PREPARATION',14),
    'cooperative-models':('COOPERATIVE_CAR_MODEL',21),
    'cooperative-install':('COOPERATIVE_RACE_INSTALL',1598),
    'app-final':('APP_TESTS',141),
    'parser':('SCRIPT_PARSE',1359),
    'preload-lifecycle-final':('GARAGE_PRELOAD',400),
    'prepared-native-effective':('GARAGE_PREPARED_CARS',28),
}
verified={}
for label,(marker,count) in selected.items():
    receipt=read(LAB/(label+'-execution.json'));log=(LAB/(label+'.log')).read_text(encoding='utf-8',errors='replace')
    assert receipt['exit']==0 and marker in log,(label,receipt)
    if marker=='GARAGE_WARM_SCHEDULING':assert f'"checks":{count}' in log and '"failures":0' in log
    else:assert re.search(rf'{marker}.*{count} (checks|scripts), 0 failures',log),label
    verified[label]=dict(checks=count,mode='headless' if '--headless' in receipt['command'] else 'Compatibility',
        evidence_adapter=receipt.get('await_existing_progressive_entry',False) or receipt.get('effective_shader_defaults',False),exit=receipt['exit'])
assert read(LAB/'preferred-execution.json')['exit']==0
assert read(LAB/'scheduling-original-final-execution.json')['exit']==1
assert read(LAB/'prepared-wrong-glass-execution.json')['exit']==1
assert '28 checks, 2 failures' in (LAB/'prepared-wrong-glass.log').read_text()

worker_full=read(LAB/'programs/binaries-import-context-1/worker-result.json')
source_hashes={n:dict(before=sha(LAB/'before'/n),after=sha(ROOT/n)) for n in runtime}
before_rear=(LAB/'before/game/vehicle/compact_rear_design.gd').read_text()
after_rear=(ROOT/'game/vehicle/compact_rear_design.gd').read_text()
assert before_rear[before_rear.index('static func _lamps'):]==after_rear[after_rear.index('static func _lamps'):]
assets=[dict(path=str(p.relative_to(ROOT)).replace('\\','/'),sha256=sha(p),bytes=p.stat().st_size)
    for p in sorted((ROOT/'game/assets/garage/cars_v1').glob('*.scn'))]
report=dict(
    date='2026-10-28',generated_utc=datetime.now(timezone.utc).isoformat(),
    task='Proceed with the approved runtime item4 improvement plan, respecting native proof gates',
    requirements=['NSP01','NSP02','NSP03','NSP04','NSP05','R01','Q01'],
    disposition='Safe GDScript scheduling changes implemented; native process architecture remains evidence-only because first-draw and memory gates fail',
    changed_runtime_files=runtime,new_regression_files=regressions,source_hashes=source_hashes,
    rear_geometry_helper_sources_exact_after_line_ending_normalization=True,
    cpu=dict(initial_rear_slice_us=50945,instrumented_control_max_us=61512,fixed_full_car_max_slice_us=16483,fixed_simple_snapshot_us=17036,
        caveat='Desktop headless observations, not a paired benchmark or hard frame budget.'),
    selected_validation=verified,preferred_validation=read(LAB/'preferred-execution.json'),
    all_test_receipts=receipts,program_controls=programs,
    full_compile_worker=worker_full,
    worker_report_provenance='Full-compile control import-context-1 is preserved. The input control binary directory was reused later, overwriting its aggregate worker report; original per-job stdout peaks are retained and analyzed. Future harness versions copy per-case worker reports.',
    exact_native_picture_control=read(LAB/'program-pixels.json'),combined_tree_picture_control=read(LAB/'final-bridge-pixels.json'),
    callback_picture_control=read(LAB/'scheduling-pixels.json'),race_attribution=attribution,
    captured_program_jobs=dict(count=len(jobs),uncompressed_bytes=sum(j['bytes'] for j in jobs),
        archive=zip_path.name,archive_sha256=sha(zip_path),records=jobs),
    generated_native_resources=dict(command='python build/native-shader-preparation-2026-10-28/run_checks.py bake-templates-latest tests/bake_garage_cars.gd gl_compatibility --seed-cache',
        assets=assets,source_checkpoint_includes_assets=False,
        reason='Generated derivatives include concurrent Electric authors; source-only checkpoint avoids claiming or reverting that geometry. Re-bake against the intended current author context.'),
    implementation_gates=dict(callback_fix=True,rear_construction_fix=True,desktop_program_import=True,desktop_picture_proof=True,
        queued_input_probe=True,first_draw_frame_budget=False,total_optional_memory_budget=False,
        supported_engine_api_implemented=False,production_native_service_enabled=False,android_tested=False),
    remaining_native_work=[
        'Warm exact first-draw state in the worker; linking alone leaves state-dependent driver work.',
        'Bound compiler workspace within the96MiB total optional budget; Windows full-compile peak162.027MiB already exceeds it.',
        'Move all source/hash/file processing away from the render thread and install at most one ready program per permitted frame.',
        'Only after native gates pass, implement a supported source-built engine API and integrate complete Garage/race readiness/lifecycle.',
        'Validate target Android context/binaries, lifecycle, input, graphics memory and combined PSS; do not infer from desktop.'
    ],
    retained_findings=[
        'Exact original studio regression16/5 and original rear regression14/6 are retained.',
        'Initial native imports192/192 rejected because context flags differ; full fingerprint and forward-compatible worker correct it.',
        'The Windows PostMessage probe gets no acknowledgements. Private loopback-to-Viewport input supersedes it; no physical-input claim.',
        'The first capture continuously posts inputs and correctly prevents idle warming; pulses stopped in that diagnostic control. Corrected capture separates phases.',
        'Initial headless carousel fixture wrongly expects a native texture; dummy/native contract is made explicit in the new regression.',
        'Unmodified prepared-finish controls retain4 failures (unset vs serialized declared defaults), reproduced under original builders. Native effective-default comparison28/0; wrong-glass control28/2; dummy effective comparison28/2.',
        'Initial asynchronous fallback test reads a nil car; bounded real readiness and asset-lifetime observations retain all400 assertions.',
        'Two old failed fixture children time out240s; later runner detects SCRIPT ERROR and stops only its own child promptly.',
        'Stale baseline author assertions and current7-template cache misses trace concurrent Electric source change1d05f7e9 to72040e49; author changes preserved.',
        'Initial missing shader path, path globalization and shell-quoting attempts retained; no production data changes from failed probes.',
        'Windows CIM query is denied and stops no process; no escalation or foreign process action.',
        'Sandbox root-certificate-store errors remain; deliberate cooperative-install deadline warning is expected.'
    ],
    concurrent_context=dict(App_account_layout_changed=True,Electric_coachwork_changed=True,
        native_metadata_author_mismatch_receipt='runs/inspect-templates.log',immutable_whole_tree=False),
    checkpoint=dict(kind='Source-only task checkpoint',patch='build/native-shader-preparation-2026-10-28/task-only.patch',
        verification='build/native-shader-preparation-2026-10-28/checkpoint-verification.json',main_index_touched=False),
    boundaries=dict(physical_device_attachment_query_or_test=False,apk_aab=False,real_auth_purchase=False,
        owner_save_or_live_backend_mutation=False,deployment=False,owner_process_restart=False,
        main_index_staging_commit_merge=False,installed_engine_modified=False,production_renderer_changed=False),
    toolchain=dict(engine='4.7.2.stable.official.ed1daf0bf',engine_sha256='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424',
        compiler='g++.exe (Rev10, Built by MSYS2 project)12.2.0'),
    compiler_commands=[
        'C:/msys64/mingw64/bin/g++.exe build/native-shader-preparation-2026-10-28/program_probe.cpp -I .tools/godot-cpp-music/gdextension -std=c++17 -O2 -shared -static -lopengl32 -lbcrypt -lpsapi -o build/native-shader-preparation-2026-10-28/program_probe.dll',
        'C:/msys64/mingw64/bin/g++.exe build/native-shader-preparation-2026-10-28/shader_worker.cpp -std=c++17 -O2 -static -lopengl32 -lgdi32 -lbcrypt -lpsapi -o build/native-shader-preparation-2026-10-28/shader_worker.exe'],
)
(DEST/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
notice=(ROOT/'docs/evidence/cold-render-investigation-2026-10-27/generated-glsl/GODOT_NOTICE.txt')
copy(notice,'GODOT_NOTICE.txt')
manifest={str(p.relative_to(DEST)).replace('\\','/'):dict(bytes=p.stat().st_size,sha256=sha(p)) for p in sorted(DEST.rglob('*')) if p.is_file() and p.name!='checksums.json'}
(DEST/'checksums.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(dict(files=len(manifest),bytes=sum(v['bytes'] for v in manifest.values()),validation=verified,
    native_gates=report['implementation_gates']),indent=2))
