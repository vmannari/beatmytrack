from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil

LAB=Path(__file__).resolve().parent
ROOT=LAB.parent.parent
DEST=ROOT/'docs/evidence/cold-render-investigation-2026-10-27'
DEST.mkdir(parents=True,exist_ok=True)

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def copy(path,relative):
    target=DEST/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(path,target)

analysis=read(LAB/'analysis.json')
assert len(analysis['cases'])==11
assert [(c['label'],c['failures']) for c in analysis['cases'] if c['failures']]==[('app-original',1)]
assert analysis['race']['checks']==60 and analysis['race']['failures']==0 and len(analysis['race']['loads'])==12
pixels=read(LAB/'pixel-comparison.json')
assert len(pixels)==6 and all(x['changed_pixels']==0 for x in pixels if x['label']!='mobile-original')
process=read(LAB/'process-bench-results.json')
assert len(process['records'])==7 and all(x['exit']==0 and x['result']['success'] for x in process['records'])
link=read(LAB/'link-bench-results-v2.json')
assert len(link['records'])==6 and all(x['exit']==0 and x['result']['success'] for x in link['records'])
for n in ['1','2']:
    heartbeat=next(x for x in process['records'] if x['label']=='process-compiler-'+n)
    for action in ['save','load']:
        operation=next(x for x in process['records'] if x['label']=='process-compiler-'+n+'-'+action)
        assert heartbeat['utc_ready_us']<=operation['utc_begin_us']<operation['utc_end_us']<=heartbeat['utc_end_us']
executions=[read(p) for p in sorted(LAB.glob('*-execution.json'))]
assert all(x['exit']==0 for x in executions if x.get('variant')!='trace_link' and x.get('scope')!='app' and x.get('renderer')!='mobile')
assert read(LAB/'mobile-original-execution.json')['exit']=='timeout'
assert read(LAB/'api-source-static-execution.json')['exit']==0
assert read(LAB/'api-source-execution.json')['exit']==1

for path in sorted(LAB.glob('*.log')):
    copy(path,Path('runs')/path.name)
for path in sorted(LAB.glob('*-execution.json')):
    copy(path,Path('runs')/path.name)
for path in sorted(LAB.glob('*-pid.json')):
    copy(path,Path('runs')/path.name)
for path in sorted(LAB.glob('*-native.jsonl')):
    copy(path,Path('native')/path.name)
for path in sorted((LAB/'frozen-original').rglob('*')):
    if path.is_file():copy(path,Path('source-start')/path.relative_to(LAB/'frozen-original'))
for path in sorted((LAB/'results').glob('*/report.json')):
    copy(path,Path('cases')/path.parent.name/path.name)
    copy(path.parent/'studio.png',Path('cases')/path.parent.name/'studio.png')
for name in ['app-original','app-reuse']:
    copy(LAB/'results'/name/'final.png',Path('cases')/name/'final.png')
for path in (LAB/'race').glob('*.json'):
    copy(path,Path('race')/path.name)
for path in (LAB/'shader-source').iterdir():
    if path.suffix in ['.vert','.frag']:copy(path,Path('generated-glsl')/path.name)
for pattern in ['*.py','*.cpp','*.gd','*.gdextension','*.ps1']:
    for path in sorted(LAB.glob(pattern)):
        copy(path,Path('harness')/path.name)
for name in ['analysis.json','source-start.json','pixel-comparison.json','gl-caps.json',
             'link-bench-results-v1.json','link-bench-results-v2.json','process-bench-results.json',
             'pinned-compile-link-disassembly.txt']:
    copy(LAB/name,name)
license_text=(ROOT/'.tools/godot-cpp-music/LICENSE.md').read_text(encoding='utf-8')
license_text=license_text.replace('Copyright (c) 2017-present Godot Engine contributors.',
    'Copyright (c) 2014-present Godot Engine contributors.\nCopyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.')
