"""Retain qualified native results, review images and a scoped task journal."""
from pathlib import Path
import gzip,hashlib,json,re,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;BUILD=ROOT/'build'/OUT.name
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda name:json.loads((OUT/name).read_text())
shape=read('candidate-shape.json');corners=read('candidate-seams-corners.json')
assert shape['failures']==0 and corners['failures']==0
prep=read('preparation-command.json');assert prep['exit_code']==0 and prep['stable']
assert all(sha(Path(p))==h for p,h in prep['after'].items())
pub=read('native-publication.json');assert all(sha(ROOT/'game/assets/vehicles/challenger_hellcat_v1'/n)==h for n,h in pub['private_native'].items())
checkpoint=read('source-checkpoint.json');assert checkpoint['forward_reverse_byte_exact']
assert all(sha(ROOT/n)==h for n,h in checkpoint['after'].items())
start=read('task-start.json')
controls={n:sha(ROOT/n)==h for n,h in start.items() if n.startswith('game/resources/cars/') or n in ['game/vehicle/handling_config.gd','game/vehicle/vehicle_simulation.gd']}
assert all(controls.values())
legacy={n:sha(ROOT/n)==h for n,h in start.items() if n.startswith('game/assets/vehicles/challenger_hellcat_v1/') and Path(n).name not in pub['private_native']}
assert len(legacy)==4 and all(legacy.values())
labels=['native-bake','candidate-export','allocation','candidate-contours','candidate-gl','coarse','livery','portraits','fitted-hood','fitted-profile','modules','physics','wash','driving','production-parse','prepared-scoped','opacity-gl','prepared-views-gl','opacity-mobile','prepared-views-mobile','prepared-close-gl','prepared-close-mobile','app-gl','app-mobile']
diagnostics={}
for label in labels:
 receipt=read(label+'-command.json');assert receipt['exit_code']==0 and receipt['script_errors']==0,label
 diagnostics[label]=[line for line in (OUT/(label+'.log')).read_text(errors='replace').splitlines() if line.startswith(('ERROR:','WARNING:')) or 'ObjectDB instances leaked' in line]
scope=read('delivery-scope.json');assert scope['challenger_scoped_passed']
fence=json.loads((BUILD/'assets/source-receipt.json').read_text());assert fence['before']==fence['after']
identity=json.loads((BUILD/'assets/client-build-identity.json').read_text(encoding='utf-8-sig'))
live=json.loads(re.search(r'MODULAR_CAR_SHA256: Dictionary = (\{[^\n]+\})',(ROOT/'game/core/build_identity.gd').read_text())[1])
assert live['super_rally']==identity['modular_car_sha256']['super_rally']
allocation=json.loads((OUT/'allocation.log').read_text().split('; ')[-1].strip())
assembled={('simple' if row['simple'] else 'full'):row['triangles'] for row in allocation}
stock=[int(v) for v in re.findall(r'COARSE_STOCK super_rally editable=\w+ triangles=(\d+)',(OUT/'coarse.log').read_text())]
retained={}
def keep(source,destination):
 destination.parent.mkdir(parents=True,exist_ok=True)
 if destination.suffix=='.gz':destination.write_bytes(gzip.compress(source.read_bytes(),compresslevel=9,mtime=0))
 else:shutil.copyfile(source,destination)
 retained[destination.relative_to(OUT).as_posix()]=sha(destination)
for name in ['baseline.json','candidate.json']:keep(BUILD/name,OUT/(name+'.gz'))
keep(BUILD/'converted/manifest.json',OUT/'conversion-manifest.json')
for renderer in ['gl_compatibility','mobile']:
 app=json.loads((BUILD/'app'/renderer/'acceptance.json').read_text());assert app['checks']==13 and app['failures']==0
 for name in ['white-owner-corner.png','white-hood-top.png','white-owner-side.png','white-nose-right.png','white-profile.png']:
  keep(BUILD/'views-final'/renderer/'simple'/name,OUT/'final'/renderer/name)
 for name in ['white-owner-corner.png','white-hood-top.png']:
  keep(BUILD/'views-final-close'/renderer/'full'/name,OUT/'final-full'/renderer/name)
 for source in (BUILD/'app'/renderer).rglob('*'):
  if source.is_file() and source.suffix in ['.png','.json']:keep(source,OUT/'final/app'/renderer/source.relative_to(BUILD/'app'/renderer))
for name in ['white-owner-corner.png','white-hood-top.png']:keep(BUILD/'views-before-corners/gl_compatibility/simple'/name,OUT/'before-corners'/name)
for name in ['white-owner-side.png','white-nose-right.png','white-profile.png']:keep(BUILD/'views-before/gl_compatibility/simple'/name,OUT/'before'/name)
for source in (BUILD/'assets').iterdir():
 if source.is_file() and source.suffix in ['.log','.json']:
  destination=OUT/'asset-receipts'/source.name
  if source.stat().st_size>500000:destination=Path(str(destination)+'.gz')
  keep(source,destination)
result={'hood_checks':shape['checks'],'seam_corner_checks':corners['checks'],'native_failures':0,'raw_assembled_triangles':assembled,'production_stock_triangles':stock,'configuration_simulation_exact':controls,'legacy_controls_exact':legacy,'bake_input_count':len(fence['after']),'complete_preflight_exit_code':scope['complete_preflight_exit_code'],'diagnostics':{k:v for k,v in diagnostics.items() if v},'source_checkpoint':checkpoint,'retained':retained}
(OUT/'final-state.json').write_text(json.dumps(result,indent=2))
print('HOOD_REDESIGN_FINAL',json.dumps({k:v for k,v in result.items() if k not in ['retained','source_checkpoint']}))
