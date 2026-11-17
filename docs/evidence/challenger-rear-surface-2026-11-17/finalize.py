from pathlib import Path
import gzip,hashlib,json,shutil,zipfile
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
build=root/'build'/out.name
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
prep=json.loads((out/'preparation-command.json').read_text())
assert prep['exit_code']==0 and prep['stable'] and all(sha(Path(p))==h for p,h in prep['after'].items())
checkpoint=json.loads((out/'source-checkpoint.json').read_text())
assert all(sha(root/p)==h for p,h in checkpoint['after'].items())
publication=json.loads((out/'native-publication.json').read_text())
assert all(sha(root/'game/assets/vehicles/challenger_hellcat_v1'/name)==h for name,h in publication['private_native'].items())
fence=json.loads((build/'assets/source-receipt.json').read_text())
assert not fence['changed'] and all(sha(root/p)==h for p,h in fence['after'].items())
labels=['native-bake','candidate-export','candidate-trunk','allocation','candidate-contours','corner-qualified-mobile','corner-pixels','app-mobile-verbose-repeat','coarse','livery','portraits','fitted-hood','fitted-profile','modules','physics','wash','driving','production-parse','prepared-scoped']
labels += [r['label'] for r in json.loads((out/'gpu-checks.json').read_text())]
for label in labels:
 receipt=json.loads((out/(label+'-command.json')).read_text())
 assert receipt['exit_code']==0,label
 pins=json.loads((out/'input-pins'/(receipt['source_pin_sha256']+'.json')).read_text())
 assert all(pins[path]==digest for path,digest in checkpoint['after'].items()),label+' must use the final source'
assert not json.loads((out/'corner-pixels.json').read_text())['corner-qualified']
repeat=(out/'app-mobile-verbose-repeat.log').read_text()
assert 'ObjectDB instances were leaked' not in repeat and 'resources still in use' not in repeat and 'SCRIPT ERROR:' not in repeat
assert json.loads((out/'candidate-rear.json').read_text())['failures']==0
assert json.loads((out/'candidate-trunk.json').read_text())['failures']==0
for name in ['baseline','candidate']:
 raw=(build/(name+'.json')).read_bytes()
 target=out/(name+'-native.json.gz')
 target.write_bytes(gzip.compress(raw))
 assert gzip.decompress(target.read_bytes())==raw
for name in ['views-before-matched','views-final','views-corner-qualified','views-mark-diagnostic','opacity','app']:
 source=build/name
 if source.is_dir():shutil.copytree(source,out/name,dirs_exist_ok=True)
asset_out=out/'asset-build';asset_out.mkdir(exist_ok=True)
for p in (build/'assets').iterdir():
 if p.is_file() and p.suffix in ['.json','.log']:shutil.copyfile(p,asset_out/p.name)
shutil.copyfile(build/'converted/manifest.json',out/'conversion-manifest.json')
for folder,source in [('before-metadata',build/'before-native'),('native-metadata',root/'game/assets/vehicles/challenger_hellcat_v1')]:
 target=out/folder;target.mkdir(exist_ok=True)
 for p in source.glob('*.json'):shutil.copyfile(p,target/p.name)
archive=out/'before-native.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as zipped:
 for p in (build/'before-native').iterdir():zipped.write(p,p.name)
with zipfile.ZipFile(archive) as zipped:
 assert all(zipped.read(p.name)==p.read_bytes() for p in (build/'before-native').iterdir())
result={'source_files_exact':True,'native_publication_exact':True,'stable_vehicle_inputs':len(fence['after']),'complete_preflight':json.loads((out/'prepared-complete-command.json').read_text()),'validated_jobs':len(labels),'private_checkpoint':checkpoint['private_commit'],'before_native_zip_sha256':sha(archive),'device_test_performed':False}
(out/'final-verification.json').write_text(json.dumps(result,indent=2))
print('REAR_FINAL_VERIFICATION',len(fence['after']),'stable inputs;',len(labels),'validated jobs')
