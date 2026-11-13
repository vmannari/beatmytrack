"""Finish the interrupted post-install audit without repeating the install."""
import json
from device import EVIDENCE, OUT, PACKAGE, adb, context, manifest
from run_device import export_info, identity_check

value = export_info()
identity_check()
original = json.loads((EVIDENCE/'original.json').read_text())
after = context()
assert after['version']==value['build_id']
assert after['first_install']==original['context']['first_install']
installed = adb('shell','pm','path',PACKAGE).strip().removeprefix('package:')
assert adb('shell','sha256sum',installed,timeout=180).split()[0]==value['apk']['sha256']
before_files = json.loads((OUT/'immediate-before-profile-install-private.json').read_text())
after_files = manifest('recovered-after-profile-install')
assert before_files==after_files, 'App files differ before first launch'
receipt = {'before':original['context'],'after':after,'apk':value['apk'],
    'result':'Successful install; post-install audit recovered after adb exit 255',
    'preserved_files_before_launch':len(before_files)}
(EVIDENCE/'temporary-install.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt),flush=True)
