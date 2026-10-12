"""Native thunder timing, audible transient/tail, pause, mute and rain preservation."""
from pathlib import Path
import hashlib
import json
import math
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/rain-thunder-2026-10-10'
def read(path):
    with wave.open(str(path)) as f:
        rate=f.getframerate();channels=f.getnchannels()
        v=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(np.float64)/32768.0
    return v.reshape(-1,channels),rate
def db(v): return 20*math.log10(max(float(np.sqrt(np.mean(v**2))),1e-9))
report={'captures':[],'failures':[]}
arrays={}
for scene in ['strike','paused','muted']:
    row={'scene':scene}
    for layer in ['mix','music','engine','rain','thunder']:
        v,rate=read(OUT/(scene+'-'+layer+'.wav'))
        body=v[round(.15*rate):-round(.15*rate)]
        arrays[scene,layer]=(body,rate)
        row[layer+'_dbfs']=db(body);row[layer+'_peak']=float(np.max(np.abs(body)))
        if row[layer+'_peak']>=.95: report['failures'].append('Insufficient headroom: '+scene+' '+layer)
        if scene=='paused' and row[layer+'_peak']!=0: report['failures'].append('Pause not silent: '+layer)
    report['captures'].append(row)
v,rate=arrays['strike','thunder']
hop=round(.05*rate)
envelope=np.array([np.sqrt(np.mean(v[i:i+hop]**2)) for i in range(0,len(v)-hop,hop)])
report['strongest_thunder_50ms_dbfs']=20*math.log10(max(float(envelope.max()),1e-9))
if report['strongest_thunder_50ms_dbfs']<report['captures'][0]['engine_dbfs']-6: report['failures'].append('Thunder transient should be audible against engine')
if report['captures'][0]['thunder_dbfs']<report['captures'][0]['rain_dbfs']+3: report['failures'].append('Thunder should rise above the rain bed')
capture=json.loads((OUT/'capture.json').read_text())
muted=report['captures'][2];gain=float(capture[2]['music_gain'])
report['muted_output_relative_music_db']=muted['mix_dbfs']-muted['music_dbfs']-20*math.log10(gain)
if abs(report['muted_output_relative_music_db'])>1: report['failures'].append('Vehicle mute should leave only music')
before=json.loads((OUT/'before/preserved-hashes.json').read_text())
report['preserved']=[{'path':p,'matches':hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==digest} for p,digest in before.items()]
if not all(row['matches'] for row in report['preserved']): report['failures'].append('Rain source/deferred wet mixer/wishlist changed')
report['rain_gain']=capture[0]['rain_gain']
report['rain_reduction_db']=20*math.log10(report['rain_gain']/.45)
if abs(report['rain_reduction_db']-20*math.log10(.45/.55))>.001: report['failures'].append('Rain reduction must match the preceding amount')
(OUT/'review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
(OUT/'review.html').write_text('<!doctype html><meta charset="utf-8"><title>Rain and thunder</title><style>body{background:#111b2b;color:#eee;font:18px system-ui;max-width:900px;margin:40px auto}audio{width:100%}</style><h1>Quieter rain and thunder</h1><p>Actual race presentation with engine and default music. The thunder follows one lightning strike.</p><audio controls src="strike-mix.wav"></audio><h2>Thunder alone at its game level</h2><audio controls src="strike-thunder.wav"></audio><p>Source: <a href="https://bigsoundbank.com/thunder-3-s3114.html">Thunder3, Joseph SARDIN and Axeline T., CC0</a>.</p>',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='preserved'},indent=2))
raise SystemExit(bool(report['failures']))
