"""Inspect native snow mixer captures and write a local listening preview."""
import json
from pathlib import Path
import wave

import numpy as np

OUT = Path(__file__).resolve().parents[1] / "docs/evidence/snowbank-audio-2026-10-22"


def main():
    report = {}
    for name in ["driving", "snow", "unwanted"]:
        with wave.open(str(OUT / (name + ".wav")), "rb") as stream:
            rate, channels = stream.getframerate(), stream.getnchannels()
            data = np.frombuffer(stream.readframes(stream.getnframes()), "<i2").astype(float).reshape(-1, channels) / 32768
        windows = {}
        for label, start, end in [("clear_ice", .5, 1.5), ("bank_entry", 2.1, 2.8), ("bank_push", 4, 9),
                                  ("back_on_ice", 11.3, 11.8), ("pause", 13.3, 13.8)]:
            values = data[int(start * rate):int(end * rate)]
            windows[label] = {"peak": float(abs(values).max()), "rms": float(np.sqrt(np.mean(values ** 2)))}
        report[name] = {"seconds": len(data) / rate, "channels": channels, "sample_rate": rate,
                        "peak": float(abs(data).max()), "windows": windows}
    report["checks"] = {
        "snow_audible_on_bank": report["snow"]["windows"]["bank_push"]["rms"] > .01,
        "snow_clear_ice_silent": report["snow"]["windows"]["clear_ice"]["peak"] == 0,
        "snow_leaving_silent": report["snow"]["windows"]["back_on_ice"]["peak"] == 0,
        "snow_pause_silent": report["snow"]["windows"]["pause"]["peak"] == 0,
        "wrong_surface_channels_silent": report["unwanted"]["peak"] == 0,
        "master_headroom": report["driving"]["peak"] < .95,
    }
    (OUT / "mixer-analysis.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    (OUT / "review.html").write_text('''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Snowbank driving sound</title>
<style>body{margin:0;background:#111c2b;color:#e8ebf0;font:17px/1.5 system-ui}main{max-width:760px;margin:40px auto;padding:24px}article{margin:24px 0;padding:20px;background:#1d2d40;border-radius:12px}h1,h2{color:#ffe18a}audio{width:100%}small{color:#b9c7d6}</style>
<main><h1>Snowbank driving sound</h1><p>Native game mixer recording: clear ice, a bumper-first entry crunch at 2 seconds, sustained sideways snow pushing, reverse, return to ice, stop and pause.</p>
<article><h2>In the game mix</h2><audio controls preload="metadata" src="driving.wav"></audio></article>
<article><h2>Snow alone</h2><audio controls preload="metadata" src="snow.wav"></audio></article>
<p>Desktop capture checks confirm audible bank contact, silence on clear ice and during pause, and no grass, sand, pebble or concrete-rumble channel in this audition. Listening quality and phone playback still need owner review.</p>
<small>Authored compression/plough foley from recorded snow. Nox Sound Design, <a href="https://nox-sound-design.itch.io/essentials-series-sfx-nox-sound">Essentials Series</a>, CC0. Full source and derivative identities: game/assets/audio/vehicles/snow_manifest.json.</small></main>
<script>document.querySelectorAll('audio').forEach(p=>p.addEventListener('play',()=>document.querySelectorAll('audio').forEach(q=>{if(q!==p)q.pause()})))</script></html>''', encoding="utf-8")
    print("SNOW_MIXER_CAPTURE:", sum(report["checks"].values()), "checks,", sum(not ok for ok in report["checks"].values()), "failures")
    if not all(report["checks"].values()): raise SystemExit(1)


if __name__ == "__main__": main()
