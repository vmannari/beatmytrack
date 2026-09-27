"""Focused contracts; no GPU/model load. Run using the WSL environment."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import generate
import serve

class ToolkitTests(unittest.TestCase):
    def setUp(self):
        self.config = {"duration": 4, "concepts": [{"name": "Example", "prompt": "quiet guitar"}]}

    def test_valid_jobs_and_limits(self):
        output, jobs = generate.prepare_jobs(self.config, "concepts", 1)
        self.assertEqual(jobs[0]["frames"], 100)
        self.assertTrue(output.is_relative_to(generate.BUILD))
        self.assertEqual(jobs[0]["alignment"], "unverified")

    def test_specific_instruction_precedes_shared_prefix(self):
        _, jobs = generate.prepare_jobs({**self.config, 'identity': 'shared ' * 200}, 'concepts')
        self.assertTrue(jobs[0]['prompt'].startswith('quiet guitar'))

    def test_rejects_shipping_and_escape_paths(self):
        for path in ["game/audio/music", "build/music/../../game", "/tmp/music"]:
            with self.subTest(path=path), self.assertRaises(ValueError):
                generate.prepare_jobs({**self.config, "output_dir": path}, "concepts")

    def test_rejects_invalid_durations_and_limits(self):
        for duration in [0, -1, float('nan'), float('inf'), 121]:
            with self.subTest(duration=duration), self.assertRaises(ValueError):
                generate.prepare_jobs({**self.config, "duration": duration}, "concepts")
        with self.assertRaises(ValueError):
            generate.prepare_jobs(self.config, "concepts", 0)

    def test_duplicate_names_and_unknown_selection(self):
        with self.assertRaises(ValueError):
            generate.prepare_jobs({**self.config, "concepts": self.config['concepts'] * 2}, "concepts")
        with self.assertRaises(ValueError):
            generate.prepare_jobs(self.config, "concepts", names=['missing'])

    def test_state_selection_keeps_original_stage(self):
        config = {"states": [{"name": f"s{i}", "prompt": "guitar"} for i in range(6)], "variants_per_state": 3}
        _, jobs = generate.prepare_jobs(config, "layers", 1, ['s5'])
        self.assertEqual(jobs[0]['state_index'], 5)

    def test_variants_have_distinct_explicit_directions(self):
        cfg = {'variants_per_state': 2, 'states': [{'name':'focus', 'prompt':'common theme',
                'variant_prompts':['fingerpicked guitar', 'felt piano']}]}
        _, jobs = generate.prepare_jobs(cfg, 'layers')
        self.assertTrue(jobs[0]['prompt'].startswith('fingerpicked guitar'))
        self.assertTrue(jobs[1]['prompt'].startswith('felt piano'))
        cfg['states'][0]['variant_prompts'] = ['only one']
        with self.assertRaises(ValueError): generate.prepare_jobs(cfg, 'layers')

    def test_failed_job_is_recorded(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            with patch.object(generate, 'BUILD', root), patch.object(generate, 'ROOT', root), patch.object(generate.metadata, 'version', return_value='wrong'):
                with self.assertRaises(RuntimeError):
                    generate.generate({**self.config, 'output_dir': '.'}, 'concepts')
            manifests = list(root.rglob('manifest.json'))
            self.assertEqual(len(manifests), 1)
            self.assertEqual(json.loads(manifests[0].read_text())['status'], 'failed')

    def test_catalog_only_serves_completed_contained_assets(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'ok.wav').write_bytes(b'fixture')
            jobs = [{'name':'ok', 'file':'ok.wav', 'status':'complete'},
                    {'name':'absent', 'file':'missing.wav', 'status':'complete'},
                    {'name':'pending', 'file':'ok.wav', 'status':'generating'},
                    {'name':'escape', 'file':'../outside.wav', 'status':'complete'}]
            (root / 'manifest.json').write_text(json.dumps({'jobs': jobs}))
            with patch.object(serve, 'ASSETS', root):
                self.assertEqual([x['name'] for x in serve.catalog()['items']], ['ok'])

    def test_audio_validation(self):
        import numpy as np
        import soundfile as sf
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'a.wav'
            sf.write(path, np.zeros((480, 2)), 48000)
            with self.assertRaises(ValueError): generate.audio_metrics(path)
            sf.write(path, np.full((480, 2), .1), 48000)
            result = generate.audio_metrics(path)
            self.assertEqual(result['channels'], 2)
            self.assertEqual(result['duration'], .01)
            self.assertEqual(len(result['sha256']), 64)

if __name__ == '__main__':
    unittest.main(verbosity=2)
