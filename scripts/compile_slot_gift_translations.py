"""Append only the directly authored gift strings to the retained catalogues."""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ["en", "fr", "es", "de", "pt_BR", "ja", "ko", "nl", "it", "fi", "sv", "nb"]


def main():
    rows = []
    for row in (ROOT / "scripts/translations/slot_gifts.tsv").read_text(encoding="utf-8").splitlines():
        if not row or row.startswith("#"):
            continue
        fields = [value.replace(r"\n", "\n") for value in row.split("|")]
        if len(fields) != len(LANGUAGES):
            raise ValueError("Expected English and eleven translations")
        rows.append(fields)
    for index, language in enumerate(LANGUAGES):
        path = ROOT / "game/localization" / (language+".po")
        backup = ROOT / "docs/evidence/track-slot-gifts-2026-10-25/before" / path.relative_to(ROOT)
        backup.parent.mkdir(parents=True, exist_ok=True)
        if not backup.exists():
            shutil.copy2(path, backup)
        text = path.read_text(encoding="utf-8")
        for fields in rows:
            identity = "msgid " + json.dumps(fields[0], ensure_ascii=False)
            if identity+"\n" in text:
                continue
            text = text.rstrip()+"\n\n#: game/ui/store_page.gd\n"+identity+"\nmsgstr "+json.dumps(fields[index], ensure_ascii=False)+"\n"
        path.write_text(text, encoding="utf-8", newline="\n")
    print(f"Compiled {len(rows)} gift strings in {len(LANGUAGES)} languages")


if __name__ == "__main__":
    main()
