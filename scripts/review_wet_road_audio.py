"""Review actual native wet rolling PCM, silence and unchanged existing masters."""
from pathlib import Path
import hashlib
import json
import math
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/wet-road-audio-2026-10-09"
BANK = ROOT / "game/assets/audio/vehicles"
report = {"captures": [], "preserved_masters": [], "failures": []}
previous = json.loads((ROOT / "docs/evidence/collision-attack-2026-10-08/before/game/assets/audio/vehicles/manifest.json").read_text())
expected = {row["file"]: row["sha256"] for row in previous["outputs"]}
# Those three impacts changed in the already-completed attack correction.
onsets = json.loads((ROOT / "docs/evidence/collision-onset-audit-2026-10-09/source-onsets.json").read_text())
expected.update({row["file"]: row["sha256"] for row in onsets["rows"]})
for name, digest in expected.items():
    actual = hashlib.sha256((BANK / name).read_bytes()).hexdigest()
    report["preserved_masters"].append({"file": name, "sha256": actual, "matches": actual == digest})
    if actual != digest:
        report["failures"].append("Existing master changed: " + name)
for name in ["slow", "medium", "fast", "stopped", "airborne", "paused"]:
    with wave.open(str(OUT / (name + ".wav"))) as handle:
        rate = handle.getframerate()
        channels = handle.getnchannels()
        pcm = np.frombuffer(handle.readframes(handle.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
    # Avoid only the record start/stop boundaries, not any interior quiet periods.
    trimmed = pcm[round(rate * channels * .1):-round(rate * channels * .1)]
    rms = float(np.sqrt(np.mean(trimmed ** 2)))
    peak = float(np.max(np.abs(trimmed)))
    report["captures"].append({"scene": name, "rms": rms, "rms_dbfs": 20 * math.log10(max(rms, 1e-9)), "peak": peak})
    if name in ["stopped", "airborne", "paused"]:
        if peak != 0:
            report["failures"].append("Contact should be exactly silent: " + name)
    elif rms < .001 or peak >= .95:
        report["failures"].append("Moving rolling must be audible with headroom: " + name)
gains = [row["rms"] for row in report["captures"][:3]]
if not gains[0] < gains[1] < gains[2]:
    report["failures"].append("Native rolling RMS must increase with speed")
(OUT / "review.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
cards = "".join(f'<article><h2>{name.title()}</h2><audio controls preload="metadata" src="{name}.wav"></audio></article>' for name in ["slow", "medium", "fast", "stopped", "airborne", "paused"])
(OUT / "review.html").write_text('<!doctype html><meta charset="utf-8"><title>Wet asphalt rolling review</title><style>body{background:#111b2b;color:#eee;font:18px system-ui;max-width:900px;margin:40px auto}article{padding:16px;margin:12px 0;background:#1c2b40}h2{margin:0 0 10px}audio{width:100%}</style><h1>Wet asphalt rolling</h1><p>Isolated native road voice: 14.4, 57.6 and 144 km/h, followed by stopped, airborne and paused. Engine and other sounds are excluded from these listening samples.</p>' + cards, encoding="utf-8")
print(json.dumps({"native_levels": report["captures"], "preserved_masters": len(expected), "failures": report["failures"]}, indent=2))
raise SystemExit(bool(report["failures"]))
