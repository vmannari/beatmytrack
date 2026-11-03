"""Append only this design's authored messages, preserving concurrent catalogues."""
from pathlib import Path
import json
import shutil
import sys

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
sys.path.insert(0, str(root / "scripts"))
import localization

languages = ["en", "fr", "es", "de", "pt_BR", "ja", "ko", "nl", "it", "fi", "sv", "nb"]
rows = [line.split("|") for line in (root / "scripts/translations/daily_results_design.tsv")
        .read_text(encoding="utf-8").splitlines() if line and not line.startswith("#")]
assert all(len(row) == len(languages) and all(row) for row in rows)
checks = 0
for code in languages + ["messages"]:
    relative = Path("game/localization") / (code + (".pot" if code == "messages" else ".po"))
    path = root / relative
    backup = out / "before" / relative
    if not backup.exists():
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, backup)
    text = path.read_text(encoding="utf-8")
    entries = localization.parse_po(text)
    addition = []
    for row in rows:
        source = row[0]
        translated = "" if code == "messages" else row[languages.index(code)]
        if ("", source) not in entries:
            addition.append("#: game/ui/daily_elimination_results.gd game/ui/daily_results_standings.gd\n"
                            "msgid " + json.dumps(source, ensure_ascii=False) + "\n"
                            "msgstr " + json.dumps(translated, ensure_ascii=False))
    if addition:
        path.write_text(text.rstrip() + "\n\n" + "\n\n".join(addition) + "\n", encoding="utf-8")
    updated = localization.parse_po(path.read_text(encoding="utf-8"))
    if code != "messages":
        for row in rows:
            assert updated["", row[0]]["msgstr"]
            assert localization.placeholders(updated["", row[0]]["msgstr"]) == localization.placeholders(row[0])
            checks += 1
print(f"DAILY_RESULTS_CATALOGUES: {checks} authored entries, nonempty and matching placeholders")
