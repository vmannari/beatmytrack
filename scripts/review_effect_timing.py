"""Pinned PCM event/asset timing comparison; no subjective or acoustic latency claim."""
from pathlib import Path
import json
import hashlib
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/effect-timing-2026-10-08"
clips = ["impact_0","impact_1","impact_2","chassis","grit_0","grit_1","grit_2"]

def attack(path):
    with wave.open(str(path)) as wav:
        rate = wav.getframerate()
        x = np.frombuffer(wav.readframes(wav.getnframes()),dtype="<i2").astype(np.float64)/32768.0
    peak = float(np.max(np.abs(x)))
    onset = float(np.flatnonzero(np.abs(x)>peak*.10)[0])/rate*1000.0
    return dict(file=path.name,peak_ms=float(np.argmax(np.abs(x)))/rate*1000.0,
                attack_10_percent_ms=onset,peak_dbfs=20*np.log10(peak),
                sha256=hashlib.sha256(path.read_bytes()).hexdigest())

bank = ROOT / "game/assets/audio/vehicles"
old_bank = OUT / "before/game/assets/audio/vehicles"
old_assets = [attack(old_bank / (clip+".wav")) for clip in clips]
new_assets = [attack(bank / (clip+".wav")) for clip in clips]
before = json.loads((OUT / "before-dispatch.json").read_text())
after = json.loads((OUT / "after-dispatch.json").read_text())
if len(before)!=5 or len(after)!=5 or any(row["raw_delay_ms"]<0 for row in before+after):
    raise ValueError("Five valid paired timing trials required")
if any(not row["direct_dispatch"] or abs(row["raw_delay_ms"])>1.0 for row in after):
    raise ValueError("Direct contacts must begin in the same mixed block as the reference")
if any(row["peak_ms"]>8.333 for row in new_assets):
    raise ValueError("Contact one-shots must put their main attack inside one physics tick")
old = json.loads((old_bank / "manifest.json").read_text())
now = json.loads((bank / "manifest.json").read_text())
old_hashes = {x["file"]:x["sha256"] for x in old["outputs"]}
changed = [x["file"] for x in now["outputs"] if old_hashes[x["file"]]!=x["sha256"]]
if changed!=["chassis.wav"]:
    raise ValueError("Timing revision must only reauthor the slow chassis source: "+str(changed))
summary = dict(before_raw_median_ms=float(np.median([x["raw_delay_ms"] for x in before])),
               after_raw_median_ms=float(np.median([x["raw_delay_ms"] for x in after])),
               before_min_max_ms=[min(x["raw_delay_ms"] for x in before),max(x["raw_delay_ms"] for x in before)],
               after_min_max_ms=[min(x["raw_delay_ms"] for x in after),max(x["raw_delay_ms"] for x in after)],
               controlled_presentation_stall_ms=30,driver_output_estimate_ms=after[0]["driver_output_ms"],
               same_buffer_after=all(x["direct_dispatch"] for x in after),changed_assets=changed,
               unchanged_assets=len(now["outputs"])-len(changed),
               chassis_peak_before_ms=next(x["peak_ms"] for x in old_assets if x["file"]=="chassis.wav"),
               chassis_peak_after_ms=next(x["peak_ms"] for x in new_assets if x["file"]=="chassis.wav"))
(OUT / "timing-report.json").write_text(json.dumps(dict(summary=summary,assets_before=old_assets,assets_after=new_assets,before=before,after=after),indent=2)+"\n",encoding="utf-8")
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Sound effect timing - Beat my track</title><style>body{margin:0;background:#101b27;color:#e9e3d7;font:17px/1.5 system-ui,sans-serif}main{max-width:800px;margin:40px auto;padding:0 24px}h2,a{color:#ffd667}article{padding:22px;margin:18px 0;border:1px solid #344450;border-radius:12px;background:#182632}audio{width:100%}p,small{color:#b3bec5}</style><main><h1>Sound effect timing</h1><p>Actual desktop PCM, with a quiet reference pulse marking collision observation. A controlled 30ms presentation workload exposes the old render-callback wait. This is digital event timing; it does not include the speaker or headphone path.</p>'''
for variant,label in [("before","Before: collision waits for presentation"),("after","After: collision starts at observation")]:
    page += f'<article><h2>{label}</h2><audio controls preload="metadata" src="{variant}-0-output.wav"></audio></article>'
page += f'<p>Median raw event/reference separation: {summary["before_raw_median_ms"]:.3f}ms before; {summary["after_raw_median_ms"]:.3f}ms after. WASAPI reports about {summary["driver_output_estimate_ms"]:.1f}ms output latency, outside these captures.</p>'
page += '<h2>Chassis attack</h2><p>Original landing/kerb/shift source, then its corrected front-loaded transient.</p><audio controls preload="metadata" src="before/game/assets/audio/vehicles/chassis.wav"></audio><audio controls preload="metadata" src="../../../game/assets/audio/vehicles/chassis.wav"></audio>'
# Evidence path is docs/evidence/<task>; reaching runtime assets needs three parent hops.
page += '<p>The three collision and three grit clip hashes remain unchanged. Existing dynamics and peak ceilings remain active. Original source credits: Nox Sound Design body movement (CC0); qubodup designed collision (CC0). Full provenance in the shipping bank NOTICE/manifest. Owner and physical-device listening remain open.</p></main></html>'
(OUT / "audition.html").write_text(page,encoding="utf-8")
print(json.dumps(summary,indent=2))
