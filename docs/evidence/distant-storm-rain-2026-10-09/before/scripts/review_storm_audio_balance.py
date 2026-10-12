"""Actual native mix levels and loop/silence checks for the storm correction."""
from pathlib import Path
import hashlib
import json
import math
import wave
import numpy as np
from test_vehicle_audio_continuity import measure

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/storm-audio-balance-2026-10-09'
report={'captures':[],'failures':[]}
def read(path):
    with wave.open(str(path)) as handle:
        rate=handle.getframerate(); channels=handle.getnchannels()
        assert handle.getsampwidth()==2
        pcm=np.frombuffer(handle.readframes(handle.getnframes()),dtype='<i2').astype(np.float64)/32768.0
    return pcm.reshape(-1,channels),rate
def db(values): return 20*math.log10(max(float(np.sqrt(np.mean(values**2))),1e-9))
for scene in ['cruise-before','cruise-after','fast-after','formula-after','stopped','paused','rain-loop']:
    row={'scene':scene}
    for layer in ['mix','engine','wet','rain']:
        pcm,rate=read(OUT/(scene+'-'+layer+'.wav'))
        body=pcm[round(.15*rate):-round(.15*rate)]
        row[layer+'_dbfs']=db(body)
        row[layer+'_peak']=float(np.max(np.abs(body)))
        if row[layer+'_peak']>=.95: report['failures'].append('Clipping/headroom: '+scene+' '+layer)
        if scene=='paused' and row[layer+'_peak']!=0: report['failures'].append('Pause should be digitally silent: '+layer)
        if layer=='wet' and scene in ['stopped','rain-loop'] and row[layer+'_peak']!=0: report['failures'].append('Stationary wet road should be silent')
        if layer=='rain' and scene!='paused' and row[layer+'_dbfs'] < -65: report['failures'].append('Foreground background rain must be present: '+scene)
    if scene in ['cruise-after','fast-after','formula-after']:
        row['wet_relative_engine_db']=row['wet_dbfs']-row['engine_dbfs']
        row['rain_relative_wet_db']=row['rain_dbfs']-row['wet_dbfs']
        if row['wet_relative_engine_db'] < -10: report['failures'].append('Wet rolling too far below engine: '+scene)
        if row['rain_relative_wet_db'] > -12: report['failures'].append('Rain should be substantially quieter than rolling: '+scene)
    report['captures'].append(row)
boost=report['captures'][1]['wet_dbfs']-report['captures'][0]['wet_dbfs']
report['measured_wet_gain_db']=boost
if not 9.0<boost<10.2: report['failures'].append('Native before/after rolling gain should be about 9.5dB')
pcm,rate=read(OUT/'rain-loop-rain.wav')
report['native_rain_continuity']=measure(pcm,rate)
if report['native_rain_continuity']['maximum_dropout_ms']>=100: report['failures'].append('Native rain contains a sustained gap')
bank=json.loads((OUT/'before/bank-hashes.json').read_text())
report['preserved_vehicle_clips']=len(bank)
for name,digest in bank.items():
    if hashlib.sha256((ROOT/'game/assets/audio/vehicles'/name).read_bytes()).hexdigest()!=digest:
        report['failures'].append('Existing vehicle WAV changed: '+name)
manifest=json.loads((ROOT/'game/assets/audio/ambience/storm_rain_manifest.json').read_text())
sample=ROOT/'game/assets/audio/ambience/storm_rain_recorded.wav'
if hashlib.sha256(sample.read_bytes()).hexdigest()!=manifest['sha256']: report['failures'].append('Rain manifest hash mismatch')
pcm,rate=read(sample)
report['rain_asset_continuity']=measure(np.tile(pcm,(3,1)),rate)
if report['rain_asset_continuity']['maximum_dropout_ms']>=100: report['failures'].append('Rain asset contains a sustained gap')
(OUT/'review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
cards=''.join('<article><h2>'+label+'</h2><audio controls preload="metadata" src="'+name+'.wav"></audio></article>' for label,name in [('Previous wet level + quiet rain','cruise-before-mix'),('Stronger wet tires + quiet rain','cruise-after-mix'),('Faster driving','fast-after-mix'),('Formula car','formula-after-mix'),('Rain at the shipping background level','rain-loop-rain')])
(OUT/'review.html').write_text('<!doctype html><meta charset="utf-8"><title>Storm audio balance</title><style>body{background:#111b2b;color:#eee;font:18px system-ui;max-width:900px;margin:40px auto}article{padding:16px;margin:12px 0;background:#1c2b40}h2{margin:0 0 10px}audio{width:100%}</style><h1>Wet tires and quiet rain</h1><p>Native engine/tire/rain mix at 57.6 and 115.2 km/h. Music is excluded. The rain recording is Joseph SARDIN\'s CC0 Rain on concrete from BigSoundBank.</p>'+cards,encoding='utf-8')
print(json.dumps(report,indent=2))
raise SystemExit(bool(report['failures']))
