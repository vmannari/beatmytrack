"""Re-measure the previously accepted unmodified observer in the same device session."""
import hashlib
import json
import zipfile
from pathlib import Path
import device
import run_device

E = device.EVIDENCE
control = E/'control'
control.mkdir(exist_ok=True)
previous = json.loads((device.ROOT/'docs/evidence/tablet-phase-profile-2026-11-07/package.json').read_text())
candidate = run_device.export_info()
before = device.context()
assert before['version'] in (candidate['build_id'],previous['build_id'])
assert device.unlocked(), 'OWNER_UNLOCK_REQUIRED'
path = Path(previous['apk']['path'])
assert hashlib.sha256(path.read_bytes()).hexdigest()==previous['apk']['sha256']
with zipfile.ZipFile(path) as archive:
    assert archive.testzip() is None
remote_apk = '/data/local/tmp/bmt-loadfix-20261107-control.apk'
if before['version']==candidate['build_id']:
    device.adb('push',str(path),remote_apk,timeout=180)
    device.adb('shell','am','force-stop',device.PACKAGE)
    files_before = device.manifest('before-control-install')
    result = device.adb('shell','pm','install','-r','-t',remote_apk,timeout=180)
    assert 'Success' in result
    after = device.context()
    assert after['version']==previous['build_id'] and after['first_install']==before['first_install']
    files_after = device.manifest('after-control-install')
    assert files_before==files_after
    (control/'install.json').write_text(json.dumps({'before':before,'after':after,'apk':previous['apk'],'preserved_files':len(files_before)},indent=2)+'\n')
else:
    assert (control/'install.json').exists(), 'Only resume our verified control install'
installed = device.adb('shell','pm','path',device.PACKAGE).strip().removeprefix('package:')
assert device.adb('shell','sha256sum',installed,timeout=180).split()[0]==previous['apk']['sha256']
device.EVIDENCE = control
run_device.EVIDENCE = control
run_device.REMOTE = 'files/tablet-phase-20261107'
device.OUT = device.OUT/'same-session-control'
device.OUT.mkdir(exist_ok=True)
run_device.OUT = device.OUT
run_device.export_info = lambda: previous
for label,mode in [('profile-startup-a','startup'),('profile-startup-b','startup'),
                   ('profile-menus-a','menus'),('profile-menus-b','menus'),
                   ('profile-races-a','races'),('profile-races-b','races')]:
    run_device.collect(label,{'mode':mode})
print('SAME_SESSION_CONTROL_COMPLETE',flush=True)
