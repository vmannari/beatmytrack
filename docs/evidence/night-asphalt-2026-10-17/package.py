"""Package only this task's diff from the retained working-copy baseline."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = HERE / 'baseline'
MODIFIED = ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md', 'licenses/ASSETS.md',
            'game/track/native_track_visual.gd', 'game/track/surface_detail.gdshaderinc',
            'game/track/surface_shader_variants.gd', 'game/track/creator_bridge_visual.gd',
            'game/track/bridge_presentation.gd']
NEW = ['scripts/bake_night_asphalt.py', 'game/tests/test_night_asphalt.gd',
       'game/tests/fixtures/night_asphalt_surface_before.gdshaderinc',
       'game/tests/fixtures/night_asphalt_variants_before.gd',
       'game/assets/textures/night_asphalt_wear_v1.png.import', 'docs/NIGHT_ASPHALT_2026_10_17.md']
ASSET = 'game/assets/textures/night_asphalt_wear_v1.png'
for name in list(NEW):
    if (ROOT / (name + '.uid')).exists(): NEW.append(name + '.uid')


def read(path):
    data = path.read_bytes()
    return data.decode('utf-16') if data.startswith((b'\xff\xfe', b'\xfe\xff')) else data.decode('utf-8-sig')


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


runs = {name: json.loads(read(HERE / name / 'result.json'))
        for name in ['gl_compatibility-headless', 'gl_compatibility-Windows', 'mobile-Windows']}
assert all(run['failures'] == 0 for run in runs.values()), runs
commands = []
for log, appdata, arguments in [
    ('import-native.log', 'build/night-asphalt-user', 'Import -CommandTimeoutSeconds 300'),
    ('focused-headless-complete.log', 'build/night-asphalt-user-complete', 'TestScript -ScriptPath res://tests/test_night_asphalt.gd -CommandTimeoutSeconds 240'),
    ('focused-gl-complete.log', 'build/night-asphalt-gl-user-complete', 'TestScript -ScriptPath res://tests/test_night_asphalt.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3 -CommandTimeoutSeconds 240'),
    ('focused-mobile-complete.log', 'build/night-asphalt-mobile-user-complete', 'TestScript -ScriptPath res://tests/test_night_asphalt.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -CommandTimeoutSeconds 240'),
    ('import-final.log', 'build/night-asphalt-user-v5', 'Import -CommandTimeoutSeconds 300'),
]:
    commands.append({'appdata': appdata, 'command': 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ' + arguments, 'log': log})
regressions = {}
for script, label, checks in [('test_terrain_sampler_budget', 'TERRAIN_SAMPLER_BUDGET', 63),
                              ('test_prepared_race_resources', 'PREPARED_RACE_RESOURCES', 162),
                              ('test_night_lighting', 'NIGHT_LIGHTING', 15),
                              ('test_script_parse', 'SCRIPT_PARSE', 854)]:
    log = script + '-guard-final.log'
    assert f'{label}: {checks} ' in read(HERE / log) and '0 failures' in read(HERE / log)
    regressions[script] = {'checks': checks, 'failures': 0, 'log': log}
    commands.append({'appdata': 'build/night-asphalt-regression-user-guard', 'command': 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/' + script + '.gd -CommandTimeoutSeconds 180', 'log': log})

patch = ''
for name in MODIFIED + NEW:
    before = read(BASE / name).splitlines(True) if name in MODIFIED else []
    after = read(ROOT / name).splitlines(True)
    # Git applies repository text with normalized LF endings.
    before = [line.replace('\r\n', '\n') for line in before]
    after = [line.replace('\r\n', '\n') for line in after]
    patch += ''.join(difflib.unified_diff(before, after, fromfile='a/' + name if before else '/dev/null', tofile='b/' + name))
(HERE / 'task.patch').write_text(patch, encoding='utf-8', newline='\n')
verification = subprocess.run(['git', 'apply', '--reverse', '--check', '--ignore-space-change', str(HERE / 'task.patch')], cwd=ROOT, capture_output=True, text=True)
(HERE / 'patch-verification.log').write_text(verification.stdout + verification.stderr, encoding='utf-8')
assert verification.returncode == 0, verification.stderr
report = {
    'date': '2026-10-17', 'requirements': ['NA01', 'NA02', 'G01', 'R01', 'Q01'],
    'engine': '4.7.2.stable.official.ed1daf0bf', 'version': 'track-kit-209-night-asphalt',
    'scope': 'Night cosmetic asphalt only; retain original geometry and canonical driving; no phone/backend action.',
    'asset': json.loads(read(HERE / 'bake-repeat.json')),
    'bakes_byte_exact': sha(ROOT / ASSET) == '064181dab0d1aa3473a3a68b99b6203b04175a3900feb6cc76e75740bcc0bb61',
    'tests': runs, 'regressions': regressions, 'commands': commands,
    'bake_command': 'python scripts/bake_night_asphalt.py',
    'initial_attempts': [
        'Sandboxed Godot failed Windows root-certificate access; native execution with project-isolated APPDATA succeeds.',
        'Initial worn_asphalt uniform collided with an existing marking local; renamed industrial_asphalt. Fresh disposable caches excluded retained invalid shader artifacts.',
        'Initial bridge fixture assumed eight declarations in every original biome material. Frozen original comparison confirms pre-existing Grass/Desert/Winter9→9, Storm8→8 and Night6→7; the existing terrain sampler regression passes63/63.',
        'Separate creator/raster bridge material bindings were completed after the first creator bridge integration failure.',
        'Winter bridge uses an unspecialized include; detection uses the expanded original source. A preprocessor guard also prevents the new texture declaration from reaching these non-Night raw shaders.',
        'ShaderMaterial duplication drops undeclared texture overrides; retain the shared Night texture in material metadata and rebind after specialization/prepared-cache hits. Corrected an initial get_meta-with-null-default diagnostic with has_meta.',
        'Initial packaging read PowerShell UTF16 JSON as the default encoding; the retained packager explicitly handles UTF16/UTF8.',
    ],
    'changed_files': MODIFIED + NEW + [ASSET],
    'source_hashes': {name: sha(ROOT / name) for name in MODIFIED + NEW + [ASSET]},
    'captures': sorted(path.relative_to(HERE).as_posix() for path in HERE.rglob('*.png')),
    'checkpoint': {'patch': 'task.patch', 'patch_sha256': sha(HERE / 'task.patch'), 'reverse_apply_check': 'pass',
                   'archive': 'night-asphalt-checkpoint.zip', 'method': 'Task-start working-copy diff plus exact new binary asset; no broad staging or concurrent-edit commit.'},
    'limitations': ['No phone attachment check or physical-phone test.', 'No APK export/install, backend mutation/deployment or FPS claim.',
                    'Owner/device visual/performance acceptance remains.', 'Wear is cosmetic albedo, with no new pothole geometry, traction or collision.',
                    'Native Compatibility/Mobile evidence is desktop rendering; no cross-renderer pixel-identity claim.',
                    'Nine-declaration original non-Night bridge-fixture material roles remain outside this task.'],
}
(HERE / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
with zipfile.ZipFile(HERE / 'night-asphalt-checkpoint.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    archive.write(HERE / 'task.patch', 'task.patch')
    archive.write(ROOT / ASSET, ASSET)
    archive.write(HERE / 'report.json', 'evidence/report.json')
    archive.write(Path(__file__), 'evidence/package.py')
    for path in sorted(HERE.rglob('*')):
        if path.is_file() and (path.suffix in ['.log', '.png'] or path.name in ['result.json', 'bake-repeat.json']):
            archive.write(path, 'evidence/' + path.relative_to(HERE).as_posix())
print(json.dumps({'checks': {name: run['checks'] for name, run in runs.items()}, 'changed_files': len(report['changed_files']), 'patch_reverse_check': 'pass', 'archive_bytes': (HERE / 'night-asphalt-checkpoint.zip').stat().st_size}, indent=2))
