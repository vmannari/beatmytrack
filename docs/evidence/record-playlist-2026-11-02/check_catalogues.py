"""Verify only the directly authored playlist messages without rewriting catalogues."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(root / 'scripts'))
import localization

rows = [line.split('|') for line in (root / 'scripts/translations/record_playlist.tsv').read_text(encoding='utf-8').splitlines() if line]
languages = ['en', 'fr', 'es', 'de', 'pt_BR', 'ja', 'ko', 'nl', 'it', 'fi', 'sv', 'nb']
for index, language in enumerate(languages):
    catalogue = localization.parse_po((root / f'game/localization/{language}.po').read_text(encoding='utf-8'))
    for row in rows:
        assert len(row) == len(languages)
        value = catalogue[('', row[0])]['msgstr']
        assert value == row[index], (language, row[0])
        assert localization.placeholders(value) == localization.placeholders(row[0])
source = localization.parse_po((root / 'game/localization/messages.pot').read_text(encoding='utf-8'))
assert all(('', row[0]) in source for row in rows)
print('Scoped playlist catalogues: 36 translations, 3 source messages, valid placeholders')
