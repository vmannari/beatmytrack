"""Append the one authored Super Wash label, preserving concurrent catalogues."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
LANGUAGES = ["en", "fr", "es", "de", "pt_BR", "ja", "ko", "nl", "it", "fi", "sv", "nb"]


def main():
    rows = (ROOT / "scripts/translations/super_wash.tsv").read_text(encoding="utf-8").splitlines()
    values = next(row for row in rows if row and not row.startswith("#")).split("|")
    assert len(values) == len(LANGUAGES)
    for language, value in [("messages", ""), *zip(LANGUAGES, values)]:
        path = ROOT / "game/localization" / (language + (".pot" if language == "messages" else ".po"))
        content = path.read_text(encoding="utf-8")
        identity = 'msgid "Super Wash"\n'
        if identity in content:
            continue
        before = Path(__file__).parent / "before" / path.relative_to(ROOT)
        before.parent.mkdir(parents=True, exist_ok=True)
        before.write_bytes(path.read_bytes())
        content = content.rstrip() + '\n\n#: game/ui/garage_page.gd\n' + identity + 'msgstr ' + json.dumps(value, ensure_ascii=False) + '\n'
        path.write_text(content, encoding="utf-8", newline="\n")
    print("Added Super Wash in all 12 catalogues and the source template")


if __name__ == "__main__":
    main()
