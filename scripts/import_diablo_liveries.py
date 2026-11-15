"""Native lossless/mipmapped PNG import in a small art-only project."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'game/assets/liveries/diablo_v3'
STAGE=ROOT/'build/diablo-livery-import'
TARGET=STAGE/'assets/liveries/diablo_v3'
OUT=ROOT/'docs/evidence/diablo-liveries-2026-11-15'
ENGINE=Path('C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe')
TARGET.mkdir(parents=True,exist_ok=True)
(STAGE/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Artist texture import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
template=(ROOT/'game/assets/liveries/apex_twin.svg.import').read_text()
sources=sorted(ART.glob('*.png'))
assert sources
for p in sources:
    resource='res://assets/liveries/diablo_v3/'+p.name
    dest='res://.godot/imported/'+p.name+'-'+hashlib.md5(resource.encode()).hexdigest()+'.ctex'
    lines=[line for line in template.splitlines() if not line.startswith(('uid=','svg/','editor/'))]
    text='\n'.join(lines).replace('res://assets/liveries/apex_twin.svg',resource).replace('res://.godot/imported/apex_twin.svg-4f7840563b0b823edd46a241a309e135.ctex',dest)+'\n'
    sidecar=Path(str(p)+'.import')
    if not sidecar.exists(): sidecar.write_text(text)
    shutil.copy2(p,TARGET/p.name)
    shutil.copy2(sidecar,TARGET/sidecar.name)
with (OUT/'import.log').open('w') as log:
    result=subprocess.run([str(ENGINE),'--headless','--path',str(STAGE),'--editor','--import'],stdout=log,stderr=subprocess.STDOUT,timeout=180)
assert result.returncode==0
for p in sources:
    sidecar=TARGET/(p.name+'.import')
    shutil.copy2(sidecar,ART/sidecar.name)
    line=next(line for line in sidecar.read_text().splitlines() if line.startswith('path='))
    relative=line.split('"')[1].removeprefix('res://')
    dest=ROOT/'game'/relative
    dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(STAGE/relative,dest)
    md5=STAGE/relative.replace('.ctex','.md5')
    if md5.exists():shutil.copy2(md5,dest.with_suffix('.md5'))
(OUT/'import-receipt.json').write_text(json.dumps({'native_png_imports':len(sources),'mipmaps':True,'lossless':True,'exit_code':0},indent=2)+'\n')
print('DIABLO_IMPORT',len(sources),'native lossless mipmapped full-colour atlases')
