"""Measure compact loop modulation and review isolated native engine/wind/road captures."""
from pathlib import Path
import hashlib
import json
import math
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/compact-loop-2026-10-10"
BANK = ROOT / "game/assets/audio/vehicles"


def read(path):
    with wave.open(str(path)) as handle:
        rate, channels = handle.getframerate(), handle.getnchannels()
        x = np.frombuffer(handle.readframes(handle.getnframes()), "<i2").astype(float) / 32768
    return x.reshape(-1, channels), rate


def envelope(x, rate):
    blocks = np.array_split(x, max(1, len(x) // round(.04 * rate)))
    power = np.array([np.sqrt(np.mean(block**2)) for block in blocks])
    return {"minimum_relative_db": float(20 * np.log10(min(power) / np.median(power))),
            "maximum_relative_db": float(20 * np.log10(max(power) / np.median(power)))}


before = json.loads((OUT / "before-bank-hashes.json").read_text())
current = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in BANK.glob("*.wav")}
assert set(before) == set(current)
changed = sorted(name for name in current if current[name] != before[name])
assert len(changed) == 6 and all(name.startswith("compact_") for name in changed), changed
assets = []
for name in changed:
    versions = []
    for folder in (OUT / "before/game/assets/audio/vehicles", BANK):
        x, rate = read(folder / name)
        assert max(abs(x[:, 0])) < .841
        versions.append({"seconds": len(x) / rate, **envelope(x, rate)})
    # Low RPM contains natural engine pulses; the old moving-speed crossfade
    # dips are specifically measured rather than relying on a dropout threshold.
    if not name.startswith("compact_0"):
        assert versions[0]["minimum_relative_db"] < -1.5, (name, "baseline defect missing")
        assert versions[1]["minimum_relative_db"] > -1.1, (name, "periodic level dip remains")
        assert versions[1]["seconds"] > versions[0]["seconds"] * 1.9
    assets.append({"file": name, "before": versions[0], "after": versions[1]})

captures = []
for variant in ("before", "after"):
    status = json.loads((OUT / f"{variant}-capture.json").read_text())
    assert status["failures"] == 0
    for item in status["reports"]:
        x, rate = read(OUT / f'{variant}-{item["clip"]}.wav')
        assert len(x) / rate > 8.5 and .01 < np.max(abs(x)) < .9
        assert np.max(abs(x[-rate // 2:])) == 0
        region = x[round(.4 * rate):round(7.6 * rate)]
        blocks = np.array_split(region, max(1, len(region) // round(.02 * rate)))
        levels = np.array([np.sqrt(np.mean(block**2)) for block in blocks])
        assert min(levels) > max(.0003, np.median(levels) * .04)
        assert item["wraps"] >= 2
        captures.append({"variant": variant, "clip": item["clip"], "wraps": item["wraps"],
                         "peak_dbfs": float(20 * math.log10(np.max(abs(x)))), "paused_tail_peak": 0})

report = {"changed_clips": changed, "unchanged_clips": len(current) - len(changed), "assets": assets, "captures": captures,
          "limitation": "Engine loop defects reduced; owner's roughly fixed-rhythm symptom is not conclusively identified. Wind/road references are unchanged."}
(OUT / "review.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
cards = []
for clip, label in (("compact_0_load", "Low revs"), ("compact_1_load", "Mid revs"), ("compact_2_load", "High revs")):
    cards.append(f'<article><h2>{label}</h2><p>Before</p><audio controls src="before-{clip}.wav"></audio><p>After</p><audio controls src="after-{clip}.wav"></audio></article>')
for clip, label in (("wind", "Wind reference"), ("road", "Rolling reference")):
    cards.append(f'<article><h2>{label}</h2><audio controls src="before-{clip}.wav"></audio><p>Unchanged; isolated here to help identify a similar artefact.</p></article>')
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Compact loop review</title>
<style>body{margin:0;background:#101b27;color:#eee5d6;font:17px/1.5 system-ui}main{max-width:760px;margin:40px auto;padding:24px}article{padding:20px;background:#1b2937;border:1px solid #425163;border-radius:12px;margin:20px 0}h2{color:#ffd667}audio{width:100%}small{color:#b4bfcc}</style>
<main><h1>Steady loop review</h1><p>Native Godot captures with fixed pitch and volume, no shifts or collisions. Each sample plays for eight seconds, then pauses.</p>'''+"".join(cards)+'''<small>Recorded engine/rolling source: Nox Sound Design, Essentials Series, CC0; filtered, transposed, looped and mastered. Wind is original noise design. Diagnostic level is raised for isolated comparison; ordinary mix gains are unchanged. Phone listening remains untested.</small></main>
<script>document.querySelectorAll('audio').forEach(p=>p.addEventListener('play',()=>document.querySelectorAll('audio').forEach(q=>{if(p!==q)q.pause()})))</script></html>'''
(OUT / "audition.html").write_text(page, encoding="utf-8")
print(json.dumps({"unchanged_clips": len(current)-len(changed), "assets": assets, "native_captures": len(captures)}, indent=2))
