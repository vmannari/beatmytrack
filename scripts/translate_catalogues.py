"""Compile directly authored translations. No inference, model or network code.

Pipe-separated rows: English, fr, es, de, pt_BR, ja, ko, nl, it, fi, sv, nb.
Newlines use literal \\n and significant spaces may use \\s.
Compilation requires complete copy.
"""
from __future__ import annotations
import argparse
import json
import re
import localization as catalog

LANGUAGES = {code: f"nplurals={forms}; plural={rule};" for code, forms, rule in (
    ("fr", 2, "(n > 1)"), ("es", 2, "(n != 1)"), ("de", 2, "(n != 1)"),
    ("pt_BR", 2, "(n > 1)"), ("ja", 1, "0"), ("ko", 1, "0"),
    ("nl", 2, "(n != 1)"), ("it", 2, "(n != 1)"), ("fi", 2, "(n != 1)"),
    ("sv", 2, "(n != 1)"), ("nb", 2, "(n != 1)"))}

def authored():
    result = json.loads((catalog.ROOT / "scripts/localization_overrides.json").read_text(encoding="utf-8"))
    for path in sorted((catalog.ROOT / "scripts/translations").glob("*.tsv")):
        for number, row in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if not row or row.startswith("#"):
                continue
            fields = [field.replace(r"\n", "\n").replace(r"\s", " ").replace(r"\p", "|") for field in row.split("|")]
            if len(fields) != 12:
                raise ValueError(f"{path.name}:{number}: expected 12 columns, found {len(fields)}")
            result[fields[0]] = dict(zip(LANGUAGES, fields[1:]))
    return result

def identity(s):
    units = catalog.PERCENT.sub("", s)
    return bool(re.search(r"[a-z][A-Z]", s) and " " not in s or s.startswith(("<path", "<svg", "<circle", "<rect"))
                or re.fullmatch(r"[0-9 +−×/.:·%\-]*(?:km/h|km|KM|m|s|x|S)[0-9 +−×/.:·%\-]*", units)
                or s in {"A / D  ·  ← / →", "W / S  ·  ↑ / ↓", "Space  ·  R  ·  Esc", "{n}", "{car} · {distance}"}
                or re.fullmatch(r"[A-Z0-9]|[0-9 /.:+%\-]+", s)
                or re.fullmatch(r"(?:COMPACT|HAULER|REARSPORT|FORMULA|KART|FORKLIFT|VOLT) / \d+", s)
                or s in {"FXAA","HSeparator","ND","RD","ST","TH","BEAT","MY","BMT / RECORDS","ids=",", cull_disabled"} or re.fullmatch(r"MSAA \dx",s)
                or s in {"Beat My Track", "Beat my track", "BEAT MY TRACK", "BEAT\nMY TRACK", "B E A T   M Y   T R A C K", "Google", "AdMob", "Android", "Joystick", "Jules", "Mira", "Noa", "UTC", "FPS", "LP", "PNG", "Compact Circuit", "COMPACT CIRCUIT", "After Hours", "Golden Hour", "Midnight", "Night Drive", "Open Road", "Trackside", "Workshop Sessions", "Coastline"}
                or s.startswith(("&", "--", "/ranking?", "/runs/", "/tracks?", "ALPHA ", "CAPTURE_SAVED:", "RACE_LOAD_STAGE ")))

def uppercase_copy(value):
    """Keep interpolation tokens byte-exact when matching an uppercase label."""
    token = re.compile(r"\{[^{}]*\}|" + catalog.PERCENT.pattern)
    parts, start = [], 0
    for match in token.finditer(value):
        parts.extend((value[start:match.start()].upper(), match[0]))
        start = match.end()
    return "".join(parts) + value[start:].upper()

