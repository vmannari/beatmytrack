import pathlib,json,hashlib,zipfile,shutil,re,difflib
ROOT=pathlib.Path(__file__).resolve().parents[2];TASK=pathlib.Path(__file__).resolve().parent;DEST=ROOT/'docs/evidence/device-performance-race-work-2026-10-27';MIRROR=TASK/'android-workspace'
DEST.mkdir(parents=True,exist_ok=True)
shutil.copy2(TASK/'device-cleanup.json',DEST/'device/cleanup.json')
clean_dir=TASK/'device-acceptance-full-v8-retry';memory_dir=TASK/'device-acceptance-instrumented-v8';garage_dir=TASK/'device-acceptance-garage-memory-v8'
clean=json.loads((clean_dir/'report.json').read_text());memory=json.loads((memory_dir/'report.json').read_text());garage=json.loads((garage_dir/'report.json').read_text())
assert all(not x['errors'] and x['debug_build']==False for x in [clean,memory,garage])
assert len(clean['cases'])==17 and len(memory['cases'])==17 and len(garage['cases'])==5
sf=json.loads((clean_dir/'surface-presentation.json').read_text());assert len(sf)==8
assert all(x['over34']==0 for x in sf)
for report in [clean,memory]:
 for row in report['cases']:
  if row['phase'].startswith('drive_'):assert row['contacts']==0 and row['meters']>=30
  if row['phase'].startswith('load_'):assert row['frozen_tick']==0 and row['countdown']==360
  if row['phase'].startswith('garage'):assert row['ready']==True
for row in garage['cases']:
 if row['phase'].startswith('garage'):assert row['ready']==True
receipts=[json.loads((x/'receipt.json').read_text()) for x in [clean_dir,memory_dir,garage_dir]]
assert len(set(x['apk_sha256'] for x in receipts))==1
for x in receipts:assert x['finished_marker'] and x['decoded_report'] and x['logcat_reconnects']==0

def copy(source,target):
 s=TASK/source;t=DEST/target;t.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(s,t)
for folder in [clean_dir,memory_dir,garage_dir]:
 for name in ['report.json','receipt.json','commands.json','surface-presentation.json','surface-raw.jsonl','android-memory.txt','cases.jsonl','probe-logcat.txt','logcat-stderr.txt','apk-badging.txt']:
  if (folder/name).exists():copy(str((folder/name).relative_to(TASK)),'device/'+folder.name+'/'+name)
for name in ['garage_first_visit.png','garage_first_visit_orbit.png','garage_repeat_orbit.png']:
 source=garage_dir/name
 if source.exists():copy(str(source.relative_to(TASK)),'captures/'+name)
for name in ['build_release.py','device_run.py','run_final_race_check.py','run_wiring_checks.py','finish_evidence.py']:
 copy(name,'sources/'+name)
for name in ['device_performance_probe.gd','device_performance_probe.tscn']:
 t=DEST/'sources'/name;t.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(MIRROR/'game/diagnostics'/name,t)
for name in ['frozen-runtime-sources.zip','frozen-client-file-hashes.json','current-runtime-source-differences.json','garage-wiring-effective-before.zip','garage-wiring-before-sha256.json','task-start-sources.zip','task-start-sha256.json','cold-opening-test-before-loading-guard.gd','race-optional-test-before-ready-fixture.gd','device-awake-lease.json','android-build-context.json','android-release-export-result.json','scope-eol-reconciliation.json','owned-test-processes-after.json']:
 copy(name,'provenance/'+name)
# Preserve failed attempts and fresh desktop logs without duplicating large screenshots.
with zipfile.ZipFile(DEST/'attempts-and-desktop-raw.zip','w',zipfile.ZIP_DEFLATED) as archive:
 for f in TASK.rglob('*'):
  if not f.is_file():continue
  relative=f.relative_to(TASK)
  if relative.parts[0] in ['android-workspace','android-appdata','adb-user','probe-smoke-appdata']:continue
  if any(x in relative.parts for x in ['appdata','__pycache__']) or any(x.startswith('checkpoint') for x in relative.parts):continue
  if f.suffix.lower() not in ['.json','.jsonl','.log','.txt','.diff']:continue
  if relative.parts[0].startswith('device-acceptance-') and relative.parts[0] in [clean_dir.name,memory_dir.name,garage_dir.name]:continue
  archive.write(f,relative.as_posix())
