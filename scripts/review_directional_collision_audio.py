"""Review the four native contact previews and the scoped collision bank edits."""
import hashlib
import json
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/directional-collision-audio-2026-10-10"
BANK = ROOT / "game/assets/audio/vehicles"
rows = []
for name in ["fence-scrape", "bridge-scrape", "oblique-impact", "head-on-crash"]:
    with wave.open(str(OUT / (name+".wav"))) as source:
        rate = source.getframerate()
        channels = source.getnchannels()
        assert source.getsampwidth() == 2
        pcm = np.frombuffer(source.readframes(source.getnframes()), dtype="<i2")
        pcm = pcm.astype(np.float64).reshape(-1, channels)/32768.0
    peak = float(np.max(np.abs(pcm)))
    tail = float(np.max(np.abs(pcm[-round(.2*rate):])))
    assert .03 < peak < .92, name+": inaudible or clipped"
    assert tail == 0, name+": paused tail is audible"
    rows.append(dict(file=name+".wav", seconds=len(pcm)/rate, peak=peak,
                     rms=float(np.sqrt(np.mean(pcm**2))), tail_peak=tail))
before = json.loads((OUT / "before-hashes.json").read_text(encoding="utf-8-sig"))
changed = []
for item in before:
    name = Path(item["Path"]).name
    if hashlib.sha256((BANK / name).read_bytes()).hexdigest().upper() != item["Hash"]:
        changed.append(name)
assert sorted(changed) == ["impact_0.wav", "impact_1.wav", "impact_2.wav"]
manifest = json.loads((BANK / "manifest.json").read_text())
for item in manifest["outputs"]:
    assert hashlib.sha256((BANK / item["file"]).read_bytes()).hexdigest() == item["sha256"]
scrape = next(item for item in manifest["outputs"] if item["file"] == "scrape.wav")
assert scrape["loop"] and scrape["continuous_texture"] and len(scrape["sources"]) == 3
report = {"captures": rows, "changed_existing_wavs": changed,
          "unchanged_existing_wavs": len(before)-len(changed), "new_wavs": ["scrape.wav"]}
(OUT / "native-pcm-review.json").write_text(json.dumps(report, indent=2)+"\n")
print(json.dumps(report, indent=2))
