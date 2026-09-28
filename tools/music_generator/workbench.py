"""Persistent local generation inbox and library. No model imports on Windows."""
from __future__ import annotations
import copy
import json
import os
from pathlib import Path
import subprocess
import threading
import time
import uuid

STATES = ['Focus', 'Momentum', 'Drive', 'Flow', 'Lift', 'Breakthrough']
ACTIVE = ('queued', 'loading_model', 'generating')


def atomic_json(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False), encoding='utf-8')
    temporary.replace(path)


def assignment(value):
    if value is not None and (type(value) is not int or value not in range(6)):
        raise ValueError('Choose a valid musical state or Unassigned.')
    return value


def title(value):
    if not isinstance(value, str) or not 1 <= len(value.strip()) <= 100:
        raise ValueError('Give the track a name of 1–100 characters.')
    return value.strip()


class Workbench:
    def __init__(self, root, assets, catalog, runner=None):
        self.root, self.assets, self.catalog = root, assets, catalog
        self.folder = assets / 'workbench'
        self.folder.mkdir(parents=True, exist_ok=True)
        # One writer across server processes, including different HTTP ports.
        self.file_lock = (self.folder / '.lock').open('a+b')
        self.file_lock.seek(0)
        try:
            if os.name == 'nt':
                import msvcrt
                if not self.file_lock.read(1):
                    self.file_lock.write(b'0'); self.file_lock.flush()
                self.file_lock.seek(0)
                msvcrt.locking(self.file_lock.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.file_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            self.file_lock.close()
            raise RuntimeError('Another music workbench is running. Close it before starting this server.')
        self.path = self.folder / 'library.json'
        self.lock = threading.RLock()
        self.runner = runner or self.run_generator
        self.data = json.loads(self.path.read_text(encoding='utf-8')) if self.path.exists() else {'schema': 1, 'jobs': [], 'tracks': {}}
        for job in self.data['jobs']:
            if job['status'] in ACTIVE:
                job.update(status='failed', error='Server stopped during generation. You can generate this prompt again.')
        self.persist()

    def persist(self):
        atomic_json(self.path, self.data)

    def snapshot(self):
        with self.lock:
            result = copy.deepcopy(self.data)
        items = self.catalog()['items']
        by_id = {i['id']: i for i in items}
        result['tracks'] = [{**by_id.get(key, {'id': key, 'missing': True}), **value} for key, value in result['tracks'].items()]
        for job in result['jobs']:
            job['item'] = by_id.get(job.get('asset'))
            if job['status'] in ACTIVE:
                manifests = list((self.folder / 'runs' / job['id']).glob('*/manifest.json'))
                if manifests:
                    try:
                        state = json.loads(manifests[0].read_text(encoding='utf-8'))['status']
                        if state in ACTIVE:
                            job['status'] = state
                    except (OSError, ValueError, KeyError):
                        pass
        result['states'] = STATES
        return result

    def start(self, payload):
        name = title(payload.get('title'))
        prompt = payload.get('prompt')
        if not isinstance(prompt, str) or not 1 <= len(prompt.strip()) <= 2000:
            raise ValueError('Write a music prompt of 1–2000 characters.')
        duration = payload.get('duration')
        if type(duration) is not int or not 4 <= duration <= 120:
            raise ValueError('Duration must be a whole number from 4 to 120 seconds.')
        state = assignment(payload.get('state_index'))
        with self.lock:
            if any(j['status'] in ACTIVE for j in self.data['jobs']):
                raise RuntimeError('A take is already generating. Wait for it to finish.')
            job_id = uuid.uuid4().hex
            job = {'id': job_id, 'title': name, 'prompt': prompt.strip(), 'duration': duration,
                   'state_index': state, 'status': 'queued', 'created': time.time()}
            self.data['jobs'].append(job)
            try:
                self.persist()
            except OSError:
                self.data['jobs'].remove(job)
                raise
            threading.Thread(target=self.generate, args=(job_id,), daemon=True).start()
            return copy.deepcopy(job)

    def generate(self, job_id):
        with self.lock:
            job = next(j for j in self.data['jobs'] if j['id'] == job_id)
            job['status'] = 'loading_model'
            self.persist()
        try:
            output = self.folder / 'runs' / job_id
            config = self.folder / (job_id + '.json')
            atomic_json(config, {'model': 'mrt2_base', 'output_dir': output.relative_to(self.root).as_posix(),
                'composition_family': 'workbench', 'duration': job['duration'],
                'concepts': [{'name': 'take', 'prompt': job['prompt']}]})
            self.runner(config, self.folder / (job_id + '.log'))
            manifests = list(output.glob('*/manifest.json'))
            if len(manifests) != 1:
                raise RuntimeError('Generator did not produce a recording manifest. See the generation log.')
            manifest_path = manifests[0]
            manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
            if manifest['status'] != 'complete':
                raise RuntimeError(manifest.get('error', 'Generation did not finish.'))
            item = manifest['jobs'][0]
            audio = (manifest_path.parent / item['file']).resolve()
            if not audio.is_relative_to(self.assets.resolve()) or not audio.is_file():
                raise RuntimeError('Generated audio is missing or outside the music folder.')
            with self.lock:
                job.update(status='ready', asset=audio.relative_to(self.assets.resolve()).as_posix())
                self.persist()
        except Exception as error:
            with self.lock:
                job.update(status='failed', error=str(error)[-2000:])
                self.persist()

    def run_generator(self, config, log):
        command = ['bash', 'tools/music_generator/scripts/run_from_windows_repo.sh', 'python',
                   'tools/music_generator/generate.py', 'concepts', '--config', config.relative_to(self.root).as_posix()]
        if os.name == 'nt':
            command = ['wsl', '-d', 'Ubuntu', '--', *command]
        with log.open('w', encoding='utf-8') as stream:
            result = subprocess.run(command, cwd=self.root, stdout=stream, stderr=subprocess.STDOUT,
                                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        if result.returncode:
            detail = log.read_text(encoding='utf-8', errors='replace')[-1800:]
            raise RuntimeError('Magenta generation failed. ' + detail)

    def save(self, payload):
        name = title(payload.get('title'))
        state = assignment(payload.get('state_index'))
        asset = payload.get('id')
        if not isinstance(asset, str) or asset not in {i['id'] for i in self.catalog()['items']}:
            raise ValueError('Recording is unavailable. Refresh and try again.')
        with self.lock:
            if any(j.get('asset') == asset and j['status'] == 'discarded' for j in self.data['jobs']):
                raise ValueError('Restore this discarded take before saving it.')
            previous = self.data['tracks'].get(asset)
            affected = [(job, job['status']) for job in self.data['jobs'] if job.get('asset') == asset]
            self.data['tracks'][asset] = {'title': name, 'state_index': state, 'saved_at': time.time()}
            for job, _ in affected:
                job['status'] = 'saved'
            try:
                self.persist()
            except OSError:
                if previous is None:
                    self.data['tracks'].pop(asset)
                else:
                    self.data['tracks'][asset] = previous
                for job, status in affected:
                    job['status'] = status
                raise
        return {'ok': True}

    def discard(self, payload):
        with self.lock:
            job = next((j for j in self.data['jobs'] if j['id'] == payload.get('id')), None)
            if not job or job['status'] not in ('ready', 'failed', 'discarded'):
                raise ValueError('Only finished, unsaved takes can be discarded or restored.')
            previous = job['status']
            job['status'] = ('ready' if job.get('asset') else 'failed') if payload.get('restore') else 'discarded'
            try:
                self.persist()
            except OSError:
                job['status'] = previous
                raise
        return {'ok': True}
