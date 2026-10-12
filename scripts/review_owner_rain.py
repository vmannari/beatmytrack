"""Owner rain loop, repeated seams, playback continuity and a listening preview."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np
from test_vehicle_audio_continuity import measure

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/owner-rain-2026-10-10'
ASSET=ROOT/'game/assets/audio/ambience/storm_rain_recorded.wav'
def read(path):
    with wave.open(str(path)) as handle:
        rate=handle.getframerate();channels=handle.getnchannels()
        pcm=np.frombuffer(handle.readframes(handle.getnframes()),dtype='<i2').astype(np.float64)/32768.0
    return pcm.reshape(-1,channels),rate
values,rate=read(ASSET)
report={'asset':measure(np.tile(values,(3,1)),rate),'failures':[]}
report['seconds']=len(values)/rate
steps=np.abs(np.diff(values,axis=0))
report['seam_step']=float(np.max(np.abs(values[0]-values[-1])))
report['reference_step']=float(np.quantile(steps,.9995))
if report['seconds']!=20: report['failures'].append('Expected20-second loop')
if report['asset']['dropout_windows']!=0: report['failures'].append('Embedded gap or seam dropout')
if report['seam_step']>report['reference_step']*1.5+2/32768: report['failures'].append('Discontinuous loop boundary')
native,native_rate=read(OUT/'loop-rain.wav')
report['native']=measure(native,native_rate)
if report['native']['dropout_windows']!=0: report['failures'].append('Native playback contains a gap')
capture=json.loads((OUT/'capture.json').read_text())
report['native_wraps']=next(row['rain_wraps'] for row in capture if row['scene']=='loop')
if report['native_wraps']<1: report['failures'].append('No actual playback wrap')
manifest=json.loads((ROOT/'game/assets/audio/ambience/storm_rain_manifest.json').read_text())
if hashlib.sha256(ASSET.read_bytes()).hexdigest()!=manifest['sha256']: report['failures'].append('Asset differs from pinned master')
hashes=json.loads((OUT/'before/preserved-hashes.json').read_text())
report['preserved']=[{'path':p,'matches':hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==digest} for p,digest in hashes.items()]
if not all(row['matches'] for row in report['preserved']): report['failures'].append('Existing playback gain/vehicle/WAV/wishlist changed')
with wave.open(str(OUT/'owner-rain-loop.wav'),'wb') as handle:
    handle.setnchannels(1);handle.setsampwidth(2);handle.setframerate(rate)
    handle.writeframes(np.rint(values*.55*32767).astype('<i2').tobytes())
(OUT/'loop-review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
(OUT/'loop-review.html').write_text('<!doctype html><meta charset="utf-8"><title>Owner rain loop</title><style>body{background:#111b2b;color:#eee;font:18px system-ui;max-width:900px;margin:40px auto}audio{width:100%}</style><h1>Your rain recording:20-second loop</h1><p>The20–41-second source section is shortened with a one-second crossfade. This player repeats the loop at the game playback level.</p><audio controls loop preload="metadata" src="owner-rain-loop.wav"></audio><p><a href="review.html">Listen with engine and music</a></p>',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='preserved'},indent=2))
raise SystemExit(bool(report['failures']))
