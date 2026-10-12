"""Verify owner-selected crash provenance, full attacks, scoped changes and PCM captures."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/owner-crash-2026-10-10"
BANK = ROOT / "game/assets/audio/vehicles"
SOURCE = ROOT / "build/vehicle_audio_sources"


def pcm(path):
    with wave.open(str(path)) as handle:
        rate = handle.getframerate()
        channels = handle.getnchannels()
        values = np.frombuffer(handle.readframes(handle.getnframes()),dtype="<i2").astype(float)/32768
    return values.reshape(-1,channels),rate


manifest = json.loads((BANK / "manifest.json").read_text())
record = next(item for item in manifest["sources"] if item["filename"]=="owner_crash_394903.wav")
assert hashlib.sha256((SOURCE / "owner_crash_394903.mp3").read_bytes()).hexdigest()==record["encoded_sha256"]
assert hashlib.sha256((SOURCE / "owner_crash_394903.wav").read_bytes()).hexdigest()==record["sha256"]
rows = []
for name in ["impact_0","impact_1","impact_2"]:
    path = BANK / (name+".wav")
    item = next(item for item in manifest["outputs"] if item["file"]==path.name)
    assert item["sources"]==["owner_crash_394903.wav"]
    values,rate = pcm(path)
    peak = float(np.max(abs(values)))
    assert abs(values[0,0])>=peak*.99 and peak<.85
    assert float(np.max(abs(values[-round(.01*rate):])))<.03
    assert hashlib.sha256(path.read_bytes()).hexdigest()==item["sha256"]
    rows.append({"file":path.name,"seconds":len(values)/rate,"peak":peak,"first_sample":float(values[0,0])})
before = json.loads((OUT / "before-hashes.json").read_text(encoding="utf-8-sig"))
changed = [Path(item["Path"]).name for item in before
           if hashlib.sha256(Path(item["Path"]).read_bytes()).hexdigest().upper()!=item["Hash"]]
assert sorted(changed)==["impact_0.wav","impact_1.wav","impact_2.wav"]
timing = json.loads((OUT / "capture-timing.json").read_text())
for row in timing:
    assert abs(row["route_delay_ms"])<3
    for label in ["raw","output"]:
        assert row[label+"_strong_ms"]-row[label+"_onset_ms"]<.5
        values,rate = pcm(OUT / f"impact-{row['trial']}-{label}.wav")
        if label=="output": assert float(np.max(abs(values)))<.89
        assert float(np.max(abs(values[-round(.12*rate):])))==0
report = {"original_filename":record["original_filename"],"original_sha256":record["encoded_sha256"],
          "outputs":rows,"native_trials":timing,"changed_wavs":changed,"unchanged_wavs":len(before)-3}
(OUT / "audio-review.json").write_text(json.dumps(report,indent=2)+"\n")
print("OWNER_CRASH_REVIEW:",len(rows),"immediate attacks;",len(timing),"native trials;",
      len(before)-3,"other WAVs exact; source/peak/tail checks pass")
