import pathlib,json,shutil,hashlib,zipfile,re
ROOT=pathlib.Path(__file__).resolve().parents[2];TASK=pathlib.Path(__file__).resolve().parent;DEST=ROOT/'docs/evidence/device-performance-race-work-2026-10-27';MIRROR=TASK/'android-workspace'
DEST.mkdir(parents=True,exist_ok=True)
def copy(relative,target=None):
 s=TASK/relative
 if s.is_file():
  t=DEST/(target or relative);t.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(s,t)
for case in ['optional-headless','optional-compatibility','optional-mobile','loading-compatibility','effects-compatibility','final-optional-headless']:
 for name in ['result.json','observations.json','stdout.log','stderr.log']:copy(case+'/'+name,'desktop/'+case+'/'+name)
for name in ['focused-gl_compatibility-Windows.json','app-effects-gl_compatibility.json','probe-desktop-smoke.log','probe-desktop-smoke.json']:copy(name,'desktop/'+name)
for name in ['task-start-sha256.json','task-start-sources.zip','source-reconciliation.json','app-concurrent.diff','garage_preloader-concurrent.diff','preloader-mirror-current.diff','android-build-context.json','device-availability.json','device-lock-recheck.json','probe-check.log','native-garage-bake.log','android-release-export.log','android-release-export-result.json','android-release-export-v1.log','android-release-export-result-v1.json','android-release-export-attempt1-ownership.log','android-release-export-attempt1-result.json']:copy(name,'setup/'+name)
for folder in TASK.glob('device-*'):
 if folder.is_dir():
  for source in folder.iterdir():
   if source.is_file() and source.suffix in ['.json','.jsonl','.log','.txt','.png']:copy(str(source.relative_to(TASK)),'device/'+folder.name+'/'+source.name)
for name in ['device_run.py','build_release.py','run_final_race_check.py','collect_evidence.py']:copy(name,'sources/'+name)
for name in ['device_performance_probe.gd','device_performance_probe.tscn']:
 t=DEST/'sources'/name;t.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(MIRROR/'game/diagnostics'/name,t)
paths=json.loads((TASK/'task-start-sha256.json').read_text())
source_report={}
for name,start in paths.items():
 m=MIRROR/name;current=ROOT/name
 source_report[name]={'task_start_sha256':start,'current_sha256':hashlib.sha256(current.read_bytes()).hexdigest(),'android_mirror_sha256':hashlib.sha256(m.read_bytes()).hexdigest()}
(DEST/'source-reconciliation.json').write_text(json.dumps(source_report,indent=2))
with zipfile.ZipFile(DEST/'runtime-inputs.zip','w',zipfile.ZIP_DEFLATED) as archive:
 for name in list(paths)+['game/vehicle/effect_preparation_pool.gd','game/vehicle/skid_trails.gdshader','game/project.godot','game/export_presets.cfg','game/core/build_identity.gd','game/resources/perf/star.json']:
  if (MIRROR/name).exists():archive.write(MIRROR/name,name)
app_functions={}
for name in ['_background_work_allowed','_wake_optional_work']:
 def function(text):
  match=re.search(r'^func '+re.escape(name)+r'\([^\n]*[\s\S]*?(?=^func |\Z)',text,re.M);return match.group(0).strip() if match else ''
 a=function((ROOT/'game/core/app.gd').read_text(encoding='utf-8'));b=function((MIRROR/'game/core/app.gd').read_text(encoding='utf-8'));app_functions[name]={'same':a==b,'current_sha256':hashlib.sha256(a.encode()).hexdigest(),'mirror_sha256':hashlib.sha256(b.encode()).hexdigest()}
