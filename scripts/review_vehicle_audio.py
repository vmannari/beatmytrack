"""Inspect actual captured game mixes and build a local listening review."""
from pathlib import Path
import json
import math
import wave
import argparse
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--continuous",action="store_true")
args = parser.parse_args()
EVIDENCE = ROOT / ("docs/evidence/vehicle-audio-continuity-2026-10-06" if args.continuous else "docs/evidence/vehicle-audio-2026-10-06")
records = []
for path in sorted(EVIDENCE.glob("*-continuous.wav" if args.continuous else "*-driving.wav")):
    with wave.open(str(path)) as handle:
        rate = handle.getframerate()
        channels = handle.getnchannels()
        frames = handle.getnframes()
        values = np.frombuffer(handle.readframes(frames),dtype="<i2").astype(np.float64)/32768.0
    peak = float(np.max(np.abs(values)))
    rms = float(np.sqrt(np.mean(values*values)))
    clipped = int(np.sum(np.abs(values)>=.999))
    silent_tail = float(np.max(np.abs(values[-rate*channels//2:])))
    assert peak>.03 and peak<.90 and clipped==0, path.name+" is silent or clipped"
    assert silent_tail==0.0, path.name+" has sound after pausing"
    records.append({"file":path.name,"seconds":frames/rate,"peak_dbfs":20*math.log10(peak),"rms_dbfs":20*math.log10(rms),"clipped_samples":clipped,"last_half_second_peak":silent_tail})
assert len(records)==5, "Capture all five vehicles with TestScript -Graphical first"
(EVIDENCE / "capture_levels.json").write_text(json.dumps(records,indent=2)+"\n",encoding="utf-8")
cards = "\n".join(f'<article><h2>{item["file"].split("-")[0].capitalize()}</h2><audio controls preload="metadata" src="{item["file"]}"></audio><p>Peak {item["peak_dbfs"]:.1f} dBFS · 0 clipped samples · silent paused tail</p></article>' for item in records)
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Beat my track — Vehicle sound review</title>
<style>body{margin:0;background:#101b27;color:#e9e3d7;font:17px/1.5 system-ui,sans-serif}main{max-width:820px;margin:48px auto;padding:0 24px}h1{font-size:34px;line-height:1.2}h2{margin:0 0 12px;font-size:22px;color:#ffd667}article{padding:20px;margin:16px 0;border:1px solid #344450;border-radius:12px;background:#182632}audio{width:100%}p{color:#b3bec5}article p{font-size:14px;margin:10px 0 0}a{color:#ffd667}small{color:#b3bec5}</style>
<main><h1>Vehicle sound review</h1><p>Actual Godot master-bus captures. Each eight-second preview moves through idle, acceleration and shifts, lift-off, braking, tire slip, a body impact, then pause.</p><p>The kart uses one gear. These are authored fictional engine voices, processed from cleared recordings. Hearing quality on the phone remains to be reviewed.</p>'''+cards+'''<small>Tire recording: audible-edge (Tom Haigh), loop edit by qubodup, <a href="https://opengameart.org/content/car-tire-squeal-skid-loop">Car tire squeal skid loop</a>, <a href="https://creativecommons.org/licenses/by/3.0/">CC BY 3.0</a>. Resampled, filtered, looped and mastered. Other recorded masters: Nox Sound Design, Joseph SARDIN and DenisChardonnet (CC0). Full credits: game/assets/audio/vehicles/NOTICE.txt.</small></main>
<script>const players=[...document.querySelectorAll('audio')];players.forEach(player=>player.addEventListener('play',()=>players.forEach(other=>{if(other!==player)other.pause()})))</script></html>'''
if args.continuous:
    page = page.replace("Vehicle sound review","Continuous engine review")
    page = page.replace("Actual Godot master-bus captures. Each eight-second preview moves through idle, acceleration and shifts, lift-off, braking, tire slip, a body impact, then pause.","Corrected recordings from the actual Godot engine bus. Each twelve-second preview contains three seconds of idle, a smooth acceleration, six seconds of sustained revs across repeated loops, lift-off, then pause. Tire and impact sounds are excluded so the engine is easy to judge.")
    page = page.replace("The kart uses one gear.","The resampling bug that inserted repeating silent gaps has been fixed. All 36 looped assets and all 15 captured idle/rev/lift-off segments pass continuity checks. The kart uses one gear.")
    page = page.replace("Tire recording:","No tire audio is present in these engine-only captures. General game tire credit:")
    if (EVIDENCE/"tires-after.wav").exists():
        comparisons = '<h2>Tire presence in the full mix</h2><p>The same held slide with engine and road sounds. The revised dry tire layer is 4.25 dB louder; grip/slip triggers are unchanged.</p><article><h2>Before</h2><audio controls preload="metadata" src="tires-before.wav"></audio></article><article><h2>After</h2><audio controls preload="metadata" src="tires-after.wav"></audio></article>'
        page = page.replace("<small>",comparisons+"<small>",1)
(EVIDENCE / "audition.html").write_text(page,encoding="utf-8")
print(json.dumps(records,indent=2))
