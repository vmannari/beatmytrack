from pathlib import Path
import csv
import json
import sys

root = Path.cwd()
sys.path.insert(0, str(root / 'scripts'))
import localization

evidence = root / 'docs/evidence/track-editor-fixes-2026-10-28'
rows = list(csv.DictReader((root / 'scripts/translations/track_editor_review_fixes.tsv').open(encoding='utf-8'), delimiter='\t'))
for language in rows[0]:
    if language == 'msgid':
        continue
    path = root / f'game/localization/{language}.po'
    original = path.read_bytes()
    saved = evidence / 'before' / path.relative_to(root)
    saved.parent.mkdir(parents=True, exist_ok=True)
    if not saved.exists():
        saved.write_bytes(original)
    text = original.decode('utf-8')
    existing = {entry.get('msgid') for entry in localization.parse_po(text).values()}
    extra = ''
    for row in rows:
        if row['msgid'] not in existing:
            extra += '\nmsgid ' + json.dumps(row['msgid'], ensure_ascii=False) + '\nmsgstr ' + json.dumps(row[language], ensure_ascii=False) + '\n'
    if extra:
        assert path.read_bytes() == original, f'Concurrent update: {path}'
        path.write_bytes(original + extra.encode('utf-8'))
    entries = {entry['msgid']:entry for entry in localization.parse_po(path.read_text(encoding='utf-8')).values()}
    for row in rows:
        assert entries[row['msgid']]['msgstr'] == row[language]
print('EDITOR_FIX_TRANSLATIONS: 22 messages, 11 languages')
