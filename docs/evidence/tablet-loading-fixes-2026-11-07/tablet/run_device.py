"""Install, exercise and restore the temporary phase-profiling client."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
import zipfile

from device import ADB, EVIDENCE, MARKER, OUT, PACKAGE, REMOTE, ROOT, SERIAL, adb, context, launch, manifest, unlocked

STOCK = '0.3.0-creator.e14bec0e820302b39bbb8c16684bda60'
TEMP_APK = '/data/local/tmp/bmt-loadfix-20261107.apk'
TEMP_RESTORE = '/data/local/tmp/bmt-loadfix-20261107-restore.apk'


def export_info():
    value = json.loads((OUT/'profiled-export.json').read_text())
    assert value['exit_code']==0
    assert set(value['source_changes']) <= {'game/core/build_identity.gd','game/project.godot'}
    return value


def identity_check():
    base = OUT/'candidate/game/core/build_identity.gd'
    current = OUT/'profiled/game/core/build_identity.gd'
    keys = ['CHECKPOINT_LAYOUT_SHA256','GARAGE_PREVIEW_SHA256','GARAGE_PREVIEW_VEHICLE_SHA256','MODULAR_CAR_SHA256','HEADER_PREVIEW_SHA256']
    a = base.read_text()
    b = current.read_text()
    rows = {}
    for key in keys:
        pattern = r'^const '+key+r':[^=]+=(.+)$'
        old = re.search(pattern,a,re.M).group(1).strip()
        new = re.search(pattern,b,re.M).group(1).strip()
        assert old==new,key
        rows[key] = old
    (EVIDENCE/'preserved-cache-identities.json').write_text(json.dumps(rows,indent=2)+'\n')


def install():
    value = export_info()
    identity_check()
    original = json.loads((EVIDENCE/'original.json').read_text())
    before = context()
    if before['version']!=STOCK:
        previous = json.loads((EVIDENCE/'temporary-install.json').read_text())
        assert before['version']==previous['after']['version'],before
        installed = adb('shell','pm','path',PACKAGE).strip().removeprefix('package:')
        assert adb('shell','sha256sum',installed,timeout=180).split()[0]==previous['apk']['sha256']
        (OUT/'superseded-temporary-install.json').write_text(json.dumps(previous,indent=2)+'\n')
    path = Path(value['apk']['path'])
    assert hashlib.sha256(path.read_bytes()).hexdigest()==value['apk']['sha256']
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None
        assert {name.split('/')[1] for name in archive.namelist() if name.startswith('lib/') and name.endswith('.so')}=={'arm64-v8a'}
    # Transfer while the normal app still owns its awake window; commit is short.
    adb('push',str(path),TEMP_APK,timeout=180)
    result = adb('shell','pm','install','-r','-t',TEMP_APK,timeout=180)
    assert 'Success' in result,result
    after = context()
    assert after['version']==value['build_id'] and after['first_install']==original['context']['first_install']
    (EVIDENCE/'temporary-install.json').write_text(json.dumps({'before':before,'after':after,'apk':value['apk'],'result':result},indent=2)+'\n')
    print('PROFILING_CLIENT_INSTALLED '+after['version'],flush=True)


def marker(options):
    assert re.fullmatch(r'[a-z][a-z0-9_-]{0,63}',options['run'])
    adb('shell','run-as',PACKAGE,'test','-e',MARKER,check=False)
    # adb return status is available in the module receipt; stdout alone cannot distinguish test outcomes.
    import device
    assert device.commands[-1]['exit_code']==1,'Existing marker must be investigated, not overwritten'
    local = OUT/(options['run']+'-config.json')
    local.write_text(json.dumps(options))
    remote = '/data/local/tmp/bmt-loadfix-20261107-'+options['run']+'.json'
    adb('push',str(local),remote)
    adb('shell','run-as',PACKAGE,'cp',remote,MARKER)
    adb('shell','rm',remote)


def collect(label, options):
    destination = EVIDENCE/(label+'.json')
    if destination.exists():
        existing = json.loads(destination.read_text())
        assert not existing['report']['failures'] and existing['report']['dropped_events']==0
        print('RETAINED_VALID_RUN '+label,flush=True)
        return
    before = context()
    assert before['version']==export_info()['build_id']
    if not unlocked(): raise RuntimeError('OWNER_UNLOCK_REQUIRED')
    marker({'schema':1,'run':label,**options})
    startup = launch(label+'-launch')
    pid = startup['pid']
    deadline = time.monotonic()+900
    completion = None
    lines = []
    while time.monotonic()<deadline:
        text = adb('logcat','-d','-v','brief','--pid='+pid)
        lines = [line for line in text.splitlines() if re.search(r'TABLET_PHASE_|APP_READY|GARAGE_LIVE_READY|ERROR:|FATAL EXCEPTION|Fatal signal',line)]
        completion = next((line for line in lines if 'TABLET_PHASE_COMPLETE' in line),None)
        fatal = [line for line in lines if re.search(r'SCRIPT ERROR|SHADER ERROR|Parse Error|FATAL EXCEPTION|Fatal signal',line)]
        if fatal: raise RuntimeError('Diagnostic runtime error: '+str(fatal))
        if completion: break
        time.sleep(1)
    (OUT/(label+'-filtered.log')).write_text('\n'.join(lines)+'\n')
    assert completion,'Profiling run did not complete'
    raw = adb('exec-out','run-as',PACKAGE,'cat',REMOTE+'/'+label+'/result.json',binary=True)
    report = json.loads(raw)
    (OUT/(label+'-raw-result.json')).write_bytes(raw)
    assert report['run']==label and report['mode']==options['mode']
    assert report['checks']>0 and not report['failures'] and report['dropped_events']==0
    initial = next(row for row in report['rows'] if row['kind']=='startup')
    assert initial['screen']!='restoring','Transient restoring screen is not accepted as menu content'
    assert report['renderer']=='gl_compatibility'
    value = {'before':before,'after':context(),'startup':startup,'report':report,
             'existing_startup_warning':[line for line in lines if 'Parent node is busy' in line]}
    destination.write_text(json.dumps(value,indent=2)+'\n')
    print(json.dumps({'run':label,'checks':report['checks'],'rows':len(report['rows']),
                      'temperature':value['after']['battery_temperature_c'],
                      'thermal_status':value['after']['thermal_status']}),flush=True)


def measure():
    assert context()['version']==export_info()['build_id']
    # These controls measure observer startup cost with the marker absent.
    for label in ['inactive-startup-a','inactive-startup-b']:
        if not (EVIDENCE/(label+'.json')).exists():
            print(json.dumps(launch(label)),flush=True)
            time.sleep(10)
    cases = [('profile-startup-a',{'mode':'startup'}),('profile-startup-b',{'mode':'startup'}),
             ('profile-menus-a',{'mode':'menus'}),('profile-menus-b',{'mode':'menus'}),
             ('profile-races-a',{'mode':'races'}),('profile-races-b',{'mode':'races'})]
    for label,options in cases:
        collect(label,options)
        time.sleep(2)
    print('DEVICE_PHASE_MATRIX_COMPLETE',flush=True)


def restore():
    original = json.loads((EVIDENCE/'original.json').read_text())
    path = OUT/'original-installed.apk'
    assert hashlib.sha256(path.read_bytes()).hexdigest()==original['apk_sha256']
    # Preserve all task data locally; it includes private preference copies and is never published.
    data = adb('exec-out','run-as',PACKAGE,'tar','-cf','-',REMOTE,binary=True,timeout=180,check=False)
    if data:
        (OUT/'device-diagnostic-data-private.tar').write_bytes(data)
    adb('push',str(path),TEMP_RESTORE,timeout=180)
    result = adb('shell','pm','install','-r','-t',TEMP_RESTORE,timeout=180)
    assert 'Success' in result,result
    after = context()
    assert after['version']==STOCK and after['first_install']==original['context']['first_install']
    installed = adb('shell','pm','path',PACKAGE).strip().removeprefix('package:')
    assert adb('shell','sha256sum',installed,timeout=180).split()[0]==original['apk_sha256']
    # Restore the normal awake app window promptly, before slower file audits.
    restored_startup = launch('restored-startup') if unlocked() else None
    # Delete only paths absent from the original game manifest and owned by this task.
    before = json.loads((OUT/'before-private.json').read_text())
    assert not any(name.startswith(REMOTE+'/') or name==MARKER for name in before)
    resolved = adb('shell','run-as',PACKAGE,'realpath',REMOTE,check=False).strip()
    if resolved:
        assert resolved.endswith('/'+PACKAGE+'/'+REMOTE) and '/files/tablet-loading-fixes-20261107' in resolved,resolved
        adb('shell','run-as',PACKAGE,'rm','-r',REMOTE)
    adb('shell','run-as',PACKAGE,'test','-e',MARKER,check=False)
    import device
    if device.commands[-1]['exit_code']==0:
        content = json.loads(adb('exec-out','run-as',PACKAGE,'cat',MARKER))
        assert str(content.get('run','')).startswith('profile-')
        adb('shell','run-as',PACKAGE,'rm',MARKER)
    adb('shell','rm','-f',TEMP_APK,TEMP_RESTORE)
    current = manifest('after')
    authored = [name for name in before if '/tracks/' in name and name.endswith('.json') and '/.backend/' not in name]
    authored_changed = [name for name in authored if current.get(name)!=before[name]]
    assert not authored_changed,authored_changed
    # Compare stored PB dictionaries, allowing legitimate settings/session/cache refreshes.
    pb_checks = json.loads((OUT/'record-paths-private.json').read_text())
    for index,name in enumerate(pb_checks):
        old = json.loads((OUT/('before-records-'+str(index)+'-private.json')).read_bytes())
        new = json.loads(adb('exec-out','run-as',PACKAGE,'cat',name,binary=True))
        assert old['records']==new['records'],'Personal-best dictionary changed'
    receipt = {'stock_apk_restored':True,'version':after['version'],'apk_sha256':original['apk_sha256'],
               'first_install_preserved':True,'authored_tracks_checked':len(authored),
               'authored_tracks_unchanged':True,'before_files':len(before),'after_files':len(current),
               'changed_existing_files':[name for name in before if current.get(name)!=before[name]],
               'personal_best_dictionaries_checked':len(pb_checks),'personal_bests_unchanged':True,
               'normal_startup_verified':restored_startup is not None,
               'screen_awake_setting':adb('shell','settings','get','global','stay_on_while_plugged_in').strip()}
    (OUT/'restore-private.json').write_text(json.dumps(receipt,indent=2)+'\n')
    receipt.pop('changed_existing_files')
    (EVIDENCE/'restoration.json').write_text(json.dumps(receipt,indent=2)+'\n')
    if restored_startup is not None:
        print(json.dumps(restored_startup),flush=True)
    print('NORMAL_CLIENT_RESTORED',flush=True)


if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action',choices=['install','measure','restore'])
    args = parser.parse_args()
    {'install':install,'measure':measure,'restore':restore}[args.action]()
