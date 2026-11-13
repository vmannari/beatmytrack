import hashlib,json,shutil,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'build/tablet-phase-profile-20261107'
E=Path(__file__).resolve().parent
value=json.loads((OUT/'export-result.json').read_text())
profile=Path(value['apk']['path']);original=OUT/'original-installed.apk'
assert hashlib.sha256(profile.read_bytes()).hexdigest()==value['apk']['sha256']
with zipfile.ZipFile(profile) as archive,zipfile.ZipFile(original) as stock:
    assert archive.testzip() is None
    libs=[name for name in archive.namelist() if name.startswith('lib/') and name.endswith('.so')]
    shared={name:hashlib.sha256(archive.read(name)).hexdigest() for name in libs}
    assert all(name.startswith('lib/arm64-v8a/') for name in libs)
    assert all(hashlib.sha256(stock.read(name)).hexdigest()==digest for name,digest in shared.items())
    receipt={'apk':value['apk'],'build_id':value['build_id'],'zip_entries':len(archive.namelist()),
             'all_zip_crc_valid':True,'arm64_only':True,'native_libraries_byte_exact_to_normal_apk':True,'native_libraries':shared,
             'source_changes':value['source_changes']}
(E/'package.json').write_text(json.dumps(receipt,indent=2)+'\n')
shutil.copyfile(OUT/'export-result.json',E/'export-result.json')
shutil.copyfile(OUT/'isolated-current/game/diagnostics/tablet_phase_tracks.gd',E/'tablet_phase_tracks.gd')
settings=json.loads((OUT/'before-records-0-private.json').read_text())['settings']
vehicle=settings['selected_car']
context={'vehicle':vehicle,'simple_car_models':settings['simple_car_models'],
         'customisation':settings['vehicle_customisation'][vehicle],
         'source_inference':'Fitted simple models explicitly bypass modular restore; live rest-pose restoration rejects simple models. Both normal source guards are unchanged.',
         'source_hashes':{name:hashlib.sha256((OUT/'isolated-current/game'/name).read_bytes()).hexdigest()
                          for name in ['vehicle/car_visual.gd','vehicle/prepared_car_cache.gd','vehicle/modular_car_base.gd','backend/menu_snapshot_writer.gd']}}
(E/'rendering-context.json').write_text(json.dumps(context,indent=2)+'\n')
print(json.dumps({k:v for k,v in receipt.items() if k!='native_libraries'},indent=2))
