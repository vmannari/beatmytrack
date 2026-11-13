from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,shutil,statistics

root=Path(__file__).resolve().parents[2]
work=Path(__file__).resolve().parent
out=root/'docs/evidence/desert-phone-performance-2026-10-25'
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def summarize(name):
    rows=read(out/name/'results.json')
    assert all(row['paused_frames']==0 and row['driven_metres']>10 for row in rows)
    assert all(row.get('clock_reference_error_ms',0)<=50 for row in rows)
    return [dict({key:row[key] for key in ['disabled_feature','frames','wall_seconds','frame_median_ms','frame_p95_ms','frame_p99_ms','frame_max_ms','weather_median_ms','car_p99_ms','driven_metres','paused_frames','scale_actual','msaa_actual','renderer','vehicle','world_pixels']},fps=row['frames']/(row['wall_seconds']-5),clock_reference_error_ms=row.get('clock_reference_error_ms'),clock_reference_query_ms=row.get('clock_reference_query_ms')) for row in rows]
profiles={name:summarize(name) for name in ['installed-baseline-02','cache-phone-01','clock-phone-01','final-sustained-01']}
runtime=['game/track/desert_sand_wind.gd','game/track/desert_ambience.gd','game/track/desert_playback_clock.gd','game/diagnostics/mobile_race_probe.gd']
source_hashes={}
for name in runtime:
    digest=hashlib.sha256((root/name).read_bytes()).hexdigest()
    assert digest==hashlib.sha256((work/'source'/name).read_bytes()).hexdigest(),name
    source_hashes[name]=digest
