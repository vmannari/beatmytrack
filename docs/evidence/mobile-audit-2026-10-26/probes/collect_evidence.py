"""Assemble audit-only artifacts; no runtime edits or service access."""
from pathlib import Path
from collections import Counter
import csv, hashlib, json, re, shutil, subprocess, xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent
DEST = ROOT / 'docs/evidence/mobile-audit-2026-10-26'
DEST.mkdir(parents=True, exist_ok=True)

for folder in ('logs','commands','probes','captures'):
    (DEST/folder).mkdir(exist_ok=True)

runs=[]
for p in sorted(SRC.glob('*.json')):
    value=json.loads(p.read_text(encoding='utf-8-sig'))
    if isinstance(value,dict) and 'command' in value and 'exit_code' in value:
        log=p.with_suffix('.log')
        text=log.read_text(encoding='utf-8',errors='replace') if log.exists() else ''
        value['log']='logs/'+log.name
        value['runtime_script_error']='SCRIPT ERROR:' in text
        value['certificate_store_error']='Failed to read the root certificate store' in text
        value['markers']=[s for s in text.splitlines() if re.search(r'checks.*failures|checks,.*failures|APP_TESTS:|SCRIPT_PARSE:|passed,.*failed|failed,.*passed|STARTUP_|INPUT_MEMORY |GARAGE_RENDER ',s)][:15]
        runs.append(value)
        shutil.copy2(p,DEST/'commands'/p.name)
        if log.exists():shutil.copy2(log,DEST/'logs'/log.name)

for name in ('backend-smoke.log','backend-full.log'):
    if (SRC/name).exists():shutil.copy2(SRC/name,DEST/'logs'/name)
for name in ('source-inventory.json','literal-load-graph.json','native-elf-alignment.json','synthetic-trajectory-result.json','ellipse-geometry.json','transition-results.json','backend-sqlite-junit.xml','backend-triage-junit.xml'):
    if (SRC/name).exists():shutil.copy2(SRC/name,DEST/name)
for name in ('audit_runner.py','verification_probe.py','input_memory_probe.gd','garage_render_probe.gd','pause_lifetime_probe.gd','transition_probe.gd','screen_probe.gd','startup_probe.gd','collect_evidence.py'):
    shutil.copy2(SRC/name,DEST/'probes'/name)
for p in (SRC/'screen-captures').glob('*.png'):shutil.copy2(p,DEST/'captures'/p.name)
for name in ('store-1280x720.png','store-960x540.png','store-1600x1000.png','narrow-600x360-top.png','narrow-600x360-bottom.png'):
    p=SRC/'store-captures/gl_compatibility'/name
    if p.exists():shutil.copy2(p,DEST/'captures'/name)

categories={
    'test_discovery_reports_remaining_lifetime':('stale test seam','Test monkeypatches discovery.time, which no longer exists.'),
    'test_visible_windows_limit_keys':('stale planner expectation','SQLite planner uses a covering tie-node index; test expects an older named visible-order index.'),
    'test_additive_attempt_migration':('migration test compatibility','Rollback from current head encounters the explicit 0054 creator-event drain guard.'),
    'test_migration_backfills_snapshots':('migration test compatibility','Rollback encounters explicit 0054 creator-event drain guard.'),
    'test_migration_bounded_backfill':('migration test compatibility','Rollback encounters explicit 0054 creator-event drain guard.'),
    'test_migration_seeds_existing_racers':('migration test compatibility','Rollback encounters explicit 0054 creator-event drain guard.'),
    'test_migration_backfills_existing_field':('migration test compatibility','Rollback encounters explicit 0054 creator-event drain guard.'),
    'test_migration_preserves_pending_jobs':('migration test compatibility','Telemetry-v2 rollback deliberately requires a reconciled backup for legacy binaries.'),
    'test_recorded_practice_through_real_publish_worker':('environment / native integration','Real track validation returns 503 in the sandbox; ordinary verifier wrapper rejects the engine certificate-store error.'),
    'test_native_deletion_and_new_identity':('environment / launcher side effect','Sandbox certificate-store and Access denied errors stop nested launcher; it regenerates build identity, subsequently restored exactly.'),
    'test_real_verifier_redaction':('environment / native integration','GodotVerifier rejects the engine error; deletion correctness is not established by this failed case.'),
    'test_canonical_three_rewinds':('environment / native integration','GodotVerifier rejects the engine certificate-store error.'),
    'test_directory_and_link_types':('test double mismatch','Patched Path.stat asserts follow_symlinks=False even on a subsequent Path.exists call with no such argument; reproduced separately. No symlink escape established.'),
    'test_backup_quiesces_writers':('stale service list','Expected stopped services omit the added admin service.'),
    'test_supervisor_starts_and_stops':('stale service list','Expected lanes omit the added discovery lane.'),
    'test_operator_queue_counts':('stale API expectation','Competition-health assertions pass; test then expects retired publications field on current admin overview.'),
    'test_nested_router_prefixes':('log contract/test mismatch','Capture includes http_cost_summary on shutdown, which has rows rather than a top-level route. Test treats every JSON log as an individual request.'),
}
failures=[]
tree=ET.parse(SRC/'backend-sqlite-junit.xml').getroot()
for t in tree.iter('testcase'):
    f=t.find('failure')
    if f is None:continue
    name=t.attrib['name']; category,why=next((v for k,v in categories.items() if name.startswith(k)),('unclassified','Requires follow-up; not asserted to be a player defect.'))
    failures.append({'test':t.attrib['classname']+'::'+name,'category':category,'disposition':why})