for case in ['accepted-optional-headless','accepted-optional-mobile','wiring-cold-compatibility-final','wiring-app-headless-final','final-current-effects']:
 for name in ['result.json','observations.json','stdout.log','stderr.log','app-effects-gl_compatibility.json']:
  if (TASK/case/name).exists():copy(case+'/'+name,'desktop/'+case+'/'+name)

cases={x['phase']:x for x in clean['cases']}
pss=[]
for directory in [memory_dir,garage_dir]:
 text=(directory/'android-memory.txt').read_text();pss.extend({'run':directory.name,'kib':int(value)} for value in re.findall(r'TOTAL PSS:\s*(\d+)',text))
app_equivalence={}
for name in ['_background_work_allowed','_wake_optional_work','_garage']:
 def get_function(source):
  m=re.search(r'^func '+re.escape(name)+r'\([^\n]*[\s\S]*?(?=^func |\Z)',source,re.M);return m.group(0).strip() if m else ''
 a=get_function((ROOT/'game/core/app.gd').read_text(encoding='utf-8'));b=get_function((MIRROR/'game/core/app.gd').read_text(encoding='utf-8'));app_equivalence[name]={'same':a==b,'root_sha256':hashlib.sha256(a.encode()).hexdigest(),'frozen_sha256':hashlib.sha256(b.encode()).hexdigest()}
