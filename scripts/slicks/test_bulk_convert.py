"""Corpus contracts; all inputs stay local and outside the game export root."""
import hashlib
import json
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

import jsonschema
from bulk_convert import normalize, author_metadata, sources, ROOT
from slicks_ss_parser import parse_v2

HANDOFF = Path(sys.argv.pop(1))
V1 = Path(sys.argv.pop(1))
V2 = Path(sys.argv.pop(1))


class CorpusTests(unittest.TestCase):
    def test_legacy_gameplay_against_175_converted_sources(self):
        with zipfile.ZipFile(V1) as old, zipfile.ZipFile(V2) as new, tempfile.TemporaryDirectory() as temp:
            for name in sorted(set(old.namelist()) & set(new.namelist())):
                with self.subTest(track=name):
                    path = Path(temp)/name; path.write_bytes(old.read(name))
                    a, b = normalize(path), parse_v2(new.read(name))
                    for field in ['checkpoints','panic_points','start']:
                        self.assertEqual(a[field],b[field])
                    # V2 adds an extra per-computer-point byte; compare geometry.
                    self.assertEqual([{k:v for k,v in p.items() if k!='extra'} for p in a['computer_points']],
                                     [{k:v for k,v in p.items() if k!='extra'} for p in b['computer_points']])

    def test_complete_native_manifest_and_author_attribution(self):
        inventory = sources([V1,V2],HANDOFF)
        manifest = json.loads((ROOT/'game/resources/builtin_tracks.json').read_text(encoding='utf8'))
        schema = json.loads((ROOT/'docs/native_track.schema.json').read_text())
        jsonschema.validate(manifest,json.loads((ROOT/'docs/schemas/builtin-track-catalog-v1.schema.json').read_text()))
        self.assertEqual(len(inventory),194)
        self.assertEqual(manifest['failures'],[])
        self.assertEqual(len(manifest['entries']),len(inventory))
        self.assertEqual(len({e['id'] for e in manifest['entries']}),194)
        with tempfile.TemporaryDirectory() as temp:
            for entry in manifest['entries']:
                name = Path(entry['source_file']).stem.upper()
                path = Path(temp)/(name+'.SS'); path.write_bytes(inventory[name][0])
                source = normalize(path)
                self.assertEqual(entry['creator'],author_metadata(source,name)['creator'])
                self.assertEqual(entry['creator_kind'],'source' if source['author'].strip() else 'fictional')
                native_path = ROOT/'game'/entry['path'].removeprefix('res://')
                native = json.loads(native_path.read_text())
                jsonschema.validate(native,schema)
                self.assertEqual(hashlib.sha256(native_path.read_bytes()).hexdigest(),entry['native_sha256'])
                self.assertEqual(native['debug']['checkpoints'],source['checkpoints'])
                self.assertEqual(native['debug']['start'],source['start'])
                self.assertEqual(native['debug']['computer_points'],source['computer_points'])

    def test_blank_author_is_stable_and_named_author_is_never_replaced(self):
        self.assertEqual(author_metadata({'author':' '},'8'),author_metadata({'author':''},'8') | {'source_author':' '})
        self.assertEqual(author_metadata({'author':'Original Author'},'8')['creator'],'Original Author')


unittest.main(verbosity=2)
