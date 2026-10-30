from pathlib import Path
import collections
import datetime
import hashlib
import json
import re
import shutil
import subprocess

ROOT = Path.cwd()
LAB = ROOT / 'build/re-audit-2026-10-27'
OUT = ROOT / 'docs/evidence/mobile-reaudit-2026-10-27'
OUT.mkdir(parents=True, exist_ok=True)


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8', newline='\n')


def read_log(path):
    data = path.read_bytes()
    return data.decode('utf-16') if data.startswith(b'\xff\xfe') else data.decode('utf-8-sig', errors='replace')


start = json.loads((LAB/'inventory-start.json').read_text(encoding='utf-8'))
suffixes = {Path(row['path']).suffix for row in start['files']}
listed = subprocess.run(['rg', '--files', 'game', 'backend', 'native', 'scripts'], capture_output=True, text=True, check=True).stdout.splitlines()
paths = sorted({Path(name).as_posix() for name in listed if Path(name).suffix in suffixes}
               | {row['path'] for row in start['files'] if (ROOT/row['path']).is_file()})
end = []
for name in paths:
    data = (ROOT/name).read_bytes()
    end.append(dict(path=name, bytes=len(data), lines=len(data.splitlines()), sha256=hashlib.sha256(data).hexdigest()))
finished = datetime.datetime.now(datetime.timezone.utc).isoformat()
write_json(LAB/'inventory-end.json', dict(generated_utc=finished, files=end))
before = {row['path']: row for row in start['files']}
after = {row['path']: row for row in end}
changes = []
for name in sorted(before.keys() | after.keys()):
    if before.get(name, {}).get('sha256') != after.get(name, {}).get('sha256'):
        changes.append(dict(path=name, before=before.get(name), after=after.get(name)))
write_json(LAB/'source-changes-during-audit.json', changes)

samples = [json.loads(line) for line in (LAB/'soak50-native/soak-50-gl_compatibility-Windows.jsonl').read_text(encoding='utf-8').splitlines()]
matched = [row for row in samples if row['cycle'] >= 11 and row['cycle'] % 10 not in [0, 9] and row['nodes'] == 740 and row['resources'] == 902 and row['objects'] == 4608]
process_samples = [json.loads(line) for line in (LAB/'soak50-process-memory.jsonl').read_text(encoding='utf-8').splitlines()]
old_soak = json.loads((LAB/'soak-summary.json').read_text(encoding='utf-8'))
soak = dict(cycles=50, checks=211, failures=0, matched_cycles=[row['cycle'] for row in matched],
            comparison_filter='cycle >= 11; cycle % 10 not in [0,9]; nodes=740; resources=902; objects=4608',
            static_min=min(row['static_bytes'] for row in matched), static_max=max(row['static_bytes'] for row in matched),
            static_range=max(row['static_bytes'] for row in matched)-min(row['static_bytes'] for row in matched),
            static_first_last_delta=matched[-1]['static_bytes']-matched[0]['static_bytes'],
            objects=4608, nodes=740, resources=902,
            peak_private=old_soak['peak_private'], peak_working_set=old_soak['peak_working_set'],
            process_samples=len(process_samples), scope='Native Windows Compatibility; full App lifecycle; no Android PSS or 200-cycle claim. CPU tests overlapped: memory evidence only.')
write_json(LAB/'soak-summary.json', soak)

# Copy only audit-generated text, harnesses and outputs. Never copy profiles,
# private backend configuration, pytest databases or owner user-data directories.
for source in LAB.iterdir():
    if source.is_file() and source.suffix in {'.json', '.jsonl', '.log', '.py', '.gd'}:
        shutil.copy2(source, OUT/source.name)
        if source.suffix == '.log' and source.read_bytes().startswith(b'\xff\xfe'):
            (OUT/(source.stem+'-normalized.log')).write_text(read_log(source), encoding='utf-8', newline='\n')
for folder in ['checks', 'native-checks', 'soak50-native', 'load-profile', 'preloader', 'preloader-native']:
    source_folder = LAB/folder
    if not source_folder.exists():
        continue
    for source in source_folder.rglob('*'):
        if source.is_file() and source.suffix in {'.gd', '.json', '.jsonl', '.png'}:
            target = OUT/source.relative_to(LAB)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
for relative in ['native-outputs/test_garage_live_entry/first-saved-live.png',
                 'native-outputs/test_garage_live_entry/saved-live-rotated.png',
                 'native-outputs/test_mobile_audit_fixes/settings-help-diagnostics.png']:
    source = LAB/relative
    if source.exists():
        target = OUT/relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)

