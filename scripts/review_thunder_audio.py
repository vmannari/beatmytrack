"""Native thunder timing, audible transient/tail, pause, mute and rain preservation."""
from pathlib import Path
import hashlib
import json
import math
import wave
import argparse
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--evidence-dir',type=Path,default=ROOT/'docs/evidence/rain-thunder-2026-10-10')
parser.add_argument('--stronger',action='store_true')
parser.add_argument('--owner-bass',action='store_true')
parser.add_argument('--background-rumble',action='store_true')
parser.add_argument('--louder-rumble',action='store_true')
args=parser.parse_args()
OUT=args.evidence_dir
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
    for layer in ['mix','music','engine','rain','thunder']+(['rumble'] if args.background_rumble else []):
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
capture=[row for scene in ['strike','paused','muted'] for row in json.loads((OUT/'capture.json').read_text()) if row['scene']==scene]
muted=report['captures'][2];gain=float(capture[2]['music_gain'])
if muted['music_peak']==0.0:
    report['muted_output_relative_music_db']=0.0
    if muted['mix_peak']!=0.0: report['failures'].append('Vehicle mute must be exactly silent when biome music is removed')
else:
    report['muted_output_relative_music_db']=muted['mix_dbfs']-muted['music_dbfs']-20*math.log10(gain)
    if abs(report['muted_output_relative_music_db'])>1: report['failures'].append('Vehicle mute should leave only music')
before=json.loads((OUT/'before/preserved-hashes.json').read_text(encoding='utf-8-sig'))
report['preserved']=[{'path':p,'matches':hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==digest} for p,digest in before.items()]
if not all(row['matches'] for row in report['preserved']): report['failures'].append('Rain source/deferred wet mixer/wishlist changed')
report['rain_gain']=capture[0]['rain_gain']
report['rain_reduction_db']=20*math.log10(report['rain_gain']/.45)
if args.stronger or args.owner_bass:
    mix,mix_rate=arrays['strike','mix']
    mix_hop=round(.05*mix_rate)
    mix_envelope=np.array([np.sqrt(np.mean(mix[i:i+mix_hop]**2)) for i in range(0,len(mix)-mix_hop,mix_hop)])
    report['strongest_output_50ms_dbfs']=20*math.log10(max(float(mix_envelope.max()),1e-9))
    if report['strongest_output_50ms_dbfs']<report['captures'][0]['engine_dbfs']+6: report['failures'].append('Strong thunder must remain dominant in final output')
    if report['rain_gain']>=.36818182: report['failures'].append('Rain must be quieter than the rejected mix')
    if report['strongest_thunder_50ms_dbfs']<report['captures'][0]['engine_dbfs']+6: report['failures'].append('Strong thunder must rise clearly above the engine')
    if args.stronger:
        with wave.open(str(OUT/'before/game/assets/audio/storm_thunder.wav')) as f:
            old=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(float)/32768
        with wave.open(str(ROOT/'game/assets/audio/storm_thunder.wav')) as f:
            new=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(float)/32768
        report['thunder_gain_increase_db']=db(new)-db(old)+20*math.log10(capture[0]['thunder_gain']/.65)
        if report['thunder_gain_increase_db']<8: report['failures'].append('Thunder body must increase substantially')
    if args.owner_bass:
        source=np.frombuffer((ROOT/'build/storm_thunder_sources/owner-thunder-29190.f32').read_bytes(),dtype='<f4').astype(float)
        with wave.open(str(ROOT/'game/assets/audio/storm_thunder.wav')) as f:
            master=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(float)/32768
        manifest=json.loads((ROOT/'game/assets/audio/storm_thunder_manifest.json').read_text())
        start=round(float(manifest.get('source_start_seconds',0))*44100)
        source=source[start:start+len(master)]
        def bass_ratio(values):
            energy=np.abs(np.fft.rfft(values))**2;hz=np.fft.rfftfreq(len(values),1/44100)
            return 10*math.log10(float(energy[(hz>=40)&(hz<=180)].sum()/energy[(hz>=400)&(hz<=2000)].sum()))
        report['bass_relative_mid_increase_db']=bass_ratio(master)-bass_ratio(source)
        if report['bass_relative_mid_increase_db']<1: report['failures'].append('Final master must measurably enhance bass relative to midrange')
