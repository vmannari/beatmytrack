"""Measure actual Godot PCM previews and build a local listening artifact."""
from pathlib import Path
import hashlib
import html
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/surface-impact-audio-2026-10-08"
stats = []
responses = {}
previews = [
    ("desert-full", "Desert: full vehicle mix", "Acceleration to 90 km/h; coast at 4-6 s; powered driving; slide at 8-10.2 s; pause at 11 s."),
    ("desert-surfaces", "Desert: sand and underside stones", "Same game mix with the engine bus muted for review. Low rolling rumble, granular spray and short metal taps; coast is quieter than powered driving."),
    ("offtrack-surfaces", "Grass, sand and pavement", "Grass at 0-4 s; sand/dirt at 4-8 s; pavement at 8-11 s; pause. Engine bus muted for review."),
    ("collision-hits", "Light, medium and heavy contacts", "Actual impulse-triggered clips at 1, 3 and 5 s. Quiet rolling vehicle background; pause at 7 s."),
]
for name, title, timeline in previews:
    target = OUT / (name + ".wav")
    with wave.open(str(target)) as handle:
        rate = handle.getframerate()
        channels = handle.getnchannels()
        pcm = np.frombuffer(handle.readframes(handle.getnframes()), dtype="<i2").astype(np.float64)/32768.0
    values = pcm.reshape(-1, channels)
    peak = float(np.max(np.abs(values)))
    pause = float(np.max(np.abs(values[-rate//2:])))
    if peak <= .003 or peak >= .95 or pause != 0:
        raise ValueError(f"Bad capture: {name}, peak={peak}, pause={pause}")
    stats.append(dict(file=target.name, seconds=len(values)/rate, peak_dbfs=20*np.log10(peak),
                      rms_dbfs=20*np.log10(np.sqrt(np.mean(values**2))), pause_peak=pause,
                      sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
    if name=="desert-surfaces":
        def rms(start, end):
            return float(np.sqrt(np.mean(values[round(start*rate):round(end*rate)]**2)))
        responses = dict(slow_rms=rms(1.0,2.0), coast_rms=rms(4.4,5.8), powered_rms=rms(6.4,7.8))
        if responses["powered_rms"]<=responses["coast_rms"] or responses["powered_rms"]<=responses["slow_rms"]:
            raise ValueError("Actual sand capture must respond to speed and tractive effort")
with wave.open(str(OUT / "desert-tire-bus.wav")) as handle:
    tire_peak = int(np.max(np.abs(np.frombuffer(handle.readframes(handle.getnframes()),dtype="<i2").astype(np.int32))))
if tire_peak!=0:
    raise ValueError("Dry desert tire bus must be digitally silent")
manifest = json.loads((ROOT / "game/assets/audio/vehicles/manifest.json").read_text())
old = json.loads((OUT / "before/game/assets/audio/vehicles/manifest.json").read_text())
old_map = {x["file"]:x["sha256"] for x in old["outputs"]}
unchanged = [x["file"] for x in manifest["outputs"] if old_map.get(x["file"])==x["sha256"]]
report = dict(captures=stats, sand_response=responses, desert_tire_peak=tire_peak, unchanged_clips=unchanged, changed_clips=[x["file"] for x in manifest["outputs"] if x["file"] in old_map and x["file"] not in unchanged],
              added_clips=[x["file"] for x in manifest["outputs"] if x["file"] not in old_map],
              bank_bytes=sum((ROOT / "game/assets/audio/vehicles" / x["file"]).stat().st_size for x in manifest["outputs"]))
(OUT / "capture-levels.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
articles = "".join(f'<article><h2>{html.escape(title)}</h2><audio controls preload="metadata" src="{name}.wav"></audio><p>{html.escape(timeline)}</p></article>' for name,title,timeline in previews)
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Surface and collision audio - Beat my track</title><style>body{margin:0;background:#101b27;color:#e9e3d7;font:17px/1.5 system-ui,sans-serif}main{max-width:850px;margin:40px auto;padding:0 24px}h2,a{color:#ffd667}article{padding:22px;margin:18px 0;border:1px solid #344450;border-radius:12px;background:#182632}audio{width:100%}p,small{color:#b3bec5}</style><main><h1>Collision, grass and sand audio</h1><p>Actual desktop game mixer recordings. Four-wheel material sampling, severity-based impacts and speed/tractive-effort-driven spray. Owner listening and phone acceptance remain open.</p>'''+articles+'''<p>Sources: <a href="https://freesound.org/people/qubodup/sounds/332058/">qubodup collision</a>, <a href="https://freesound.org/people/cognito%20perceptu/sounds/97605/">cognito perceptu gravel drive</a>, <a href="https://freesound.org/people/KALeigh0218/sounds/655924/">KALeigh0218 stone contacts</a> (CC0 HQ MP3 previews); Nox grass/dirty-ground/body foley (CC0). Collision is designed mechanical foley, not a crash field recording. Full source/derivative hashes in the game bank manifest.</p><small>Any pavement tire squeal uses audible-edge (Tom Haigh), loop edit by qubodup, <a href="https://opengameart.org/content/car-tire-squeal-skid-loop">Car tire squeal skid loop</a>, <a href="https://creativecommons.org/licenses/by/3.0/">CC BY 3.0</a>, resampled/filtered/mastered. No phone listening or AAA-quality approval claimed.</small></main></html>'''
(OUT / "audition.html").write_text(page, encoding="utf-8")
print(json.dumps(dict(captures=len(stats), unchanged_clips=len(unchanged), changed_clips=report["changed_clips"],added_clips=report["added_clips"],bank_bytes=report["bank_bytes"],peak_dbfs=max(x["peak_dbfs"] for x in stats),pause_silent=all(x["pause_peak"]==0 for x in stats)), indent=2))