client = json.loads((LAB/'client-results.json').read_text(encoding='utf-8'))
native = json.loads((LAB/'native-results.json').read_text(encoding='utf-8'))
extra_logs = ['free-race-restart.log', 'test_handling.log', 'test_checkpoint_rules.log',
              'test_electric_slide_access.log', 'test_creator.log', 'parser-final.log', 'test_garage_preload.log', 'test_garage_preload-native.log']
extra = []
for name in extra_logs:
    log = LAB/name
    if log.exists():
        text = read_log(log)
        extra.append(dict(log=name, summaries=[line for line in text.splitlines() if re.search(r'(checks|SCRIPT_PARSE|GARAGE_PRELOAD|failures)', line)],
                          errors=[line for line in text.splitlines() if 'ERROR:' in line or 'leaked' in line]))
identity = json.loads((LAB/'synthetic-trajectory-result.json').read_text(encoding='utf-8'))['accepted']['manifest']
deployment_path = ROOT/'docs/evidence/backend-compatibility-deploy-2026-10-27/report.json'
deployment_data = deployment_path.read_bytes()
deployment = json.loads(deployment_data)
report = dict(
    audit='Beat My Track comprehensive re-audit', date='2026-10-27', timezone='Europe/Helsinki',
    completed_utc=finished, mode='Audit only; no intentional product implementation changes',
    audit_document=dict(path='docs/COMPREHENSIVE_MOBILE_REAUDIT_2026_10_27.md',
                        sha256=hashlib.sha256((ROOT/'docs/COMPREHENSIVE_MOBILE_REAUDIT_2026_10_27.md').read_bytes()).hexdigest()),
    requirements=['AUD01 architecture','AUD02 performance/memory','AUD03 UI','AUD04 correctness','AUD05 debt','AUD06 security/privacy','AUD07 Android release','AUD08 testing','AUD09 observability','AUD10 report/evidence/actions'],
    scope=dict(inventory_start=len(start['files']), inventory_end=len(end),
               roots=dict(collections.Counter(Path(row['path']).parts[0] for row in end)),
               concurrent_changes=changes,
               coherence='Tests ran during concurrent owner edits. This is not an immutable release checkpoint; test script copy hashes are retained.'),
    engine=dict(version=identity['engine_version'], executable='C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe',
                sha256='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'),
    contracts=dict(physics=identity['physics_version'], rules=identity['rules_key'], compiler=identity['compiler_version'], vehicles=identity['vehicles']),
    retained_deployment=dict(path=deployment_path.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(deployment_data).hexdigest(),
                             completed_utc=deployment['completed_utc'],complete=deployment['complete'],
                             manifest_fields_match_fresh_local_geometry=all(identity.get(key)==value for key,value in deployment['manifest'].items()),
                             track_specific_geometry_extra_keys=sorted(identity.keys()-deployment['manifest'].keys()),
                             image=deployment['image'],independently_requeried_live=False),
    fresh=dict(headless_client=client, native_client=native, additional_client=extra, soak=soak,
               loading=json.loads((LAB/'load-profile-summary.json').read_text(encoding='utf-8')),
               backend_unit=dict(passed=160, skipped=2, deselected=37, selection='8 named modules, -m not godot -k not postgres'),
               backend_wire_direct=dict(passed=5,deselected=5, scope='Original wire assertions; only dev.ps1 fixture launch replaced by direct pinned Godot invocation'),
               garage_preloader_native=json.loads((LAB/'preloader-native/report.json').read_text(encoding='utf-8')),
               trajectory_reproduction='synthetic-trajectory-result.json', localization='localization-full.json', ruff='ruff-utf8.json'),
    failures_and_controls=[
        'backend-checks-setup-failure.log: initial invocation from wrong import root; corrected',
        'backend-checks.log: 160 passed, 2 failed, 5 fixture errors, 2 skipped, 30 deselected; strict native verifier rejects root certificate ERROR; native dev.ps1 fixture also access denied',
        'All Godot runs report sandbox root certificate store ERROR; no suppression or production verifier relaxation applied',
        'test_pause_menu.log: incorrect headless invocation waits for a rendered frame; only the owned process was stopped; native rerun passes 17 assertions',
        'native-test_pause_menu.log: 17 assertions pass but 60 ObjectDB / 11 resources retained at shutdown',
        'pause-settled.log: only cleanup changed, assertions intact; retention reduces to 4 Ogg audio objects / 1 resource, not proven continuing App leak',
        'native-test_runtime_render_lifecycle.log: 16 assertions pass, 4 ObjectDB / 1 resource at exit',
        'native-test_mobile_audit_fixes.log: 266 assertions pass; OS clipboard restore failed during fixture cleanup',
        'localization-source-check.log: 176 missing translations, 16 newer messages in each of 11 non-English catalogues; POT current',
        'ruff.json: 18 findings, 5 production and 13 tests; no claim all are vulnerabilities',
        'trajectory-probe.log: strict GodotVerifier fails closed on certificate error; raw unchanged native runner geometry plus actual Python acceptance function used for local trust reproduction'
    ],
    test_copy_changes=[
        'Explicit isolated empty backend.cfg and cleared BMT_API_URL; no live backend calls',
        'Known output path redirects into owned build audit directory; assertions and old fixture reads preserved',
        'pause_settled.gd only waits for teardown and nulls fixture locals before exit',
        'test_resume_recovery_wire_direct.py only replaces blocked development-wrapper subprocess invocation'
    ],
    incidental_side_effect='Original backend native-wire fixture called scripts/dev.ps1 and regenerated project.godot/build_identity.gd. No rollback attempted because concurrent sources changed. Those product files are excluded from audit deliverables.',
    retained_evidence=[
        'docs/COMPREHENSIVE_MOBILE_AUDIT_2026_10_26.md',
        'docs/MOBILE_AUDIT_FIXES_2026_10_26.md',
        'docs/RUNTIME_MEMORY_CORRECTNESS_FIXES_2026_10_26.md',
        'docs/MEMORY_DRIFT_INVESTIGATION_2026_10_26.md',
        'docs/RUNTIME_STALL_INVESTIGATION_2026_10_26.md',
        'docs/FULL_BACKEND_DEPLOY_2026_10_26.md',
        'docs/BACKEND_COMPATIBILITY_DEPLOY_2026_10_27.md'
    ],
    not_performed=[
        'Physical-device attachment query, Android test, APK/AAB build or install',
        '200-cycle App acceptance or Android PSS/graphics/thermal/battery profile',
        'Actual provider authentication, purchase, ads, payment or production player mutation',
        'Live PostgreSQL concurrency/migration/restore, complete backend suite or full client suite',
        'Independent new live backend query: public bootstrap inaccessible here; current 27 October rollout receipt was inspected and its complete manifest compared with fresh local geometry',
        'Dependency advisory audit, live penetration testing or legal compliance determination',
        'Owner-process restart, root Git staging/commit/merge or deployment'
    ],
    scores=dict(runtime=6,memory=8,ui_ux=7,correctness=8,architecture=6,maintainability=6,security=6,testing=7,observability=7,android_production_readiness=4),
    findings=[
        dict(id='RA01',priority='P1',status='measured',title='Cold and repeated native loading still blocks frames'),
        dict(id='RA02',priority='P1',status='confirmed accepted design risk',title='Trajectory-only trust and client clean-race claim'),
        dict(id='RA03',priority='P1',status='confirmed verification gap',title='Release regression selection/prerequisites/error handling incomplete'),
        dict(id='RA04',priority='P1 conditional on monetized release',status='confirmed integration gap',title='Production Billing and ads incomplete'),
        dict(id='RA05',priority='P1 release gate',status='final Android acceptance missing; retained current service manifest matches',title='Final Android artifact and device memory/frame envelope'),
        dict(id='RA06',priority='P2',status='confirmed',title='16 newer messages untranslated in 11 catalogues'),
        dict(id='RA07',priority='P2',status='static maintainability risk',title='App still combines independently evolving lifecycles'),
        dict(id='RA08',priority='P2 release operations',status='partial implementation, operational acceptance missing',title='Guest crash/ANR reporting and privacy configuration need release proof')
    ]
)
write_json(OUT/'report.json', report)
manifest = []
for path in sorted(OUT.rglob('*')):
    if path.is_file() and path.name != 'artifact-hashes.json':
        data=path.read_bytes()
        manifest.append(dict(path=path.relative_to(OUT).as_posix(), bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
write_json(OUT/'artifact-hashes.json', manifest)
print(json.dumps(dict(files=len(manifest), bytes=sum(row['bytes'] for row in manifest), source_changes=[row['path'] for row in changes], soak=soak), indent=2))
