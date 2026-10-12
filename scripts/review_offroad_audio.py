"""Audit offroad hiss reduction, real playback onset and preserved accepted audio."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

root = Path(__file__).resolve().parents[1]
out = root / 'docs/evidence/offroad-texture-2026-10-11'
bank = root / 'game/assets/audio/vehicles'

def read(path):
    with wave.open(str(path)) as handle:
        rate,channels = handle.getframerate(),handle.getnchannels()
        values = np.frombuffer(handle.readframes(handle.getnframes()),dtype='<i2').astype(float)/32768
    return values.reshape(-1,channels),rate

def texture(path):
    values,rate = read(path)
    mono = values.mean(axis=1)
    power = abs(np.fft.rfft(mono))**2
    hz = np.fft.rfftfreq(len(mono),1/rate)
    blocks = np.array_split(mono,max(1,len(mono)//round(.1*rate)))
    rms = np.array([np.sqrt(np.mean(block**2)) for block in blocks])
    return dict(seconds=len(mono)/rate,hiss_fraction=float(power[hz>2200].sum()/power.sum()),
        spectral_centroid_hz=float((hz*power).sum()/power.sum()),
        envelope_variation=float(rms.std()/rms.mean()))

before = json.loads((out / 'before-hashes.json').read_text(encoding='utf-8-sig'))
changed = [item['file'] for item in before if hashlib.sha256((bank / item['file']).read_bytes()).hexdigest()!=item['sha256']]
assert set(changed)=={'grass.wav','loose.wav'},changed
manifest = json.loads((bank / 'manifest.json').read_text())
report = dict(changed_wavs=changed,unchanged_wavs=len(before)-2,textures=[],captures=[])
for name in ['grass','loose']:
    clip = next(item for item in manifest['outputs'] if item['file']==name+'.wav')
    assert clip['sources']==[] and clip['generator']=='offroad-texture-1'
    old = texture(out / 'before/game/assets/audio/vehicles' / (name+'.wav'))
    new = texture(bank / (name+'.wav'))
    assert new['hiss_fraction']<old['hiss_fraction']*.20, 'Reduce high-frequency hiss'
    assert new['envelope_variation']>.10, 'Keep uneven contact instead of flattening the loop'
    report['textures'].append(dict(layer=name,before=old,after=new))
for row in json.loads((out / 'grass-onset.json').read_text()):
    assert row['ratio']>=.85 and row['first']>.35
traces = json.loads((out / 'native-contact-timing.json').read_text())
for trace in traces:
    case = trace['case']
    for suffix in ['','-grass','-kerb','-loose']:
        path = out / (case+suffix+'.wav')
        values,rate = read(path)
        peak = float(abs(values).max())
        tail = float(abs(values[-round(.15*rate):]).max())
        assert peak<.94 and tail==0,(path.name,peak,tail)
        if (case=='grass-speeds' and suffix=='-grass') or (case=='gravel-speeds' and suffix=='-loose'):
            assert peak>.05,'Offroad texture must be audible'
        if case in ['grass-speeds','gravel-speeds'] and suffix=='-kerb': assert peak==0
        if case=='grass-entry' and suffix=='-grass':
            first = np.flatnonzero(np.max(abs(values),axis=1)>.0008)
            assert len(first) and abs(first[0]/rate-trace['first_grass_s'])<.10
        report['captures'].append(dict(file=path.name,peak=peak,pause_tail_peak=tail))
(out / 'audio-review.json').write_text(json.dumps(report,indent=2)+'\n')
print('OFFROAD_REVIEW:',len(report['captures']),'native captures;',report['unchanged_wavs'],'other WAVs exact')
print('OFFROAD_TEXTURES:',report['textures'])
