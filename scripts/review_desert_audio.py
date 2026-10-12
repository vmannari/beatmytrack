"""Review actual captured desert mix and exact tire silence; local audio-only evidence."""
from pathlib import Path
import json
import wave
import math
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/"docs/evidence/desert-audio-2026-10-06"
stats = []
for name in ["desert-driving.wav","desert-tire-bus.wav"]:
    with wave.open(str(OUT/name)) as handle:
        rate = handle.getframerate()
        channels = handle.getnchannels()
        frames = handle.getnframes()
        data = np.frombuffer(handle.readframes(frames),dtype="<i2").astype(np.float64)/32768.0
    peak = float(np.max(np.abs(data)))
    rms = float(np.sqrt(np.mean(data*data)))
    silent_tail = float(np.max(np.abs(data[-rate*channels//2:])))
    assert silent_tail==0, name+": paused tail must be silent"
    if name=="desert-tire-bus.wav": assert peak==0, "No dry-desert tire output is permitted"
    else: assert .03<peak<.9, "Desert mix must be audible and unclipped"
    stats.append({"file":name,"seconds":frames/rate,"peak":peak,"peak_dbfs":20*math.log10(peak) if peak else None,"rms":rms,"clipped_samples":int(np.sum(np.abs(data)>=.999)),"silent_tail":silent_tail})
(OUT/"levels.json").write_text(json.dumps(stats,indent=2)+"\n",encoding="utf-8")
html = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Desert sand and stones — Beat my track</title><style>body{margin:0;background:#101b27;color:#e9e3d7;font:17px/1.5 system-ui,sans-serif}main{max-width:760px;margin:48px auto;padding:0 24px}h1{font-size:32px}h2,a{color:#ffd667}article{padding:22px;border:1px solid #344450;border-radius:12px;background:#182632}audio{width:100%}p,small{color:#b3bec5}</style><main><h1>Desert sand and flying stones</h1><p>The game emits sand spray and short pebble-scatter bursts. Desert tire squeal and tread loops are silent.</p><article><h2>Actual game mix</h2><audio controls preload="metadata" src="desert-driving.wav"></audio><p>Idle → acceleration → ordinary driving → sliding (5–9 s) → straight driving → pause. Includes the engine, wind, sand and pebble bursts.</p></article><p>The separately captured dry tire bus has a peak of exactly zero. All contact, pause and replay checks pass. Phone listening remains pending.</p><small>Sand/stone foley: Nox Sound Design Essentials Series (CC0). Dirty-ground driving and black-pebble recordings were filtered, cut, looped and mastered for this mix. Full source hashes and derivative details: game/assets/audio/vehicles/manifest.json and NOTICE.txt.</small></main></html>'''
(OUT/"audition.html").write_text(html,encoding="utf-8")
print(json.dumps(stats,indent=2))
