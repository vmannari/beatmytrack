"""Audit the installed normal client; retain the failed strict appearance comparison."""
import hashlib
import json
import zipfile
from pathlib import Path
import device

E,OUT = device.EVIDENCE,device.OUT
normal = json.loads((OUT/'qualified-export.json').read_text())
original = json.loads((E/'original.json').read_text())
after = device.context()
assert after['version']==normal['build_id']
assert after['first_install']==original['context']['first_install']
installed = device.adb('shell','pm','path',device.PACKAGE).strip().removeprefix('package:')
assert device.adb('shell','sha256sum',installed,timeout=180).split()[0]==normal['apk']['sha256']
with zipfile.ZipFile(normal['apk']['path']) as archive,zipfile.ZipFile(OUT/'original-installed.apk') as old:
    assert archive.testzip() is None
    libs=[p for p in archive.namelist() if p.startswith('lib/') and p.endswith('.so')]
    assert libs and all(p.startswith('lib/arm64-v8a/') and archive.read(p)==old.read(p) for p in libs)
    package={'entries':len(archive.namelist()),'crc_valid':True,'arm64_only':True,'native_libraries_unchanged':True}
initial=json.loads((OUT/'before-private.json').read_text())
current=device.manifest('final-audited')
assert not any(p==device.MARKER or p.startswith(device.REMOTE+'/') or p.startswith('files/tablet-phase-20261107/') for p in current)
authored=[p for p in initial if '/tracks/' in p and p.endswith('.json') and '/.backend/' not in p]
assert all(current.get(p)==initial[p] for p in authored)
paths=json.loads((OUT/'record-paths-private.json').read_text())
differences=[]
livery_differences=[]
for index,path in enumerate(paths):
    old=json.loads((OUT/('before-records-'+str(index)+'-private.json')).read_bytes())
    new=json.loads(device.adb('exec-out','run-as',device.PACKAGE,'cat',path,binary=True))
    assert old['records']==new['records']
    for setting in ['selected_car','simple_car_models','vehicle_livery']:
        assert old['settings'].get(setting)==new['settings'].get(setting),setting
    old_liveries=old['settings'].get('vehicle_liveries',{})
    new_liveries=new['settings'].get('vehicle_liveries',{})
    for car in old_liveries.keys()|new_liveries.keys():
        if old_liveries.get(car)==new_liveries.get(car): continue
        assert car=='compact'
        old_ack=old['settings'].get('vehicle_appearance_sync',{}).get('baseline',{}).get(car,{}).get('livery')
        new_ack=new['settings'].get('vehicle_appearance_sync',{}).get('baseline',{}).get(car,{}).get('livery')
        assert old_ack==old_liveries[car] and new_ack==new_liveries[car]
        livery_differences.append({'vehicle':car,'changed_fields':['colors.body','colors.detail','colors.accent','pattern'],
            'before_matches_acknowledged_sync':True,'after_matches_acknowledged_sync':True})
    a,b=old['settings'].get('vehicle_customisation',{}),new['settings'].get('vehicle_customisation',{})
    for car in a.keys()|b.keys():
        if a.get(car)==b.get(car):continue
        fields=[k for k in a.get(car,{}).keys()|b.get(car,{}).keys() if a.get(car,{}).get(k)!=b.get(car,{}).get(k)]
        old_ack=old['settings'].get('vehicle_appearance_sync',{}).get('baseline',{}).get(car,{}).get('customisation')
        new_ack=new['settings'].get('vehicle_appearance_sync',{}).get('baseline',{}).get(car,{}).get('customisation')
        differences.append({'vehicle':car,'changed_fields':fields,'before':a.get(car),'after':b.get(car),
            'before_matches_acknowledged_sync':old_ack==a.get(car),'after_matches_acknowledged_sync':new_ack==b.get(car)})
assert len(differences)<=1
if differences:
    assert differences[0]['vehicle']=='compact' and differences[0]['changed_fields']==['body']
    assert differences[0]['before']['body']=='wide' and differences[0]['after']['body']=='rally'
    assert differences[0]['after_matches_acknowledged_sync']
receipt={'before':json.loads((E.parent/'tablet-final/install.json').read_text())['after'],'after':after,
    'apk':normal['apk'],'package':package,'first_install_preserved':True,
    'authored_tracks_checked':len(authored),'authored_tracks_unchanged':True,
    'pb_dictionaries_checked':len(paths),'pb_dictionaries_unchanged':True,
    'selected_car_and_simple_preference_unchanged':True,'liveries_unchanged':not livery_differences,
    'saved_car_fit_and_simple_preference_unchanged':not differences,
    'appearance_differences':differences,'livery_differences':livery_differences,
    'strict_initial_preference_audit':'failed and retained: Compact body and livery differ' if differences or livery_differences else 'passed',
    'appearance_change_cause_not_attributed':True,'current_acknowledged_appearance_preserved':True,
    'diagnostics_removed':True,'normal_startup_verified':(E/'normal-startup.json').exists(),
    'full_prelaunch_manifest_compared':False,'initial_files':len(initial),'final_files':len(current),
    'screen_awake_setting':device.adb('shell','settings','get','global','stay_on_while_plugged_in').strip()}
(E/'normal-deployment.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt),flush=True)
