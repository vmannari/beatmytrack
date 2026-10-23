"""Review own-process contact timing and compare the revised snow audition."""
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import shutil
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/snow-audio-response-2026-10-22"


def pcm(path):
    with wave.open(str(path), "rb") as stream:
        return np.frombuffer(stream.readframes(stream.getnframes()), "<i2").astype(float).reshape(-1, stream.getnchannels()) / 32768, stream.getframerate()


def main():
    groups = {}
    for phase in ["before", "after"]:
        source = ROOT / "build/snow-audio-response-2026-10-22" / phase
        dest = OUT / phase
        dest.mkdir(exist_ok=True)
        for name in ["ready.json", "events.json", "timing-report.json", "packets.csv", "loopback.pcm", "capture-meta.txt", "engine.log", "engine-error.log"]:
            shutil.copyfile(source / name, dest / name)
        events = json.loads((source / "events.json").read_text())
        timings = json.loads((source / "timing-report.json").read_text())
        by_clip = defaultdict(list)
        for event, timing in zip(events, timings["rows"]):
            if event["trial"] != timing["trial"]: raise ValueError("Mismatched trial identities")
            by_clip[event["clip"]].append({"milliseconds": timing["latency_ms"], "route": event["route"]})
        groups[phase] = {clip: {"median_ms": float(np.median([item["milliseconds"] for item in rows])),
                                "minimum_ms": min(item["milliseconds"] for item in rows),
                                "maximum_ms": max(item["milliseconds"] for item in rows), "trials": rows}
                         for clip, rows in by_clip.items()}
    before = OUT / "before/game/assets/audio/vehicles/snow_hit.wav"
    after = ROOT / "game/assets/audio/vehicles/snow_hit.wav"
    attacks = {}
    for phase, path in [("before", before), ("after", after)]:
        values, rate = pcm(path)
        envelope = abs(values).max(axis=1)
        attacks[phase] = {"strong_onset_ms": float(np.flatnonzero(envelope >= envelope.max() * .5)[0] / rate * 1000),
                          "peak_ms": float(envelope.argmax() / rate * 1000), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    values, rate = pcm(OUT / "audition/driving.wav")
    unwanted, _ = pcm(OUT / "audition/unwanted.wav")
    snow, snow_rate = pcm(OUT / "audition/snow.wav")
    checks = {
        "all_five_cues_captured_three_times": all(len(rows["trials"]) == 3 for phase in groups.values() for rows in phase.values()),
        "snow_used_delayed_path_before": all(row["route"] == "godot" for row in groups["before"]["snow_hit"]["trials"]),
        "snow_uses_fast_path_after": all(row["route"] == "windows_raw" for row in groups["after"]["snow_hit"]["trials"]),
        "snow_output_median_below_75ms": groups["after"]["snow_hit"]["median_ms"] < 75,
        "snow_output_improved_over_60ms": groups["before"]["snow_hit"]["median_ms"] - groups["after"]["snow_hit"]["median_ms"] > 60,
        "other_contacts_stay_prompt": all(row["maximum_ms"] < 80 for name, row in groups["after"].items() if name != "snow_hit"),
        "snow_strong_attack_within_5ms": attacks["after"]["strong_onset_ms"] <= 5,
        "audition_has_headroom": float(abs(values).max()) < .95,
        "wrong_surface_channels_silent": float(abs(unwanted).max()) == 0,
        "snow_pause_silent": float(abs(snow[int(13.3 * snow_rate):int(13.8 * snow_rate)]).max()) == 0,
    }
    report = {"groups": groups, "sample_attack": attacks, "checks": checks,
              "limits": "Own-process Windows loopback before physical speaker/headphone/Bluetooth hardware. Audition records fallback buses to compare tone; separate output captures verify the native route."}
    (OUT / "timing-comparison.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    shutil.copyfile(ROOT / "docs/evidence/snowbank-audio-2026-10-22/driving.wav", OUT / "before-driving.wav")
    shutil.copyfile(ROOT / "docs/evidence/snowbank-audio-2026-10-22/snow.wav", OUT / "before-snow.wav")
    rows = "".join(f'<tr><td>{clip}</td><td>{groups["before"][clip]["median_ms"]:.1f} ms</td><td>{groups["after"][clip]["median_ms"]:.1f} ms</td></tr>' for clip in groups["before"])
    html = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Snow contact revision</title>
<style>body{background:#152132;color:#edf0f5;font:17px/1.5 system-ui;margin:0}main{max-width:800px;margin:40px auto;padding:24px}article{background:#22354a;border-radius:12px;padding:18px;margin:20px 0}h1,h2{color:#ffe09a}audio{width:100%}td,th{padding:8px 15px;border-bottom:1px solid #465b70}small{color:#b9c8da}</style>
<main><h1>Snow contact revision</h1><p>Revised muffled compression and smoother snow scraping. The main attack now starts at contact; side-panel contact follows the visible snow spray.</p>
<article><h2>Previous game mix</h2><audio controls preload="metadata" src="before-driving.wav"></audio></article>
<article><h2>Revised game mix</h2><audio controls preload="metadata" src="audition/driving.wav"></audio></article>
<article><h2>Previous snow alone</h2><audio controls preload="metadata" src="before-snow.wav"></audio></article>
<article><h2>Revised snow alone</h2><audio controls preload="metadata" src="audition/snow.wav"></audio></article>
<h2>Measured Windows output</h2><p>Three matching process-loopback trials per cue, shown as medians. These measure the output path, before speaker/headphone hardware. The tone auditions above record Godot buses separately.</p><table><tr><th>Cue</th><th>Before</th><th>After</th></tr>'''+rows+'''</table>
<p>A complete client restart loads the updated native Windows adapter. Preferred tone/volume and physical-device listening still need owner review.</p>
<small>Original snow recordings: Nox Sound Design Essentials Series, CC0. Only the snow derivatives changed; crash/body source recordings remain exact.</small></main>
<script>document.querySelectorAll('audio').forEach(p=>p.addEventListener('play',()=>document.querySelectorAll('audio').forEach(q=>{if(q!==p)q.pause()})))</script></html>'''
    (OUT / "review.html").write_text(html, encoding="utf-8")
    print(json.dumps({phase: {clip: row["median_ms"] for clip, row in clips.items()} for phase, clips in groups.items()}, indent=2))
    print("SNOW_RESPONSE_CAPTURE:", sum(checks.values()), "checks,", sum(not value for value in checks.values()), "failures")
    if not all(checks.values()): raise SystemExit(1)


if __name__ == "__main__": main()