report={'schema':1,'date':'2026-10-27','task':'Finish device performance and four small race-work findings','status':'four findings verified; physical performance awaiting secure tablet unlock','new_production_runtime_edits_by_this_task':False,'runtime_fixes':'Already present in shared working tree at task start; see docs/RACE_OPTIONAL_WORK_FIXES_2026_10_27.md and its scoped patch','requirements':{'RW01':'defer new optional snapshot dispatch; permit admitted atomic completion','RW02':'hold completed header image publication/readback until eligible; revalidate ownership/appearance','RW03':'construct presentation key only when paused','RW04':'sleep empty preloader after reaping outstanding reads; explicit wake','DP01':'separate offline release Android package and own data','DP02':'actual Android frame/presentation, loading and memory/thermal evidence; pending unlock','Q01':'preserve visual/canonical behavior and report evidence limits'},'desktop':[],'android':{'package':'org.beatmytrack.perf.r20261027a','mode':'release template with task-only signing key; no production signing credentials','model':'OPD2403','sdk':35,'gpu_seen_at_engine_start':'Qualcomm Adreno 750','physical_pixels':[2120,3000],'performance_cases_completed':0,'blocker':'Android keyguard showing=true secure=true; no credential entered','launch_only_attempt':'device/device-first-v2; runner stopped only its own package after log stream ended; no engine crash inferred','expected_case_count':17,'surface_flinger':'Timing-only mode collects own SurfaceView actual-present timestamps','instrumentation_boundary':'First pass includes screenshots/PSS diagnostics; second pass excludes them and collects presentation timestamps','installed_game_and_data_modified':False},'app_function_equivalence':app_functions,'limitations':['No Android frame-rate, load-time, memory plateau or touch acceptance yet','Desktop native Mobile means Vulkan on Windows, not Android','Root app/menu/editor sources changed concurrently; frozen APK sources are archived; relevant App policy/wake bodies compared independently','Existing sandbox root certificate initialization errors are retained','Desktop timing under concurrent workstation activity is diagnostic and is not device performance','Probe uses diagnostic route input at bounded speed; it is not a full-speed stress or physical-touch acceptance suite','Optional snapshot/header/pause/preloader fixes are functional work removal; no measured bill/FPS saving is inferred'],'initial_failures':['Sandbox ADB could not create root .android; scoped elevated SDK calls used','Isolated Garage preview provenance was stale; native bake refreshed only copied project','First export stopped on copied-repo ownership; exact process-scoped safe.directory allowed retry','First device preflight treated absent pm path exit code as error; corrected with explicit empty result','First installed launch ran behind secure lock; live capture ended early; normal keyguard dismissal preserved secure lock','Runner now checks lock before install/launch, captures logcat stderr and reconnects boundedly; incomplete case sets fail']}
for case in ['optional-headless','optional-compatibility','optional-mobile','loading-compatibility','effects-compatibility','final-optional-headless']:
 result=json.loads((TASK/case/'result.json').read_text());row={'case':case,'exit':result['exit'],'seconds':result.get('seconds')}
 obs=TASK/case/'observations.json'
 if obs.exists():
  d=json.loads(obs.read_text());row.update(checks=d.get('checks'),failures=d.get('failures'),natural_window=d.get('observations',{}).get('natural_window'))
 report['desktop'].append(row)
report['loading_regression']={'focused_checks':744,'focused_failures':0,'real_app_effect_checks':114,'real_app_effect_failures':0,'assertions':'exact grid/mesh and immutable shader identity; all 20 particles; covered sequential prepare; frozen tick/countdown/trail ring; all cars/themes; cancellation/selection/scope/pressure/reuse/teardown'}
apk=MIRROR/'build/android/circuit01-debug.apk'
if apk.exists():report['android']['prepared_apk_sha256']=hashlib.sha256(apk.read_bytes()).hexdigest();report['android']['prepared_apk_bytes']=apk.stat().st_size
(DEST/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
hashes={str(p.relative_to(DEST)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in DEST.rglob('*') if p.is_file() and p.name not in ['hashes.json','checkpoint.patch','checkpoint-verification.json']}
(DEST/'hashes.json').write_text(json.dumps(hashes,indent=2));print(json.dumps({'files':len(hashes),'output':str(DEST),'app_equivalence':app_functions},indent=2))
