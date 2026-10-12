"""Validate shipping loops/combinations and captured mixer output; create listening page.

Use the existing WSL audio environment via scripts/run_from_windows_repo.sh.
Technical measurements do not constitute listening or artistic acceptance.
"""
from pathlib import Path
import hashlib
import html
import itertools
import json
import math
import os
import shutil
import subprocess

import numpy as np
from scipy.signal import resample_poly
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "game/assets/audio/score_v1"
EVIDENCE = ROOT / "docs/evidence/adaptive-score-2026-10-07"
WORK = ROOT / "build/music/score-v1/verification"
FFMPEG = os.environ.get("BMT_SCORE_FFMPEG") or shutil.which("ffmpeg") or str(Path.home() / ".local/share/bmt-music-tools/ffmpeg")


def db(value):
    return 20 * math.log10(max(float(value), 1e-12))


def read(path):
    if path.suffix == ".ogg":
        decoded = WORK / (path.stem + ".wav")
        subprocess.run([FFMPEG, "-nostdin", "-y", "-hide_banner", "-loglevel", "error", "-i", str(path),
                        "-c:a", "pcm_f32le", str(decoded)], check=True)
        return sf.read(decoded, always_2d=True)
    return sf.read(path, always_2d=True)


def measure(pcm, rate):
    assert np.isfinite(pcm).all() and len(pcm) > 1000
    rms = np.sqrt(np.mean(pcm ** 2))
    mono = np.sqrt(np.mean(pcm.mean(axis=1) ** 2))
    # Use bandlimited oversampling to measure inter-sample peaks, not only digital clipping.
    true_peak = np.max(np.abs(resample_poly(pcm, 4, 1, axis=0)))
    return {"duration": len(pcm) / rate, "rate": rate, "frames": len(pcm), "channels": pcm.shape[1],
            "peak_dbfs": db(np.max(np.abs(pcm))), "rms_dbfs": db(rms), "true_peak_dbtp": db(true_peak),
            "clipped_samples": int(np.count_nonzero(np.abs(pcm) >= 0.999)), "mono_rms_ratio": float(mono / max(rms, 1e-12))}


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((BANK / "manifest.json").read_text())
    sources = json.loads((ROOT / "build/music/score-v1/sources/manifest.json").read_text())
    for source in sources["sources"]:
        path = ROOT / "build/music/score-v1/sources" / source["path"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == source["sha256"]
    decoded, assets = {}, []
    for asset in manifest["outputs"]:
        path = BANK / asset["file"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == asset["sha256"]
        pcm, rate = read(path)
        measurements = measure(pcm, rate)
        measurements["file"] = path.name
        if asset["loop"]:
            assert len(pcm) == asset["frames"] and rate == 44100 and pcm.shape[1] == 2
            delta = np.max(np.abs(pcm[0] - pcm[-1]))
            measurements["seam_delta"] = float(delta)
            assert delta < 0.008 and measurements["mono_rms_ratio"] > 0.85
            # The two repetitions use literal frame wrapping, preserving note and room tails.
            boundary = np.concatenate([pcm[-4410:], pcm[:4410]])
            assert np.max(np.abs(np.diff(boundary, axis=0))) < 0.12
            decoded[path.name] = pcm
        assert measurements["clipped_samples"] == 0 and measurements["true_peak_dbtp"] < -6
        assets.append(measurements)
    combinations = []
    for package in manifest["packages"]:
        layers = [decoded[name] for name in package["layers"]]
        for weights in itertools.product([0, 1], repeat=4):
            mix = layers[0] + sum(layer * weight for layer, weight in zip(layers[1:], weights))
            result = measure(mix, 44100)
            assert result["clipped_samples"] == 0 and result["true_peak_dbtp"] < -6
            assert result["mono_rms_ratio"] > 0.85
            result.update(family=package["id"], layers=[1, *weights])
            combinations.append(result)
    captures = []
    for path in sorted(EVIDENCE.glob("godot-*.wav")):
        pcm, rate = read(path)
        result = measure(pcm, rate)
        result["file"] = path.name
        assert result["clipped_samples"] == 0 and result["true_peak_dbtp"] < 0
        if "interface-music" not in path.name: assert result["rms_dbfs"] > -70, "Unexpectedly silent capture: " + path.name
        if "daybreak-car-recovery" in path.name:
            result["paused_tail_peak"] = float(np.max(np.abs(pcm[-round(rate * 0.4):])))
            assert result["paused_tail_peak"] == 0, "Actual paused output must be silent"
        captures.append(result)
    assert len(captures) == 8, "Run the full graphical soundtrack capture first"
    trace = json.loads((EVIDENCE / "runtime-trace.json").read_text())
    assert trace["failures"] == 0 and 59 <= trace["full_at_seconds"] < 63
    report = {"sources": len(sources["sources"]), "shipping_audio_bytes": sum(a["bytes"] for a in manifest["outputs"]),
              "assets": assets, "combinations": combinations, "captures": captures,
              "actual_full_at_seconds": trace["full_at_seconds"], "listening_performed": False, "artistic_approval": "pending"}
    (EVIDENCE / "audio-verification.json").write_text(json.dumps(report, indent=2) + "\n")
    review_page(trace, captures)
    print(f"SCORE_VERIFY: {len(assets)} assets, {len(combinations)} combinations, {len(captures)} actual captures; 0 clipped samples")
    print(f"Actual final layer reached at {trace['full_at_seconds']:.3f}s; shipping audio {report['shipping_audio_bytes']:,} bytes")


def review_page(trace, captures):
    cards = [
        ("Menu · Workshop", "menu-workshop-v2.wav", "Quiet piano, cello, harp and occasional wind answers. Original theme; source loop is 85.33 seconds.", "Source render"),
        ("Race A · Open Horizon", "horizon-clean-race-v2.wav", "Reflective minor theme, warm sustained voices, gradual motion and a string-led arrival at one minute. Used for Grass, Winter, Night and Storm.", "Offline clean-drive illustration · 90s"),
        ("Race B · First Light", "daybreak-clean-race-v2.wav", "A brighter modal answer with more harp movement and the same instrumental identity. Used for Desert.", "Offline clean-drive illustration · 90s"),
        ("Actual game audio · Clean development", "godot-horizon-clean.wav", f"Recorded from Godot with scripted clean-driving signals. Full layer reached at {trace['full_at_seconds']:.2f}s; includes a complete race-loop wrap.", "Actual master bus · 90s"),
        ("Actual game audio · Car and recovery", "godot-daybreak-car-recovery.wav", "Full desert variation with the real compact-car audio model. A scripted impact at 8s softens the arrangement; the paused tail is silent. Scripted mixer fixture, not a player replay.", "Actual master bus · 19s"),
        ("Actual game audio · Menu loop", "godot-menu-loop.wav", "One full menu wrap, including the circular room tail. Menus retain their musical position when pages change.", "Actual master bus · 88.5s"),
        ("Menu feedback", "godot-interface.wav", "Focus, select, confirm and back, in that order. Quiet wood/piano signatures. Steering controls do not make menu clicks.", "Actual master bus"),
    ]
    articles = []
    for title, file, description, kind in cards:
        markers = '<div class="markers"><button data-seek="0">Opening</button><button data-seek="24">Motion</button><button data-seek="40">Flight</button><button data-seek="60">Arrival</button></div>' if "clean" in file else ""
        articles.append(f'<article><small>{html.escape(kind)}</small><h2>{html.escape(title)}</h2><p>{html.escape(description)}</p>'
                        f'<audio controls preload="metadata" src="{html.escape(file)}"></audio>{markers}</article>')
    page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Beat my track · Soundtrack review</title><style>
*{box-sizing:border-box}body{margin:0;background:#0b141e;color:#edf0e9;font:17px/1.6 system-ui,sans-serif}
main{max-width:1000px;margin:50px auto;padding:0 24px}h1{font-size:42px;line-height:1.12;margin:12px 0 20px}h2{font-size:24px;line-height:1.3;margin:8px 0 12px}
.eyebrow,small{color:#ffd348;font-size:13px;letter-spacing:.08em}.intro{max-width:760px;color:#afbfcc}article{background:#12222e;border:1px solid #344e5d;border-radius:14px;padding:24px;margin:22px 0}p{color:#afbfcc}audio{width:100%;margin-top:12px}
button{background:#ffd348;border:0;border-radius:8px;color:#0b141e;font:600 14px system-ui;padding:10px 16px;cursor:pointer}.markers{display:flex;flex-wrap:wrap;gap:10px;margin-top:12px}.arc{display:grid;grid-template-columns:repeat(5,1fr);border:1px solid #344e5d;border-radius:12px;overflow:hidden;margin:24px 0}.arc span{padding:15px 12px;background:#172832;border-right:1px solid #344e5d;font-size:14px}.arc strong{display:block;color:#ffd348}a{color:#ffd348}footer{color:#9caebc;padding:20px 0 40px;font-size:14px}@media(max-width:600px){h1{font-size:32px}.arc{grid-template-columns:1fr}.arc span{border-right:0;border-bottom:1px solid #344e5d}}</style>
<main><div class="eyebrow">BEAT MY TRACK · ORIGINAL SCORE · MIX 2</div><h1>A theme that grows with your driving</h1>
<p class="intro">Menu music and two related race arrangements, performed with cleared recorded instruments. Begin with the menu, then compare the two 90-second race arcs. Listen at a comfortable level. Artistic approval remains pending; technical measurements are not listening evidence.</p>
<div class="arc"><span><strong>0s · Foundation</strong>Piano and cello identity</span><span><strong>12s · Current</strong>Harp answers</span><span><strong>24s · Motion</strong>Bowed pulse, soft drums</span><span><strong>40s · Flight</strong>Wind and horn colour</span><span><strong>60s · Arrival</strong>The full string theme</span></div>
''' + "\n".join(articles) + '''<footer>Source instruments: VSCO 2 Community Edition, CC0-1.0; recordings by Sam Gossner &amp; Simon Dalzell, sample cutting by Elan Hickler/Soundemote. <a href="https://github.com/sgossner/VSCO-2-CE">Source and licence</a>. Original notes/arrangements authored for this project. No reference-game audio used. Headphones, phone speakers, repetition fatigue and owner acceptance still need listening review.</footer></main>
<script>document.querySelectorAll('audio').forEach(a=>a.addEventListener('play',()=>document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()})));document.querySelectorAll('[data-seek]').forEach(b=>b.addEventListener('click',()=>{const a=b.closest('article').querySelector('audio');a.currentTime=Number(b.dataset.seek);a.play().catch(e=>{if(e.name!=='AbortError')throw e})}));</script></html>'''
    (EVIDENCE / "audition.html").write_text(page, encoding="utf-8")


if __name__ == "__main__": main()
