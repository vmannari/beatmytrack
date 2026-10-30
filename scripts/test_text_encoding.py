"""Exercise byte-encoding damage separately from legitimate multilingual text."""
import json
import tempfile
import unittest
from pathlib import Path

import text_encoding as encoding


class TextEncodingTests(unittest.TestCase):
    def test_utf8_misdecoded_as_windows1252_is_detected(self):
        for expected in ('…', '·', '×', '→', '−', '✓', '°', '–', '“', 'é', 'å', '😀'):
            with self.subTest(expected=expected):
                damaged = expected.encode().decode('cp1252')
                issues = encoding.find_issues('Text ' + damaged + ' end')
                self.assertEqual(len(issues), 1)
                self.assertEqual(issues[0].replacement, expected)
                self.assertEqual(issues[0].offset, 5)

    def test_latin1_damage_and_lost_bytes_are_detected(self):
        damaged = '✓'.encode().decode('latin1')
        self.assertEqual(encoding.find_issues(damaged)[0].replacement, '✓')
        for value in ('\ufffd', '\x00', '\x85', '\x9f'):
            self.assertTrue(encoding.find_issues(value))

    def test_valid_multilingual_text_is_accepted_without_normalizing(self):
        for value in ('Loading… 3×3 · 22.5° → ✓ −', 'Ångström, Ää, Öö, déjà vu, Português',
                      'Âge, âme, Ã, â, ð, Þ', '読み込み中… 日本語', '불러오는 중… 한국어',
                      '😀 🏎️ 🏁', 'e\u0301', 'Line one\nLine two\tValue\fPage two', '«Été»'):
            with self.subTest(value=value):
                self.assertEqual(encoding.find_issues(value), [])

    def test_adjacent_damage_and_valid_punctuation_are_separate(self):
        damaged = '·'.encode().decode('cp1252')
        issues = encoding.find_issues(damaged + damaged + '…')
        self.assertEqual([issue.replacement for issue in issues], ['·', '·'])

    def test_scanner_includes_notices_and_rejects_invalid_utf8(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'game/legal').mkdir(parents=True)
            (root / 'game/tests').mkdir()
            (root / 'game/.godot').mkdir()
            (root / 'game/legal/notice.txt').write_text('Lost \ufffd quote', encoding='utf-8')
            (root / 'game/invalid.gd').write_bytes(b'"invalid \xff"')
            for name in ('game/tests/before.gd', 'game/.godot/generated.gd'):
                (root / name).write_text('\ufffd', encoding='utf-8')
            report = encoding.scan(root)
            self.assertEqual(report['files_checked'], 2)
            self.assertEqual({issue['reason'] for issue in report['issues']},
                             {'invalid UTF-8', 'replacement character'})

    def test_current_shipped_text_is_clean(self):
        self.assertEqual(encoding.scan()['issues'], [])

    def test_json_escapes_are_checked_after_decoding(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'game').mkdir()
            path = root / 'game/captions.json'
            damaged = '…'.encode().decode('cp1252')
            path.write_text(json.dumps({'caption': damaged, 'nested': ['\ud800']}), encoding='utf-8')
            issues = encoding.scan(root)['issues']
            self.assertEqual({issue['reason'] for issue in issues}, {'misdecoded UTF-8', 'unpaired surrogate'})
            path.write_text(json.dumps({'caption': '読み込み中…', 'emoji': '😀'}), encoding='utf-8')
            self.assertEqual(encoding.scan(root)['issues'], [])


if __name__ == '__main__':
    unittest.main()
