"""Audit engine-isolated playback and the repaired recorded ground mix."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

root = Path(__file__).resolve().parents[1]
out = root / 'docs/evidence/engine-grass-repair-2026-10-11'
bank = root / 'game/assets/audio/vehicles'

def read(path):
    with wave.open(str(path)) as handle:
        rate,channels = handle.getframerate(),handle.getnchannels()
        values = np.frombuffer(handle.readframes(handle.getnframes()),dtype='<i2').astype(float)/32768
    return values.reshape(-1,channels),rate

def levels(values,rate,start,end):
    segment = values[round(start*rate):round(end*rate)]
    blocks = np.array_split(segment,max(1,len(segment)//round(.02*rate)))
    rms = np.array([np.sqrt(np.mean(block**2)) for block in blocks])
    steps = abs(np.diff(segment,axis=0))
    return dict(minimum=float(rms.min()),median=float(np.median(rms)),peak=float(abs(segment).max()),
        step_outlier_ratio=float(steps.max()/max(float(np.quantile(steps,.9999)),1/32768)))

before = json.loads((out / 'before-hashes.json').read_text(encoding='utf-8-sig'))
changed = [item['file'] for item in before if hashlib.sha256((bank / item['file']).read_bytes()).hexdigest()!=item['sha256']]
assert set(changed)=={'grass.wav','loose.wav'},changed
report = dict(changed_wavs=changed,unchanged_wavs=len(before)-2,engine_assets_unchanged=30,textures=[],engines=[],captures=[])
manifest = json.loads((bank / 'manifest.json').read_text())
report['compressor_probe'] = []
for label in ['before','after']:
    values,rate = read(out / (label+'-engine-surface-probe.wav'))
    mono = values.mean(axis=1)
    width = round(.1*rate)
    amplitude = []
    for start in range(0,len(mono)-width,width):
        time = np.arange(start,start+width)/rate
        amplitude.append(float(2*abs(np.sum(mono[start:start+width]*np.exp(-2j*np.pi*40*time)))/width))
    clear = float(np.median(amplitude[2:5]))
    loaded = np.asarray(amplitude[8:34])/clear
    report['compressor_probe'].append(dict(case=label,minimum_engine_gain=float(loaded.min()),maximum_engine_gain=float(loaded.max())))
assert report['compressor_probe'][0]['minimum_engine_gain']<.80,'Reproduce shared-compressor engine ducking'
assert report['compressor_probe'][1]['minimum_engine_gain']>.96 and report['compressor_probe'][1]['maximum_engine_gain']<1.04,'Steady engine must survive surface peaks'
source_names = {'grass':'Vehicle_Truck_Drive_Grass_Exterior_Loop_Stereo.wav','loose':'gravel_drive_cc0.wav'}
for name in source_names:
    clip = next(item for item in manifest['outputs'] if item['file']==name+'.wav')
    assert clip['generator']=='offroad-recorded-2' and clip['sources']==[source_names[name]]
    record = next(item for item in manifest['sources'] if item['filename']==source_names[name])
    assert record['license']=='CC0-1.0'
    rows = []
    for label,path in [('before',out / 'before/game/assets/audio/vehicles' / (name+'.wav')),('after',bank / (name+'.wav'))]:
        values,rate = read(path)
        hz = np.fft.rfftfreq(len(values),1/rate)
        power = abs(np.fft.rfft(values[:,0]))**2
        rows.append(dict(case=label,sub220hz_fraction=float(power[hz<220].sum()/power.sum())))
    assert rows[1]['sub220hz_fraction']<rows[0]['sub220hz_fraction']*.20
    report['textures'].append(dict(layer=name,measurements=rows))
for car in ['compact','pickup','classic','formula','kart']:
    values,rate = read(out / 'engine-continuity' / (car+'-continuous.wav'))
    stats = levels(values,rate,8,19)
    assert stats['minimum']>max(.0003,stats['median']*.04),car+': no engine dropouts'
    assert stats['step_outlier_ratio']<3.5,car+': no isolated discontinuity spikes'
    assert abs(values).max()<.90 and abs(values[-round(.4*rate):]).max()==0,car
    report['engines'].append(dict(car=car,**stats))
for folder in ['before-engine','after-engine']:
    values,rate = read(out / folder / 'compact-after.wav')
    stats = levels(values,rate,8.5,11.5)
    assert stats['minimum']>max(.0003,stats['median']*.04)
    assert stats['step_outlier_ratio']<3.5
    assert abs(values).max()<.90 and abs(values[-round(.4*rate):]).max()==0
    report['engines'].append(dict(case=folder,**stats))
for row in json.loads((out / 'grass-onset.json').read_text()): assert row['ratio']>=.85 and row['first']>.35
traces = json.loads((out / 'native-contact-timing.json').read_text())
for trace in traces:
    case = trace['case']
    for suffix in ['','-grass','-kerb','-loose','-engine']:
        path = out / (case+suffix+'.wav')
        values,rate = read(path)
        peak = float(abs(values).max())
        tail = float(abs(values[-round(.15*rate):]).max())
        assert peak<.94 and tail==0,(path.name,peak,tail)
        if (case=='grass-speeds' and suffix=='-grass') or (case=='gravel-speeds' and suffix=='-loose'): assert peak>.035
        if case in ['grass-speeds','gravel-speeds'] and suffix=='-kerb': assert peak==0
        if case=='grass-entry' and suffix=='-grass':
            first = np.flatnonzero(np.max(abs(values),axis=1)>.0008)
            assert len(first) and abs(first[0]/rate-trace['first_grass_s'])<.10
        if suffix=='-engine':
            stats = levels(values,rate,.2,2.5)
            assert stats['minimum']>max(.0003,stats['median']*.04),case+': isolated engine has no dropout'
        report['captures'].append(dict(file=path.name,peak=peak,pause_tail_peak=tail))
(out / 'audio-review.json').write_text(json.dumps(report,indent=2)+'\n')
print('ENGINE_GRASS_REVIEW:',len(report['engines']),'engine captures;',len(report['captures']),'mixed/isolated captures;',report['unchanged_wavs'],'other WAVs exact')
