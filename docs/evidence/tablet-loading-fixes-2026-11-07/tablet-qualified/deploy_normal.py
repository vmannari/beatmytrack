"""Replace our temporary observer with the qualified normal client, preserving saves."""
import hashlib
import json
import zipfile
from pathlib import Path

from device import EVIDENCE, MARKER, OUT, PACKAGE, REMOTE, adb, context, launch, manifest, unlocked
from run_device import export_info, TEMP_APK


def main():
    normal = json.loads((OUT/'qualified-export.json').read_text())
    assert normal['exit_code']==0
    assert set(normal['source_changes']) <= {'game/core/build_identity.gd','game/project.godot'}
    profile = export_info()
    before = context()
    control_receipt = EVIDENCE/'control/install.json'
    if control_receipt.exists():
        control = json.loads(control_receipt.read_text())
        if before['version']==control['after']['version']:
            profile = {'build_id':control['after']['version'],'apk':control['apk']}
    assert before['version']==profile['build_id'], 'A newer/different client must be preserved'
    installed = adb('shell','pm','path',PACKAGE).strip().removeprefix('package:')
    assert adb('shell','sha256sum',installed,timeout=180).split()[0]==profile['apk']['sha256']
    assert unlocked(), 'OWNER_UNLOCK_REQUIRED'
    path = Path(normal['apk']['path'])
    assert hashlib.sha256(path.read_bytes()).hexdigest()==normal['apk']['sha256']
    with zipfile.ZipFile(path) as archive, zipfile.ZipFile(OUT/'original-installed.apk') as original:
        assert archive.testzip() is None
        libs = [name for name in archive.namelist() if name.startswith('lib/') and name.endswith('.so')]
        assert libs and all(name.startswith('lib/arm64-v8a/') for name in libs)
        assert all(archive.read(name)==original.read(name) for name in libs)
        package = {'entries':len(archive.namelist()),'crc_valid':True,'arm64_only':True,'native_libraries_unchanged':True}
    remote_apk = '/data/local/tmp/bmt-loadfix-20261107-normal.apk'
    adb('push',str(path),remote_apk,timeout=180)
    folders = [REMOTE]
    if control_receipt.exists(): folders.append('files/tablet-phase-20261107')
    for index,folder in enumerate(folders):
        archive = adb('exec-out','run-as',PACKAGE,'tar','-cf','-',folder,binary=True,timeout=180)
        (OUT/('device-diagnostic-data-'+str(index)+'-private.tar')).write_bytes(archive)
    initial_files = json.loads((OUT/'before-private.json').read_text())
    assert MARKER not in initial_files
    for folder in folders:
        assert not any(name.startswith(folder+'/') for name in initial_files)
        resolved = adb('shell','run-as',PACKAGE,'realpath',folder).strip()
        assert resolved.endswith('/'+PACKAGE+'/'+folder), resolved
        adb('shell','run-as',PACKAGE,'rm','-r',folder)
    adb('shell','run-as',PACKAGE,'test','-e',MARKER,check=False)
    import device
    if device.commands[-1]['exit_code']==0:
        marker = json.loads(adb('exec-out','run-as',PACKAGE,'cat',MARKER))
        assert str(marker.get('run','')).startswith('profile-')
        adb('shell','run-as',PACKAGE,'rm',MARKER)
    # Complete expensive audits while the app owns its awake window. Android's
    # 30-second secure timeout can expire across two full manifests plus install.
    files_before = manifest('before-normal-install')
    result = adb('shell','pm','install','-r','-t',remote_apk,timeout=180)
    assert 'Success' in result,result
    ready = launch('normal-startup')
    after = context()
    original = json.loads((EVIDENCE/'original.json').read_text())
    assert after['version']==normal['build_id']
    assert after['first_install']==original['context']['first_install']
    installed = adb('shell','pm','path',PACKAGE).strip().removeprefix('package:')
    assert adb('shell','sha256sum',installed,timeout=180).split()[0]==normal['apk']['sha256']
    adb('shell','rm','-f',remote_apk,TEMP_APK,'/data/local/tmp/bmt-loadfix-20261107-control.apk')
    current = manifest('final')
    authored = [name for name in initial_files if '/tracks/' in name and name.endswith('.json') and '/.backend/' not in name]
    assert all(current.get(name)==initial_files[name] for name in authored)
    pb_paths = json.loads((OUT/'record-paths-private.json').read_text())
    for index,name in enumerate(pb_paths):
        old = json.loads((OUT/('before-records-'+str(index)+'-private.json')).read_bytes())
        new = json.loads(adb('exec-out','run-as',PACKAGE,'cat',name,binary=True))
        assert old['records']==new['records'], 'Personal best dictionary changed'
        for setting in ['selected_car','simple_car_models','vehicle_customisation','vehicle_livery','vehicle_liveries']:
            assert old['settings'].get(setting)==new['settings'].get(setting), 'Saved car/preference changed: '+setting
    receipt = {'before':before,'after':after,'apk':normal['apk'],'package':package,
        'files_before_install':len(files_before),'full_prelaunch_manifest_compared':False,'first_install_preserved':True,
        'authored_tracks_checked':len(authored),'authored_tracks_unchanged':True,
        'pb_dictionaries_checked':len(pb_paths),'pb_dictionaries_unchanged':True,
        'saved_car_fit_and_simple_preference_unchanged':True,
        'diagnostics_removed':True,'normal_startup_verified':True,
        'initial_files':len(initial_files),'final_files':len(current),
        'screen_awake_setting':adb('shell','settings','get','global','stay_on_while_plugged_in').strip()}
    (EVIDENCE/'normal-deployment.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt),flush=True)


if __name__=='__main__': main()