def resolve(source, rows):
    if source in rows:
        return rows[source]
    punctuation_variant = source.replace("’", "'")
    if punctuation_variant != source and punctuation_variant in rows:
        return rows[punctuation_variant]
    if identity(source.strip()):
        return dict.fromkeys(LANGUAGES, source)
    if re.fullmatch(r"[ +\-0-9.%df]+ deg", source):
        return dict.fromkeys(LANGUAGES, source.replace(" deg", "°"))
    plain = source.strip()
    # Whitespace belongs to the containing label, not to its wording.
    trimmed = {key.strip(): value for key, value in rows.items() if key.strip()}
    if plain in trimmed:
        prefix = re.match(r"\s*", source)[0]
        ending = re.search(r"\s*$", source)[0]
        return {code: prefix + value.strip() + ending for code, value in trimmed[plain].items()}
    dimensions = re.fullmatch(r"(.+?)(\s+[+\-−])", plain)
    if dimensions and dimensions[1] in rows:
        return {code: value + dimensions[2] for code, value in rows[dimensions[1]].items()}
    decoration = re.match(r"^(?:[·—/←↑↓↻‹+.\-]\s+)", plain)
    if decoration:
        rest = resolve(plain[decoration.end():], rows)
        if rest:
            return {code: decoration[0] + value for code, value in rest.items()}
    # Compose only independently authored complete sentences; retain paragraph
    # breaks and printf order. This never translates individual unknown words.
    clauses = re.split(r'(?<=[.!?])(\s+)(?=[A-Z0-9])', plain)
    if len(clauses) > 1:
        pieces = [resolve(part, rows) if index % 2 == 0 else dict.fromkeys(LANGUAGES, part) for index, part in enumerate(clauses)]
        if all(piece is not None for piece in pieces):
            prefix = re.match(r"\s*", source)[0]
            ending = re.search(r"\s*$", source)[0]
            return {code: prefix + "".join(piece[code] for piece in pieces) + ending for code in LANGUAGES}
    for template, entry in rows.items():
        if "{object}" not in template:
            continue
        before, after = template.split("{object}")
        if plain.startswith(before) and plain.endswith(after) and len(plain) > len(before) + len(after):
            item = plain[len(before):len(plain) - len(after) if after else None]
            punctuation = ""
            if not after:
                ending = re.search(r"(?:\.\.\.|…|\.)$", item)
                if ending:
                    punctuation = ending[0]
                    item = item[:ending.start()]
            target = resolve(item, {key: value for key, value in rows.items() if "{object}" not in key})
            if target:
                return {code: entry[code].replace("{object}", target[code]) + punctuation for code in LANGUAGES}
    suffix = ""
    while plain.endswith((" ›", " →", ".", "…", "...", ":")):
        tail = next((ending for ending in ("...", " ›", " →", ".", "…", ":") if plain.endswith(ending)))
        suffix = tail + suffix
        plain = plain[:-len(tail)].rstrip()
    for key in (plain, plain.title(), plain.capitalize(), plain.lower(), plain.upper()):
        if key in rows:
            prefix = re.match(r"\s*", source)[0]
            ending = re.search(r"\s*$", source)[0]
            uppercase = catalog.PERCENT.sub("", re.sub(r'\{[^}]*\}', "", source)).strip().isupper()
            return {code: prefix + (uppercase_copy(value) if uppercase else value) + ("。" if code == "ja" and suffix == "." else "：" if code == "ja" and suffix == ":" else " :" if code == "fr" and suffix == ":" else suffix) + ending for code, value in rows[key].items()}
    return None

def render(messages, language, values):
    rules = LANGUAGES[language]
    forms = int(re.search(r"nplurals=(\d+)", rules)[1])
    q = catalog.quoted
    lines = ["# Beat My Track: directly authored translations.",
             "# Empty entries use English fallback. Run the completeness checks before release.", 'msgid ""', 'msgstr ""',
             q("Project-Id-Version: Beat My Track\n"), q(f"Language: {language}\n"),
             q("MIME-Version: 1.0\n"), q("Content-Type: text/plain; charset=UTF-8\n"),
             q("Content-Transfer-Encoding: 8bit\n"), q(f"Plural-Forms: {rules}\n"), ""]
    for (context, source), entry in sorted(messages.items()):
        lines.append("#: " + " ".join(sorted(entry["references"])))
        if context:
            lines.append("msgctxt " + q(context))
        lines.append("msgid " + q(source))
        if entry["plural"]:
            lines.append("msgid_plural " + q(entry["plural"]))
            lines.extend(f"msgstr[{i}] " + q(values[source if i == 0 else entry["plural"]]) for i in range(forms))
        else:
            lines.append("msgstr " + q(values[source]))
        lines.append("")
    return "\n".join(lines).rstrip("\n") + "\n"

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-incomplete", action="store_true")
    args = parser.parse_args()
    rows = authored()
    messages = catalog.collect()
    sources = sorted({s for _, s in messages} | {v["plural"] for v in messages.values() if v["plural"]})
    values = {source: resolve(source, rows) for source in sources}
    missing = [source for source in sources if values[source] is None]
    report = {"authorship": "direct assistant authorship; no translation model", "messages": len(messages), "authored_rows": len(rows), "missing": missing}
    (catalog.ROOT / "build/direct-translation-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(sources) - len(missing)}/{len(sources)} sources covered; {len(missing)} remaining")
    if missing and not args.allow_incomplete:
        raise SystemExit("Author the remaining sources listed in build/direct-translation-report.json")
    for language in LANGUAGES:
        translated = {source: item[language] if item else "" for source, item in values.items()}
        (catalog.DESTINATION / f"{language}.po").write_text(render(messages, language, translated), encoding="utf-8", newline="\n")

if __name__ == "__main__":
    main()
