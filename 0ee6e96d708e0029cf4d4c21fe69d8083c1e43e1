"""Deterministic, dependency-free gettext source extraction and catalogue checks.

Run `python scripts/localization.py extract` after changing display copy, and
`python scripts/localization.py check` before shipping. English is the fallback.
Only languages explicitly listed in languages.json are offered to players.
"""
from __future__ import annotations

import argparse
import ast
import json
from pathlib import Path
import re
import string

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "game/localization"
TOKEN = re.compile(r'''#[^\n]*|""".*?"""|\x27\x27\x27.*?\x27\x27\x27|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27''', re.S)
CALL = re.compile(r'\b(tr_n|tr|GameText\.message|GameText\.plural|GameText\.bind_upper|GameText\.bind)\(')
PERCENT = re.compile(r"%(?:[-+0 #]*)(?:\d+|\*)?(?:\.\d+)?[sdiffoxXc]")


def display_text(value: str) -> bool:
    """Inventory presentation literals, including arrays passed through UI helpers.

    The inventory is intentionally conservative: some unused diagnostic copy can
    be included, but resource paths, identifiers and canonical data are excluded.
    """
    if not value.strip() or not re.search(r"[A-Za-z]", PERCENT.sub("", value)):
        return False
    if any(part in value for part in ("res://", "user://", "http://", "https://")):
        return False
    if re.match(r"^/[a-z][a-z0-9_/-]*[?=]", value):
        return False  # API routes and serialized batch delimiters, never captions.
    if re.search(r"\b(shader_type|uniform|EMISSION|ALBEDO)\b", value) or "<" in value and any(part in value for part in ("fill=", "stroke=", "<svg", "<defs", "</")) or value.startswith('width="') and 'viewBox=' in value:
        return False
    if "_" in value.strip() and not re.search(r"\s", value.strip()):
        return False
    if r"\s" in value or r"\(" in value:
        return False
    if re.fullmatch(r"[a-z0-9_./:#-]+", value) or re.fullmatch(r"[A-Z0-9_]+", value) and "_" in value:
        return False
    if re.fullmatch(r"[\w./:-]+\.(gd|json|png|svg|tres|tscn|wav|ogg|cfg|tmp|bak)", value):
        return False
    return True


def sources() -> list[Path]:
    files = [*ROOT.glob("game/ui/*.gd"), *ROOT.glob("game/tutorial/*.gd"), *ROOT.glob("game/editor/*.gd"),
             *ROOT.glob("game/vehicle/*catalog.gd"), ROOT / "game/core/app.gd",
             ROOT / "game/backend/account_controller.gd", ROOT / "game/backend/cosmetic_economy.gd",
             ROOT / "game/backend/cloud_tracks.gd", ROOT / "game/input/control_layout.gd",
             ROOT / "game/track/track_theme.gd", ROOT / "game/soundtrack/record_library.gd",
             ROOT / "game/camera/camera_profile.gd", ROOT / "game/race/personal_ghost_run.gd",
             ROOT / "game/vehicle/vehicle_customisation.gd",
             ROOT / "game/presentation/graphics_preferences.gd"]
    return sorted(path for path in files if path.exists())


def translation_calls(text: str):
    """Find constant message/context arguments without evaluating GDScript code."""
    masked = TOKEN.sub(lambda match: " " * len(match.group()), text)
    for call in CALL.finditer(masked):
        arguments = []
        depth, cursor, start = 1, call.end(), call.end()
        while cursor < len(text):
            token = TOKEN.match(text, cursor)
            if token:
                cursor = token.end()
                continue
            char = text[cursor]
            if char in "([{":
                depth += 1
            elif char in ")]}":
                depth -= 1
                if depth == 0:
                    arguments.append(text[start:cursor].strip())
                    break
            elif char == "," and depth == 1:
                arguments.append(text[start:cursor].strip())
                start = cursor + 1
            cursor += 1

        def constant(index: int) -> str:
            try:
                value = ast.literal_eval(arguments[index])
                return value if isinstance(value, str) else ""
            except (IndexError, ValueError, SyntaxError):
                return ""

        indices = {"tr": (0, None, 1), "tr_n": (0, 1, 3),
                   "GameText.message": (0, None, 2), "GameText.plural": (0, 1, 4),
                   "GameText.bind": (1, 3, 5), "GameText.bind_upper": (1, None, 2)}
        source, many, context = indices[call[1]]
        if constant(source):
            yield constant(source), constant(many) if many is not None else "", constant(context), text.count("\n", 0, call.start()) + 1


