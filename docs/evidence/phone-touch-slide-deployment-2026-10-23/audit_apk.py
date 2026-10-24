from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[2]
work = Path(__file__).resolve().parent
old = root / 'build/tablet-lap-stutter-deployment-2026-10-23/source/build/android/circuit01-debug.apk'
new = work / 'source/build/android/circuit01-debug.apk'

def contents(path):
    result = {}
    with zipfile.ZipFile(path) as archive:
        for entry in archive.infolist():
            if entry.is_dir():
                continue
            digest = hashlib.sha256()
            with archive.open(entry) as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(block)
            result[entry.filename] = digest.hexdigest()
    return result

before, after = contents(old), contents(new)
changed = sorted(name for name in before.keys() & after.keys() if before[name] != after[name])
added, removed = sorted(after.keys() - before.keys()), sorted(before.keys() - after.keys())
native = [name for name in before if name.startswith('lib/')]
assert native and all(name in after and before[name] == after[name] for name in native)
assert any('ui/touch_controls' in name for name in changed), 'Expected updated touch script in APK'
scripts = [name for name in changed if name.endswith(('.gdc', '.gd'))]
assert all('ui/touch_controls' in name or 'core/build_identity' in name for name in scripts), scripts
report = {'old_entries': len(before), 'new_entries': len(after), 'changed': changed, 'added': added, 'removed': removed, 'native_library_count': len(native), 'native_libraries_exact': True, 'changed_script_entries': scripts}
(work / 'apk-content-audit.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