coverage=[
('App startup/navigation','game/core/app.gd; game/core/app.tscn','Source trace; headless App141; six graphical offline screens; attributed startup','MA03 MA09 MA13; graphical full-App fixture timeout retained'),
('Canonical driving/input','game/vehicle/vehicle_simulation.gd; game/input/driver_input.gd; game/input/drive_frame.gd','Driving72; handling88; quantized fixed-step source review','Current physical-device feel not assessed'),
('Lap/checkpoint/timing','game/race/track_session.gd; game/race/race_rules.gd','Checkpoint266; native five-lap and server gate source trace','MA01; malicious trajectory accepted locally'),
('Rewind/restart/pause','game/race/rewind_history.gd; game/core/game.gd; game/ui/race_pause_menu.gd','Rewind61; pause label619; isolated lifetime reproduction','MA06; native provider/engine tests blocked'),
('Ghosts/incidents/results','game/race/personal_ghost_run.gd; game/race/lap_telemetry.gd; game/ui/race_results.gd','Capture/branch/result and reward authority source trace; App round trips','MA01; full all-car ghost device sweep unperformed'),
('Creator schema and geometry','game/editor/track_document.gd; game/editor/track_compiler.gd; game/editor/creator_limits.gd','Creator113; native bounds, sections and object cost trace','Large valid UGC mobile cost requires profiling'),
('Creator gestures/history/transactions','game/editor/editor_canvas.gd; game/editor/editor_history.gd; game/editor/commit_queue.gd; game/editor/write_queue.gd','Editor workflow254; control layout407; history and cancellation review','MA09; current graphical Creator capture is an early preparation state'),
('Local save/recovery','game/persistence/local_records.gd; game/persistence/track_library.gd; game/persistence/condition_store.gd','Records54; bounded validated saves and backup trace','Fault/power-loss matrix not fully executed'),
('Cloud result journals and uploads','game/backend/cloud_tracks.gd; game/backend/result_save_queue.gd; game/backend/pending_input_recovery.gd','Ownership/idempotency trace; actual memory append measurement','MA05; fixture HTTP lifecycle attempt fails without configured fixture'),
('Discovery/catalogue/leaderboards','game/ui/track_browser.gd; game/ui/track_catalog.gd; backend/bmt_backend/discovery_v3.py; backend/bmt_backend/runs.py','Source trace; broader backend selection; empty offline Race capture','Some planner/API expectation failures; no live population/load audit'),
('Rivalry/ranking','game/backend/weekly_rivalry_client.gd; game/ui/weekly_rivalry_page.gd; backend/bmt_backend/rivalry.py; backend/bmt_backend/world_ranking.py','Client/server boundary, prepared views and immutable scoring review; selected backend execution','No authenticated live graphical roster or full physical-device flow'),
('Challenges/tries/rewards','game/backend/challenges_client.gd; game/ui/challenges_page.gd; backend/bmt_backend/challenges.py; backend/bmt_backend/economy.py','Challenges216; source contract and backend coverage','PostgreSQL try/reservation races unverified here'),
('Track of the Day','game/ui/track_of_day_page.gd; backend/bmt_backend/track_of_day.py','UTC/supply/history and client rollover source trace; native attempt recorded','Native configured HTTP fixture unavailable; not a feature-failure claim'),
('Garage/models/cosmetics/wash','game/ui/garage_page.gd; game/ui/car_showroom.gd; game/ui/garage_reflections.gd; game/backend/appearance_sync.gd','Appearance56; current native capture; actual invalidation and startup probes','MA04 MA13; no comprehensive all-model art certification'),
('Store/gifts/purchases','game/ui/store_page.gd; game/platform/purchase_simulator.gd; backend/bmt_backend/commerce.py','Gift57; Store131 headless/144 graphical; provider/domain source trace','MA02 MA07; actual Billing unavailable'),
('Ads/resume resources','native/admob; game/platform/resume_credits.gd; game/platform/race_ad_breaks.gd; backend/bmt_backend/resumes.py','Debug gates/demo units, journal and server proof/order trace','MA02; no live ad/purchase/device activity'),
('Settings/onboarding/localization','game/ui/settings_page.gd; game/tutorial; game/localization; scripts/localization.py','Localization62; translations302; authoring7; extraction check; captures','MA08; catalogue check1045 errors and source currency failure'),
('Profiles/friends/news/moderation','game/ui/player_profile.gd; game/backend/news_client.gd; game/ui/community_safety_ui.gd; backend/bmt_backend/news.py; backend/bmt_backend/community.py','Bounded scopes, public user text and account-fence source trace; selected backend coverage','No interactive live friend/moderation review'),
('Authentication/token lifecycle','game/backend/backend_client.gd; game/backend/session_vault.gd; backend/bmt_backend/security.py; backend/bmt_backend/auth.py','TLS/nonce/audience/rotation/storage boundary trace; security35','No successful external authentication; sandbox vault test limitations retained'),
('Privacy/deletion/retention','game/backend/privacy_local.gd; backend/bmt_backend/privacy.py; backend/bmt_backend/privacy_pages.py; backend/bmt_backend/erasure_journal.py','Deletion/restore/journal and disclosure source trace; available backend tests','MA12; real PostgreSQL and final legal/provider disclosures not signed off'),
('HTTP ingress and isolation','backend/bmt_backend/middleware.py; backend/bmt_backend/http_server.py; backend/bmt_backend/workloads.py','Body/deadline/routing/MFA/workload separation trace; security35; focused trace triage','Request-log test contract mismatch retained; no live penetration test'),
('Economy/progression','backend/bmt_backend/economy.py; backend/bmt_backend/achievements.py; backend/bmt_backend/commerce.py','Server-owned lock/idempotency/reward authority trace; broad backend tests','MA01 clean claim; PostgreSQL concurrency not validated'),
('Workers/storage/retention','backend/bmt_backend/worker.py; backend/bmt_backend/queueing.py; backend/bmt_backend/storage.py; backend/bmt_backend/local_object_listing.py','Leases, capacity, immutable data and deletion/backup ownership review; selected backend tests','External object provider/IAM/load/restore rehearsal unverified'),
('Studio/reporting/configuration/monitoring','backend/bmt_backend/studio.py; backend/bmt_backend/studio_reporting.py; backend/bmt_backend/game_config.py; backend/bmt_backend/studio_watchdog.py','Source/configuration inspection, safe capability interpretation and available backend execution','No interactive Studio browser, live MFA/provider/configuration or incident delivery acceptance'),
('Observability','game/backend/client_quality.gd; game/backend/product_telemetry.gd; backend/bmt_backend/observability.py; backend/bmt_backend/quality.py','Consent/bounds/coverage and safe logging trace; focused trace failure investigation','MA10; guest stacks, ANR/vitals and release symbols unverified'),
('Rendering/assets/resources','game/track/native_track_visual.gd; game/track/prepared_world_cache.gd; game/track/surface_shader_variants.gd; game/assets','Batch/cache/shader/material/texture import inspection; nine repeated native scenes; graphical captures','MA04 MA05 MA13; GPU device cost and whole-app PSS soak unperformed'),
('Weather/effects/audio/haptics','game/track/storm_weather.gd; game/track/night_fire_volume.gdshader; game/track/desert_sand_wind.gd; game/soundtrack/audio_world.gd; game/platform/drift_haptics.gd; native/windows_audio','Bounded sources/loops, shader candidates, pause and native mixer source inspection','No physical audio, thermal/battery, driver or listening acceptance'),
('Android Java/native adapters','native/google_sign_in; native/challenges; game/addons; game/platform/track_geometry','Keystore/intent/provider/manifest review; both native ELF segment alignments checked16KiB','Final APK manifest/ZIP alignment/SDK behavior and device lifecycle untested'),
('Build/dependencies/release','game/export_presets.cfg; backend/requirements.lock; backend/Dockerfile; scripts/dev.ps1; scripts/build_identity.ps1','Pinning, debug/release exclusions, signing-ignore rules and tracked credential-name scan','MA03 MA11; no full vulnerability scan or final signed artifact'),
('Legacy/ancillary tooling','archive; tools; Android_racing_game_blueprint_v2; historical game/tests fixtures','Inventory, export boundary, retained compatibility references and documentation review','No production dead module proven removable; no full trailer/music-tool/browser-product audit'),
]
with (DEST/'coverage.csv').open('w',encoding='utf-8',newline='') as stream:
    writer=csv.writer(stream);writer.writerow(['system','source_paths','review_and_verification','limits_or_findings']);writer.writerows(coverage)

