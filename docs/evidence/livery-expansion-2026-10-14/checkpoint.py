"""Save this cosmetic change with a private index; preserve shared HEAD/index."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
BEFORE = EVIDENCE / 'before'
removed = json.loads((EVIDENCE / 'removed-files.json').read_text())
modified = json.loads((EVIDENCE / 'baseline-files.json').read_text())
patterns = json.loads((ROOT / 'game/assets/liveries/catalog.json').read_text())
stickers = json.loads((ROOT / 'game/assets/liveries/stickers.json').read_text())
new_patterns = {p['id'] for p in patterns} - {p['id'] for p in json.loads((BEFORE / 'game__assets__liveries__catalog.json').read_text())}
new_stickers = {p['id'] for p in stickers} - {p['id'] for p in json.loads((BEFORE / 'game__assets__liveries__stickers.json').read_text())}

env = os.environ.copy()
env['GIT_INDEX_FILE'] = str(EVIDENCE / 'checkpoint.index')

def git(*args, data=None):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], env=env, input=data)

def read(path):
    data = path.read_bytes()
    return data if path.suffix == '.png' else data.decode('utf-8-sig').replace('\r\n', '\n').encode()

def stage(name, data):
    digest = git('hash-object', '-w', '--stdin', data=data).decode().strip()
    git('update-index', '--add', '--cacheinfo', '100644', digest, name)

head = git('rev-parse', 'HEAD').decode().strip()
baseline_data = {name: read(BEFORE / name.replace('/', '__')) for name in modified}
owned = {name: read(ROOT / name) for name in modified if name not in removed}
new = ['docs/LIVERY_EXPANSION_2026_10_14.md']

# Recaptured existing recipe photos use the checked-in asset snapshot as their
# binary baseline. Code/catalog baselines were saved before the task's edits.
assets = []
for key in sorted(new_patterns):
    assets.extend([f'game/assets/liveries/{key}.svg', f'game/assets/liveries/{key}_preview.svg'])
for key in sorted(new_stickers):
    assets.append(f'game/assets/liveries/{key}_sticker.svg')
assets += [p.relative_to(ROOT).as_posix() for p in sorted((ROOT / 'game/assets/liveries/previews_v2').rglob('*.png'))]
assets += [name + '.import' for name in list(assets)]
assets.append('game/assets/liveries/phoenix_sticker.svg') # Generator normalizes path spacing only.
for name in assets:
    path = ROOT / name
    if not path.is_file(): raise RuntimeError('Missing delivery asset: ' + name)
    old = subprocess.run(['git', '-C', str(ROOT), 'show', head + ':' + name], capture_output=True)
    if old.returncode == 0:
        if name not in baseline_data:
            baseline_data[name] = old.stdout if name.endswith('.png') else old.stdout.decode('utf-8-sig').replace('\r\n', '\n').encode()
        owned[name] = read(path)
    else:
        new.append(name)

# Scope status files to this task's added paragraph while retaining all other
# working-file notes outside the private checkpoint delta.
for name in ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']:
    current = owned[name].decode()
    original = baseline_data[name].decode()
    if name == 'AGENTS.md':
        start = current.index('## Expanded liveries and fictional sponsors override')
        end = current.index('\n## ', start + 4)
        prefix = current[start:end].strip() + '\n\n'
        owned[name] = original.replace('# Project agent instructions\n\n', '# Project agent instructions\n\n' + prefix, 1).encode()
    else:
        prefix = next(p for p in current.split('\n\n') if p.startswith('2026-10-14 LE01-LE04')) + '\n\n'
        owned[name] = (prefix + original).encode()

git('read-tree', head)
for name, data in baseline_data.items(): stage(name, data)
baseline = git('commit-tree', git('write-tree').decode().strip(), '-p', head, '-m', 'Capture starting sources for livery expansion').decode().strip()
for name in removed: git('update-index', '--force-remove', name)
for name, data in owned.items(): stage(name, data)
for name in sorted(set(new)): stage(name, read(ROOT / name))
checkpoint = git('commit-tree', git('write-tree').decode().strip(), '-p', baseline, '-m', 'Keep Midnight and add original wraps and fictional sponsor decals').decode().strip()
ref = 'refs/codex/checkpoints/livery-expansion-2026-10-14'
prior = subprocess.run(['git', '-C', str(ROOT), 'rev-parse', '--verify', ref], capture_output=True)
git('update-ref', ref, checkpoint, prior.stdout.decode().strip() if prior.returncode == 0 else '0' * 40)
(EVIDENCE / 'task-only.patch').write_bytes(git('diff', '--binary', baseline, checkpoint))
git('diff', '--check', baseline, checkpoint)

logs = EVIDENCE / 'logs'
logs.mkdir(exist_ok=True)
markers = {
    'native-bake': 'LIVERY_PREVIEWS: 165 captures complete',
    'livery-compatibility': 'Livery patterns: 546 checks, 0 failures (gl_compatibility)',
    'livery-mobile': 'Livery patterns: 546 checks, 0 failures (mobile)',
    'paint-persistence': 'Garage livery: 115 checks, 0 failures',
    'carousel': 'GARAGE_CAROUSEL: 178 checks, 0 failures',
    'retained-controls': 'GARAGE_CUSTOMISATION_SPEED: 1398 checks, 0 failures',
}
receipts = {}
all_logs = sorted((ROOT / 'build/logs').rglob('*.log'), key=lambda p: p.stat().st_mtime, reverse=True)
for label, marker in markers.items():
    source = next(p for p in all_logs if marker in p.read_text(errors='replace'))
    shutil.copy2(source, logs / (label + '.log'))
    receipts[label] = {'marker': marker, 'source_log': source.relative_to(ROOT).as_posix()}
# Record unsuccessful broader checks too; never imply that a target pass means
# the concurrently edited entire project has a clean full-regression result.
failure_markers = {
    'initial-full-import': "Failed to open 'C:/Codes/Godot/Beat my track/game/platform/windows/~bmt_windows_audio_v4.dll'",
    'initial-asset-check': 'FAIL: filtered artwork monza_fan',
    'initial-carousel': 'GARAGE_CAROUSEL: 178 checks, 7 failures',
    'parser-editor-api': 'Static function "from_native()" not found in base "TrackDocument"',
    'parser-menu-signature': 'The function signature doesn\'t match the parent.',
}
for label, marker in failure_markers.items():
    matches = [p for p in all_logs if marker in p.read_text(errors='replace')]
    if matches:
        shutil.copy2(matches[0], logs / (label + '.log'))
        receipts[label] = {'outcome': 'initial or broader failure; see task document', 'source_log': matches[0].relative_to(ROOT).as_posix()}
parse_logs = sorted((ROOT / 'build/logs').glob('CheckScript-*/parse.log'), key=lambda p: p.stat().st_mtime, reverse=True)
direct = next(p for p in parse_logs if 'res://ui/garage_livery_menu.gd' in p.read_text(errors='replace') and 'Parse Error' not in p.read_text(errors='replace'))
shutil.copy2(direct, logs / 'direct-livery-parse.log')
receipts['direct-livery-parse'] = {'outcome': 'passed', 'source_log': direct.relative_to(ROOT).as_posix()}
files = sorted(set(owned) | set(new))
receipt = {
    'checkpoint_commit': checkpoint, 'baseline_commit': baseline, 'checkpoint_ref': ref,
    'head_at_start': head, 'head_at_end': git('rev-parse', 'HEAD').decode().strip(),
    'shared_head_and_index_written': False, 'commands': receipts,
    'removed_files': removed,
    'files': [{'path': name, 'bytes': (ROOT / name).stat().st_size, 'sha256': hashlib.sha256((ROOT / name).read_bytes()).hexdigest()} for name in files],
    'patterns': len(patterns), 'emblems': 12, 'fictional_sponsors': len(new_stickers),
    'native_recipe_photos': 165, 'phone_test': 'Not performed', 'apk_export_install': 'Not performed',
    'backend_deployment': 'Not performed',
    'whole_project_parse': 'Two broader attempts stopped at concurrently stale editor/menu test API signatures. Direct changed-menu parse passes.',
}
(EVIDENCE / 'delivery.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps({'checkpoint': checkpoint, 'ref': ref, 'delivered_files': len(files), 'removed_files': len(removed), 'task_diff_check': 'passed'}))
