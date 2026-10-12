"""Audit the supplied rustles, seamless grass playback and untouched accepted audio."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

root = Path(__file__).resolve().parents[1]
out = root / 'docs/evidence/owner-grass-rustle-2026-10-11'
bank = root / 'game/assets/audio/vehicles'

def read(path):
    with wave.open(str(path)) as handle:
        rate,channels = handle.getframerate(),handle.getnchannels()
        values = np.frombuffer(handle.readframes(handle.getnframes()),dtype='<i2').astype(float)/32768
    return values.reshape(-1,channels),rate

before = json.loads((out / 'before-hashes.json').read_text(encoding='utf-8-sig'))
changed = [item['file'] for item in before if hashlib.sha256((bank / item['file']).read_bytes()).hexdigest()!=item['sha256']]
assert changed==['grass.wav'],changed
manifest = json.loads((bank / 'manifest.json').read_text())
clip = next(item for item in manifest['outputs'] if item['file']=='grass.wav')
assert clip['sources']==['owner_grass_511299.wav','owner_grass_511301.wav']
assert clip['generator']=='owner-grass-rustle-1'
assert 'sidechain = &"Engine"' in (root / 'game/default_bus_layout.tres').read_text()
report = dict(changed_wavs=changed,unchanged_wavs=len(before)-1,clip=clip,captures=[])
for source in clip['sources']:
    record = next(item for item in manifest['sources'] if item['filename']==source)
    assert hashlib.sha256((root / 'build/vehicle_audio_sources' / source).read_bytes()).hexdigest()==record['sha256']
for row in json.loads((out / 'grass-onset.json').read_text()): assert row['ratio']>=.85 and row['first']>.35
for trace in json.loads((out / 'native-contact-timing.json').read_text()):
    case = trace['case']
    for suffix in ['','-grass','-kerb','-loose','-engine']:
        path = out / (case+suffix+'.wav')
        values,rate = read(path)
        peak = float(abs(values).max())
        tail = float(abs(values[-round(.15*rate):]).max())
        assert peak<.94 and tail==0,(path.name,peak,tail)
        if case=='grass-speeds' and suffix=='-grass':
            blocks = np.array_split(values[round(.2*rate):round(2.5*rate)],115)
            rms = np.array([np.sqrt(np.mean(block**2)) for block in blocks])
            assert peak>.05 and rms.min()>.0003,'Live grass sweep must be continuous/audible'
        if case=='grass-entry' and suffix=='-grass':
            first = np.flatnonzero(np.max(abs(values),axis=1)>.0008)
            assert len(first) and abs(first[0]/rate-trace['first_grass_s'])<.10
        if case in ['grass-speeds','gravel-speeds'] and suffix=='-kerb': assert peak==0
        report['captures'].append(dict(file=path.name,peak=peak,pause_tail_peak=tail))
(out / 'audio-review.json').write_text(json.dumps(report,indent=2)+'\n')
print('OWNER_GRASS_REVIEW:',len(report['captures']),'native captures;',report['unchanged_wavs'],'other WAVs exact; both rustle sources verified')
