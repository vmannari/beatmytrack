"""Save only the new pattern collection using a private Git index."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
BEFORE = EVIDENCE / 'before'
modified = json.loads((EVIDENCE / 'baseline-files.json').read_text())
keys = json.loads((EVIDENCE / 'new-patterns.json').read_text())
new = ['docs/LIVERY_VARIETY_2026_10_14.md']
for key in keys:
    new += [f'game/assets/liveries/{key}.svg', f'game/assets/liveries/{key}_preview.svg']
    new += [f'game/assets/liveries/previews_v2/{car}/{key}.png' for car in ['compact', 'pickup', 'classic', 'formula', 'kart']]
new += [name + '.import' for name in list(new) if name.endswith(('.svg', '.png'))]

def payload(path):
    data = path.read_bytes()
    return data if path.suffix == '.png' else data.decode('utf-8-sig').replace('\r\n', '\n').encode()

owned = {name: payload(ROOT / name) for name in modified}
original = {name: payload(BEFORE / name.replace('/', '__')) for name in modified}
for name in ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']:
    current = owned[name].decode()
    starting = original[name].decode()
    if name == 'AGENTS.md':
        start = current.index('## Tribal and varied livery collection override')
        end = current.index('\n## ', start + 4)
        entry = current[start:end].strip() + '\n\n'
        owned[name] = starting.replace('# Project agent instructions\n\n', '# Project agent instructions\n\n' + entry, 1).encode()
    else:
        entry = next(p for p in current.split('\n\n') if p.startswith('2026-10-14 LVY01-LVY04')) + '\n\n'
        owned[name] = (entry + starting).encode()

env = os.environ.copy()
env['GIT_INDEX_FILE'] = str(EVIDENCE / 'checkpoint.index')
def git(*args, data=None):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], env=env, input=data)
def stage(name, data):
    digest = git('hash-object', '-w', '--stdin', data=data).decode().strip()
    git('update-index', '--add', '--cacheinfo', '100644', digest, name)

head = git('rev-parse', 'HEAD').decode().strip()
git('read-tree', head)
for name, data in original.items(): stage(name, data)
baseline = git('commit-tree', git('write-tree').decode().strip(), '-p', head, '-m', 'Capture current sources before tribal livery variety').decode().strip()
for name, data in owned.items(): stage(name, data)
for name in new: stage(name, payload(ROOT / name))
checkpoint = git('commit-tree', git('write-tree').decode().strip(), '-p', baseline, '-m', 'Add six tribal and ten varied original livery designs').decode().strip()
ref = 'refs/codex/checkpoints/livery-variety-2026-10-14'
prior = subprocess.run(['git', '-C', str(ROOT), 'rev-parse', '--verify', ref], capture_output=True)
git('update-ref', ref, checkpoint, prior.stdout.decode().strip() if prior.returncode == 0 else '0' * 40)
git('diff', '--check', baseline, checkpoint)
(EVIDENCE / 'task-only.patch').write_bytes(git('diff', '--binary', baseline, checkpoint))

logs = EVIDENCE / 'logs'
logs.mkdir(exist_ok=True)
all_logs = sorted((ROOT / 'build/logs').rglob('*.log'), key=lambda p: p.stat().st_mtime, reverse=True)
markers = {
    'native-bake': 'LIVERY_PREVIEWS: 80 captures complete',
    'livery-compatibility': 'Livery patterns: 842 checks, 0 failures (gl_compatibility)',
    'livery-mobile': 'Livery patterns: 842 checks, 0 failures (mobile)',
    'script-parse': 'SCRIPT_PARSE: 710 scripts, 0 failures',
}
receipts = {}
for label, marker in markers.items():
    source = next(p for p in all_logs if marker in p.read_text(errors='replace'))
    shutil.copy2(source, logs / (label + '.log'))
    receipts[label] = {'outcome': 'passed', 'marker': marker, 'source_log': source.relative_to(ROOT).as_posix()}
initial_errors = {
    'initial-missing-class': 'Identifier "CompactAero" not declared in the current scope.',
    'initial-trail-fixture': 'Closing ")" doesn\'t have an opening counterpart.',
    'initial-dust-interface': "Nonexistent function 'prepare_track' in base 'Node3D (SandDust)'",
}
for label, marker in initial_errors.items():
    matches = [p for p in all_logs if marker in p.read_text(errors='replace')]
    if matches:
        shutil.copy2(matches[0], logs / (label + '.log'))
        receipts[label] = {'outcome': 'concurrent intermediate failure; final retry passed', 'source_log': matches[0].relative_to(ROOT).as_posix()}
files = modified + new
receipt = {
    'checkpoint_commit': checkpoint, 'baseline_commit': baseline, 'checkpoint_ref': ref,
    'head_at_start': head, 'head_at_end': git('rev-parse', 'HEAD').decode().strip(),
    'shared_head_and_index_written': False, 'commands': receipts,
    'new_patterns': keys, 'wraps_total': 48, 'plain_preset': 'Midnight', 'new_photos': 80, 'photos_total': 245,
    'files': [{'path': name, 'bytes': (ROOT / name).stat().st_size, 'sha256': hashlib.sha256((ROOT / name).read_bytes()).hexdigest()} for name in files],
    'phone_test': 'Not performed', 'apk_export_install': 'Not performed', 'backend_deployment': 'Not performed',
}
(EVIDENCE / 'delivery.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps({'checkpoint': checkpoint, 'ref': ref, 'files': len(files), 'task_diff_check': 'passed'}))
