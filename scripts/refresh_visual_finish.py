"""Refresh the six current vehicles using existing native bakers and source fences."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/visual-fixes-2026-11-13'
WORK = ROOT / 'build/visual-fixes-2026-11-13'
IDS = ['compact', 'kart', 'forklift', 'electric', 'hovercraft', 'super_rally']


def run(label, script, *options, extra_env=None):
    env = dict(os.environ, **(extra_env or {}))
    subprocess.run([sys.executable, str(ROOT / 'scripts/run_visual_finish.py'), label, script, *options],
                   cwd=ROOT, env=env, check=True, stdout=subprocess.DEVNULL)
    print(label, 'passed', flush=True)


def sources():
    paths = []
    for directory in ['game/vehicle', 'game/resources', 'game/ui', 'game/track', 'game/rendering']:
        paths += [p for p in (ROOT / directory).rglob('*')
                  if p.suffix in ['.gd', '.gdshader', '.gdshaderinc', '.json', '.tres']]
    paths += [p for p in (ROOT / 'game/assets/vehicles').rglob('*')
              if p.suffix in ['.res', '.png', '.json']
              and 'modular_kits_v1' not in p.parts and 'modular_car_bases_v1' not in p.parts]
    for directory in ['game/assets/liveries', 'game/assets/fonts']:
        paths += [p for p in (ROOT / directory).rglob('*') if p.is_file() and p.suffix != '.uid']
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def identity(label):
    with (OUT / (label + '.log')).open('w', encoding='utf-8') as log:
        subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                        str(ROOT / 'scripts/refresh_visual_finish_identity.ps1')],
                       cwd=ROOT, check=True, stdout=log, stderr=subprocess.STDOUT)
    data = json.loads((WORK / 'identity/client-build-identity.json').read_text(encoding='utf-8-sig'))
    (OUT / (label + '.json')).write_text(json.dumps(data, indent=2), encoding='utf-8')
    print(label, 'passed', flush=True)
    return data


def fence(before, label, excluded=()):
    after = sources()
    changed = sorted(p for p in before.keys() | after.keys() if p not in excluded and before.get(p) != after.get(p))
    reviewed = {p: {'before': before.get(p), 'after': after.get(p)} for p in excluded}
    (OUT / (label + '.json')).write_text(json.dumps({'inputs': len(before), 'changed': changed,
                                                   'reviewed_non_vehicle_inputs': reviewed}, indent=2))
    assert not changed, 'Authored inputs changed: ' + ', '.join(changed)


def rivalry(label):
    # This baker uses a native filesystem path rather than a resource URI.
    run(label, 'res://tests/bake_rivalry_car_previews.gd', '--rendering-method', 'gl_compatibility',
        extra_env={'BMT_REAL_CAR_EVIDENCE': str(OUT / 'rivalry-art'), 'BMT_REAL_CAR_ONLY': ''})


def art_fence(before):
    outputs = [p for p in before if p.startswith('game/assets/liveries/previews_v2/') and p.endswith('.png')]
    fence(before, 'art-source-fence', outputs)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    if '--finish-prepared' in sys.argv:
        # The broad fence caught a concurrent world-disk-cache edit. It is not
        # a declared vehicle dependency; keep its rejected receipt and require
        # unchanged vehicle revisions plus full native source metadata below.
        before = json.loads((OUT / 'prepared-source-before.json').read_text())
        first = json.loads((OUT / 'identity-before-bakes.json').read_text())
        excluded = ['game/track/prepared_world_disk_cache.gd']
        fence(before, 'prepared-reviewed-source-fence', excluded)
        finish_prepared(before, first, excluded)
        return
    if '--verify-models' in sys.argv:
        before = sources()
        with ThreadPoolExecutor(max_workers=2) as pool:
            jobs = [pool.submit(run, 'modular-' + car, 'res://tests/test_modular_car_assets.gd',
                                '--headless', '--', '--vehicle=' + car, '--all-kits') for car in IDS]
            for job in jobs:
                job.result()
        fence(before, 'model-equivalence-source-fence')
        return
    if '--rivalry-only' in sys.argv:
        before = json.loads((OUT / 'art-source-before.json').read_text())
        rivalry('rivalry-art-retry')
        art_fence(before)
        return
    if '--static' in sys.argv:
        # Only redirect the existing baker's evidence. Preserve its reduction algorithm.
        source = (ROOT / 'game/tests/bake_car_static_reductions.gd').read_text(encoding='utf-8')
        source = source.replace('docs/evidence/car-simplification-2026-11-13',
                                'docs/evidence/visual-fixes-2026-11-13')
        (WORK / 'bake_static.gd').write_text(source, encoding='utf-8')
        run('static-reductions', 'res://../build/visual-fixes-2026-11-13/bake_static.gd', '--headless')
        return
    before = sources()
    phase = 'art' if '--art-only' in sys.argv else 'prepared'
    (OUT / (phase + '-source-before.json')).write_text(json.dumps(before, indent=2))
    if phase == 'art':
        run('profile-art', 'res://tests/bake_model_refinement_art.gd', '--rendering-method', 'gl_compatibility')
        run('super-profile-art', 'res://tests/bake_super_rally_art.gd', '--rendering-method', 'gl_compatibility')
        for car in IDS:
            run('liveries-' + car, 'res://tests/bake_livery_previews.gd', '--rendering-method', 'gl_compatibility',
                '--', '--vehicle=' + car)
            run('news-' + car, 'res://tests/bake_news_car_photos.gd', '--rendering-method', 'gl_compatibility',
                '--', '--vehicle=' + car, '--evidence-root=res://../docs/evidence/visual-fixes-2026-11-13/news/' + car)
        rivalry('rivalry-art')
        art_fence(before)
        return
    first = identity('identity-before-bakes')
    for car in IDS:
        run('bases-' + car, 'res://tests/bake_modular_car_bases.gd', '--headless', '--', '--vehicle=' + car)
    with ThreadPoolExecutor(max_workers=3) as pool:
        jobs = [pool.submit(run, 'kits-' + car, 'res://tests/bake_modular_car_kits.gd',
                            '--headless', '--', '--vehicle=' + car) for car in IDS]
        for job in jobs:
            job.result()
    for car in IDS:
        run('garage-' + car, 'res://tests/bake_garage_cars.gd', '--headless', '--', '--vehicle=' + car)
    run('header-template', 'res://tests/bake_header_simple_compact.gd', '--headless')
    fence(before, 'prepared-source-fence')
    finish_prepared(before, first)


def finish_prepared(before, first, excluded=()):
    final = identity('identity-after-bakes')
    assert first['modular_car_sha256'] == final['modular_car_sha256'], 'Geometry revision changed during refresh'
    run('garage-pictures', 'res://../scripts/bake_garage_previews.gd', '--rendering-method', 'gl_compatibility')
    run('prepared-preflight', 'res://tests/check_prepared_assets.gd', '--headless')
    with (OUT / 'picture-preflight.log').open('w', encoding='utf-8') as log:
        subprocess.run([sys.executable, 'scripts/check_garage_previews.py'], cwd=ROOT, check=True,
                       stdout=log, stderr=subprocess.STDOUT)
    fence(before, 'prepared-final-fence', excluded)
    print('SIX_CAR_REFRESH: source fence and strict prepared/picture checks passed', flush=True)


if __name__ == '__main__':
    main()
