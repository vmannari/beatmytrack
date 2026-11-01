"""Inventory the delivered source, prepared assets and native review evidence."""
import hashlib
import json
from pathlib import Path

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').exists())
OUT = Path(__file__).resolve().parent

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def read(name):
    return json.loads((OUT/name).read_text(encoding='utf-8'))

active = ROOT/'game/assets/vehicles/electric_curved_rear_window_v1'
old = ROOT/'game/assets/vehicles/electric_subtle_fenders_v1'
manifest = json.loads((active/'manifest.json').read_text())
retained = {}
for name in ['game/vehicle/electric_car_model.gd','game/vehicle/electric_reference_details.gd',
             'game/vehicle/handling_config.gd','game/vehicle/vehicle_simulation.gd',
             'game/resources/cars/electric.tres']:
    retained[name] = digest(ROOT/name)==digest(OUT/'task-base'/name)
assert all(retained.values()), retained
old_hashes = read('old-mesh-hashes.json')
old_exact = all(digest(ROOT/path)==sha for path,sha in old_hashes.items())
assert old_exact
meshes = []
for item in manifest['meshes']:
    name = item['file']
    meshes.append(dict(item, sha256=digest(active/name),
                       resource_bytes_changed=digest(active/name)!=digest(old/name)))
sources = {name:digest(ROOT/'game/vehicle'/name) for name in manifest['sources']}
assert sources==manifest['sources']
pictures = list((ROOT/'game/assets/liveries/previews_v2/electric').glob('*.png'))
pictures += [ROOT/p for p in ['game/assets/menu/header_cars_v1/electric.png',
            'game/assets/garage/previews_v1/electric.png','game/assets/news/vehicles/electric.png']]
assert len(pictures)==52
assets = [active/item['file'] for item in manifest['meshes']]+[active/'manifest.json']+pictures
assets += [ROOT/p for p in ['game/assets/vehicles/modular_car_bases_v1/electric_full_fixed.scn',
           'game/assets/vehicles/modular_car_bases_v1/electric_simple_fixed.scn',
           'game/assets/garage/cars_v1/electric.scn','game/assets/garage/previews_v1/provenance.json',
           'game/assets/vehicles/racing_simple_v1/manifest.json']]
assets += list((ROOT/'game/assets/vehicles/racing_simple_v1').glob('electric_shadow_*.res'))
commands = {}
for path in OUT.glob('*.json'):
    data = json.loads(path.read_text(encoding='utf-8'))
    if isinstance(data,dict) and 'command' in data: commands[path.stem]=data
report = dict(
    requirements={
        'RGC01':'Lower rear-window boundary bows rearward following the red guide.',
        'RGC02':'Glass curves gently and meets the reshaped painted deck and rails.',
        'RGC03':'Retain accepted hood, roof, flanks, wheel fit and handling.'},
    runtime_files=['game/vehicle/electric_reference_body.gd','game/vehicle/electric_reference_cabin.gd',
                   'game/vehicle/electric_reference_mesh.gd'],
    sources=sources, curve=read('final-measurements.json'), control=read('control-measurements-final.json'),
    retained_sources_exact=retained, old_prepared_directory_exact=old_exact,
    meshes=meshes, prepared_mesh_count=len(meshes),
    prepared_array_comparison=read('prepared-array-comparison.json'),
    parity=read('parity-measurements.json'), fenders=read('fender-measurements.json'),
    native_views={name:read(name+'/captures.json') for name in ['before','final-gl','final-mobile']},
    regenerated_pictures=len(pictures),
    assets=[dict(path=str(p.relative_to(ROOT)).replace('\\','/'),sha256=digest(p)) for p in assets],
    commands=commands,
    retained_findings=[
        'Initial curve fixtures used sanitized node names as cache keys; the missing side resources caused script errors. Both sessions were interrupted and the key lookup was corrected.',
        'An initial retention check expected an exact deck lip. The lip follows the revised deck; the final check requires the actual tail cap to stay exact instead. No runtime shape was changed to satisfy that initial check.',
        'The standard Garage baker reused a modular assembly and lacked the PreparedCarCache entry it needs (error 20). The offline direct wrapper disables modular restoration; the successful bake follows.',
        'Certificate-store warnings are retained. App frame-hitch output is not a performance measurement.',
        'Initial array-audit void-return error corrected; subsequent strict audit found tiny side-window rounding differences. The morph now bypasses unchanged corners, restoring 323 exact meshes with only ten intended changes.'
    ],
    limits=['Owner reload/rebuild and appearance acceptance remain.','No physical-device test or query.',
            'No APK, deployment, live/backend or owner-save mutation, owner-process restart or main-index write.',
            'Desktop Mobile rendering does not measure phone performance.'],
    checkpoint=read('checkpoint.json') if (OUT/'checkpoint.json').exists() else None)
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(prepared=len(meshes),changed_parts=report['prepared_array_comparison']['changed'],
                      pictures=len(pictures),old_prepared_exact=old_exact,retained=retained)))