device=read(out/'device-verification.json')
assert device['app_ready'] and device['matched_startup_errors']==0 and device['installed_apk_sha256_matches']
final=read(out/'final-phone-state.json')
assert final['diagnostic_markers_removed'] and final['normal_app_ready']
present=read(out/'present-final.json'); present['fps']=present['frames']/present['seconds']
report={
 'date':'2026-10-25','completed_utc':datetime.now(timezone.utc).isoformat(),
 'authorization':'Owner reports poor Desert performance on the phone and requests improvement; preceding phone deployment/USB authorization persists.',
 'requirements':['DPP01: identify actual phone bottleneck','DPP02: improve bounded presentation work with retained appearance/behavior','DPP03: install and verify same-phone improvement','R01','G01','V05','Q01'],
 'outcome':'Optimized build installed and normal play restored; same-scene phone callbacks improve from about43FPS to59FPS, with independently measured Android presentation p95 about17ms.',
 'device':device,'final_phone_state':final,'profiles':profiles,'surfaceflinger':present,
 'lookup_benchmark':{'before':read(out/'lookup-before.json'),'after':read(out/'lookup-after.json'),'scope':'720 standalone desktop discovery calls, not Android frame time'},
 'validation':{
  'cache_headless':{'checks':34,'failures':0},'cache_compatibility':{'checks':51,'failures':0},'cache_desktop_mobile':{'checks':51,'failures':0},
  'wind_lifecycle':{'checks':168,'failures':0},'ambience':{'checks':125,'failures':0},'playback_clock':{'checks':23,'failures':0},
  'isolated_sync_headless':{'checks':44,'failures':0},'isolated_sync_native':{'checks':56,'failures':0,'recorded_frames':181,'loop_wraps':1,'linked':True},
  'android_driving':{'checks':72,'failures':0},'android_catalogue':{'checks':21,'failures':0},'android_menus':{'checks':41,'failures':0},
  'android_import_startup_export':'passed','native_cache_pixels':'three exact before/after views per renderer',
  'scoped_diff_check':'passed','full_regression_run':False},
 'apk_audit':read(out/'apk-audit.json'),'build_scope':read(out/'build-scope.json'),'root_runtime_hashes_match_installed_snapshot':source_hashes,
 'commands':[
  'python build/desert-phone-performance-2026-10-25/profile.py --name installed-baseline-01 (locked phone, 0/7; cleanup completed)',
  'scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_desert_wind_lookup.gd (before/after)',
  'scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_wind_cache.gd (headless, Compatibility, Mobile; initial fixture failure and corrected rerun)',
  'scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd',
  'scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_ambience.gd',
  'scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_playback_clock.gd',
  'scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_wind_sync.gd (concurrent font-fallback error retained)',
  'python build/desert-phone-performance-2026-10-25/prepare-build.py',
  'powershell -NoProfile -ExecutionPolicy Bypass -File build/desert-phone-performance-2026-10-25/run-build.ps1 (cache-only, then cache+clock)',
  'same helper directory: verify-build.ps1; audit-apk.py; deploy.py (each candidate)',
  'profile.py --name installed-baseline-02 --seconds 20',
  'profile.py --name cache-phone-01 --features baseline,desert_wind,baseline --seconds 25',
  'profile.py --name clock-phone-01 --features baseline,desert_wind,baseline --seconds 25',
  'run-test.ps1 -ScriptPath res://tests/test_desert_wind_sync.gd (headless and -Graphical, isolated installed-source base)',
  'run-test.ps1 -ScriptPath res://tests/test_desert_playback_clock.gd',
  'profile.py --name final-sustained-01 --features baseline --seconds 60',
  'profile-present.ps1 -Seconds 45 -Output build/desert-phone-performance-2026-10-25/present-final',
  'verify-phone-final.py; git diff --check (scoped); write-report.py; task-only patch reverse-apply check'],
 'initial_failures_retained':[
  'First phone run was locked and produced zero timing stages; logs retained privately and all task markers removed.',
  'First native pixel comparison left the baseline effect hidden between poses; fixed the fixture visibility/resume state and kept exact equality.',
  'Root synchronization run stopped at a concurrent localization/game_fonts.gd:28 Array versus Array[Font] assignment; isolated phone-source headless/native synchronization both pass.',
  'Cache-only phone build removes expensive source-scan spikes but does not materially fix steady FPS; second audio-timing change is responsible for sustained improvement.'],
 'sources':[{'url':'https://github.com/godotengine/godot/blob/master/servers/audio/audio_driver.cpp','use':'primary implementation shows get_time_since_last_mix taking the driver lock; phone timings establish the measured effect'}],
 'limitations':[
  'Engine callback p95 remains about20.8–21.0ms; Android actual-presentation p95 is16.990ms. These are different boundaries.',
  'Wind-clock native sampled phase errors14.89–37.39ms remain below one20Hz envelope sample; no sample-exact hardware synchronization claim.',
  '60-second run is not extended thermal certification; no general hitch-free or all-track/car claim.',
  'Comparison APK uses the exact prior installed2f8163c3 source plus task changes; concurrent root vehicle/Garage/localization/backend work is preserved and excluded from this paired comparison.'],
 'changed_files':runtime+['game/tests/test_desert_wind_cache.gd','game/tests/test_desert_playback_clock.gd','game/tests/profile_desert_wind_lookup.gd','game/tests/fixtures/desert_phone_performance_before/*','generated .uid metadata','docs/DESERT_PHONE_PERFORMANCE_2026_10_25.md','docs/ANDROID.md','docs/README.md','AGENTS.md','DEVELOPMENT_STATUS.md','docs/evidence/desert-phone-performance-2026-10-25/*','ignored build/desert-phone-performance-2026-10-25/*'],
 'scope':{'app_data_retained_by_install_r':True,'uninstall':False,'app_data_clear':False,'track_sync':False,'provider_interaction':False,'purchase':False,'backend_deployment':False,'desktop_owner_process_restart':False,'root_git_index_or_commit_changed':False,'concurrent_work_preserved':True},
 'remaining_acceptance':['Owner driving, appearance and listening review','Other Desert tracks/cars','Cold start and longer thermal session'],
 'checkpoint':{'path':'docs/evidence/desert-phone-performance-2026-10-25/task-only.patch','validation_command':'git apply --reverse --check'},
}
report['artifact_sha256']={p.relative_to(out).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.rglob('*')) if p.is_file() and p.name not in ['report.json','task-only.patch']}
(out/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'report':str(out/'report.json'),'final_build':device['build']['build_id'],'sustained_fps':profiles['final-sustained-01'][0]['fps'],'present_p95_ms':present['p95_ms']}))
