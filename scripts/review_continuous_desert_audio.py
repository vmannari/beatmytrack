"""Measure long native desert captures and dense texture continuity; local audition."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/desert-continuous-audio-2026-10-08"

def read(path):
    with wave.open(str(path)) as wav:
        rate = wav.getframerate()
        channels = wav.getnchannels()
        x = np.frombuffer(wav.readframes(wav.getnframes()),dtype="<i2").astype(np.float64)/32768.0
    return x.reshape(-1,channels),rate

def continuity(x,rate):
    width = round(rate*.02)
    envelope = np.array([np.sqrt(np.mean(x[i:i+width]**2)) for i in range(0,len(x)-width,width)])
    median = float(np.median(envelope))
    return dict(rms_min=float(envelope.min()),rms_median=median,rms_max=float(envelope.max()),
                envelope_cv=float(envelope.std()/envelope.mean()),quiet_20ms_windows=int(np.sum(envelope<median*.15)),
                peak_dbfs=float(20*np.log10(np.max(np.abs(x)))))

asset,rate = read(ROOT / "game/assets/audio/vehicles/sand_debris.wav")
texture = continuity(np.tile(asset,(3,1)),rate)
if texture["quiet_20ms_windows"] or texture["envelope_cv"]>.25:
    raise ValueError("Dense grain texture must be continuously active without isolated large clumps")
captures = []
balance = []
for name in ["steady-sand","desert-driving"]:
    target = OUT / (name+".wav")
    values,rate = read(target)
    peak = float(np.max(np.abs(values)))
    pause = float(np.max(np.abs(values[-rate//2:])))
    if peak<.01 or peak>=.95 or pause!=0:
        raise ValueError(f"Bad native capture: {name}; peak {peak}, pause {pause}")
    segment = values[round(rate*.5):round(rate*15.5)] if name=="steady-sand" else values[round(rate*3.8):round(rate*13.8)]
    stats = continuity(segment,rate)
    if name=="steady-sand" and stats["quiet_20ms_windows"]:
        raise ValueError("Steady native sand stream contains gaps")
    captures.append(dict(file=target.name,seconds=len(values)/rate,sha256=hashlib.sha256(target.read_bytes()).hexdigest(),pause_peak=pause,**stats))
    if name=="desert-driving":
        engine,engine_rate = read(OUT / (name+"-engine.wav"))
        sand,sand_rate = read(OUT / (name+"-sand.wav"))
        if engine_rate!=sand_rate:
            raise ValueError("Engine and sand references must share the same mixer clock")
        for label,start,end in [("coasting",5.5,6.7),("powered",8.0,10.0),("sliding",11.5,12.5)]:
            engine_rms = float(np.sqrt(np.mean(engine[round(start*engine_rate):round(end*engine_rate)]**2)))
            sand_rms = float(np.sqrt(np.mean(sand[round(start*sand_rate):round(end*sand_rate)]**2)))
            relative_db = float(20*np.log10(sand_rms/engine_rms))
            if relative_db> -3.0:
                raise ValueError("Sand must remain quieter than engine during "+label+": "+str(relative_db))
            balance.append(dict(segment=label,sand_relative_to_engine_db=relative_db,engine_rms=engine_rms,sand_rms=sand_rms))
old = json.loads((OUT / "before/game/assets/audio/vehicles/manifest.json").read_text())
now = json.loads((ROOT / "game/assets/audio/vehicles/manifest.json").read_text())
mapping = {x["file"]:x["sha256"] for x in now["outputs"]}
if any(mapping[x["file"]]!=x["sha256"] for x in old["outputs"]):
    raise ValueError("Existing vehicle/collision/grass/sand masters must remain exact")
report = dict(texture=texture,captures=captures,engine_balance=balance,unchanged_prior_clips=len(old["outputs"]),
              bank_clips=len(now["outputs"]),bank_bytes=sum((ROOT / "game/assets/audio/vehicles" / x["file"]).stat().st_size for x in now["outputs"]),
              notes="Digital continuity and source integrity; no subjective/phone listening claim.")
(OUT / "audio-review.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Continuous desert audio - Beat my track</title><style>body{margin:0;background:#101b27;color:#e9e3d7;font:17px/1.5 system-ui,sans-serif}main{max-width:820px;margin:40px auto;padding:0 24px}h2,a{color:#ffd667}article{padding:22px;margin:18px 0;border:1px solid #344450;border-radius:12px;background:#182632}audio{width:100%}p,small{color:#b3bec5}</style><main><h1>Soft sand and fine underbody gravel</h1><p>Actual desktop mixer recordings. Steady sand swish carries light gravel detail underneath the engine. Tone shifts slightly with speed; power changes intensity. Owner listening and physical-device balance remain open.</p><article><h2>Desert driving: complete vehicle mix</h2><audio controls preload="metadata" src="desert-driving.wav"></audio><p>Acceleration to 90 km/h; coast at 5-7s; power again; slide at 11-13s; stop at 16s; pause at 17s. Engine/sand balance is measured from simultaneous separate buses.</p></article><article><h2>Steady sand at 90 km/h</h2><audio controls preload="metadata" src="steady-sand.wav"></audio><p>Engine muted only for texture review. Constant contact for 16 seconds, including the actual loop wrap; stop at 16s, pause at 17s. No recurring pebble-hit events.</p></article><article><h2>Rejected earlier continuous mix</h2><audio controls preload="metadata" src="rejected-loud-r1/desert-driving.wav"></audio><p>The brighter, louder first candidate is preserved for comparison.</p></article><article><h2>Current continuous texture source</h2><audio controls preload="metadata" src="../../../game/assets/audio/vehicles/sand_debris.wav"></audio><p>9.9-second seamless source. Recorded granular driving dominates; damped fine grains supply subdued detail.</p></article><small>Existing CC0 stone-contact recording by KALeigh0218 and gravel-driving recording by cognito perceptu; exact sources/licenses/derivative hashes in the shipping vehicle bank manifest and NOTICE. Existing Nox rolling/sand layers retained at adjusted desert balance. This is designed granular foley, not a dedicated under-car field recording.</small></main></html>'''
(OUT / "audition.html").write_text(page,encoding="utf-8")
print(json.dumps(dict(texture=texture,engine_balance=balance,unchanged_prior_clips=report["unchanged_prior_clips"],bank_clips=report["bank_clips"],bank_bytes=report["bank_bytes"],captures=captures),indent=2))
