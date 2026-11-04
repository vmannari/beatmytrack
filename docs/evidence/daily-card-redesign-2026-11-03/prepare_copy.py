"""Append only this task's directly authored copy; preserve concurrent catalogues."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
languages = ['en', 'fr', 'es', 'de', 'pt_BR', 'ja', 'ko', 'nl', 'it', 'fi', 'sv', 'nb']
for row in (root / 'scripts/translations/daily_card_redesign.tsv').read_text(encoding='utf-8').splitlines():
    fields = row.split('|')
    assert len(fields) == len(languages)
    for language, value in zip(languages, fields):
        path = root / 'game/localization' / (language + '.po')
        text = path.read_text(encoding='utf-8')
        source = json.dumps(fields[0], ensure_ascii=False)
        if 'msgid ' + source + '\n' not in text:
            text = text.rstrip() + '\n\n#: game/ui/daily_result_card.gd\nmsgid ' + source + '\nmsgstr ' + json.dumps(value, ensure_ascii=False) + '\n'
            path.write_text(text, encoding='utf-8', newline='\n')
    template = root / 'game/localization/messages.pot'
    text = template.read_text(encoding='utf-8')
    source = json.dumps(fields[0], ensure_ascii=False)
    if 'msgid ' + source + '\n' not in text:
        template.write_text(text.rstrip() + '\n\n#: game/ui/daily_result_card.gd\nmsgid ' + source + '\nmsgstr ""\n', encoding='utf-8', newline='\n')
