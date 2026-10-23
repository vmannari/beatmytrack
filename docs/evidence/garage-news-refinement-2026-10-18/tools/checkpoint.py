from pathlib import Path
import hashlib
import json
import re
import subprocess

root = Path.cwd()
out = root / 'docs/evidence/garage-news-refinement-2026-10-18'
before, after = out / 'before-source', out / 'after-source'
paths = [
    'game/ui/garage_news_menu.gd', 'game/ui/garage_news_art.gd',
    'game/ui/garage_news_paper.gdshader', 'game/ui/garage_news_paper.gdshader.uid',
    'game/assets/fonts/libre_baskerville/LibreBaskerville-Italic.ttf',
    'game/assets/fonts/libre_baskerville/LibreBaskerville-Italic.ttf.import',
    'game/tests/test_garage_news_native.gd',
    'docs/GARAGE_NEWS_REFINEMENT_2026_10_18.md',
    'licenses/ASSETS.md', 'AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md',
]
prefixes = json.loads((out / 'documentation-prefixes.json').read_text())
manifest = {}
for relative in paths:
    raw = (root / relative).read_bytes()
    if not relative.endswith('.ttf'):
        raw = raw.replace(b'\r\n', b'\n')
    old = None
    if relative in prefixes:
        value = raw.decode('utf-8')
        prefix = prefixes[relative]
        assert value.count(prefix) == 1, relative
        old = value.replace(prefix, '', 1).encode()
    elif relative == 'licenses/ASSETS.md':
        value = raw.decode('utf-8')
        start = value.index('Garage News reference refinement (2026-10-18):')
        end = value.index('\n\n', start) + 2
        old = (value[:start] + value[end:]).encode()
    elif (out / 'before' / relative).exists():
        old = (out / 'before' / relative).read_bytes().replace(b'\r\n', b'\n')
    destination = after / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(raw)
    if old is not None:
        original = before / relative
        original.parent.mkdir(parents=True, exist_ok=True)
        original.write_bytes(old)
    manifest[relative] = {
        'before_sha256': hashlib.sha256(old).hexdigest() if old is not None else None,
        'after_sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw),
    }
result = subprocess.run(
    ['git', 'diff', '--no-index', '--binary', '--no-ext-diff', '--', 'before-source', 'after-source'],
    cwd=out, capture_output=True,
)
assert result.returncode == 1, result.stderr
patch = result.stdout.decode('utf-8').replace('a/before-source/', 'a/').replace('b/after-source/', 'b/').replace('a/after-source/', 'a/')
patch_file = out / 'task-only.patch'
patch_file.write_text(patch, encoding='utf-8', newline='\n')
checked = subprocess.run(['git', 'apply', '--reverse', '--check', str(patch_file)], cwd=root, capture_output=True, text=True)
assert checked.returncode == 0, checked.stderr
(out / 'checkpoint.json').write_text(json.dumps({
    'scope': 'Task-only newspaper source, licensed italic font/import, regression checks and documentation. Exact pre-task runtime images retained; shared documentation before images remove only this task entry. Unrelated workspace edits and original Git index/HEAD remain untouched.',
    'source_files': manifest, 'patch': 'task-only.patch', 'binary_font_included': True,
    'reverse_apply_check': 'passed',
}, indent=2) + '\n')
report = json.loads((out / 'report.json').read_text())
report['checkpoint'] = 'checkpoint.json'
report['changed_files'] = paths
for entry in report['validation']:
    if 'log' not in entry:
        continue
    raw = (out / entry['log']).read_bytes()
    text = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')
    if entry['exit_code'] == 0:
        assert not re.search(r'SCRIPT ERROR:|(^|\s)ERROR:|Parse Error:', text, re.M), entry['log']
        if 'checks' in entry['result']:
            assert entry['result'] in text, entry['log']
report['validation'] = [entry for entry in report['validation'] if not entry['command'].startswith('git apply')]
report['validation'].append({
    'command': 'git apply --reverse --check docs/evidence/garage-news-refinement-2026-10-18/task-only.patch',
    'result': 'passed', 'exit_code': 0,
})
(out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
print('Task-only binary patch:', len(paths), 'files; reverse apply check passed; final success logs have no captured script/parse/shader errors')
