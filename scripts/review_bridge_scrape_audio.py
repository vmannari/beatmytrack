"""Measure bridge screech against the same-clock native engine and full mix."""
import hashlib
import json
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/bridge-screech-2026-10-10"


def measure(path):
    with wave.open(str(path)) as source:
        rate = source.getframerate()
        channels = source.getnchannels()
        pcm = np.frombuffer(source.readframes(source.getnframes()),dtype="<i2").astype(float)/32768.0
    pcm = pcm.reshape(-1,channels)
    segment = pcm[round(.35*rate):round(2.35*rate)]
    return {"rms":float(np.sqrt(np.mean(segment**2))),"peak":float(np.max(np.abs(pcm))),
            "tail_peak":float(np.max(np.abs(pcm[-round(.2*rate):]))),"seconds":len(pcm)/rate}


rows = []
for speed in [4,12,24]:
    row = {"speed_mps":speed}
    for version in ["before","after"]:
        stats = {name:measure(OUT / f"{version}-{speed}-{name}.wav") for name in ["mix","engine","scrape"]}
        row[version] = stats
        assert stats["mix"]["peak"] < .94, "mix clipping"
        assert all(item["tail_peak"]==0 for item in stats.values()), "paused tail is audible"
        if version=="before":
            assert stats["scrape"]["peak"]==0, "baseline must reproduce absent parallel friction"
        else:
            ratio = 20*np.log10(max(stats["scrape"]["rms"],1e-9)/stats["engine"]["rms"])
            row["scrape_vs_engine_db"] = float(ratio)
            assert -8 < ratio < 8, "screech should be audible against the normal engine"
    rows.append(row)
before = json.loads((OUT / "before-hashes.json").read_text(encoding="utf-8-sig"))
for item in before:
    file = ROOT / "game/assets/audio/vehicles" / Path(item["Path"]).name
    assert hashlib.sha256(file.read_bytes()).hexdigest().upper()==item["Hash"], "no WAV edit intended"
report = {"captures":rows,"unchanged_vehicle_wavs":len(before)}
(OUT / "native-mix-review.json").write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps(report,indent=2))
