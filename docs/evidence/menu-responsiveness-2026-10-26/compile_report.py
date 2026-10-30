from pathlib import Path
import difflib
import hashlib
import json
import shutil

root = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
evidence = Path(__file__).resolve().parent
read = lambda p: p.read_text(encoding='utf-8')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
runtime = ['game/core/app.gd', 'game/ui/car_showroom.gd', 'game/ui/garage_environment.gd', 'game/ui/garage_preview_cache.gd']
new = ['game/tests/profile_menu_responsiveness.gd', 'game/tests/test_menu_responsiveness.gd', 'game/tests/bake_garage_architecture.gd', 'game/assets/garage/workshop_v1.provenance.json', 'docs/MENU_RESPONSIVENESS_2026_10_26.md']
for name in list(new):
    if name.endswith('.gd') and (root / (name + '.uid')).exists():
        new.append(name + '.uid')

patch = []
scratch = root / 'build/menu-responsiveness-patch-check'
for name in runtime + ['AGENTS.md', 'DEVELOPMENT_STATUS.md'] + new:
    after = read(root / name)
    if name in new:
        before = ''
    elif name in ['AGENTS.md', 'DEVELOPMENT_STATUS.md']:
        start = after.index('<!-- MENU-RESPONSIVENESS-20261026 -->')
        marker = '<!-- /MENU-RESPONSIVENESS-20261026 -->'
        end = after.index(marker, start) + len(marker)
        if after[end:end + 2] == '\n\n':
            end += 2
        before = after[:start] + after[end:]
        (evidence / 'checkpoint-base' / name).write_text(before, encoding='utf-8', newline='\n')
    elif (evidence / 'checkpoint-base' / name).exists():
        before = read(evidence / 'checkpoint-base' / name)
    else:
        before = read(evidence / 'before' / name)
    patch.append('diff --git a/' + name + ' b/' + name + '\n')
    if name in new:
        patch.append('new file mode 100644\n')
    patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='/dev/null' if name in new else 'a/' + name, tofile='b/' + name))
    if before:
        target = scratch / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(before, encoding='utf-8', newline='\n')
    target = evidence / 'task-final' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / name, target)
(evidence / 'checkpoint.patch').write_text(''.join(patch), encoding='utf-8', newline='\n')

commands = []
for path in sorted(evidence.glob('*/command.json')):
    record = json.loads(read(path))
    record['label'] = path.parent.name
    record['log'] = str(path.parent.relative_to(evidence) / 'run.log')
    commands.append(record)
profiles = {}
for label in ['baseline', 'matched-baseline', 'final-profile', 'integrated-profile']:
    data = json.loads(read(evidence / label / 'profile.json'))
    profiles[label] = [{k: v for k, v in t.items() if k != 'frames'} for t in data['transitions']]

report = {
    'requirements': ['MR01', 'MR02', 'MR03', 'R01', 'Q01'],
    'date': '2026-10-26',
    'engine': read(root / 'godot-version.txt').strip(),
    'runtime_scope': runtime,
    'new_files': new + ['game/assets/garage/workshop_v1.scn'],
    'source_sha256': {f: sha(root / f) for f in runtime + new},
    'prepared_scene': {'path': 'game/assets/garage/workshop_v1.scn', 'bytes': (root / 'game/assets/garage/workshop_v1.scn').stat().st_size, 'sha256': sha(root / 'game/assets/garage/workshop_v1.scn')},
    'excluded_concurrent_sources': {f: sha(root / f) for f in ['game/ui/profile_car.gd', 'game/ui/header_car_icons.gd', 'game/ui/garage_page.gd']},
    'checkpoint_note': 'App base includes concurrent Rivalry and parking-hall preparation. Documentation bases preserve concurrent continuous-loop artwork notes. Only menu responsiveness hunks are included. The prepared binary is separate and identified by hash.',
    'profiles': profiles,
    'commands': commands,
    'passing_results': {'focused_headless': 35, 'focused_compatibility': 42, 'app': 141, 'audit_compatibility': 266, 'audit_desktop_mobile': 266, 'parser_scripts': 1283},
    'retained_failures': {
        'mobile_strict_pixels': '32 checks / 2 failures. Synchronous controls also differ: 2421 components, max 10/255; cooperative comparison: 2441, max 10/255. Zero pixel assertions retained.',
        'broader_swipes': '162 checks / 75 failures, exact same failure labels with restored original sources.',
        'broader_quality': 'Missing hero title at line 33; same error with original App and fresh instance. Current attempt reaches its 240-second deadline.',
        'initial_pixel_fixture': 'First synchronous draw differs from repeated synchronous draw; explicit warmup corrects the Compatibility fixture without a tolerance change.',
        'invalid_baseline_subclass': 'Reloading a base behind a precompiled subclass produced invalid member offsets. This attempt is excluded as a production diagnostic; fresh App construction reproduces the original missing-title error.',
        'header_attachment': 'Visual review caught the retained picture resolving anchors against the viewport. Reset both parent and picture bounds after destination attachment; final tests check parent and picture bounds through navigation/resizing.',
        'test_audio_teardown': 'Verbose trace identifies Ogg playback objects. Stopping test playback after profile load resolves leakage; production audio is unchanged.',
        'concurrent_asset_import': 'First integrated audit logs missing image loader errors during concurrent header asset creation; not a clean pass despite its 266 assertions. Repeated cleanly after import.',
        'editor_import': 'Exits zero but logs native extension copy/load errors; not claimed as a clean import pass.',
        'environment': 'Sandbox certificate-store error is retained in raw logs and distinguished from test failures.',
    },
    'limitations': [
        'Cold Garage construction and driver/shader stalls remain, including 34.6 seconds in the integrated profile.',
        'Integrated revisit frames measured 437 ms and 22 ms; visible preview hitches remain possible.',
        'Some non-Compact construction stages remain synchronous.',
        'Timings are desktop measurements with driver/cache and concurrency variation; no phone performance claim.',
        'Reload/rebuild and owner appearance/input/performance acceptance remain.',
    ],
    'not_performed': ['device attachment check', 'physical-device test', 'APK/AAB', 'real authentication or purchase', 'owner save/live backend mutation', 'deployment', 'owner-process restart', 'git staging', 'git commit'],
}
(evidence / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print('Wrote report, snapshots and scoped patch.')