else:
    if abs(report['rain_reduction_db']-20*math.log10(.45/.55))>.001: report['failures'].append('Rain reduction must match the preceding amount')
if args.background_rumble:
    bed,rate=read(OUT/'bed-rumble.wav')
    bed=bed[round(.15*rate):-round(.15*rate)]
    hop=round(.20*rate)
    energy=np.array([np.sqrt(np.mean(bed[i:i+hop]**2)) for i in range(0,len(bed)-hop,hop)])
    report['background_rumble']=dict(seconds=len(bed)/rate,rms_dbfs=db(bed),
        peak=float(np.max(np.abs(bed))),quietest_200ms_dbfs=20*math.log10(max(float(energy.min()),1e-9)),
        below_strong_thunder_db=db(arrays['strike','thunder'][0])-db(bed))
    if len(bed)/rate<18 or energy.min()<.001: report['failures'].append('Distant rumble must remain continuous through the 16s loop wrap')
    lower,upper=(8,18) if args.louder_rumble else (18,32)
    if not lower<=report['background_rumble']['below_strong_thunder_db']<=upper: report['failures'].append('Distant rumble must match the requested balance beneath strong cues')
    if args.louder_rumble:
        engine,engine_rate=read(OUT/'bed-engine.wav')
        engine=engine[round(.15*engine_rate):-round(.15*engine_rate)]
        report['background_rumble']['relative_engine_db']=db(bed)-db(engine)
        if report['background_rumble']['relative_engine_db'] < -6: report['failures'].append('Raised background rumble must be audible alongside the engine')
    if arrays['muted','mix'][0].max()!=0 or arrays['muted','mix'][0].min()!=0: report['failures'].append('Vehicle mute must silence the new bed in final output')
    for layer in ['thunder','rumble','mix']:
        plain,plain_rate=read(OUT/('bed-'+layer+'.wav'))
        if layer=='thunder' and np.max(np.abs(plain))!=0: report['failures'].append('Continuous bed must not trigger a strong strike')
        if np.max(np.abs(plain))>=.95: report['failures'].append('Continuous mix must keep headroom: '+layer)
(OUT/'review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
credit='Owner-supplied freesound_community-thunder-big-wav-29190.mp3 with bass enhancement.' if args.owner_bass else 'Source: <a href="https://bigsoundbank.com/thunder-3-s3114.html">Thunder3, Joseph SARDIN and Axeline T., CC0</a>.'
rapid='<h2>Rapid replacement fixture</h2><audio controls src="rapid-cues.wav"></audio>' if (OUT/'rapid-cues.wav').exists() else ''
if args.background_rumble:
    rapid='<h2>Continuous faint rumble with engine and rain</h2><audio controls src="bed-mix.wav"></audio><h2>Distant thunder alone at its game level</h2><audio controls src="bed-rumble.wav"></audio>'+rapid
(OUT/'review.html').write_text('<!doctype html><meta charset="utf-8"><title>Rain and thunder</title><style>body{background:#111b2b;color:#eee;font:18px system-ui;max-width:900px;margin:40px auto}audio{width:100%}</style><h1>Rain and thunder</h1><p>Actual race presentation with driving/weather audio. The thunder follows one lightning strike.</p><audio controls src="strike-mix.wav"></audio><h2>Thunder alone at its game level</h2><audio controls src="strike-thunder.wav"></audio>'+rapid+'<p>'+credit+'</p>',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='preserved'},indent=2))
raise SystemExit(bool(report['failures']))
