"""Check repeated source pitch patterns as well as amplitude and native layer blends."""
from pathlib import Path
import hashlib
import json
import math
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/compact-period-2026-10-10"
BANK = ROOT / "game/assets/audio/vehicles"


def read(path):
    with wave.open(str(path)) as handle:
        rate, channels = handle.getframerate(), handle.getnchannels()
        x = np.frombuffer(handle.readframes(handle.getnframes()), "<i2").astype(float) / 32768
    return x.reshape(-1, channels), rate


def rate_range(x, rate, target):
    frequencies = np.fft.fftfreq(len(x), 1 / rate)
    band = (frequencies > target * .9) & (frequencies < target * 1.1)
    analytic = np.fft.ifft(np.where(band, np.fft.fft(x) * 2, 0))
    phase = np.unwrap(np.angle(analytic))
    instantaneous = np.gradient(phase) * rate / (2 * np.pi)
    window = round(.02 * rate)
    cumulative = np.r_[0, np.cumsum(instantaneous)]
    smoothed = (cumulative[window:] - cumulative[:-window]) / window
    central = smoothed[round(.15 * rate):-round(.15 * rate)]
    low, high = np.percentile(central, [5, 95])
    return {"median_hz": float(np.median(central)), "p5_hz": float(low), "p95_hz": float(high), "span_hz": float(high-low)}


before = json.loads((OUT / "before-bank-hashes.json").read_text())
current = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in BANK.glob("*.wav")}
assert set(before) == set(current)
changed = sorted(name for name in current if current[name] != before[name])
expected = [f"compact_{index}_{mode}.wav" for index in (1, 2) for mode in ("coast", "load")]
assert changed == expected, changed
assets = []
for name in expected:
    target = 100 if name.startswith("compact_1") else 200
    versions = []
    for folder in (OUT / "before/game/assets/audio/vehicles", BANK):
        x, rate = read(folder / name)
        assert np.max(abs(x)) < .841
        versions.append({"seconds": len(x)/rate, **rate_range(x[:, 0], rate, target)})
    assert versions[0]["span_hz"] > 1.0, (name, "repeated source pitch pattern missing")
    assert versions[1]["seconds"] == 8.0
    assert abs(versions[1]["median_hz"]-target) < .01
    assert versions[1]["span_hz"] < .05, (name, "source pitch pattern remains")
    assets.append({"file": name, "before": versions[0], "after": versions[1]})

status = json.loads((OUT / "native-capture.json").read_text())
assert status["failures"] == 0 and len(status["reports"]) == 4
captures = []
for item in status["reports"]:
    path = OUT / f'{item["variant"]}-{item["fixture"]}.wav'
    x, rate = read(path)
    assert len(x)/rate > 25.5 and .02 < np.max(abs(x)) < .9
    assert np.max(abs(x[-rate//2:])) == 0
    assert min(item["wraps"]) >= 2
    region = x[round(.5*rate):round(24.5*rate)].mean(axis=1)
    blocks = np.array_split(region, len(region)//round(.02*rate))
    rms = np.array([np.sqrt(np.mean(block**2)) for block in blocks])
    assert min(rms) > max(.0003, np.median(rms)*.04), path.name
    target = 200 if item["fixture"] == "high" else 150
    frequencies = rate_range(region, rate, target)
    if item["variant"] == "after":
        assert abs(frequencies["median_hz"]-target) < .05
        assert frequencies["span_hz"] < .2, (path.name, frequencies)
    captures.append({**item, "peak_dbfs": float(20*math.log10(np.max(abs(x)))), "paused_tail_peak": 0, **frequencies})

report = {"changed_clips": changed, "unchanged_clips": len(current)-len(changed), "assets": assets, "native_captures": captures,
          "owner_acceptance": "1.5-second source pattern removed from the local bank; exact reported artefact/platform and listening remain unconfirmed."}
(OUT / "review.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
cards = []
for fixture, label in (("high", "High revs with load/coast blend"), ("overlap", "Mid/high layers at 4500 RPM")):
    cards.append(f'<article><h2>{label}</h2><p>Before</p><audio controls preload="metadata" src="before-{fixture}.wav"></audio><p>After</p><audio controls preload="metadata" src="after-{fixture}.wav"></audio></article>')
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Compact sustain review</title>
<style>body{margin:0;background:#101b27;color:#eee5d6;font:17px/1.5 system-ui}main{max-width:760px;margin:40px auto;padding:24px}article{padding:20px;background:#1b2937;border:1px solid #425163;border-radius:12px;margin:20px 0}h2{color:#ffd667}audio{width:100%}small{color:#b4bfcc}</style>
<main><h1>Compact sustain review</h1><p>Matched native mixer captures at fixed RPM and 65% load. Each plays for 25 seconds across several wraps, then pauses. No gear changes, tires or weather.</p>'''+"".join(cards)+'''<small>Nox Sound Design CC0 recorded engine cycles, averaged and sustained offline; original restrained shaped-noise texture added. This is an authored fictional engine voice, not an unmodified field recording. Phone listening remains untested.</small></main>
<script>document.querySelectorAll('audio').forEach(p=>p.addEventListener('play',()=>document.querySelectorAll('audio').forEach(q=>{if(p!==q)q.pause()})))</script></html>'''
(OUT / "audition.html").write_text(page, encoding="utf-8")
print(json.dumps(report, indent=2))
