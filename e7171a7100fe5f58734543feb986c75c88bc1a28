"""Merge only this pass's directly authored rows, retaining all other copy."""
from pathlib import Path
import json
import re
import sys

sys.path.insert(0, str(Path.cwd() / 'scripts'))
import localization as catalog
import translate_catalogues as authored

rows = {}
for line in Path('scripts/translations/editor_ux_2026_10_28.tsv').read_text(encoding='utf-8').splitlines():
    fields = line.split('|')
    assert len(fields) == len(authored.LANGUAGES)+1
    rows[fields[0]] = dict(zip(authored.LANGUAGES, fields[1:]))
messages = catalog.collect()
for source in ['%.0f deg','%.1f m']:
    value = authored.resolve(source,{})
    assert value is not None
    rows[source] = value
applied = {}
for language in authored.LANGUAGES:
    path = catalog.DESTINATION / f'{language}.po'
    blocks = path.read_text(encoding='utf-8').strip().split('\n\n')
    done = set()
    for index, block in enumerate(blocks):
        entries = catalog.parse_po(block+'\n')
        for (context, source), entry in entries.items():
            if not context and source in rows:
                value = rows[source][language]
                assert catalog.placeholders(source) == catalog.placeholders(value)
                blocks[index] = re.sub(r'(?m)^msgstr ".*"(?:\n".*")*', 'msgstr '+catalog.quoted(value), block)
                done.add(source)
    for source in rows.keys()-done:
        key = ('',source)
        if key not in messages: continue
        value = rows[source][language]
        blocks.append('#: '+' '.join(sorted(messages[key]['references']))+'\nmsgid '+catalog.quoted(source)+'\nmsgstr '+catalog.quoted(value))
        done.add(source)
    path.write_text('\n\n'.join(blocks)+'\n',encoding='utf-8',newline='\n')
    applied[language] = len(done)
(catalog.DESTINATION/'messages.pot').write_text(catalog.render(messages),encoding='utf-8',newline='\n')
(catalog.DESTINATION/'en.po').write_text(catalog.render(messages,True),encoding='utf-8',newline='\n')
Path('docs/evidence/editor-ux-improvements-2026-10-28/translation-merge.json').write_text(json.dumps(applied,indent=2),encoding='utf-8')
print(json.dumps(applied))
