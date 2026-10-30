"""Validate the owned message with the repository's localization rules."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
import localization

messages = {key: value for key, value in localization.collect().items() if key[1] == "Super Wash"}
assert len(messages) == 1
errors = []
for language in ["en", "fr", "es", "de", "pt_BR", "ja", "ko", "nl", "it", "fi", "sv", "nb"]:
    entries = localization.parse_po((ROOT / "game/localization" / (language + ".po")).read_text(encoding="utf-8"))
    selected = {key: value for key, value in entries.items() if key in messages or key == ("", "")}
    errors.extend(localization.validate(selected, messages, language))
assert not errors, errors
print("SUPER_WASH_LOCALIZATION: 12 catalogues pass")
