import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
WORK = ROOT / 'build/tablet-garage-liveries-2026-10-28'
SOURCE = WORK / 'source'
assert not SOURCE.exists(), 'Preserve any existing deployment snapshot'
SOURCE.mkdir(parents=True)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


names = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others',
                                 '--exclude-standard', '--', 'game', 'native', 'scripts',
                                 'godot-version.txt', '.gitignore', '.gitattributes'], cwd=ROOT).decode().split('\0')
manifest = {}
for name in sorted(set(names)):
    if not name or not (ROOT / name).is_file():
        continue
    target = SOURCE / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / name, target)
    manifest[name] = sha(target)
for name, digest in manifest.items():
    assert sha(ROOT / name) == digest, 'Source changed during snapshot: ' + name
(WORK / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')

# Import caches are disposable build inputs, never player persistence.
shutil.copytree(ROOT / 'game/.godot/imported', SOURCE / 'game/.godot/imported')
for name in ['global_script_class_cache.cfg', 'uid_cache.bin', 'extension_list.cfg', '.gdignore']:
    path = ROOT / 'game/.godot' / name
    if path.exists():
        shutil.copy2(path, SOURCE / 'game/.godot' / name)
template = SOURCE / '.tools/admob/android_source.zip'
template.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(ROOT / '.tools/admob/android_source.zip', template)
assert sha(template) == 'a15416b528efb0a19a7d187e4d9f4e5336d0689144b111329fb4bd12c4447ad3'
settings = Path(os.environ['APPDATA']) / 'Godot'
isolated = WORK / 'appdata/Godot'
isolated.mkdir(parents=True)
shutil.copy2(settings / 'editor_settings-4.7.tres', isolated / 'editor_settings-4.7.tres')
templates = isolated / 'export_templates/4.7.2.stable'
templates.mkdir(parents=True)
for name in ['android_debug.apk', 'version.txt']:
    shutil.copy2(settings / 'export_templates/4.7.2.stable' / name, templates / name)
(SOURCE / 'game/tests/task_bake_garage_previews.gd').write_text('extends "res://../scripts/bake_garage_previews.gd"\n')
print(json.dumps(dict(source=str(SOURCE), files=len(manifest), isolated_persistence=True)))
