from pathlib import Path
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[2]
work = Path(__file__).resolve().parent
old_work = root / 'build/tablet-lap-stutter-deployment-2026-10-23'
old = old_work / 'source'
target = work / 'source'
assert not target.exists(), 'Preserve existing snapshot'
manifest = json.loads((old_work / 'source-manifest.json').read_text(encoding='utf-8-sig'))
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
rows = manifest['files']
generated = {'game/core/build_identity.gd', 'game/project.godot'}
prior_generated_differences = []
for row in rows:
    name = row['path']
    source = old / name
    if digest(source) != row['sha256']:
        assert name in generated, name
        prior_generated_differences.append(name)
    destination = target / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)

fix = 'game/ui/touch_controls.gd'
tested = json.loads((root / 'docs/evidence/touch-slide-activation-2026-10-23/report.json').read_text())
assert digest(root / fix) == tested['sha256'][fix], 'Fix differs from tested source'
assert (old / fix).read_bytes() == (root / 'docs/evidence/touch-slide-activation-2026-10-23/before/touch_controls.gd.txt').read_bytes()
for name in [fix, 'game/tests/test_touch_slide_activation.gd', 'game/tests/test_touch_slide_activation.gd.uid', 'game/tests/test_touch_target_padding.gd']:
    destination = target / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / name, destination)

# Machine-local resource imports/settings/templates stay in ignored build space.
shutil.copytree(old / 'game/.godot', target / 'game/.godot')
template = old / '.tools/admob/android_source.zip'
assert digest(template).upper() == 'A15416B528EFB0A19A7D187E4D9F4E5336D0689144B111329FB4BD12C4447AD3'
destination = target / '.tools/admob/android_source.zip'
destination.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(template, destination)
destination = work / 'appdata/Godot/editor_settings-4.7.tres'
destination.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(old_work / 'appdata/Godot/editor_settings-4.7.tres', destination)
shutil.copytree(old_work / 'appdata/Godot/export_templates/4.7.2.stable', work / 'appdata/Godot/export_templates/4.7.2.stable')

changes = [row['path'] for row in rows if not row['path'].startswith('game/tests/') and (old / row['path']).read_bytes() != (target / row['path']).read_bytes()]
assert changes == [fix], changes
paths = sorted(set(row['path'] for row in rows) | {'game/tests/test_touch_slide_activation.gd', 'game/tests/test_touch_slide_activation.gd.uid'})
frozen = [{'path': name, 'sha256': digest(target / name), 'bytes': (target / name).stat().st_size} for name in paths]
(work / 'source-manifest.json').write_text(json.dumps({'base_build': '0.3.0-creator.3ae28a749c83e1a138e1c689731c58b2', 'shipping_changes': changes, 'prior_generated_manifest_differences': prior_generated_differences, 'files': frozen}, indent=2) + '\n')
print(json.dumps({'files': len(frozen), 'shipping_changes': changes}))
