from pathlib import Path
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[2]
work = Path(__file__).resolve().parent
previous = root / 'build/phone-current-deployment-2026-10-25'
source = work / 'source'
assert not source.exists(), 'Preserve existing candidate'
manifest = json.loads((previous / 'source-manifest.json').read_text())
generated = {'game/project.godot', 'game/core/build_identity.gd'}
for row in manifest['files']:
    name = row['path']
    data = (previous / 'source' / name).read_bytes()
    assert name in generated or hashlib.sha256(data).hexdigest() == row['sha256'], name
    destination = source / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
overlay = ['game/track/desert_sand_wind.gd', 'game/diagnostics/mobile_race_probe.gd', 'game/tests/test_desert_wind_cache.gd', 'game/tests/profile_desert_wind_lookup.gd', 'game/tests/fixtures/desert_phone_performance_before/desert_sand_wind.gd.txt']
for name in overlay:
    destination = source / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / name, destination)
shutil.copytree(previous / 'source/game/.godot/imported', source / 'game/.godot/imported')
for name in ('.gdignore','global_script_class_cache.cfg','uid_cache.bin','extension_list.cfg'):
    path = previous / 'source/game/.godot' / name
    if path.exists(): shutil.copy2(path,source / 'game/.godot' / name)
template = previous / 'source/.tools/admob/android_source.zip'
assert hashlib.sha256(template.read_bytes()).hexdigest().upper() == 'A15416B528EFB0A19A7D187E4D9F4E5336D0689144B111329FB4BD12C4447AD3'
destination = source / '.tools/admob/android_source.zip'
destination.parent.mkdir(parents=True)
shutil.copy2(template,destination)
(work / 'build-scope.json').write_text(json.dumps({'base_installed_build':'0.3.0-creator.2f8163c3a95d18ced951ffbe6194f742','shipping_changes':overlay[:2],'test_overlays':overlay[2:]},indent=2)+'\n')
print('Prepared exact installed source plus Desert cache and local diagnostic toggle')
