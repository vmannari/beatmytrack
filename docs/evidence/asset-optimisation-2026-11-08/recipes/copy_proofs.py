from pathlib import Path
import shutil,hashlib,json
ROOT=Path(__file__).resolve().parents[2];WORK=Path(__file__).resolve().parent;EV=ROOT/'docs/evidence/asset-optimisation-2026-11-08'
for name in ['cars-gl_compatibility-prepared-final','cars-mobile-prepared-final']:
    shutil.copytree(WORK/'frozen/docs/evidence/asset-optimisation-2026-11-08'/name,EV/name,dirs_exist_ok=True)
shutil.copyfile(WORK/'frozen/source-hashes.json',EV/'qualified-source-hashes.json')
sources={}
for path in (WORK/'frozen/game').rglob('*'):
    if path.is_file() and '.godot' not in path.parts and path.suffix in ['.gd','.gdshader','.gdshaderinc','.tres']:
        sources[path.relative_to(WORK/'frozen').as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
(EV/'qualified-code-hashes.json').write_text(json.dumps(sources,indent=2)+'\n')
print('Copied native prepared proofs and exact isolated code pins.')
