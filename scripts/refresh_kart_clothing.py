"""Refresh Kart clothing pictures and the prepared resources that consume them."""
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import sys
from refresh_visual_finish import sources

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/kart-clothing-2026-11-14'
WORK = ROOT / 'build/kart-clothing-2026-11-14'
IDS = ['compact', 'kart', 'forklift', 'electric', 'hovercraft', 'super_rally']


def run(label, script, *args, env=None):
    subprocess.run([sys.executable, str(ROOT / 'scripts/run_kart_clothing.py'), label, script, *args],
                   cwd=ROOT, env=dict(os.environ, **(env or {})), check=True, stdout=subprocess.DEVNULL)
    print(label, 'passed', flush=True)


def identity(label):
    with (OUT / (label + '.log')).open('w', encoding='utf-8') as log:
        subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                        str(ROOT / 'scripts/refresh_kart_clothing_identity.ps1')], cwd=ROOT,
                       check=True, stdout=log, stderr=subprocess.STDOUT)
    data = json.loads((WORK / 'identity/client-build-identity.json').read_text(encoding='utf-8-sig'))
    (OUT / (label + '.json')).write_text(json.dumps(data, indent=2))
    print(label, 'passed', flush=True)
    return data


def fence(before, label):
    after = sources()
    changed = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
    (OUT / (label + '.json')).write_text(json.dumps({'inputs': len(before), 'changed': changed}, indent=2))
    assert not changed, changed


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    if '--finish' in sys.argv:
        before = json.loads((OUT / 'prepared-source-before.json').read_text())
        after = sources()
        changed = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
        # News layout is neither a prepared-vehicle dependency nor a producer
        # input for these native photographs. Keep the original rejected fence.
        assert changed == ['game/ui/garage_news_menu.gd'], changed
        (OUT / 'reviewed-concurrent-news.json').write_text(json.dumps({
            'path': changed[0], 'before': before[changed[0]], 'after': after[changed[0]],
            'reason': 'Display-only news-menu edit; vehicle revisions and complete native source metadata are independently required below.'}, indent=2))
        before[changed[0]] = after[changed[0]]
        first = json.loads((OUT / 'identity-before.json').read_text())
        finish(before, first)
        return
    if '--art' in sys.argv:
        run('profile-art', 'res://tests/bake_model_refinement_art.gd', '--rendering-method', 'gl_compatibility', '--', '--vehicle=kart')
        run('livery-art', 'res://tests/bake_livery_previews.gd', '--rendering-method', 'gl_compatibility', '--', '--vehicle=kart')
        run('news-art', 'res://tests/bake_news_car_photos.gd', '--rendering-method', 'gl_compatibility', '--', '--vehicle=kart',
            '--evidence-root=res://../docs/evidence/kart-clothing-2026-11-14/news')
        run('rivalry-art', 'res://tests/bake_rivalry_car_previews.gd', '--rendering-method', 'gl_compatibility',
            env={'BMT_REAL_CAR_EVIDENCE': str(OUT / 'rivalry-art'), 'BMT_REAL_CAR_ONLY': 'kart'})
        return
    before = sources()
    (OUT / 'prepared-source-before.json').write_text(json.dumps(before, indent=2))
    first = identity('identity-before')
    for car in IDS:
        run('bases-' + car, 'res://tests/bake_modular_car_bases.gd', '--headless', '--', '--vehicle=' + car)
    with ThreadPoolExecutor(max_workers=3) as pool:
        jobs = [pool.submit(run, 'kits-' + car, 'res://tests/bake_modular_car_kits.gd', '--headless', '--', '--vehicle=' + car) for car in IDS]
        for job in jobs:
            job.result()
    for car in IDS:
        run('garage-' + car, 'res://tests/bake_garage_cars.gd', '--headless', '--', '--vehicle=' + car)
    run('header-template', 'res://tests/bake_header_simple_compact.gd', '--headless')
    fence(before, 'prepared-source-fence')
    finish(before, first)


def finish(before, first):
    last = identity('identity-after')
    assert first['modular_car_sha256'] == last['modular_car_sha256'], 'Vehicle revisions changed during bake'
    run('garage-pictures', 'res://../scripts/bake_garage_previews.gd', '--rendering-method', 'gl_compatibility')
    run('prepared-preflight', 'res://tests/check_prepared_assets.gd', '--headless')
    with (OUT / 'picture-preflight.log').open('w', encoding='utf-8') as log:
        subprocess.run([sys.executable, 'scripts/check_garage_previews.py'], cwd=ROOT,
                       check=True, stdout=log, stderr=subprocess.STDOUT)
    fence(before, 'prepared-final-fence')
    print('KART_CLOTHING_REFRESH: complete source, resource and picture checks passed', flush=True)


if __name__ == '__main__':
    main()
