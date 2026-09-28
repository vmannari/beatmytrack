"""Registry package/state/delete contracts, isolated from the owner's music."""
import json
import threading
import unittest
from unittest.mock import patch
from test_studio import StudioTests
from workbench import Workbench
import serve


class PackageTests(unittest.TestCase):
    setUp = StudioTests.setUp
    tearDown = StudioTests.tearDown
    render = StudioTests.render
    request = StudioTests.request
    completed = StudioTests.completed

    def track(self):
        self.workbench.start(self.request())
        job = self.completed()
        self.workbench.save({'id': job['asset'], 'title': 'Saved', 'state_index': 5})
        return job['asset']

    def package(self, asset, count=3):
        return self.workbench.save_package({'name': 'Coherent set', 'mode': 'layers',
            'states': [{'name': f'State {i + 1}', 'pool': [asset]} for i in range(count)]})

    def test_schema_one_upgrade_and_backup(self):
        self.workbench.file_lock.close()
        old = {'schema': 1, 'jobs': [], 'tracks': {'earlier.wav': {'title': 'Keep me', 'state_index': 5}}}
        self.workbench.path.write_text(json.dumps(old))
        self.workbench = Workbench(self.root, self.assets, serve.catalog, self.render)
        self.assertEqual(self.workbench.data['schema'], 2)
        self.assertEqual(json.loads((self.workbench.folder / 'library-schema-1-backup.json').read_text()), old)
        self.assertEqual(self.workbench.snapshot()['tracks'][0]['title'], 'Keep me')

    def test_global_counts_do_not_rewrite_package_states(self):
        asset = self.track(); self.package(asset)
        self.workbench.configure_states({'states': [f'Part {i}' for i in range(9)]})
        self.workbench.save({'id': asset, 'title': 'High state', 'state_index': 8})
        self.workbench.configure_states({'states': ['Opening', 'Full']})
        snapshot = self.workbench.snapshot()
        self.assertIsNone(snapshot['tracks'][0]['state_index'])
        self.assertEqual(len(snapshot['states']), 2)
        self.assertEqual(len(snapshot['packages'][0]['states']), 3)
        self.assertTrue(snapshot['packages'][0]['ready'])

    def test_delete_cleans_all_pools_restore_preserves_source(self):
        asset = self.track(); self.package(asset)
        self.workbench.delete_track({'id': asset})
        snapshot = self.workbench.snapshot()
        self.assertFalse(snapshot['tracks']); self.assertEqual(len(snapshot['trash']), 1)
        self.assertEqual(snapshot['jobs'][0]['status'], 'deleted')
        self.assertFalse(snapshot['packages'][0]['ready'])
        self.assertTrue(all(not s['pool'] for s in snapshot['packages'][0]['states']))
        self.assertTrue((self.assets / asset).exists())
        with self.assertRaises(ValueError): self.workbench.save({'id': asset, 'title': 'Bypass trash', 'state_index': 0})
        with self.assertRaises(ValueError): self.package(asset)
        self.workbench.restore_track({'id': asset})
        self.assertEqual(len(self.workbench.snapshot()['tracks']), 1)
        self.assertFalse(self.workbench.snapshot()['packages'][0]['ready'])

    def test_package_validation_draft_and_missing_file(self):
        asset = self.track()
        for states in [[], ['x'] * 13, ['Same', 'same'], [''], [42]]:
            with self.assertRaises(ValueError): self.workbench.configure_states({'states': states})
        for change in [{'mode': 'random'}, {'states': [{'name': 'A', 'pool': [asset, asset]}]},
                       {'states': [{'name': 'A', 'pool': ['../../outside.wav']}]}]:
            with self.assertRaises(ValueError): self.workbench.save_package({'name': 'Bad', 'mode': 'layers', 'states': [{'name': 'A', 'pool': [asset]}], **change})
        draft = self.workbench.save_package({'name': 'Draft', 'mode': 'arrangement', 'states': [{'name': 'One', 'pool': []}]})
        self.assertFalse(self.workbench.snapshot()['packages'][0]['ready'])
        self.workbench.delete_package({'id': draft['id']})
        self.package(asset, 1)
        (self.assets / asset).unlink()
        self.assertFalse(self.workbench.snapshot()['packages'][0]['ready'])
        self.assertIn('unavailable', self.workbench.snapshot()['packages'][0]['issues'][0])

    def test_atomic_package_delete_state_transactions(self):
        asset = self.track(); package = self.package(asset)
        before = self.workbench.snapshot()
        with patch('workbench.atomic_json', side_effect=OSError('disk full')):
            for action, payload in [(self.workbench.delete_track, {'id': asset}),
                                    (self.workbench.delete_package, {'id': package['id']}),
                                    (self.workbench.configure_states, {'states': ['Only']}),
                                    (self.workbench.save_package, {**package, 'name': 'Changed'})]:
                with self.assertRaises(OSError): action(payload)
                self.assertEqual(self.workbench.snapshot(), before)

    def test_reload_and_edit_during_generation(self):
        gate = threading.Event()
        self.workbench.runner = lambda config, log: (gate.wait(3), self.render(config, log))
        self.workbench.start(self.request(state_index=5))
        self.workbench.configure_states({'states': ['Single state']})
        gate.set()
        job = self.completed()
        self.assertEqual(job['status'], 'ready'); self.assertIsNone(job['state_index'])
        self.workbench.save({'id': job['asset'], 'title': 'New', 'state_index': 0})
        self.package(job['asset'], 12)
        self.workbench.file_lock.close()
        self.workbench = Workbench(self.root, self.assets, serve.catalog, self.render)
        self.assertEqual(len(self.workbench.snapshot()['packages'][0]['states']), 12)
        self.assertEqual(self.workbench.snapshot()['states'], ['Single state'])


if __name__ == '__main__': unittest.main(verbosity=2)
