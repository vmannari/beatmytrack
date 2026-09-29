import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
spec = importlib.util.spec_from_file_location("review", Path(__file__).resolve().parents[1]/"scripts/review_pack.py")
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)

class ReviewTests(unittest.TestCase):
    def test_peak_safe_common_target(self):
        common, gains = r.plan_gains([(-30, -2), (-20, -6)], -20, -1)
        self.assertEqual(common, -29)
        self.assertEqual(gains, [1, -9])
        for (lufs, peak), gain in zip([(-30, -2), (-20, -6)], gains):
            self.assertLessEqual(peak + gain, -1)
            self.assertEqual(lufs + gain, common)

    def test_silence_rejected(self):
        result = subprocess.CompletedProcess([], 0, '', '{"input_i":"-inf","input_tp":"-inf"}')
        with patch.object(r.subprocess, "run", return_value=result):
            with self.assertRaises(ValueError): r.measure(Path("silent.wav"))

    def test_failed_decode(self):
        with patch.object(r.subprocess, "run", side_effect=subprocess.CalledProcessError(1, 'ffmpeg')):
            with self.assertRaises(subprocess.CalledProcessError): r.measure(Path("bad.wav"))

    def test_existing_output_preserved(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d); src=base/'source.wav'; src.write_bytes(b'original')
            with self.assertRaises(FileExistsError): r.build_pack([src], base)
            self.assertEqual(src.read_bytes(), b'original')

    def test_success_preserves_source(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d); src=base/'source.wav'; src.write_bytes(b'original')
            def render(cmd, **kwargs):
                self.assertIn('-n',cmd)
                Path(cmd[-1]).write_bytes(b'audition')
            with patch.object(r.shutil,'which',return_value='ffmpeg'), patch.object(r,'measure',side_effect=[(-30,-2),(-29,-1)]), patch.object(r.subprocess,'run',side_effect=render):
                result=r.build_pack([src],base/'out')
            self.assertEqual(src.read_bytes(), b'original')
            self.assertEqual(result['common_target_lufs'],-29)
            self.assertTrue((base/'out/index.html').is_file())

    def test_decode_failure_creates_no_pack(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d); src=base/'bad.wav'; src.write_bytes(b'bad')
            with patch.object(r.shutil,'which',return_value='ffmpeg'), patch.object(r,'measure',side_effect=ValueError('decode')):
                with self.assertRaises(ValueError): r.build_pack([src],base/'out')
            self.assertFalse((base/'out').exists())
            self.assertEqual(src.read_bytes(),b'bad')

    def test_missing_ffmpeg_creates_no_pack(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d); src=base/'source.wav'; src.write_bytes(b'original')
            with patch.object(r.shutil,'which',return_value=None):
                with self.assertRaises(RuntimeError): r.build_pack([src],base/'out')
            self.assertFalse((base/'out').exists())
