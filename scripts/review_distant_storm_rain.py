"""Distant-rain asset comparison and quiet listening previews, build tools only."""
from pathlib import Path
import hashlib
import json
import math
import wave
import numpy as np
from test_vehicle_audio_continuity import measure

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/distant-storm-rain-2026-10-09'
ASSET=ROOT/'game/assets/audio/ambience/storm_rain_recorded.wav'
def read(path):
    with wave.open(str(path)) as handle:
        rate=handle.getframerate()
        assert handle.getnchannels()==1 and handle.getsampwidth()==2
        pcm=np.frombuffer(handle.readframes(handle.getnframes()),dtype='<i2').astype(np.float64)/32768.0
    return pcm,rate
def stats(pcm,rate):
    rms=float(np.sqrt(np.mean(pcm**2)))
    energy=np.abs(np.fft.rfft(pcm))**2
    hz=np.fft.rfftfreq(len(pcm),1/rate)
    return dict(rms_dbfs=20*math.log10(rms),crest_db=20*math.log10(np.max(np.abs(pcm))/rms),
        high_energy_fraction=float(energy[hz>3000].sum()/energy.sum()),
        continuity=measure(np.tile(pcm[:,None],(3,1)),rate))
old,rate=read(OUT/'before/game/assets/audio/ambience/storm_rain_recorded.wav')
new,new_rate=read(ASSET)
report=dict(before=stats(old,rate),after=stats(new,new_rate),failures=[])
if report['after']['rms_dbfs']>report['before']['rms_dbfs']-3: report['failures'].append('Distant bed must remain quieter')
if report['after']['crest_db']>=report['before']['crest_db']: report['failures'].append('Distant field should soften individual drop transients')
if report['after']['high_energy_fraction']>=report['before']['high_energy_fraction']: report['failures'].append('Distant field should contain less sharp high-frequency detail')
if report['after']['continuity']['maximum_dropout_ms']>=100: report['failures'].append('Rain asset must not contain sustained gaps')
hashes=json.loads((OUT/'before/preserved-hashes.json').read_text())
report['unchanged_vehicle_wavs']=0
for name,digest in hashes.items():
    path=ROOT/name
    if '/vehicles/' not in name.replace('\\','/'): continue
    report['unchanged_vehicle_wavs']+=1
    if hashlib.sha256(path.read_bytes()).hexdigest()!=digest: report['failures'].append('Vehicle WAV changed: '+name)
for name,pcm,rate in [('near-rain',old,rate),('distant-rain',new,new_rate)]:
    with wave.open(str(OUT/(name+'.wav')),'wb') as handle:
        handle.setnchannels(1);handle.setsampwidth(2);handle.setframerate(rate)
        handle.writeframes(np.rint(pcm*.13*32767).astype('<i2').tobytes())
(OUT/'distance-review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
(OUT/'distance-review.html').write_text('<!doctype html><meta charset="utf-8"><title>Distant storm rain</title><style>body{background:#111b2b;color:#eee;font:18px system-ui;max-width:900px;margin:40px auto}article{padding:16px;margin:12px 0;background:#1c2b40}audio{width:100%}</style><h1>Distant rain for the overhead view</h1><p>Both samples use the actual quiet playback level. Perspective processing is sound design; the source was recorded on the ground.</p><article><h2>Previous close surface drops</h2><audio controls preload="metadata" src="near-rain.wav"></audio></article><article><h2>New diffuse rural rainfall</h2><audio controls preload="metadata" src="distant-rain.wav"></audio></article><p><a href="review.html">Hear it with the engine and wet tires</a>. Source: <a href="https://freesound.org/people/jmbphilmes/sounds/200271/">Rain light 1 (rural), jmbphilmes, CC0</a>.</p>',encoding='utf-8')
print(json.dumps(report,indent=2))
raise SystemExit(bool(report['failures']))