def collect() -> dict[tuple[str, str], dict]:
    messages: dict[tuple[str, str], dict] = {}

    def add(value: str, reference: str, many: str = "", context: str = "") -> None:
        entry = messages.setdefault((context, value), {"plural": many, "references": set()})
        if many:
            if entry["plural"] and entry["plural"] != many:
                raise ValueError(f"Conflicting plural for {value!r}")
            entry["plural"] = many
        entry["references"].add(reference)

    for path in sources():
        text = path.read_text(encoding="utf-8-sig")
        relative = path.relative_to(ROOT).as_posix()
        # Mask comments without changing source offsets for subsequent scans.
        for token in TOKEN.finditer(text):
            if token.group().startswith("#"):
                continue
            # Embedded shader source is code, not display copy.
            if token.group().startswith(('"""', "'''")):
                continue
            value = ast.literal_eval(token.group())
            # Query/classifier keys and node lookups are not visible copy. A
            # literal used elsewhere for a Label or explicit tr() is still added.
            prefix = text[max(0, token.start()-160):token.start()]
            if re.search(r'\.find_children\([^\n]*,\s*$', prefix):
                continue  # The second argument is an engine class, not copy.
            if (relative == "game/editor/track_compiler.gd" and value in {"creator route origin", "local creator", "original route with built-in track kit"}
                    or relative == "game/editor/track_document.gd" and value == " remix"):
                continue  # Canonical document provenance/default creator title.
            if re.search(r'\.(?:contains|begins_with|ends_with|trim_prefix|trim_suffix|find|rfind|find_child|get_node|has_node|set_meta|get_meta|has_meta|add_to_group|is_in_group|remove_from_group|replace)\(\s*$', prefix):
                continue
            if re.search(r'(?:\b(?:print|printerr|print_debug|push_error|push_warning)\(\s*|\.name\s*=\s*)$', prefix):
                continue
            if re.search(r'\bassert\([^\n]*,\s*$', prefix):
                continue
            if display_text(value):
                add(value, f"{relative}:{text.count(chr(10), 0, token.start()) + 1}")
        for source, many, context, line in translation_calls(text):
            reference = f"{relative}:{line}"
            for literal in ([source] if context else []) + ([many] if many else []):
                entry = messages.get(("", literal))
                if entry:
                    entry["references"].discard(reference)
                    if not entry["references"]:
                        del messages[("", literal)]
            add(source, reference, many, context)
    # This model also contains sample driver/track names; inventory only its
    # explicit presentation calls rather than treating those names as UI copy.
    path = ROOT / "game/race/weekly_rivalry.gd"
    for source, many, context, line in translation_calls(path.read_text(encoding="utf-8-sig")):
        add(source, f"{path.relative_to(ROOT).as_posix()}:{line}", many, context)
    # Licence headings are UI copy; legal bodies and copyright notices stay exact.
    path = ROOT / "game/legal/third_party_notices.gd"
    text = path.read_text(encoding="utf-8-sig")
    for match in re.finditer(r'"title":\s*("(?:[^"\\]|\\.)*")', text):
        add(ast.literal_eval(match[1]), f"{path.relative_to(ROOT).as_posix()}:{text.count(chr(10), 0, match.start()) + 1}")
    for path in (ROOT / "game/persistence/achievement_catalog.json",):
        data = json.loads(path.read_text(encoding="utf-8"))
        for family in data["families"]:
            for field in ("title", "category", "description"):
                if field in family:
                    value = family[field]
                    singular = value
                    if field == "description":
                        for word in ("races", "tracks", "cars", "biomes", "times", "challenges", "weeks", "friends"):
                            singular = singular.replace("{n} different " + word, "{n} " + word[:-1])
                            singular = singular.replace("{n} " + word, "{n} " + word[:-1])
                        singular = singular.replace("{n} Weekly Rivalry weeks", "{n} Weekly Rivalry week")
                    add(singular, f"{path.relative_to(ROOT).as_posix()}:{family['id']}/{field}", value if singular != value else "")
    return messages