(DEST/'generated-glsl/GODOT_NOTICE.txt').write_text(
    'The captured generated shader includes Godot Engine GLSL and project material code.\n'
    'Engine: ed1daf0bf, https://github.com/godotengine/godot\n'
    'These are local diagnostic captures from the owned offline Compact Garage fixture.\n'
    'The following MIT notice applies to the Godot Engine portions.\n\n'+license_text,encoding='utf-8')

engine=Path('C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe')
engine_sha=digest(engine)
assert engine_sha=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
native_attribution=dict(
    engine_sha256=engine_sha,image_base='0x140000000',most_frequent_return_rva='0x1411778',
    most_frequent_return_va='0x141411778',call_instruction_va='0x141411776',
    glad_refptr_rva='0x7e23a20',named_entrypoint='glLinkProgram',pointer_match=True,
    direct_capture=dict(program=73,link_us=368973,vertex_bytes=33847,fragment_bytes=92852),
    caveat='Only the exact pinned executable and owned test process. No private NVIDIA symbol/function-name attribution; sampling perturbs execution.')
report=dict(
    task='Investigate runtime item 4 and plan the best improvement',
    date='2026-10-27',generated_utc=datetime.now(timezone.utc).isoformat(),
    disposition='Investigation and plan only; no authored production runtime edits',
    recommendation='First remove the asynchronous CanvasItem _draw helper collision. Lead prototype: separate-process exact GLSL compilation with bounded program-binary imports, gated on actual first-draw/UI/Android/memory results.',
    environment=dict(engine='4.7.2.stable.official.ed1daf0bf',engine_path=str(engine),engine_sha256=engine_sha,
        platform='Windows desktop',capabilities=read(LAB/'gl-caps.json'),window=[1280,720],
        app_profiles='Private APPDATA/LOCALAPPDATA below the task build directory; backend.cfg has an explicit empty URL',
        cold_definition='First engine use in a fresh owned application/cache profile. Global driver caches not cleared; not a clean-driver or physical-device claim.'),
    native_attribution=native_attribution,
    analysis=analysis,pixel_comparison=pixels,call_order_controls=link,process_controls=process,
    executions=executions,
    generated_programs=[dict(name=p.name,bytes=p.stat().st_size,sha256=digest(p),archived=p.suffix in ['.vert','.frag']) for p in (LAB/'shader-source').iterdir()],
    tool_binary_receipts=[dict(name=p.name,sha256=digest(p),bytes=p.stat().st_size) for p in LAB.iterdir() if p.suffix in ['.exe','.dll']],
    compiler_version='g++.exe (Rev10, Built by MSYS2 project) 12.2.0',
    native_harness_versions=dict(initial_call_order='harness/link_bench-v1.cpp',
        corrected_call_order='harness/link_bench-v2.cpp',process_controls='harness/link_bench.cpp'),
    compiler_reproduction_commands=[
      'C:/msys64/mingw64/bin/g++.exe build/cold-render-investigation-2026-10-27/gl_caps.cpp -std=c++17 -O2 -static -lopengl32 -lgdi32 -o build/cold-render-investigation-2026-10-27/gl_caps.exe',
      'C:/msys64/mingw64/bin/g++.exe build/cold-render-investigation-2026-10-27/sampler.cpp -std=c++17 -O2 -static -ldbghelp -o build/cold-render-investigation-2026-10-27/sampler.exe',
      'C:/msys64/mingw64/bin/g++.exe build/cold-render-investigation-2026-10-27/parallel_probe.cpp -I .tools/godot-cpp-music/gdextension -std=c++17 -O2 -shared -static -lopengl32 -o build/cold-render-investigation-2026-10-27/parallel_probe.dll',
      'C:/msys64/mingw64/bin/g++.exe build/cold-render-investigation-2026-10-27/link_bench.cpp -std=c++17 -O2 -static -lopengl32 -lgdi32 -o build/cold-render-investigation-2026-10-27/link_bench.exe'],
    inspection_commands=[
      'C:/msys64/mingw64/bin/objdump.exe -d --start-address=0x141411250 --stop-address=0x1414117b0 C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe',
      'python build/cold-render-investigation-2026-10-27/run_link_bench.py',
      'python build/cold-render-investigation-2026-10-27/run_process_bench.py',
      'python build/cold-render-investigation-2026-10-27/analyze.py',
      'powershell -NoProfile -ExecutionPolicy Bypass -File build/cold-render-investigation-2026-10-27/pixel_compare.ps1',
      'python build/cold-render-investigation-2026-10-27/make_report.py'],
    findings_retained=[
      'app-original: 15 checks / 1 fixture failure: carousel texture checked after App normally consumes it. app-reuse checks before transfer: 15/0.',
      'api-source: missing libwinpthread DLL, 10 checks / 2 failures; static DLL api-source-static: 10/0, exit0.',
      'mobile-original: all14 assertions and captures complete, but owned child times out during teardown at240s; not clean renderer acceptance.',
      'inspect-api: initial unisolated headless log rotation denied; corrected isolated profile exits normally.',
      'PowerShell local script policy initially rejects pixel helper; process-local ExecutionPolicy Bypass succeeds without persistent policy change.',
      'Initial shared-context bench used one surface; v2 uses separate surfaces and prewarms main clear/swap; both versions retained.',
      'Known sandbox root-certificate-store errors retained. Separate render-thread control logs synchronization warnings.',
      'Sampler only suspends threads of validated owned Godot children; maximum Garage suspension10309us. Later driver modules unresolved in parallel-hint/race traces.',
      'Race UTC frame list capped6000 and does not cover every load; cache stage labels do not attribute the4980ms frame.'
    ],
    limits=[
      'Exploratory interleaved desktop cases, one fixed Compact view, no statistical or normal-launch/phone/FPS claim.',
      'Seven Garage scripts reloaded from frozen sources; twelve source snapshots; concurrent App edits preserved. Race probe uses shared actual tree.',
      'Separate-process controls compile one exact GLSL program, draw clear/swap in another process and validate binary link status. No real draw using imported binary, full UI, Android, or helper-memory acceptance.',
      'Exact canonical/replay, all-car/theme and lifecycle acceptance of the proposed native architecture are future gates, not tested implementation.',
      'No production fix applied; callback rename, engine preparation API, process service and cache integration remain planned.'
    ],
    boundaries=dict(physical_device_attachment_query_or_test=False,apk_aab=False,real_auth_purchase=False,
        owner_save_or_live_service_mutation=False,deployment=False,owner_process_restart=False,
        main_index_staging_commit_merge=False,production_runtime_edits=False),
    primary_sources=[
      'https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/drivers/gles3/shader_gles3.cpp',
      'https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html',
      'https://registry.khronos.org/OpenGL/extensions/KHR/KHR_parallel_shader_compile.txt',
      'https://registry.khronos.org/OpenGL/extensions/ARB/ARB_get_program_binary.txt',
      'https://developer.android.com/guide/components/processes-and-threads'],
    evidence_validation=dict(case_count=11,original_App_fixture_failure_preserved=True,
        race_loads=12,race_checks=60,corrected_same_process_controls=6,
        process_records=7,compiler_and_import_spans_overlap_heartbeat=True,
        compared_images=6,five_Compatibility_variants_pixel_exact=True))
(DEST/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
manifest={str(p.relative_to(DEST)).replace('\\','/'):dict(bytes=p.stat().st_size,sha256=digest(p))
          for p in sorted(DEST.rglob('*')) if p.is_file() and p.name!='checksums.json'}
(DEST/'checksums.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(dict(evidence_files=len(manifest),evidence_bytes=sum(x['bytes'] for x in manifest.values()),
                     report=str(DEST/'report.json'),validation=report['evidence_validation']),indent=2))
