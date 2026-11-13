"""Keep the rejected mixed-source APK out of the standard install path."""
import hashlib
import json
from pathlib import Path
import shutil

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
initial = json.loads((OUT/'concurrent-source-export-result.json').read_text())
accepted = json.loads((OUT/'export-result.json').read_text())
path = Path(initial['apk']['path'])
source = Path(accepted['apk']['path'])
target = OUT/'rejected-concurrent-source.apk'
for item in [path, source, target]:
    assert item.resolve().is_relative_to(ROOT.resolve()),item
record = {'rejected_export_installed':False,'canonical_apk_updated':False}
if path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest()==initial['apk']['sha256']:
    assert not target.exists()
    assert hashlib.sha256(source.read_bytes()).hexdigest()==accepted['apk']['sha256']
    path.replace(target)
    shutil.copyfile(source,path)
    assert hashlib.sha256(path.read_bytes()).hexdigest()==accepted['apk']['sha256']
    record.update(canonical_apk_updated=True,rejected_apk=str(target),
                  rejected_sha256=initial['apk']['sha256'],canonical_apk=str(path),
                  canonical_sha256=accepted['apk']['sha256'])
else:
    record['note']='Canonical path changed independently; left untouched.'
(ROOT/'docs/evidence/tablet-loading-deploy-2026-11-07/quarantine.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record))