assert all(v['same'] for v in app_equivalence.values())
critical_paths=['game/core/game.gd','game/ui/header_car_appearance_cache.gd','game/backend/menu_snapshot_writer.gd','game/ui/garage_preloader.gd']
critical={name:{'current':hashlib.sha256((ROOT/name).read_bytes()).hexdigest(),'frozen':hashlib.sha256((MIRROR/name).read_bytes()).hexdigest()} for name in critical_paths}
assert all(value['current']==value['frozen'] for value in critical.values())
(DEST/'provenance/final-policy-source-comparison.json').write_text(json.dumps(critical,indent=2))
scope_paths=['game/core/app.gd','game/tests/test_garage_cold_opening.gd','game/tests/test_race_optional_work.gd']
report={'schema':2,'date':'2026-10-27','status':'scoped fixes and selected-device validation completed; limits retained','requirements':{'RW01':'new optional snapshot dispatch sleeps while race policy closes; admitted atomic writes finish','RW02':'completed header image publication/readback waits and revalidates scope/appearance','RW03':'pause key constructed only during pause','RW04':'empty preloader sleeps after outstanding reads are reaped; explicit wake','DP01':'isolated offline release Android package, pinned engine/templates and task-only key','DP02':'actual presentation/frame and memory/thermal observations','DP03':'restore staged cold-Garage integration with original finishes/reflections','DP04':'race-loading policy blocks optional studio admission','R01':'retain ownership/cancellation/canonical state and existing assertions','Q01':'separate frozen-device, current-root, timing, instrumentation and cache states'},'scope':{'production_edit':'game/core/app.gd: two admission/integration lines in _garage','eol_reconciliation':'Original LF restored on App and regression fixture; normalized text identical to passing tests; provenance/scope-eol-reconciliation.json','tests_edited':scope_paths[1:],'four_findings':'already fixed in task-start shared tree; implementation in docs/RACE_OPTIONAL_WORK_FIXES_2026_10_27.md; freshly verified here','concurrent_changes':'preserved and excluded from the scoped patch; device snapshot is archived, not a whole-current-tree release claim','app_function_equivalence':app_equivalence,'critical_policy_comparison':'provenance/final-policy-source-comparison.json'},'desktop_final':{'race_work_headless':{'checks':86,'failures':0},'race_work_vulkan_mobile_windows':{'checks':86,'failures':0},'cold_garage_native_compatibility':{'checks':208,'failures':0,'dispatch_ms':73.351,'first_picture_ms':505.989},'app':{'checks':141,'failures':0},'loading_shaders_geometry_initial':{'checks':744,'failures':0},'real_app_effects_final_current_sources':{'checks':114,'failures':0}},'android':{'package':'org.beatmytrack.perf.r20261027a','engine':clean['engine'],'debug_build':clean['debug_build'],'renderer':clean['renderer'],'adapter':clean['adapter'],'model':clean['model'],'screen_hz':clean['screen_hz'],'engine_max_fps':clean['engine_max_fps'],'physical_display':[3000,2120],'physics':clean['physics'],'rules':clean['rules'],'clean_cases':17,'instrumented_cases':17,'garage_memory_cases':5,'apk_sha256':receipts[0]['apk_sha256'],'clean_receipt':'device/'+clean_dir.name+'/receipt.json','memory_receipt':'device/'+memory_dir.name+'/receipt.json','garage_receipt':'device/'+garage_dir.name+'/receipt.json','clean_surface_windows':sf,'clean_driving_seconds':sum(x['wall_ms'] for x in clean['cases'] if x['phase'].startswith('drive_'))/1000,'clean_driving_contacts':sum(x['contacts'] for x in clean['cases'] if x['phase'].startswith('drive_')),'garage_first_visit':cases['garage_first_visit'],'garage_repeat':cases['garage_repeat'],'clean_loads':[x for x in clean['cases'] if x['phase'].startswith('load_')],'pss_samples':pss,'largest_pss_sample_mib':max(x['kib'] for x in pss)/1024,'endpoint_thermal_and_battery':[{'run':p.name,'before':r['before'],'after':r['after']} for p,r in zip([clean_dir,memory_dir,garage_dir],receipts)],'reset_attempt':'optional pm clear of this test package denied by Android; final tests use existing private probe data and shader caches; no bypass','cleanup_receipt':'device/cleanup.json','cleanup':json.loads((TASK/'device-cleanup.json').read_text())},'limitations':['One high-end tablet in its current 50 Hz mode; not a 60 FPS/all-device guarantee','Frozen source/model inputs are archived; later concurrent v14 model/editor/render changes are not physically accepted by this run','Six bounded diagnostic drives (no completed five-lap race) and two live Garage orbits; no maximum-speed/large particle-burst or physical-touch-latency claim','App scene initialization is not whole launch-to-interactive latency; am start timing is not game readiness','Fixture compilation is separately timed and its latency is retained; App entry receives the ordinary already compiled NativeTrack','Final runs use existing probe data/caches; first-install diagnostic Star 39.487 s / 2.260 s max frame remains historical and is not a matched comparison','Cold/preparation frames still exceed the display budget, including 645.646 ms during Garage preparation in the clean run; navigation improvement is not a hitch-free loading claim','Android PSS samples may miss instantaneous peaks and do not establish a leak plateau or low-memory-device budget','Thermal status/battery temperature are sampled endpoints; USB charging, no measured battery-energy or sustained-throttling certification','Engine process/physics monitors are delayed/overlapping observations, not direct GPU or additive CPU timings','No new backend deployment, real auth/purchase, player export, owner-save mutation, owner-process restart or main-index staging/commit/merge'], 'initial_failures':['Sandbox ADB root .android creation failed; scoped elevated SDK calls worked','Stale isolated Garage previews rebaked natively; provenance assertion retained','Copied-repo Git ownership check fixed with process-scoped exact-directory safe.directory','Absent-package pm path exit handling corrected','Secure keyguard initially blocked capture; owner unlocked tablet, no credential entered','Initial legacy-ellipse controller hit barriers; production Freight routes preflighted and final drives have zero contacts','Initial bool(null) readiness conversion invalid; typed optional-property handling replaces it; false Garage timeouts are not performance results','Initial Android stdout chunks truncated at 1024 bytes; 700-character chunks and full report decoding validated','Android 15 decorated SurfaceFlinger layer name unwrapped; no missing presentation data accepted','Optional stay-awake setting and test-app-data reset denied by Android; neither permission was bypassed','First post-wiring race fixture saw four disabled viewports while cold preparation was pending; setup now waits for the completed studio, retaining the original strict three-viewport assertion'],'checkpoint':{'patch':'checkpoint.patch','verification':'checkpoint-verification.json','main_index_touched':False}}
(DEST/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
(DEST/'acceptance-validation.json').write_text(json.dumps({'passed':True,'reports':[17,17,5],'same_release_apk':True,'clean_sampled_present_frames':sum(x['frames'] for x in sf),'clean_sampled_max_present_gap_ms':max(x['max_ms'] for x in sf),'clean_sampled_present_gaps_over34':sum(x['over34'] for x in sf),'critical_app_function_equivalence':app_equivalence},indent=2))
hashes={p.relative_to(DEST).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in DEST.rglob('*') if p.is_file() and p.name not in ['hashes.json','checkpoint.patch','checkpoint-verification.json']}
(DEST/'hashes.json').write_text(json.dumps(hashes,indent=2));print(json.dumps({'evidence':str(DEST),'hashed_files':len(hashes),'largest_pss_sample_mib':report['android']['largest_pss_sample_mib'],'present_frames':sum(x['frames'] for x in sf)},indent=2))
