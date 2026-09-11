"""Offline converter regression. Supply the extracted owner handoff directory."""
import hashlib
import json
import sys
import unittest
from pathlib import Path
from convert import convert, rotated, runs
from slicks_ss_parser import parse_ss
from slicks_track_renderer_corrected import parse_dat

SOURCE = Path(sys.argv.pop(1))
ROOT = Path(__file__).resolve().parents[2]


class ConversionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.resources, _ = parse_dat(SOURCE / 'SLICKS.DAT')
        cls.config = json.loads(Path(__file__).with_name('config.json').read_text())
        cls.golden = json.loads(Path(__file__).with_name('golden.json').read_text())

    def test_four_native_fixtures_and_source_contracts(self):
        for name in ['FREEWAY','1WAY','66','OFFROAD']:
            with self.subTest(track=name):
                source_path=SOURCE/'original_tracks'/f'{name}.SS'
                parsed=parse_ss(source_path)
                native=convert(source_path,self.resources,self.config)
                encoded=(json.dumps(native,separators=(',',':'))+'\n').encode()
                self.assertEqual(hashlib.sha256(encoded).hexdigest(),self.golden[name]['native_sha256'])
                self.assertEqual(hashlib.sha256(source_path.read_bytes()).hexdigest(),self.golden[name]['source_sha256'])
                self.assertEqual(encoded,(ROOT/'game/resources/tracks'/f'{native["identity"]}.json').read_bytes())
                self.assertEqual(native['debug']['checkpoints'],parsed['checkpoints'])
                self.assertEqual(native['debug']['computer_points'],parsed['computer_points'])
                self.assertEqual(native['debug']['start'],parsed['start'])
                self.assertEqual(len(native['debug']['blocks']),parsed['block_count'])
                self.assertEqual(native['representative_width_m']/native['car_width_m'],5)
                self.assertTrue(all(b[4] < len(self.resources) for b in native['debug']['blocks']))

    def test_clockwise_rotation_and_dimensions(self):
        r={'w':3,'h':2,'pix':bytes([1,2,3,4,5,6])}
        self.assertEqual(rotated(r,1),(2,3,bytes([4,1,5,2,6,3])))
        self.assertEqual(rotated(r,4),(3,2,r['pix']))

    def test_rectangles_losslessly_cover_grid(self):
        grid=[[int(90<x<130 and 30<y<80) for x in range(320)] for y in range(200)]
        restored=[[-1]*320 for _ in range(200)]
        for x,y,w,h,value in runs(grid):
            for row in range(y,y+h):
                for column in range(x,x+w):
                    self.assertEqual(restored[row][column],-1)
                    restored[row][column]=value
        self.assertEqual(restored,grid)

    def test_unknown_block_semantics_fail_closed(self):
        config=dict(self.config)
        config['semantic_blocks']={}
        with self.assertRaisesRegex(ValueError,'Unreviewed block'):
            convert(SOURCE/'original_tracks/FREEWAY.SS',self.resources,config)


unittest.main(verbosity=2)
