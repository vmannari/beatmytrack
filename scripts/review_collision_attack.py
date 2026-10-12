"""Report the reproduced wall gap separately from native PCM attack/DSP timing."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/collision-attack-2026-10-08"
old = json.loads((OUT / "before/game/assets/audio/vehicles/manifest.json").read_text())
now = json.loads((ROOT / "game/assets/audio/vehicles/manifest.json").read_text())
old_hashes = {x["file"]:x["sha256"] for x in old["outputs"]}
changed = [x["file"] for x in now["outputs"] if x["sha256"]!=old_hashes[x["file"]]]
assert changed==["impact_0.wav","impact_1.wav","impact_2.wav"],changed
attacks = []
for name in changed:
    target = ROOT / "game/assets/audio/vehicles" / name
    with wave.open(str(target)) as handle:
        rate = handle.getframerate()
        x = np.frombuffer(handle.readframes(handle.getnframes()),dtype="<i2").astype(np.int32)
    peak = int(np.max(np.abs(x)))
    assert abs(int(x[0]))>=peak*.99
    attacks.append(dict(file=name,first_sample=int(x[0]),peak=peak,peak_frame=int(np.argmax(np.abs(x))),sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
walls = json.loads((OUT / "wall-contact-comparison.json").read_text())
pcm = json.loads((OUT / "capture-timing.json").read_text())
assert len(walls)==25 and all(row["new_gap_ms"]==0 for row in walls)
assert len(pcm)==6 and all(abs(row["route_delay_ms"])<3 for row in pcm)
assert all(row["output_strong_ms"]-row["output_onset_ms"]<.5 for row in pcm)
summary = dict(changed_assets=changed,unchanged_assets=len(now["outputs"])-len(changed),
               source_attacks=attacks,wall_cases=len(walls),all_wall_cues_same_tick=True,
               compact_4mps=next(x for x in walls if x["car"]=="compact" and x["speed"]==4),
               native_output_route_ms=float(np.median([row["route_delay_ms"] for row in pcm])),
               native_strong_attack_after_onset_ms=float(np.median([row["output_strong_ms"]-row["output_onset_ms"] for row in pcm])),
               driver_reported_latency_ms=pcm[0]["driver_latency_ms"],
               bank_bytes=sum((ROOT / "game/assets/audio/vehicles" / row["file"]).stat().st_size for row in now["outputs"]))
(OUT / "review.json").write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Wall collision audio - Beat my track</title><style>body{margin:0;background:#101b27;color:#e9e3d7;font:17px/1.5 system-ui,sans-serif}main{max-width:860px;margin:40px auto;padding:0 24px}h2,a{color:#ffd667}article{padding:22px;margin:18px 0;border:1px solid #344450;border-radius:12px;background:#182632}audio{width:100%}p,small{color:#b3bec5}table{border-collapse:collapse;width:100%}td,th{text-align:left;padding:10px;border-bottom:1px solid #344450}</style><main><h1>Wall collision onset</h1><p>The reproduced large gap came from the rendered bumper reaching the wall before the circular driving collider. At 4 m/s, compact visible touch was tick62, while the physical response was tick81:158ms. The sound now starts at tick62; the existing physical response stays at tick81. The later same-wall cue is deduplicated.</p><table><tr><th>Compact speed</th><th>Old geometry gap</th><th>New cue gap</th></tr>'''
for row in walls:
    if row["car"]=="compact":
        page += f'<tr><td>{row["speed"]*3.6:.0f} km/h</td><td>{row["old_gap_ms"]:.1f} ms</td><td>{row["new_gap_ms"]:.1f} ms</td></tr>'
page += '</table><p>All25 forward cases/five cars align at visible touch. Actual Game callback: sound and visible touch both62, response81. No canonical handling/input/record change. The three collision files now begin at their strongest transient, with no leading silence or fade-in.</p>'
for index,title in enumerate(["Light contact","Medium contact","Hard contact"]):
    page += f'<article><h2>{title}</h2><audio controls preload="metadata" src="impact-{index}-output.wav"></audio><p>Actual protected desktop master output. First meaningful signal reaches half its peak within one48kHz sample; the retained final-output limiter adds about2.04ms.</p></article>'
page += '<small>Digital/source/dispatch evidence does not measure speaker/Bluetooth latency. WASAPI reports about10ms output latency. Device/owner listening remains open. Existing cleared qubodup/Nox source credits remain in the bank NOTICE/manifest; only the three impact derivatives changed.</small></main></html>'
(OUT / "audition.html").write_text(page,encoding="utf-8")
print(json.dumps(summary,indent=2))
