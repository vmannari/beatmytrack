"""Retain unrelated source-inventory drift and verify this task's ten messages."""
import json
from pathlib import Path
import sys
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))
import localization as catalog

current = catalog.collect()
current_pot = catalog.parse_po((catalog.DESTINATION / "messages.pot").read_text(encoding="utf-8"))
read = Path.read_text
sources = catalog.sources()

def before_read(path, *args, **kwargs):
    try:
        before = HERE / "before" / path.relative_to(ROOT)
    except ValueError:
        return read(path, *args, **kwargs)
    return read(before if before.exists() else path, *args, **kwargs)

with patch.object(Path, "read_text", before_read), patch.object(catalog, "sources", lambda: [p for p in sources if p.name != "draft_terms_dialog.gd"]):
    baseline = catalog.collect()
    baseline_pot = catalog.parse_po((HERE / "before/game/localization/messages.pot").read_text(encoding="utf-8"))

keys = ["Ready to race?", "Sign in to save results online, join events and race friends.", "Continue with Google", "Play as guest", "Local progress stays on this device. Events require sign-in.", "Terms of Service (draft)", "I agree to the {terms}", "I agree to the draft Terms of Service", "Save a copy", "Could not save the terms. Please try again."]
locales = json.loads((catalog.DESTINATION / "languages.json").read_text(encoding="utf-8"))["languages"]
for locale in locales:
    entries = catalog.parse_po((catalog.DESTINATION / (locale + ".po")).read_text(encoding="utf-8"))
    for source in keys:
        value = entries[("", source)]["msgstr"]
        assert value and catalog.placeholders(value) == catalog.placeholders(source), (locale, source)

result = {
    "task_messages": len(keys), "locales": len(locales), "translated_placeholder_checks": len(keys) * len(locales),
    "task_start_ui_control_source_catalogue_current": catalog.source_catalogue_matches(read(HERE / "before/game/localization/messages.pot", encoding="utf-8"), baseline),
    "task_start_ui_control_missing_keys": len(set(baseline) - set(baseline_pot)),
    "current_source_catalogue_current": catalog.source_catalogue_matches(read(catalog.DESTINATION / "messages.pot", encoding="utf-8"), current),
    "current_missing_keys": len(set(current) - set(current_pot)),
    "control_scope": "Task-start owned UI sources and catalogues substituted in process memory; other concurrent sources remain current. No runtime rollback.",
}
(HERE / "catalogue-audit.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result, indent=2))
