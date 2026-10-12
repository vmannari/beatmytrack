"""Review matched native engine captures, continuity and compact-only asset scope."""
from pathlib import Path
import hashlib
import json
import math
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/compact-audio-2026-10-10"
BANK = ROOT / "game/assets/audio/vehicles"


def read(path):
    with wave.open(str(path)) as handle:
        rate, channels = handle.getframerate(), handle.getnchannels()
        values = np.frombuffer(handle.readframes(handle.getnframes()), "<i2").astype(float) / 32768
    return values.reshape(-1, channels), rate


def db(value):
    return 20 * math.log10(max(float(value), 1e-12))


before = json.loads((OUT / "before-bank-hashes.json").read_text())
current = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in BANK.glob("*.wav")}
assert set(current) == set(before), "Do not add/remove unrelated clips"
changed = [name for name in current if current[name] != before[name]]
assert len(changed) == 6 and all(name.startswith("compact_") for name in changed), changed
layers = []
for path in sorted(BANK.glob("compact_*.wav")):
    values, rate = read(path)
    x = values[:, 0]
    frequencies = np.fft.rfftfreq(len(x), 1 / rate)
    power = abs(np.fft.rfft(x * np.hanning(len(x))))
    target = (40, 100, 200)[int(path.stem.split("_")[1])]
    band = (frequencies > target * .9) & (frequencies < target * 1.1)
    order = float(frequencies[band][np.argmax(power[band])])
    blocks = [np.sqrt(np.mean(block**2)) for block in np.array_split(x, max(1, len(x) // 882))]
    assert abs(order - target) < 1.5, (path.name, order)
    assert max(abs(x)) < .841 and min(blocks) > .001, path.name
    layers.append({"file": path.name, "seconds": len(x) / rate, "engine_order_hz": order,
                   "target_order_hz": target, "peak_dbfs": db(max(abs(x))), "minimum_20ms_rms": float(min(blocks))})

captures = []
for variant in ("before", "after"):
    values, rate = read(OUT / f"compact-{variant}.wav")
    assert len(values) / rate > 18.5
    assert .03 < np.max(abs(values)) < .9
    assert np.max(abs(values[-rate // 2:])) == 0, "Paused tail must be exactly silent"
    segments = {}
    for name, start, end in (("idle", .5, 1.7), ("acceleration", 2.5, 7.8), ("cruise", 8.5, 11.5), ("coast", 12.5, 15.5), ("rev", 16.5, 17.5)):
        region = values[round(start * rate):round(end * rate)]
        blocks = [np.sqrt(np.mean(block**2)) for block in np.array_split(region, max(1, len(region) // 882))]
        assert min(blocks) > max(.0003, np.median(blocks) * .04), (variant, name, "audio dropout")
        segments[name] = {"rms_dbfs": db(np.sqrt(np.mean(region**2))), "minimum_20ms_rms": float(min(blocks))}
    telemetry = json.loads((OUT / f"{variant}-telemetry.json").read_text())
    assert telemetry["failures"] == 0 and min(telemetry["wraps"]) >= 2
    captures.append({"variant": variant, "seconds": len(values) / rate, "peak_dbfs": db(np.max(abs(values))),
                     "paused_tail_peak": 0, "observed_wraps": telemetry["wraps"], "segments": segments})
report = {"changed_clips": changed, "unchanged_clips": len(current) - len(changed), "layers": layers, "captures": captures}
(OUT / "review.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
cards = "".join(f'<article><h2>{variant.capitalize()}</h2><audio controls preload="metadata" src="compact-{variant}.wav"></audio></article>' for variant in ("before", "after"))
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Compact engine audition</title>
<style>body{background:#101b27;color:#eee5d6;font:17px/1.5 system-ui;margin:0}main{max-width:760px;margin:44px auto;padding:24px}article{background:#1a2938;border:1px solid #425163;padding:22px;border-radius:12px;margin:20px 0}h2{color:#ffd667}audio{width:100%}small{color:#b4bfcc}</style>
<main><h1>Compact engine audition</h1><p>Matched recordings from the actual Godot engine bus. Idle 0–2s; acceleration and shifts 2–8s; cruise 8–12s; lift-off 12–16s; stationary rev 16–18s; pause 18–19s.</p>'''+cards+'''<small>Engine recordings: Nox Sound Design, Essentials Series, CC0. Transposed, filtered, loop-crossfaded and mastered for a fictional compact car. These engine-only previews contain no tires, weather, impacts or music. Phone listening remains untested.</small></main>
<script>document.querySelectorAll('audio').forEach(p=>p.addEventListener('play',()=>document.querySelectorAll('audio').forEach(q=>{if(q!==p)q.pause()})))</script></html>'''
(OUT / "audition.html").write_text(page, encoding="utf-8")
print(json.dumps({"changed_clips": len(changed), "unchanged_clips": len(current)-len(changed), "captures": [{"variant": c["variant"], "peak_dbfs": c["peak_dbfs"], "paused_tail_peak": c["paused_tail_peak"]} for c in captures]}, indent=2))
