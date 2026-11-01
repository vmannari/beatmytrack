"""Reconcile executed commands, checked sources and generated Volt assets."""
import hashlib
import json
from pathlib import Path
import re
import struct

ROOT = next(path for path in Path(__file__).resolve().parents if (path / 'game/project.godot').exists())
OUT = Path(__file__).resolve().parent

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

manifest = read(ROOT / 'game/assets/vehicles/electric_sport_fastback_v1/manifest.json')
sources = {'game/vehicle/' + name: value for name, value in manifest['sources'].items()}
assert all(digest(ROOT/name) == value for name, value in sources.items())
for renderer in ['final-gl', 'final-mobile']:
    captures = read(OUT / renderer / 'captures.json')
    assert captures['sources'] == manifest['sources'] and captures['failures'] == 0
    assert len(captures['captures']) == 18

preserved = {}
for name in ['game/resources/cars/electric.tres', 'game/vehicle/vehicle_simulation.gd',
             'game/vehicle/handling_config.gd', 'game/vehicle/electric_glass.gdshader']:
    previous = OUT / 'task-base' / name
    preserved[name] = {'sha256': digest(ROOT/name), 'exact_task_start': digest(previous) == digest(ROOT/name)}
assert all(item['exact_task_start'] for item in preserved.values())

assets = [*sorted((ROOT/'game/assets/vehicles/electric_sport_fastback_v1').glob('*'))]
assets += [ROOT / f'game/assets/vehicles/racing_simple_v1/electric_shadow_{i}.res' for i in range(5)]
assets += [ROOT / 'game/assets/garage/cars_v1/electric.scn', ROOT/'game/assets/garage/previews_v1/provenance.json']
pictures = [*sorted((ROOT/'game/assets/liveries/previews_v2/electric').glob('*.png'))]
pictures += [ROOT/name for name in ['game/assets/menu/header_cars_v1/electric.png',
             'game/assets/garage/previews_v1/electric.png', 'game/assets/news/vehicles/electric.png']]
assert len(pictures) == 52
assets += pictures
inventory = []
for path in assets:
    if not path.is_file(): continue
    item = {'path': path.relative_to(ROOT).as_posix(), 'bytes': path.stat().st_size, 'sha256': digest(path)}
    if path.suffix == '.png':
        item['pixels'] = struct.unpack('>II', path.read_bytes()[16:24])
        item['changed_from_task_start'] = digest(OUT/'task-base'/item['path']) != item['sha256']
    inventory.append(item)
(OUT/'assets.json').write_text(json.dumps(inventory, indent=2), encoding='utf-8')

commands = []
for path in sorted(OUT.glob('*.json')):
    data = read(path)
    if isinstance(data, dict) and 'command' in data:
        data = {'name': path.stem, **data, 'log': path.stem+'.log'}
        log = (OUT/data['log']).read_text(encoding='utf-8')
        data['results'] = [line for line in log.splitlines() if re.search(r'(checks, \d+ failures|B[A-Z_]*:|VOLT_SPORT_REDESIGN:|PREVIEWS:|FRAMING:)', line)]
        commands.append(data)
(OUT/'commands.json').write_text(json.dumps(commands, indent=2), encoding='utf-8')
for name in ['app-gl', 'app-mobile']:
    data = next(command for command in commands if command['name'] == name)
    assert data['exit_code'] == 0 and 'ELECTRIC_REAR_APP: 58 checks, 0 failures' in (OUT/(name+'.log')).read_text(encoding='utf-8')

control_log = (OUT/'final-control.log').read_text(encoding='utf-8')
control_models = json.loads(re.search(r'VOLT_SPORT_REDESIGN: 72 checks, 22 failures; (\[.*\])', control_log).group(1))
(OUT/'control-measurements.json').write_text(json.dumps({'models': control_models, 'source': 'final-control.log'}, indent=2), encoding='utf-8')
report = {
    'requirements': {'VSR01': 'substantial lower cabin and shallow hood',
                     'VSR02': 'sporting body proportions and flank surfacing',
                     'VSR03': 'finished fascia, lights, bonnet, wheels and rear',
                     'VSR04': 'current prepared assets, pictures and native integration'},
    'sources': sources, 'preserved': preserved,
    'measurements_before': control_models,
    'measurements_after': read(OUT/'prepared.json')['models'],
    'geometry_visible_triangles': {'detailed': 118584, 'simple': 36600, 'simple_shadow_triangles': 3054},
    'checks': {'procedural': [98,0], 'prepared_and_exact_parity': [104,0],
               'negative_control': [72,22], 'optics_procedural': [16,0], 'optics_prepared': [16,0],
               'sport_nose_prepared': [8,0], 'electric_garage_template': [4,0], 'picture_identity': [5,0],
               'racing': [23,0], 'app_compatibility': [58,0], 'app_desktop_mobile': [58,0],
               'unchanged_historical_redesign': [150,12]},
    'prepared_meshes_exact': 289, 'pictures_rebuilt': len(pictures),
    'native_final_captures': {'garage_model_compatibility': 18, 'garage_model_desktop_mobile': 18,
                              'app_compatibility': 9, 'app_desktop_mobile': 9},
    'checkpoint': read(OUT/'checkpoint.json'),
    'command_details': 'commands.json', 'asset_details': 'assets.json', 'comparison': 'before-after.html',
    'retained_findings': [
        'Initial model exceeded triangle budget; tessellation was reduced without changing budget assertions.',
        'Initial lamp housing had a 6.8 mm wrap mismatch; housing centre was corrected and original optics tests pass.',
        'Initial new-test node lookup used periods instead of Godot-normalized underscores; corrected lookup keeps geometry assertions.',
        'Historical twelve monolithic closed-bumper coverage checks conflict with new opening/separate bumper pieces; original fixture unchanged.',
        'New regression checks physical recess returns and upper paint coverage across all separate pieces.',
        'Initial checkpoint byte comparison caught Git global CRLF conversion; explicit autocrlf=false yields exact forward/reverse content.',
        'An unquoted PowerShell @import argument was omitted before native launch; quoted import completed.',
        'Windows root-certificate-store warnings remain; actual App logs include frame hitches.'],
    'limitations': ['owner appearance acceptance remains', 'no physical-device query or test',
                    'desktop Mobile is not a phone performance test', 'no AAA certification',
                    'other cars may rebuild their editor Garage templates under the shared source guard'],
    'operations': {'owner_save_or_live_backend_mutation': False, 'deployment': False,
                   'owner_process_restart': False, 'apk': False, 'main_index_write': False}
}
(OUT/'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'sources_exact': True, 'preserved_physics_and_glass': True,
                  'asset_paths': len(inventory), 'pictures': len(pictures), 'commands': len(commands)}))
