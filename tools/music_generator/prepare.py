"""Prepare provisional audition endpoints, never claim musical alignment.

Keeps raw files intact. Uses a single gain for the pair (preserving dynamics),
10ms edge fades, source hashes and explicit unknown musical metadata.
"""
from pathlib import Path
import json
import time
import uuid
import numpy as np
import soundfile as sf
from generate import BUILD, atomic_json, audio_metrics

def latest(name):
    found = []
    for path in (BUILD / 'raw/grass').rglob('manifest.json'):
        manifest = json.loads(path.read_text())
        if manifest.get('approval') == 'superseded': continue
        for job in manifest.get('jobs', []):
            if job.get('name') == name and job.get('status') == 'complete' and 'conditioning_tokens' in job:
                found.append((path.parent.name, path.parent / job['file'], job))
    if not found: raise ValueError('Generate a corrected ' + name + ' take first')
    return sorted(found)[-1][1:]

def prepare():
    selected = [latest(name) for name in ['00_focus', '05_breakthrough']]
    if selected[0][1]['metrics']['sha256'] == selected[1][1]['metrics']['sha256']:
        raise ValueError('Endpoints must not be duplicate audio')
    arrays = [sf.read(path, always_2d=True) for path, _ in selected]
    if len({(len(samples), rate) for samples, rate in arrays}) != 1:
        raise ValueError('Endpoints need identical duration/sample rate for this audition')
    peak = max(float(np.abs(samples).max()) for samples, _ in arrays)
    gain = min(1., .5 / max(peak, 1e-9))
    run = BUILD / 'prepared' / (time.strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:8])
    run.mkdir(parents=True)
    manifest = {'schema':'bmt-music-generation-1', 'status':'complete', 'approval':'unreviewed',
        'musical_contract':{'bpm':None, 'meter':None, 'key':None, 'chord_timeline':None,
                            'note':'Requires listening and musical editing; equal sample length is not beat alignment.'},
        'processing':{'shared_gain':gain, 'edge_fade_seconds':.01, 'clipping_repair':False}, 'jobs':[]}
    for (source, original), (samples, rate) in zip(selected, arrays):
        samples = samples * gain
        edge = min(round(rate * .01), len(samples)//2)
        ramp = np.linspace(0, 1, edge)
        samples[:edge] *= ramp[:, None]; samples[-edge:] *= ramp[::-1, None]
        path = run / (original['name'] + '__prepared.wav')
        sf.write(path, samples, rate, subtype='PCM_24')
        job = {**original, 'file':path.name, 'name':original['name'] + '_prepared',
            'source':str(source.relative_to(BUILD)), 'source_sha256':original['metrics']['sha256'],
            'source_near_full_scale_samples':original['metrics']['near_full_scale_samples'],
            'metrics':audio_metrics(path), 'alignment':'equal-length, musically unverified'}
        manifest['jobs'].append(job)
    atomic_json(run / 'manifest.json', manifest)
    print('PREPARED ' + str(run))
    return run

if __name__ == '__main__':
    prepare()
