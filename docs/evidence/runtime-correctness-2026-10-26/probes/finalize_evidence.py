from pathlib import Path
import datetime, hashlib, json, re, shutil

ROOT = Path.cwd()
WORK = ROOT/'build/runtime-correctness-2026-10-26'
OUT = ROOT/'docs/evidence/runtime-correctness-2026-10-26'

def text(path):
    data=path.read_bytes()
    return data.decode('utf-16' if data.startswith(b'\xff\xfe') else 'utf-8-sig',errors='replace')

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def marked(name, marker):
    return [json.loads(line.split(marker,1)[1]) for line in text(WORK/name).splitlines() if line.startswith(marker)]

def matched_samples(rows):
    # Compare the same warm state, avoiding first warmup, pressure and owner switch.
    comparable=[row for row in rows if row['cycle']>=15 and row['cycle']%10 in range(5,9)]
    if not comparable: comparable=[row for row in rows if row['cycle']%10 in range(5,9)]
    if not comparable: return {}
    return {'cycles':[row['cycle'] for row in comparable],
            'ranges':{key:[min(row[key] for row in comparable),max(row[key] for row in comparable)] for key in ['nodes','resources','static_bytes']},
            'first':comparable[0],'last':comparable[-1]}

tests = {
 'result_safety':'accepted-test_runtime_result_safety.log',
 'pending_recovery':'accepted-test_pending_input_recovery.log',
 'challenge_flows':'challenge-all-final.log',
 'challenge_result_actions':'test_challenge_result_action-final.log',
 'rivalry_start_failure':'test_rivalry_start_failure-final.log',
 'free_race_restart':'accepted-test_free_race_restart.log',
 'app':'app-geometry-final.log',
 'cooperative_install':'accepted-test_cooperative_race_install.log',
 'cooperative_car_parity':'accepted-test_cooperative_car_model.log',
 'native_cancellation':'cancellation-lamps-final.log',
 'recording_limit_result':'recording-limit-accepted.log',
 'garage':'accepted-garage.log',
 'actual_load_pause':'accepted-runtime-profile.log',
 'rewind':'accepted-test_rewind.log',
 'launch':'accepted-test_launch_start.log',
 'checkpoint_bridge':'checkpoint-gates-accepted.log',
 'star_laps':'star-gates-accepted.log',
 'winter_sources':'test_winter_road_edge_snow-accepted.log',
 'storm_editor':'storm-editor-final.log',
 'parse':'parse-all-final.log',
}
accepted=[]
for name,log in tests.items():
    source=text(WORK/log)
    summary=[line for line in source.splitlines() if re.search(r'\d+ (?:checks|scripts)(?:,| /) \d+ failures',line)]
    assert summary and re.search(r'(?:,| /) 0 failures',summary[-1]),(name,summary)
    accepted.append({'name':name,'log':'logs/'+log,'summary':summary[-1]})

soaks=[]
for log,phase in [
 ('soak-50-headless-pine.log','earlier implementation; headless'),
 ('soak-50-mobile.log','earlier implementation; native Vulkan Mobile'),
 ('soak-50-code-final-headless.log','later implementation with subsequently removed preload proposal; headless'),
 ('soak-50-code-final-mobile.log','later implementation with subsequently removed preload proposal; native Vulkan Mobile'),
 ('accepted-soak-final-10.log','after preload removal and final cooperative car scheduling; native Vulkan Mobile'),
 ('soak-200-headless.log','final uninterrupted automated 200-cycle headless pass'),
 ('soak-200-mobile.log','optional native 200-cycle extension, intentionally stopped after 33 cycles; no completed-pass claim'),
]:
    path=WORK/log
    if not path.exists(): continue
    source=text(path); samples=marked(log,'RUNTIME_SOAK ')
    summaries=[line for line in source.splitlines() if line.startswith('RUNTIME_SOAK_RESULT:')]
    soaks.append({'phase':phase,'log':'logs/'+log,'completed_cycles':len(samples),
        'finished':bool(summaries),'summary':summaries[-1] if summaries else ('Stopped owned test process; no completed-pass claim' if log=='soak-200-mobile.log' else 'Still running; no pass claimed'),
        'comparable_samples':matched_samples(samples)})

