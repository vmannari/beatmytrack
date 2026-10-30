"""Check shipped text and translation inputs for damaged Unicode; never rewrite it.

Run `python scripts/text_encoding.py` before shipping. Legitimate accented letters,
CJK text, punctuation, emoji and combining marks are retained without normalization.
"""
from __future__ import annotations

import argparse
import json
import os
import re
from dataclasses import asdict, dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTINUATIONS = ''.join(bytes([value]).decode('cp1252', errors='ignore')
                        for value in range(0x80, 0xc0)) + ''.join(map(chr, range(0x80, 0xc0)))
MOJIBAKE = re.compile('[\u00c2-\u00f4][' + re.escape(CONTINUATIONS) + ']{1,3}')
INVALID = re.compile('[\ufffd\ud800-\udfff\x00-\x08\x0b\x0e-\x1f\x7f-\x9f]')
EXTENSIONS = {'.gd', '.tscn', '.tres', '.json', '.po', '.pot', '.txt', '.csv', '.tsv',
              '.svg', '.html', '.css', '.js', '.py', '.xml', '.java', '.kt', '.cfg',
              '.gradle', '.kts', '.fnt', '.gdshader', '.cpp', '.h', '.hpp', '.c'}


@dataclass(frozen=True)
class Issue:
    offset: int
    text: str
    reason: str
    replacement: str = ''


def find_issues(text: str) -> list[Issue]:
    """Recognize only reversible UTF-8/legacy-byte damage and invalid controls."""
    result = []
    covered = set()
    for match in MOJIBAKE.finditer(text):
        for encoding in ('cp1252', 'latin1'):
            lead = ord(match[0][0])
            count = 2 if lead < 0xe0 else 3 if lead < 0xf0 else 4
            original = match[0][:count]
            if len(original) != count:
                continue
            try:
                replacement = original.encode(encoding).decode('utf-8')
            except (UnicodeEncodeError, UnicodeDecodeError):
                continue
            result.append(Issue(match.start(), original, 'misdecoded UTF-8', replacement))
            covered.update(range(match.start(), match.start() + count))
            break
    for match in INVALID.finditer(text):
        if match.start() not in covered:
            reason = ('replacement character' if match[0] == '\ufffd' else
                      'unpaired surrogate' if 0xd800 <= ord(match[0]) <= 0xdfff else
                      'unexpected control character')
            result.append(Issue(match.start(), match[0], reason))
    return sorted(result, key=lambda issue: issue.offset)


def source_files(root: Path = ROOT):
    """Include game resources/notices, all catalogues and authored translations.

    Also check the first-party backend/UI and Android sign-in adapter. Historical
    test fixtures, generated caches, builds and external vendor trees are excluded.
    """
    for relative in ('game', 'scripts/translations', 'scripts/localization_overrides.json',
                     'backend/bmt_backend', 'native'):
        base = root / relative
        if base.is_file():
            yield base
        elif base.is_dir():
            for directory, folders, names in os.walk(base):
                folders[:] = sorted(folder for folder in folders if folder not in {
                    '.godot', '.git', 'tests', '__pycache__', 'build', '.gradle',
                    'godot-cpp', 'vendor', 'third_party', 'android'})
                for name in sorted(names):
                    path = Path(directory) / name
                    if path.suffix in EXTENSIONS:
                        yield path


def scan(root: Path = ROOT) -> dict:
    files = list(source_files(root))
    issues = []
    for path in files:
        try:
            text = path.read_text(encoding='utf-8-sig')
        except UnicodeDecodeError as error:
            issues.append({'file': path.relative_to(root).as_posix(), 'reason': 'invalid UTF-8',
                           'byte_offset': error.start})
            continue
        for issue in find_issues(text):
            issues.append({'file': path.relative_to(root).as_posix(),
                           'line': text.count('\n', 0, issue.offset) + 1, **asdict(issue)})
        # JSON can hide damaged display text behind syntactically valid escapes.
        if path.suffix == '.json' and re.search(r'\\u[0-9a-fA-F]{4}', text):
            try:
                document = json.loads(text)
            except ValueError:
                continue  # Syntax validation belongs to the resource's own gate.
            pending = [document]
            while pending:
                value = pending.pop()
                if isinstance(value, dict):
                    pending.extend(value.keys())
                    pending.extend(value.values())
                elif isinstance(value, list):
                    pending.extend(value)
                elif isinstance(value, str):
                    for issue in find_issues(value):
                        issues.append({'file': path.relative_to(root).as_posix(),
                                       'location': 'decoded JSON string', **asdict(issue)})
    return {'files_checked': len(files), 'issues': issues}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--json', type=Path, help='Write the complete check result')
    args = parser.parse_args()
    result = scan()
    if args.json:
        args.json.write_text(json.dumps(result, ensure_ascii=True, indent=2) + '\n', encoding='utf-8')
    for issue in result['issues'][:40]:
        print(f"{issue['file']}:{issue.get('line', '?')}: {issue['reason']} {issue.get('text', '')!a}")
    print(f"TEXT_ENCODING: {result['files_checked']} files, {len(result['issues'])} issues")
    raise SystemExit(bool(result['issues']))


if __name__ == '__main__':
    main()
