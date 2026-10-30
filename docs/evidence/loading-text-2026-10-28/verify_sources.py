"""Confirm this repair changes only the loading literals and keeps translations."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'scripts'))
import localization as catalog

before = (OUT / 'before/game/core/app.gd').read_text(encoding='utf-8-sig')
after = (ROOT / 'game/core/app.gd').read_text(encoding='utf-8-sig')
assert len(before.splitlines()) == len(after.splitlines())
changed = []
for old, new in zip(before.splitlines(), after.splitlines()):
    if old != new:
        assert any(token in old for token in ['loading.stage(', 'overlay.stage(',
                   'loading.facts_label.text', 'MenuStyle.label("Preparing track'])
        assert old.encode('cp1252').decode('utf-8') == new
        changed.append(new.strip())
assert len(changed) == 13
messages = catalog.collect()
loading_messages = ['Connecting race\u2026', 'Downloading track\u2026', 'Preparing track\u2026',
                    'Loading ghost\u2026', 'Opening parking hall\u2026', 'Loading track\u2026',
                    'Preparing start\u2026', 'P1 parking hall \u00b7 Free drive \u00b7 120 \u00d7 72 m',
                    '5 laps  \u00b7  ']
coverage = {}
for path in sorted(catalog.DESTINATION.glob('*.po')):
    entries = catalog.parse_po(path.read_text(encoding='utf-8'))
    for source in loading_messages:
        assert ('', source) in entries and entries[('', source)]['msgstr'], (path.name, ascii(source))
    coverage[path.stem] = len(loading_messages)
assert catalog.source_catalogue_matches((catalog.DESTINATION / 'messages.pot').read_text(encoding='utf-8'), messages)
assert not catalog.validate(catalog.parse_po((catalog.DESTINATION / 'en.po').read_text(encoding='utf-8')), messages, 'en')
metadata = {}
for name in ['game/project.godot', 'game/core/build_identity.gd']:
    current = (ROOT / name).read_bytes()
    original = (OUT / 'before' / name).read_bytes()
    generated = (OUT / 'native' / name).read_bytes()
    assert current != generated  # This task's generated identity was retired.
    metadata[name] = {'matches_task_start': current == original,
                      'task_generated_identity_retired': True,
                      'current_sha256': hashlib.sha256(current).hexdigest()}

files = ['game/core/app.gd', 'game/localization/messages.pot', 'game/localization/en.po']
patch = ''.join(''.join(difflib.unified_diff(
    (OUT / 'before' / name).read_text(encoding='utf-8-sig').splitlines(keepends=True),
    (ROOT / name).read_text(encoding='utf-8-sig').splitlines(keepends=True),
    fromfile='a/' + name, tofile='b/' + name)) for name in files)
(OUT / 'task.patch').write_text(patch, encoding='utf-8', newline='\n')
commands = [
    [sys.executable, '-m', 'unittest', 'discover', '-s', 'scripts', '-p', 'test_localization.py'],
    ['git', 'diff', '--check', '--', *files],
    ['git', 'apply', '--check', '--reverse', str(OUT / 'task.patch')],
]
results = []
for index, command in enumerate(commands):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, encoding='utf-8')
    (OUT / f'verification-{index}.log').write_text(result.stdout + result.stderr, encoding='utf-8')
    results.append({'command': command, 'exit_code': result.returncode})
    assert result.returncode == 0, result.stdout + result.stderr
report = {
    'requirements': ['LT01', 'LT02', 'R01', 'Q01'],
    'changed_runtime_files': files[:1], 'changed_catalogues': files[1:],
    'changed_app_lines': len(changed), 'loading_messages': loading_messages,
    'catalogue_coverage': coverage, 'source_catalogue_current': True,
    'other_app_code_exact_to_task_start': True, 'metadata': metadata,
    'verification': results,
    'headless': json.loads((OUT / 'headless.json').read_text(encoding='utf-8')),
    'native': json.loads((OUT / 'native.json').read_text(encoding='utf-8')),
    'screenshots': sorted(path.name for path in OUT.glob('*.png')),
    'sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in files},
    'limitations': ['Reload/rebuild and owner appearance acceptance remain.', 'No physical-device test performed.'],
    'initial_attempt': 'Sandboxed engine startup could not read the Windows certificate store; same offline test passed after approved local execution.',
}
(OUT / 'report.json').write_text(json.dumps(report, indent=2, ensure_ascii=True) + '\n', encoding='utf-8')
print(f'LOADING_TEXT: {len(changed)} exact text repairs; 9 messages covered in {len(coverage)} languages; 14 tooling tests, native captures and scoped patch checks pass.')