def quoted(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def render(messages: dict, english: bool = False) -> str:
    lines = ['# Beat My Track display copy. Generated by scripts/localization.py.',
             '# Names, creator titles, protocol identifiers and canonical documents are not translated.',
             'msgid ""', 'msgstr ""',
             quoted("Project-Id-Version: Beat My Track\n"),
             quoted("Language: en\n" if english else "Language: \n"),
             quoted("MIME-Version: 1.0\n"), quoted("Content-Type: text/plain; charset=UTF-8\n"),
             quoted("Content-Transfer-Encoding: 8bit\n"),
             quoted("Plural-Forms: nplurals=2; plural=(n != 1);\n"), ""]
    for (context, source), entry in sorted(messages.items()):
        lines.append("#: " + " ".join(sorted(entry["references"])))
        if context:
            lines.append("msgctxt " + quoted(context))
        lines.append("msgid " + quoted(source))
        if entry["plural"]:
            lines.extend(["msgid_plural " + quoted(entry["plural"]),
                          "msgstr[0] " + quoted(source if english else ""),
                          "msgstr[1] " + quoted(entry["plural"] if english else "")])
        else:
            lines.append("msgstr " + quoted(source if english else ""))
        lines.append("")
    return "\n".join(lines) + "\n"


def parse_po(text: str) -> dict:
    """Read gettext fields and continuation lines; reject duplicates and malformed entries."""
    entries: dict = {}
    entry: dict[str, str] = {}
    field = ""
    fuzzy = False

    def finish() -> None:
        nonlocal entry, field, fuzzy
        if entry:
            if "msgid" not in entry or not any(key.startswith("msgstr") for key in entry):
                raise ValueError("Incomplete PO entry")
            key = (entry.get("msgctxt", ""), entry["msgid"])
            if key in entries:
                raise ValueError(f"Duplicate PO entry: {key}")
            entries[key] = {**entry, "fuzzy": fuzzy}
        entry, field, fuzzy = {}, "", False

    for number, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line:
            finish()
        elif line.startswith("#"):
            fuzzy |= line.startswith("#,") and "fuzzy" in line
        elif line.startswith('"'):
            if not field:
                raise ValueError(f"Orphan continuation at line {number}")
            entry[field] += ast.literal_eval(line)
        else:
            match = re.fullmatch(r'(msgctxt|msgid_plural|msgid|msgstr(?:\[\d+\])?)\s+(".*")', line)
            if not match or match[1] in entry:
                raise ValueError(f"Invalid PO field at line {number}")
            field = match[1]
            entry[field] = ast.literal_eval(match[2])
    finish()
    return entries


def placeholders(value: str) -> tuple:
    named = sorted(field for _, field, _, _ in string.Formatter().parse(value) if field is not None)
    # Written percentages, including French/Nordic spacing, are prose.
    value = re.sub(r"(?<=\d)[ \u00a0\u202f]*%(?![A-Za-z0-9])", "", value)
    percent = [item[-1] for item in PERCENT.findall(value.replace("%%", ""))]
    return named, percent


def source_catalogue_matches(text: str, messages: dict) -> bool:
    # Source locations help translators, but moving code does not change copy.
    # Compare every key/context/plural, rather than requiring current line numbers.
    actual = {key: entry.get("msgid_plural", "") for key, entry in parse_po(text).items() if key[1]}
    return actual == {key: entry["plural"] for key, entry in messages.items()}


def validate(entries: dict, messages: dict, language: str) -> list[str]:
    errors = []
    header = entries.get(("", ""), {}).get("msgstr", "")
    if f"Language: {language}\n" not in header or "charset=UTF-8" not in header:
        errors.append(f"{language}: missing language/UTF-8 header")
    plural_forms = re.search(r"nplurals=(\d+)", header)
    forms = int(plural_forms[1]) if plural_forms else 0
    for key, entry in entries.items():
        if not key[1]:
            continue
        if key not in messages:
            errors.append(f"{language}: obsolete message {key!r}")
            continue
        plural = messages[key]["plural"]
        if entry.get("msgid_plural", "") != plural:
            errors.append(f"{language}: mismatched plural for {key!r}")
        translations = [entry.get(f"msgstr[{i}]", "") for i in range(forms)] if plural else [entry.get("msgstr", "")]
        if entry["fuzzy"] or not translations or not all(translations):
            errors.append(f"{language}: untranslated message {key!r}")
        for value in translations:
            if value and placeholders(value) != placeholders(key[1]):
                errors.append(f"{language}: changed placeholders in {key!r}")
    missing = messages.keys() - entries.keys()
    errors.extend(f"{language}: missing message {key!r}" for key in sorted(missing))
    return errors


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["extract", "check"])
    args = parser.parse_args()
    messages = collect()
    expected = render(messages)
    if args.action == "extract":
        (DESTINATION / "messages.pot").write_text(expected, encoding="utf-8", newline="\n")
        (DESTINATION / "en.po").write_text(render(messages, True), encoding="utf-8", newline="\n")
        print(f"Extracted {len(messages)} messages; refreshed English catalogue")
        return
    errors = []
    if not source_catalogue_matches((DESTINATION / "messages.pot").read_text(encoding="utf-8"), messages):
        errors.append("Source catalogue is stale; run python scripts/localization.py extract")
    manifest = json.loads((DESTINATION / "languages.json").read_text(encoding="utf-8"))["languages"]
    project = (ROOT / "game/project.godot").read_text(encoding="utf-8")
    exports = (ROOT / "game/export_presets.cfg").read_text(encoding="utf-8")
    if 'localization/languages.json' not in exports:
        errors.append("Language manifest is not included in the Android export")
    for language in manifest:
        path = DESTINATION / f"{language}.po"
        if f'res://localization/{language}.po' not in project:
            errors.append(f"{language}: approved catalogue is not registered in project.godot")
        if not path.exists():
            errors.append(f"{language}: catalogue is missing")
        else:
            errors.extend(validate(parse_po(path.read_text(encoding="utf-8")), messages, language))
    if errors:
        raise SystemExit("\n".join(errors[:40]) + f"\n{len(errors)} localisation errors")
    print(f"LOCALIZATION: {len(messages)} messages, {len(manifest)} approved language(s), valid placeholders and current source catalogue")


if __name__ == "__main__":
    main()
