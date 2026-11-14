"""Publish four qualified shell resources, preserving every other live mesh."""
from pathlib import Path
import hashlib,json,os,shutil

ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
PRIVATE=ROOT/'build/challenger-surface-simplification-2026-11-14/native'
LIVE=ROOT/'game/assets/vehicles/challenger_hellcat_v1'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
controls=json.loads((OUT/'task-start.json').read_text())
comparison=json.loads((OUT/'native-comparison.json').read_text())
assert comparison['failures']==0 and comparison['checks']==120
conversion=json.loads((OUT/'preparation-command.json').read_text())
assert conversion['stable'] and conversion['exit_code']==0
assert all(sha(Path(p))==h for p,h in conversion['after'].items())
for name,h in controls.items():
    if name.startswith('game/assets/vehicles/challenger_hellcat_v1/') or name.startswith('game/resources/cars/') or name=='game/vehicle/super_rally_model.gd':
        assert sha(ROOT/name)==h,'Concurrent source/native write: '+name
names=['full_body_paint.res','simple_body_paint.res','full_body_contour.res','simple_body_contour.res','source.json','manifest.json']
before={name:(LIVE/name).read_bytes() for name in names}
published=[]
try:
    for name in names:
        backup=OUT/'before/game/assets/vehicles/challenger_hellcat_v1'/name
        if not backup.exists():backup.write_bytes(before[name])
        assert (LIVE/name).read_bytes()==before[name],'Concurrent output write: '+name
        temporary=LIVE/(name+'.challenger-surface-candidate')
        shutil.copyfile(PRIVATE/name,temporary)
        os.replace(temporary,LIVE/name)
        published.append(name)
except BaseException:
    for name in reversed(published):
        assert (LIVE/name).read_bytes()==(PRIVATE/name).read_bytes(),'Preserve concurrent output during rollback: '+name
        (LIVE/name).write_bytes(before[name])
    raise
unchanged={name:h for name,h in controls.items() if name.startswith('game/assets/vehicles/challenger_hellcat_v1/') and (ROOT/name).name not in names}
assert all(sha(ROOT/name)==h for name,h in unchanged.items())
(OUT/'native-publication.json').write_text(json.dumps({'published':{n:sha(LIVE/n) for n in names},'unchanged_native_controls':len(unchanged),'manifest_published_last':True},indent=2))
print('NATIVE_PUBLICATION: four shell resources and two manifests; all other native files exact')