baseline=json.loads((SRC/'source-inventory.json').read_text())
changes=[]
for x in baseline:
    p=ROOT/x['path'];actual=hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
    if actual!=x['sha256']:changes.append({'path':x['path'],'before_sha256':x['sha256'],'after_sha256':actual,'disposition':'Concurrent external handling work; preserved' if x['path']=='game/vehicle/handling_config.gd' else 'Inspect before concluding audit'})
summary={
    'schema':'bmt-mobile-audit-v1','date':'2026-10-26','timezone':'Europe/Helsinki',
    'requirements':['AUD'+str(i).zfill(2) for i in range(1,11)],
    'report':'../../COMPREHENSIVE_MOBILE_AUDIT_2026_10_26.md',
    'findings':{'P0':0,'P1':['MA01','MA02','MA03','MA13'],'P2':['MA04','MA05','MA06','MA07','MA08','MA09','MA10','MA11','MA12']},
    'source_inventory_files':len(baseline),'coverage_systems':len(coverage),
    'backend_available':{'passed':1249,'failed':20,'skipped':35,'deselected':1013,'stopped_at_failure_limit':20,'not_a_full_suite_pass':True},
    'backend_security_smoke':{'passed':35,'failed':0,'log':'logs/backend-smoke.log'},
    'backend_triage':{'passed':35,'failed':3,'junit':'backend-triage-junit.xml'},
    'backend_failure_dispositions':failures,
    'interrupted_attempts':[{'name':'backend-full','status':'Interrupted after repeated unreachable PostgreSQL fixture errors; marker selection did not exclude parametrized postgres cases','log':'logs/backend-full.log'}],
    'engine_version':'4.7.2.stable.official.ed1daf0bf',
    'runs':runs,'source_changes_during_audit':changes,
    'incidental_generated_identity':{'cause':'Nested test_privacy_http launcher invoked scripts/dev.ps1 TestScript','original_recovered_from':'build/logs/Import-17520/client-build-identity.json','restore':'Exact baseline SHA256 matched for both files; only generated identity fields were replaced','files':['game/project.godot','game/core/build_identity.gd']},
    'bounds':{'production_fixes':False,'device_attachment_check':False,'device_test':False,'apk_or_aab_build':False,'real_purchase':False,'external_authentication_success':False,'production_database_mutation':False,'deployment':False,'owner_process_restart':False,'git_stage_commit_merge':False},
    'limitations':['No physical Android FPS/PSS/GPU/thermal/battery/touch acceptance','No deployed cloud/IAM/provider audit','PostgreSQL concurrency unavailable','Sandbox engine certificate-store error blocks normal GodotVerifier integration','No exhaustive advisory/SBOM scan or final release artifact','Concurrent working tree; external handling source changed','Diagnostic timing is desktop only; earlier host measurements shared CPU with tests'],
}
(DEST/'report.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
entries=[]
for p in sorted(DEST.rglob('*')):
    if p.is_file() and p.name!='artifact-hashes.json':entries.append({'path':p.relative_to(DEST).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(DEST/'artifact-hashes.json').write_text(json.dumps(entries,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'artifacts':len(entries),'bytes':sum(x['bytes'] for x in entries),'runs':len(runs),'coverage':len(coverage),'changed_sources':changes},indent=2))
