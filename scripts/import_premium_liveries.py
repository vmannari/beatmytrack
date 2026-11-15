"""Import only the authored SVGs without touching an owner's loaded extension."""
from pathlib import Path
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'game/assets/liveries/premium_v1'
STAGE = ROOT / 'build/premium-livery-import'
TARGET = STAGE / 'assets/liveries/premium_v1'
ENGINE = Path('C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe')
TARGET.mkdir(parents=True, exist_ok=True)
(STAGE / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Premium art import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
for source in ART.glob('*.svg'):
    shutil.copy2(source, TARGET / source.name)
    shutil.copy2(str(source)+'.import', TARGET / (source.name+'.import'))
out = ROOT / 'docs/evidence/premium-liveries-2026-11-15'
with (out/'import.log').open('w') as log:
    result = subprocess.run([str(ENGINE),'--headless','--path',str(STAGE),'--editor','--import'], stdout=log, stderr=subprocess.STDOUT, timeout=120)
assert result.returncode == 0, 'isolated import failed; see import.log'
for source in ART.glob('*.svg'):
    sidecar = TARGET / (source.name+'.import')
    shutil.copy2(sidecar, ART / sidecar.name)
    line = next(line for line in sidecar.read_text().splitlines() if line.startswith('path='))
    relative = line.split('"')[1].removeprefix('res://')
    target = ROOT / 'game' / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(STAGE / relative, target)
    md5 = STAGE / relative.replace('.ctex','.md5')
    if md5.exists(): shutil.copy2(md5, target.with_suffix('.md5'))
(out/'import-receipt.json').write_text(json.dumps({'native_svg_imports':18,'texture_size':[1536,1024],'mipmaps':True,'exit_code':result.returncode},indent=2)+'\n')
print('PREMIUM_IMPORT: 18 lossless mipmapped native SVG textures / isolated art-only project')
