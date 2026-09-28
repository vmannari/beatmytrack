"""Local service contracts using isolated disk storage and a deterministic fake renderer."""
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
from urllib.request import Request, urlopen
from urllib.error import HTTPError
from http.server import ThreadingHTTPServer
import serve
from workbench import Workbench


class StudioTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.assets = self.root / 'build/music'
        self.catalog_patch = patch.object(serve, 'ASSETS', self.assets)
        self.catalog_patch.start()
        self.workbench = Workbench(self.root, self.assets, serve.catalog, self.render)

    def tearDown(self):
        self.workbench.file_lock.close()
        self.catalog_patch.stop()
        self.temp.cleanup()

    def render(self, config, log):
        config = json.loads(config.read_text())
        folder = self.root / config['output_dir'] / 'test-run'
        folder.mkdir(parents=True)
        (folder / 'take.wav').write_bytes(b'audio-fixture')
        (folder / 'manifest.json').write_text(json.dumps({'status': 'complete', 'jobs': [
            {'status': 'complete', 'file': 'take.wav', 'name': 'take', 'prompt': config['concepts'][0]['prompt']}]}))

    def request(self, **updates):
        return {'title': 'New track', 'prompt': 'Low cello', 'duration': 4, 'state_index': 0, **updates}

    def completed(self):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            snapshot = self.workbench.snapshot()
            if snapshot['jobs'][-1]['status'] in ('ready', 'failed'):
                return snapshot['jobs'][-1]
            time.sleep(.01)
        self.fail('Worker did not complete')

    def test_save_reassign_reload_and_source_unchanged(self):
        self.workbench.start(self.request(prompt='Quotes " and shell $(unchanged); <script>'))
        job = self.completed()
        original = (self.assets / job['asset']).read_bytes()
        for state in [5, 2, None]:
            self.workbench.save({'id': job['asset'], 'title': 'Renamed', 'state_index': state})
            track = self.workbench.snapshot()['tracks'][0]
            self.assertEqual(track['state_index'], state)
        self.workbench.file_lock.close()
        self.workbench = Workbench(self.root, self.assets, serve.catalog, self.render)
        self.assertEqual(self.workbench.snapshot()['tracks'][0]['title'], 'Renamed')
        self.assertIsNone(self.workbench.snapshot()['tracks'][0]['state_index'])
        self.assertEqual((self.assets / job['asset']).read_bytes(), original)
        self.assertEqual(self.workbench.snapshot()['jobs'][0]['status'], 'saved')

    def test_discard_restore_and_save_guards(self):
        self.workbench.start(self.request())
        job = self.completed()
        self.workbench.discard({'id': job['id']})
        self.assertTrue((self.assets / job['asset']).exists())
        with self.assertRaises(ValueError):
            self.workbench.save({'id': job['asset'], 'title': 'x', 'state_index': 0})
        self.workbench.discard({'id': job['id'], 'restore': True})
        self.assertEqual(self.workbench.snapshot()['jobs'][0]['status'], 'ready')
        self.workbench.save({'id': job['asset'], 'title': 'x', 'state_index': 0})
        with self.assertRaises(ValueError): self.workbench.discard({'id': job['id']})

    def test_validation_does_not_start_jobs(self):
        for change in [{'prompt': ''}, {'prompt': 'x' * 2001}, {'title': ''}, {'title': 'x' * 101}, {'duration': 0}, {'duration': 121}, {'duration': True}, {'state_index': -1}, {'state_index': 6}, {'state_index': False}]:
            with self.subTest(change=change), self.assertRaises(ValueError): self.workbench.start(self.request(**change))
        self.assertFalse(self.workbench.snapshot()['jobs'])
        with self.assertRaises(ValueError): self.workbench.save({'id': '../../outside.wav', 'title': 'x', 'state_index': None})

    def test_busy_rejects_parallel_generation(self):
        gate = threading.Event()
        self.workbench.runner = lambda config, log: (gate.wait(3), self.render(config, log))
        self.workbench.start(self.request())
        try:
            with self.assertRaises(RuntimeError): self.workbench.start(self.request())
        finally: gate.set()
        self.assertEqual(self.completed()['status'], 'ready')

    def test_failed_disk_write_does_not_claim_saved_or_discarded(self):
        self.workbench.start(self.request())
        job = self.completed()
        with patch('workbench.atomic_json', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                self.workbench.save({'id': job['asset'], 'title': 'Unsaved edit', 'state_index': 5})
            self.assertFalse(self.workbench.snapshot()['tracks'])
            self.assertEqual(self.workbench.snapshot()['jobs'][0]['status'], 'ready')
            with self.assertRaises(OSError): self.workbench.discard({'id': job['id']})
            self.assertEqual(self.workbench.snapshot()['jobs'][0]['status'], 'ready')
            with self.assertRaises(OSError): self.workbench.start(self.request())
            self.assertEqual(len(self.workbench.snapshot()['jobs']), 1)

    def test_failed_generation_keeps_retry_information(self):
        def broken(*_): raise RuntimeError('CUDA unavailable')
        self.workbench.runner = broken
        self.workbench.start(self.request())
        job = self.completed()
        self.assertEqual(job['status'], 'failed')
        self.assertIn('CUDA unavailable', job['error'])
        self.assertEqual(job['prompt'], 'Low cello')
        self.assertFalse(self.workbench.snapshot()['tracks'])

    def test_restart_marks_interrupted_job_and_single_writer(self):
        with self.assertRaises(RuntimeError): Workbench(self.root, self.assets, serve.catalog, self.render)
        self.workbench.data['jobs'] = [{'id': 'interrupted', 'status': 'generating'}]
        self.workbench.persist()
        self.workbench.file_lock.close()
        self.workbench = Workbench(self.root, self.assets, serve.catalog, self.render)
        self.assertEqual(self.workbench.snapshot()['jobs'][0]['status'], 'failed')

    def test_api_security_and_catalog_visibility(self):
        server = ThreadingHTTPServer(('127.0.0.1', 0), serve.Handler)
        server.workbench, server.token = self.workbench, 'test-token'
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        url = f'http://127.0.0.1:{server.server_port}'
        def post(payload, **headers):
            return urlopen(Request(url + '/api/generate', json.dumps(payload).encode(), headers={'Content-Type': 'application/json', **headers}), timeout=3)
        try:
            with self.assertRaises(HTTPError) as denied: post(self.request())
            self.assertEqual(denied.exception.code, 403)
            with self.assertRaises(HTTPError) as denied: post(self.request(), **{'X-Workbench-Token': 'test-token', 'Origin': 'https://outside.example'})
            self.assertEqual(denied.exception.code, 403)
            with post(self.request(), **{'X-Workbench-Token': 'test-token', 'Origin': url}) as response: self.assertEqual(response.status, 200)
            job = self.completed()
            with urlopen(url + '/api/catalog') as response: self.assertFalse(json.load(response)['items'])
            self.workbench.save({'id': job['asset'], 'title': 'Saved', 'state_index': 5})
            with urlopen(url + '/api/catalog') as response:
                item = json.load(response)['items'][0]
                self.assertEqual(item['state_index'], 5); self.assertEqual(item['title'], 'Saved')
            with self.assertRaises(HTTPError) as denied: urlopen(url + '/audio/../../secret.wav')
            self.assertEqual(denied.exception.code, 403)
        finally:
            server.shutdown(); server.server_close(); thread.join()


if __name__ == '__main__': unittest.main(verbosity=2)
