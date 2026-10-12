import hashlib,json,shutil
from pathlib import Path
def hashes(folder):
 return {str(p.relative_to(folder)):hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.rglob('*') if p.is_file() and '__pycache__' not in p.parts and '.godot' not in p.parts}
backend=Path('/app/bmt_backend');game=Path('/opt/bmt');source=Path('/tmp/studio-source')
original_game=hashes(game);original_backend=hashes(backend)
for name,expected in json.loads(Path('/tmp/studio-baseline.json').read_text()).items():
 assert hashlib.sha256((backend/name).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==expected,('Unexpected live source',name)
for p in source.rglob('*'):
 if p.is_file():
  target=backend/p.relative_to(source);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
p=backend/'app.py';s=p.read_text();assert 'studio.router' not in s
needle='    from .verifier import GodotVerifier\n';assert s.count(needle)==1
s=s.replace(needle,needle+'    from . import studio\n')
needle='    app.include_router(admin_support.router)\n';assert s.count(needle)==1
s=s.replace(needle,needle+'    app.include_router(studio.router)\n');p.write_text(s)
for name in ('admin.py','studio.py','app.py'):compile((backend/name).read_text(),name,'exec')
import sys;sys.path.insert(0,'/app')
import bmt_backend.app,bmt_backend.studio
from bmt_backend.migrate import SCHEMA_HEAD
final_backend=hashes(backend);changed=sorted(k for k in final_backend if original_backend.get(k)!=final_backend[k])
expected=sorted(['app.py']+[str(p.relative_to(source)) for p in source.rglob('*') if p.is_file()])
assert changed==expected,(changed,expected)
assert original_game==hashes(game)
assert all(v==final_backend[k] for k,v in original_backend.items() if k not in changed)
Path('/app/studio-overlay-proof.json').write_text(json.dumps({'changed_files':changed,'canonical_unchanged':True,'canonical_files':len(original_game),'game_hashes':original_game,'schema':SCHEMA_HEAD,'backend_unchanged_files':len(original_backend)-len([k for k in changed if k in original_backend])}))
print('STUDIO_NINE_FILE_OVERLAY_VALID')