OUT.mkdir(parents=True,exist_ok=True)
(OUT/'logs').mkdir(exist_ok=True)
logs=[]
for path in sorted(WORK.glob('*.log')):
    dest=OUT/'logs'/path.name; shutil.copyfile(path,dest)
    issues=[line for line in text(path).splitlines() if re.match(r'^(?:ERROR:|SCRIPT ERROR:|WARNING:|FAIL:)',line)]
    logs.append({'path':'logs/'+path.name,'sha256':digest(dest),'bytes':dest.stat().st_size,'issue_lines':issues})

for source_name,dest_name in [
 ('exception-baseline.log','prior-audit-exception-baseline.log'),
 ('gameplay-baseline.log','prior-audit-gameplay-baseline.log')]:
    source=ROOT/'docs/evidence/mobile-audit-fixes-2026-10-26/logs'/source_name
    if source.exists():
        dest=OUT/'logs'/dest_name; shutil.copyfile(source,dest)
        logs.append({'path':'logs/'+dest_name,'sha256':digest(dest),'bytes':dest.stat().st_size,'historical_baseline':str(source.relative_to(ROOT)).replace('\\','/')})

shutil.copytree(WORK/'before',OUT/'before',dirs_exist_ok=True)
(OUT/'probes').mkdir(exist_ok=True)
for name in ['build_review.py','finalize_evidence.py','inspect_render_api.gd','profile_route_validation.gd','model_resource_job.rejected.gd.txt','profile_cover_probe.gd','soak_objects_probe.gd','soak_bounded_sample_probe.gd']:
    if (WORK/name).exists(): shutil.copyfile(WORK/name,OUT/'probes'/name)

manifest=json.loads((OUT/'source-manifest.json').read_text(encoding='utf-8'))
for row in manifest:
    assert digest(ROOT/row['path'])==row['sha256'],row['path']

