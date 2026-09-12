"""Additional v2 corpus regression; sources stay outside the runtime/export root.

Usage: python test_extra_convert.py <175-track ZIP> <handoff/SLICKS.DAT>
"""
import hashlib
import json
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

import jsonschema

from convert import convert
from slicks_ss_parser import parse_ss
from slicks_track_renderer_corrected import parse_dat

ARCHIVE = Path(sys.argv.pop(1))
DAT = Path(sys.argv.pop(1))
ROOT = Path(__file__).resolve().parents[2]


class ExtraConversionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.golden = json.loads(Path(__file__).with_name('extra_golden.json').read_text())
        cls.config = json.loads(Path(__file__).with_name('config.json').read_text())
        cls.schema = json.loads((ROOT / 'docs/native_track.schema.json').read_text())
        cls.resources, _ = parse_dat(DAT)

    def test_archive_and_dat_are_pinned(self):
        self.assertEqual(hashlib.sha256(ARCHIVE.read_bytes()).hexdigest(), self.golden['archive_sha256'])
        self.assertEqual(hashlib.sha256(DAT.read_bytes()).hexdigest(), self.golden['dat_sha256'])

    def test_three_native_fixtures_preserve_source_contracts(self):
        with zipfile.ZipFile(ARCHIVE) as archive, tempfile.TemporaryDirectory() as temp:
            for name, expected in self.golden['tracks'].items():
                with self.subTest(track=name):
                    # Only the three fixed manifest filenames are materialized.
                    path = Path(temp) / (name + '.SS')
                    path.write_bytes(archive.read(name + '.SS'))
                    self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), expected['source_sha256'])
                    source = parse_ss(path)
                    native = convert(path, self.resources, self.config)
                    jsonschema.validate(native, self.schema)
                    encoded = (json.dumps(native, separators=(',', ':')) + '\n').encode('utf8')
                    self.assertEqual(hashlib.sha256(encoded).hexdigest(), expected['native_sha256'])
                    self.assertEqual(encoded, (ROOT / 'game/resources/tracks' / (native['identity'] + '.json')).read_bytes())
                    self.assertEqual(native['debug']['checkpoints'], source['checkpoints'])
                    self.assertEqual(native['debug']['computer_points'], source['computer_points'])
                    self.assertEqual(native['debug']['start'], source['start'])
                    self.assertEqual(len(native['debug']['blocks']), source['block_count'])
                    self.assertEqual(native['bridges'], [])
                    self.assertEqual(native['corrections'], {})
                    self.assertEqual(native['cell_size'], 0.25)
                    self.assertEqual(native['representative_width_m'], 9.0)
                    self.assertEqual(native['theme'], self.config['track_metadata'][name]['theme'])


unittest.main(verbosity=2)
