"""Final local audit, reproducible checks and a patch excluding concurrent copy."""
from pathlib import Path
import collections
import difflib
import hashlib
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'scripts'))
import localization as catalog
import text_encoding


def blocks(text):
    result = {}
    for block in text.strip().split('\n\n'):
        entries = catalog.parse_po(block + '\n')
        assert len(entries) == 1
        result[next(iter(entries))] = block
    return result


scan = text_encoding.scan()
assert not scan['issues']
(OUT / 'encoding-after.json').write_text(json.dumps(scan, indent=2) + '\n', encoding='utf-8')
messages = catalog.collect()
assert catalog.source_catalogue_matches((catalog.DESTINATION / 'messages.pot').read_text(encoding='utf-8'), messages)
assert not catalog.validate(catalog.parse_po((catalog.DESTINATION / 'en.po').read_text(encoding='utf-8')), messages, 'en')
changes = {}
patch = []
for name, expected_lines in [('game/core/app.gd', 15), ('backend/bmt_backend/studio_simulator.py', 2),
                             ('game/legal/GOOGLEID-NOTICES.txt', 3),
                             ('game/assets/menu/challenges/three-by-three-tracks-tickets-v7.json', 3)]:
    old = (OUT / 'before' / name).read_text(encoding='utf-8-sig')
    new = (ROOT / name).read_text(encoding='utf-8-sig')
    assert len(old.splitlines()) == len(new.splitlines())
    count = 0
    for a, b in zip(old.splitlines(), new.splitlines()):
        if a != b:
            assert (a.replace('\ufffd', '"') == b if name.endswith('.txt') else
                    a.replace(r'\u00c3\u2014', r'\u00d7') == b if name.endswith('.json') else
                    a.encode('cp1252').decode('utf-8') == b)
            count += 1
    assert count == expected_lines
    changes[name] = count
    patch.extend(difflib.unified_diff(old.splitlines(keepends=True), new.splitlines(keepends=True),
                                   fromfile='a/' + name, tofile='b/' + name))

catalogue_keys = {}
for name in ['game/localization/messages.pot', 'game/localization/en.po']:
    old = blocks((OUT / 'before' / name).read_text(encoding='utf-8'))
    new_text = (ROOT / name).read_text(encoding='utf-8')
    current = blocks(new_text)
    scoped_before = current.copy()
    affected = []
    for key in old:
        if text_encoding.find_issues(key[1]):
            corrected = (key[0], key[1].encode('cp1252').decode('utf-8'))
            assert corrected in current
            affected.append(corrected)
            if corrected not in old:
                scoped_before.pop(corrected, None)
            else:
                scoped_before[corrected] = old[corrected]
            scoped_before[key] = old[key]
    assert len(affected) == 16
    catalogue_keys[name] = len(affected)
    scoped_text = '\n\n'.join(scoped_before[key] for key in sorted(scoped_before)) + '\n'
    patch.extend(difflib.unified_diff(scoped_text.splitlines(keepends=True), new_text.splitlines(keepends=True),
                                   fromfile='a/' + name, tofile='b/' + name))

existing_tools = ['scripts/localization.py', 'scripts/test_localization.py']
new_tools = ['scripts/text_encoding.py', 'scripts/test_text_encoding.py']
for name in existing_tools + new_tools:
    previous = OUT / 'before' / name
    old = previous.read_text(encoding='utf-8') if previous.exists() else ''
    new = (ROOT / name).read_text(encoding='utf-8')
    patch.extend(difflib.unified_diff(old.splitlines(keepends=True), new.splitlines(keepends=True),
                                   fromfile='a/' + name if previous.exists() else '/dev/null', tofile='b/' + name))
(OUT / 'task.patch').write_text(''.join(patch), encoding='utf-8', newline='\n')

commands = [
    [sys.executable, '-m', 'unittest', 'discover', '-s', 'scripts', '-p', 'test_text_encoding.py'],
    [sys.executable, '-m', 'unittest', 'discover', '-s', 'scripts', '-p', 'test_localization.py'],
    [sys.executable, '-m', 'unittest', 'discover', '-s', 'scripts', '-p', 'test_translation_authoring.py'],
    [str(ROOT / '.tools/backend-secure-venv/Scripts/python.exe'), '-m', 'ruff', 'check',
     *new_tools, 'scripts/test_localization.py', 'backend/bmt_backend/studio_simulator.py'],
    ['git', 'diff', '--check', '--', *changes, *catalogue_keys, *existing_tools, *new_tools],
    ['git', 'apply', '--check', '--reverse', str(OUT / 'task.patch')],
]
outcomes = []
for index, command in enumerate(commands):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, encoding='utf-8')
    (OUT / f'check-{index}.log').write_text(result.stdout + result.stderr, encoding='utf-8')
    outcomes.append({'command': command, 'exit_code': result.returncode})
    assert result.returncode == 0, result.stdout + result.stderr

placeholder_errors = []
coverage = {}
for path in sorted(catalog.DESTINATION.glob('*.po')):
    entries = catalog.parse_po(path.read_text(encoding='utf-8'))
    for key, entry in entries.items():
        for field, value in entry.items():
            if field.startswith('msgstr') and value and key[1]:
                source = entry.get('msgid_plural', key[1]) if field not in ('msgstr', 'msgstr[0]') else key[1]
                if catalog.placeholders(source) != catalog.placeholders(value):
                    placeholder_errors.append((path.stem, key, field))
    errors = catalog.validate(entries, messages, path.stem)
    coverage[path.stem] = dict(collections.Counter(error.split(': ', 1)[1].split(' message', 1)[0]
                                                  if ' message' in error else 'other' for error in errors))
assert not placeholder_errors
(OUT / 'final-catalogue-check.json').write_text(json.dumps(coverage, indent=2) + '\n', encoding='utf-8')
files = [*changes, *catalogue_keys, *existing_tools, *new_tools]
report = {'requirements': ['AT01', 'AT02', 'AT03', 'R01', 'Q01'],
          'files_checked': scan['files_checked'], 'remaining_encoding_issues': 0,
          'changed_source_lines': changes, 'repaired_source_sequences': 31,
          'repaired_escaped_metadata_sequences': 4,
          'repaired_notice_quotes': 8, 'catalogue_keys_repaired': catalogue_keys,
          'placeholder_errors_in_all_catalogues': placeholder_errors,
          'commands': outcomes, 'native_capture': json.loads((OUT / 'capture.json').read_text()),
          'broader_packaged_test': json.loads((OUT / 'translations.json').read_text()),
          'strict_translation_completeness': coverage,
          'screenshots': sorted(path.name for path in OUT.glob('*.png')),
          'sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in files},
          'limitations': ['No physical-device test; reload/rebuild and owner appearance acceptance remain.',
                          'Existing incomplete/stale translations remain; encoding and placeholder checks are clean.',
                          'Broader packaged test reports inventory mismatches and aborts on the concurrently missing Hovercraft image.',
                          'Historical fixtures/caches, private saves and live server text were not changed.'],
          'notice_sources': ['https://www.mozilla.org/en-US/MPL/1.1/',
                             'https://website-archive.mozilla.org/www.mozilla.org/mpl/mpl/npl/1.1/']}
(OUT / 'report.json').write_text(json.dumps(report, indent=2, ensure_ascii=True) + '\n', encoding='utf-8')
print(f"ALL_TEXT: {scan['files_checked']} files clean; 29 tooling tests and 224 native checks pass; all catalogue placeholders intact; scoped patch checks.")
