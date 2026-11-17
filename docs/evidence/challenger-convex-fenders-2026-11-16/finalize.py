"""Retain final evidence and verify every published input before task cleanup."""
from pathlib import Path
import gzip,hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;BUILD=ROOT/'build'/OUT.name
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
prep=json.loads((OUT/'preparation-command.json').read_text())
assert prep['exit_code']==0 and prep['stable']
assert all(sha(Path(path))==digest for path,digest in prep['after'].items())
publication=json.loads((OUT/'native-publication.json').read_text())
assert all(sha(ROOT/'game/assets/vehicles/challenger_hellcat_v1'/name)==digest for name,digest in publication['private_native'].items())
start=json.loads((OUT/'task-start.json').read_text())
protected={path:digest for path,digest in start.items() if path.startswith('game/resources/cars/') or path in ['game/vehicle/vehicle_simulation.gd','game/vehicle/handling_config.gd'] or Path(path).name.startswith('legacy_')}
protected.update({path:digest for path,digest in start.items() if path.startswith('scripts/') and path!='scripts/prepare_challenger.py'})
# The four unused native resources are outside the current manifest allowlist.
protected.update({path:digest for path,digest in start.items() if path.startswith('game/assets/vehicles/challenger_hellcat_v1/') and Path(path).suffix=='.res' and Path(path).name not in publication['private_native']})
assert all(sha(ROOT/path)==digest for path,digest in protected.items())
checkpoint=json.loads((OUT/'source-checkpoint.json').read_text())
assert all(sha(ROOT/path)==digest for path,digest in checkpoint['after'].items())
assets=BUILD/'assets'
fence=json.loads((assets/'source-receipt.json').read_text())
assert fence['before']==fence['after'] and not fence['changed']
assert all(sha(ROOT/path)==digest for path,digest in fence['after'].items())
labels=['native-bake','allocation','candidate-contours','fitted-hood','fitted-profile','modules','physics','wash','driving','production-parse','prepared-complete','prepared-scoped']
labels += [row['label'] for row in json.loads((OUT/'gpu-checks.json').read_text())]
for label in labels:assert json.loads((OUT/(label+'-command.json')).read_text())['exit_code']==0,label
for name in ['candidate-shape.json','candidate-seams-corners.json']:
 assert json.loads((OUT/name).read_text())['failures']==0
for name in ['baseline','candidate']:
 raw=(BUILD/(name+'.json')).read_bytes();target=OUT/(name+'-native.json.gz')
 with gzip.GzipFile(filename=str(target),mode='wb',mtime=0) as stream:stream.write(raw)
 assert gzip.decompress(target.read_bytes())==raw
for source,target in [(BUILD/'views-before/mobile/simple',OUT/'before'),(BUILD/'views-before-gl/gl_compatibility/simple',OUT/'before-gl'),(BUILD/'views-final',OUT/'final'),(BUILD/'views-final-close',OUT/'final-full'),(BUILD/'views-highlights',OUT/'highlights'),(BUILD/'opacity',OUT/'opacity'),(BUILD/'app',OUT/'app')]:
 if source.exists():shutil.copytree(source,target,dirs_exist_ok=True)
for name in ['source-receipt.json','client-build-identity.json','prepared.log','picture-preflight.log']:
 shutil.copyfile(assets/name,OUT/('final-'+name))
shutil.copyfile(BUILD/'converted/manifest.json',OUT/'conversion-manifest.json')
for label,directory in [('before-metadata',BUILD/'before/game/assets/vehicles/challenger_hellcat_v1'),('native-metadata',ROOT/'game/assets/vehicles/challenger_hellcat_v1')]:
 destination=OUT/label;destination.mkdir(exist_ok=True)
 for name in ['manifest.json','source.json','hood_profile.json','bonnet_contour.json']:
  shutil.copyfile(directory/name,destination/name)
result={'protected_inputs':len(protected),'protected_sha256':protected,'final_input_count':len(fence['after']),
 'final_input_fence_stable':True,'native_resources_current':len(publication['private_native']),
 'source_checkpoint_current':True,'required_command_receipts':labels,
 'physical_phone_test_performed':False}
(OUT/'final-verification.json').write_text(json.dumps(result,indent=2))
print('CHALLENGER_FINAL_VERIFICATION',len(protected),'protected inputs;',len(fence['after']),'stable inputs; final evidence retained')