report={
 'date':'2026-10-26','generated_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'scope':{'request':'Fix the concrete runtime, memory and correctness work list',
          'requirements':['R1','R2','R3','R4','M1','M2','M3','M4','C1','C2','C3','C4','C5'],
          'runtime_implementation':'Packed input, immutable queued evidence, byte admission, serialized encoder, staged journal recovery, asynchronous preview IO, retained Garage pressure cleanup, paused presentation reuse, cooperative car construction and covered first draws',
          'open_acceptance':['R3: cold cover/start/graphics frame stalls still exceed a consistently responsive loading-frame target','M4: static-counter drift is not fully attributed; physical Android PSS/graphics and long-run acceptance remain open','Owner/device appearance, motion, controls and thermal/frame pacing acceptance'],
          'no_claim':'All areas 10/10 or device-certified'},
 'environment':{'engine':'4.7.2.stable.official.ed1daf0bf',
     'executable':r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe',
     'native_renderers':['Windows Compatibility / OpenGL 3.3 / NVIDIA RTX 3090','Windows Vulkan Mobile / NVIDIA RTX 3090'],
     'isolated_profiles':['build/runtime-correctness-2026-10-26/profile','build/runtime-correctness-2026-10-26/profile-soak200-headless'],
     'backend':'BMT_API_URL/BMT_DEV_AUTH_KEY empty; only owned fixture transports',
     'limits':['Sandbox root-certificate store error in startup logs','Native Garage clipboard restoration OS error after the copy assertions passed','No target-device run or attachment check','Concurrent owner work and shared driver caches prevent matched release/device performance claims']},
 'accepted_checks':accepted,
 'actual_process_death':{'phases':['manifest','payload','marker','job'],
    'batch':'trial2','writer':'Start-Process -WindowStyle Hidden; wait for this writer ready file; Stop-Process only its captured PID',
    'recovery':'Fresh Godot process at each phase; 4/4 retain original submission key, replay hash and queued time',
    'logs':['logs/crash-trial2-'+phase+'-recovery.log' for phase in ['manifest','payload','marker','job']],
    'disk_faults':'ENOSPC modeled by injected write failure; failed rename modeled by owned directory obstacle. No actual disk filled.'},
 'metrics':{
    'result_safety':json.loads((OUT/'result-safety.json').read_text(encoding='utf-8-sig')),
    'garage':json.loads(next(line[line.index('{'):] for line in text(WORK/'accepted-garage.log').splitlines() if line.startswith('MOBILE_AUDIT_FIXES:'))),
    'load_profile_final_repeat':marked('accepted-runtime-profile.log','RUNTIME_LOAD '),
    'load_profile_final_first':marked('profile-lamps-final.log','RUNTIME_LOAD '),
    'soaks':soaks,
    'soak_semantics':'Actual App lifecycle; completion state is an explicit fixture. It is not a fully driven race count. Canonical laps/physics covered separately.'},
 'remaining_loading':{'cold_star_max_frame_ms':[502.552,569.391],
    'cold_observed_stage':'before world; original synchronous-car attribution is superseded',
    'warm_star_max_frame_ms':[229.335,261.384],
    'longest_cooperative_car_slice_us':[68239,104206],
    'car_yields':[112,113],'car_assembly_wall_us':[1074228,1123826],
    'ground_gate_bake_before_ms':2210,'restart_after_ms':[13,19],
    'explanation':'Actual graphics calls can still block inside an individual operation; the frame staging is not a hard frame-time guarantee.',
    'official_reference':'https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html'},
 'additional_diagnostics':{
    'cover_probe':{'log':'logs/cover-probe.log','scope':'In-memory script instrumentation; simultaneous with headless soak, not a comparable performance sample',
        'observation':'Cover setup 1660us and route drawing submission 642us for 496 points. First covered draw wait about12.3s in this unpaired run; do not attribute the whole wait to UI construction.',
        'exit':'10 assertions passed, followed by 4 ObjectDB / 1 resource exit findings; this diagnostic run is not accepted as a clean regression',
        'captures':'Star images in load-images were recaptured by this diagnostic process; Storm images retain the accepted full-profile run'},
    'object_count_probe':{'log':'logs/soak-objects-probe.log','scope':'Additional object/store/job counters during real App lifecycle; parse-attempt error preserved separately',
       'samples':marked('soak-objects-probe.log','RUNTIME_SOAK ')},
    'bounded_sample_probe':{'log':'logs/soak-bounded-sample-probe.log','scope':'Retains only one measurement row to distinguish harness allocation from product ownership',
       'samples':marked('soak-bounded-sample-probe.log','RUNTIME_SOAK '),
       'finding':'Measurement-row retention explains part of the static drift. Stable object/node/resource counts and zero outstanding jobs do not prove that all remaining byte growth is explained.'}},
 'retained_failures':[
    {'test':'test_gameplay_f13_f16_f19_f24','outcome':'4303 checks / 1 frozen Forklift reference mismatch','baseline':'logs/prior-audit-gameplay-baseline.log','policy':'Concurrent approved physics is preserved; assertion not weakened'},
    {'test':'test_backend_exception_recovery','outcome':'Legacy direct input-submit recovery expectation fails, followed by a test script schema error','baseline':'logs/prior-audit-exception-baseline.log','policy':'No weakening of trajectory-only policy; supported legacy outbox suite passes'},
    {'proposal':'Threaded baked model resource preload','outcome':'Did not remove measured construction blocker; runtime helper deleted, rejected source and probe logs retained'},
    {'test':'Earlier rendering lifecycle fixture','outcome':'One immediate-exit Dummy-audio resource-leak finding; fixture music disabled; later verbose 16-check exit clean'},
 ],
 'packaged_resource_inventory':json.loads((OUT/'content-inventory.json').read_text(encoding='utf-8-sig')),
 'export':{'artifact':'build/runtime-correctness-2026-10-26/content.zip','sha256':digest(WORK/'content.zip'),'scope':'Android content ZIP inventory only; not an APK/AAB or final release-script validation'},
 'review':{'patch':'checkpoint.patch','sha256':digest(OUT/'checkpoint.patch'),
    'source_manifest':'source-manifest.json','files':len(manifest),
    'validation':'Isolated Git diff --check; reverse/apply checks and exact byte round-trip; root Git index untouched',
    'preserved_concurrent_work':['App Rivalry summary/profile-header/draft-save behavior','Cloud/Backend claimed-lap/skipped non-improving-result contract','Game authored-route practice eligibility','Garage paint/list/camera/kit transitions','Storm driving-variety source tracks and owner library','Canonical physics/configuration/cameras/validators']},
 'source_manifest':manifest,
 'native_views':[{'path':str(path.relative_to(OUT)).replace('\\','/'),'sha256':digest(path),'bytes':path.stat().st_size} for path in sorted(OUT.rglob('*.png'))],
 'commands':'commands.txt: reproducible invocations actually used; raw logs retain emitted command fragments',
 'raw_logs':logs,
 'not_performed':['Device attachment check/test','APK/AAB build/install','Real authentication or purchase','Live backend mutation','Deployment/merge/commit/root staging','Owner process restart'],
}
(OUT/'report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print('Evidence:',len(accepted),'accepted check groups,',len(logs),'raw logs;',[(r['completed_cycles'],r['finished']) for r in soaks])
