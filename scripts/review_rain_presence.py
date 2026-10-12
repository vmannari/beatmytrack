"""Same-clock actual race rain/engine/music audibility, pause and mute review."""
from pathlib import Path
import hashlib
import json
import math
import wave
import argparse
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--evidence-dir',type=Path,default=ROOT/'docs/evidence/rain-presence-2026-10-09')
OUT=parser.parse_args().evidence_dir
def read(path):
    with wave.open(str(path)) as handle:
        rate=handle.getframerate();channels=handle.getnchannels()
        values=np.frombuffer(handle.readframes(handle.getnframes()),dtype='<i2').astype(np.float64)/32768.0
    values=values.reshape(-1,channels)
    return values[round(rate*.15):-round(rate*.15)],rate
def db(values): return 20*math.log10(max(float(np.sqrt(np.mean(values**2))),1e-9))
report={'captures':[],'failures':[]}
audio={}
for scene in ['before','after','paused','muted']:
    row={'scene':scene}
    for layer in ['mix','engine','music','rain']:
        values,rate=read(OUT/(scene+'-'+layer+'.wav'))
        audio[scene,layer]=values
        row[layer+'_dbfs']=db(values)
        row[layer+'_peak']=float(np.max(np.abs(values)))
        if row[layer+'_peak']>=.95: report['failures'].append('Capture lacks headroom: '+scene+' '+layer)
        if scene=='paused' and row[layer+'_peak']!=0: report['failures'].append('Pause is not digitally silent: '+layer)
    report['captures'].append(row)
old,new=report['captures'][:2]
report['gain_db']=new['rain_dbfs']-old['rain_dbfs']
report['rain_relative_engine_db']=new['rain_dbfs']-new['engine_dbfs']
report['rain_relative_music_db']=new['rain_dbfs']-new['music_dbfs']
if not 11.8<report['gain_db']<13.3: report['failures'].append('Rain increase should be about12.5dB')
if not -15<report['rain_relative_engine_db']<-5: report['failures'].append('Rain should be present below the engine')
if new['music_peak']<.001: report['failures'].append('Mix must include actual default race music')
# With Vehicle muted, only default music reaches the output. Compare RMS;
# source buses are recorded before mute and retain their raw references.
muted=report['captures'][3]
capture=json.loads((OUT/'capture.json').read_text())
music_gain=float(next(row['music_bus_gain'] for row in capture if row['scene']=='muted'))
report['music_bus_gain']=music_gain
report['muted_output_relative_music_db']=muted['mix_dbfs']-muted['music_dbfs']-20*math.log10(music_gain)
if abs(report['muted_output_relative_music_db'])>1: report['failures'].append('Vehicle mute output should match the remaining music')
previous=json.loads((OUT/'before/preserved.json').read_text())
report['preserved']=[{'path':p,'matches':hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==digest} for p,digest in previous.items()]
if not all(row['matches'] for row in report['preserved']): report['failures'].append('Rain source, deferred wet mixer or wishlist changed')
(OUT/'review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
cards=''.join('<article><h2>'+label+'</h2><audio controls preload="metadata" src="'+name+'.wav"></audio></article>' for label,name in [('Quiet reference with engine and music','before-mix'),('Current rain with engine and music','after-mix'),('Rain alone at the current playback level','after-rain')])
(OUT/'review.html').write_text('<!doctype html><meta charset="utf-8"><title>Distant rain presence</title><style>body{background:#111b2b;color:#eee;font:18px system-ui;max-width:900px;margin:40px auto}article{padding:16px;margin:12px 0;background:#1c2b40}audio{width:100%}</style><h1>Distant rain presence</h1><p>Actual race presentation at a held86.4km/h, with default engine/music settings. Wet road rolling remains disabled. The same soft rain recording plays at the stronger level.</p>'+cards,encoding='utf-8')
print(json.dumps(report,indent=2))
raise SystemExit(bool(report['failures']))
