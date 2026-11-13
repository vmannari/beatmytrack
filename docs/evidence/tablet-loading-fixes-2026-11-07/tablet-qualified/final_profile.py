"""Qualify the final three changes after rejecting the startup deferral."""
import hashlib
import json
import zipfile
from pathlib import Path
import device
import run_device

e = device.EVIDENCE
out = device.OUT
final = e.parent/'tablet-final'
final.mkdir(exist_ok=True)
info = run_device.export_info()
control = json.loads((e/'control/install.json').read_text())
before = device.context()
assert before['version']==control['after']['version']
installed = device.adb('shell','pm','path',device.PACKAGE).strip().removeprefix('package:')
assert device.adb('shell','sha256sum',installed,timeout=180).split()[0]==control['apk']['sha256']
assert device.unlocked(), 'OWNER_UNLOCK_REQUIRED'
path = Path(info['apk']['path'])
assert hashlib.sha256(path.read_bytes()).hexdigest()==info['apk']['sha256']
with zipfile.ZipFile(path) as archive:
    assert archive.testzip() is None
initial = json.loads((out/'before-private.json').read_text())
assert not any(p.startswith(device.REMOTE+'/') for p in initial)
saved = device.adb('exec-out','run-as',device.PACKAGE,'tar','-cf','-',device.REMOTE,binary=True,timeout=180)
(out/'rejected-deferral-device-data-private.tar').write_bytes(saved)
resolved = device.adb('shell','run-as',device.PACKAGE,'realpath',device.REMOTE).strip()
assert resolved.endswith('/'+device.PACKAGE+'/'+device.REMOTE)
device.adb('shell','run-as',device.PACKAGE,'rm','-r',device.REMOTE)
remote = '/data/local/tmp/bmt-loadfix-20261107.apk'
device.adb('push',str(path),remote,timeout=180)
device.EVIDENCE = final
run_device.EVIDENCE = final
run_device.identity_check()
device.OUT = out/'final-profile'
device.OUT.mkdir(exist_ok=True)
run_device.OUT = device.OUT
run_device.export_info = lambda: info
result = device.adb('shell','pm','install','-r','-t',remote,timeout=180)
assert 'Success' in result
# Restore the app's awake window immediately; no slow manifest in this gap.
ready = device.launch('inactive-startup-a')
after = device.context()
assert after['version']==info['build_id'] and after['first_install']==before['first_install']
installed = device.adb('shell','pm','path',device.PACKAGE).strip().removeprefix('package:')
assert device.adb('shell','sha256sum',installed,timeout=180).split()[0]==info['apk']['sha256']
(final/'install.json').write_text(json.dumps({'before':before,'after':after,'apk':info['apk'],
    'previous_diagnostics_archived':True,'task_race_cache_starts_empty':True,
    'full_prelaunch_manifest_compared':False},indent=2)+'\n')
run_device.measure()
for label,forced in [('fit-cold-a',True),('fit-reuse-a',False),('fit-reuse-b',False),('fit-cold-b',True)]:
    run_device.collect(label,{'mode':'races','fitted_compact':True,'force_car_cache_miss':forced,
        'cache_label':'fit-cold' if forced else 'fit-reuse'})
print('FIXED_FIT_ABBA_COMPLETE',flush=True)
