"""Import refreshed native vehicle pictures and verify each imported source digest."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/kart-clothing-2026-11-14'
PROFILE = ROOT / 'build/kart-clothing-2026-11-14/import-profile'
for name in ['roaming', 'local']:
    (PROFILE / name).mkdir(parents=True, exist_ok=True)
env = dict(os.environ, APPDATA=str(PROFILE / 'roaming'), LOCALAPPDATA=str(PROFILE / 'local'),
           BMT_API_URL='', BMT_DEV_AUTH_KEY='')
project = ROOT / 'game/project.godot'
project_before = hashlib.sha256(project.read_bytes()).hexdigest()
engine = r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
assert subprocess.check_output([engine, '--version'], text=True).strip() == (ROOT / 'godot-version.txt').read_text().strip()
command = [engine, '--headless', '--editor', '--import', '--path', str(ROOT / 'game'), '--audio-driver', 'Dummy']
started = time.monotonic()
with (OUT / 'image-import.log').open('w', encoding='utf-8') as log:
    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT,
                               creationflags=subprocess.CREATE_NO_WINDOW)
    (OUT / 'image-import-process.json').write_text(json.dumps({'pid': process.pid, 'command': command}))
    try:
        code = process.wait(timeout=300)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
        raise
assert code == 0, code
assert hashlib.sha256(project.read_bytes()).hexdigest() == project_before, 'Editor changed project settings'
images = []
for car in ['kart']:
    images += list((ROOT / 'game/assets/liveries/previews_v2' / car).glob('*.png'))
    images += [ROOT / 'game/assets/menu' / (car + '_illustration_v1.png'),
               ROOT / 'game/assets/menu/header_cars_v1' / (car + '.png'),
               ROOT / 'game/assets/news/vehicles' / (car + '.png'),
               ROOT / 'game/assets/garage/previews_v1' / (car + '.png')]
rows = []
images += [ROOT / 'game/assets/garage/previews_v1' / (car + '.png')
           for car in ['compact', 'electric', 'forklift', 'hovercraft', 'super_rally']]
for picture in images:
    metadata = Path(str(picture) + '.import').read_text()
    match = re.search(r'path="res://([^\"]+\.ctex)"', metadata)
    assert match, picture
    imported = ROOT / 'game' / match[1]
    checksum = imported.with_suffix('.md5').read_text()
    digest = hashlib.md5(picture.read_bytes()).hexdigest()
    assert imported.is_file() and f'source_md5="{digest}"' in checksum, picture
    rows.append({'path': picture.relative_to(ROOT).as_posix(), 'source_md5': digest})
content = (OUT / 'image-import.log').read_text(encoding='utf-8', errors='replace')
diagnostics = [line for line in content.splitlines() if line.startswith(('ERROR:', 'SCRIPT ERROR:'))]
rivalry = json.loads((OUT / 'rivalry-art/bake.json').read_text())
rivalry_rows = []
for car, record in rivalry['cars'].items():
    for role, digest in record['hashes'].items():
        texture = ROOT / 'game/assets/menu/rivalry_cars_v2' / (car + '_' + role + '.res')
        assert hashlib.sha256(texture.read_bytes()).hexdigest() == digest, texture
        rivalry_rows.append({'path': texture.relative_to(ROOT).as_posix(), 'sha256': digest})
receipt = {'exit_code': code, 'verified_images': len(rows), 'seconds': time.monotonic() - started,
           'verified_rivalry_textures': len(rivalry_rows), 'rivalry_textures': rivalry_rows,
           'project_settings_exact': True, 'editor_diagnostics': diagnostics, 'images': rows}
(OUT / 'image-import-receipt.json').write_text(json.dumps(receipt, indent=2))
print(json.dumps({k: v for k, v in receipt.items() if k not in ['images', 'rivalry_textures']}, indent=2))
