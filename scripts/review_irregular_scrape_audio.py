"""Check lower scrape spectrum, retained uneven strokes and the native vehicle mix."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/irregular-low-scrape-2026-10-10"


def measure(path):
    with wave.open(str(path)) as source:
        rate = source.getframerate()
        channels = source.getnchannels()
        values = np.frombuffer(source.readframes(source.getnframes()),dtype="<i2").astype(float)/32768.0
    values = values.reshape(-1,channels)
    mono = values.mean(axis=1)
    power = abs(np.fft.rfft(mono*np.hanning(len(mono))))**2
    hz = np.fft.rfftfreq(len(mono),1/rate)
    hop = round(.1*rate)
    envelope = np.array([np.sqrt(np.mean(mono[i:i+hop]**2)) for i in range(0,len(mono)-hop,hop)])
    return {"rms":float(np.sqrt(np.mean(values**2))),"seconds":len(values)/rate,
            "peak":float(np.max(abs(values))),"tail_peak":float(np.max(abs(values[-round(.2*rate):]))),
            "centroid_hz":float((power*hz).sum()/power.sum()),"energy_below_900":float(power[hz<900].sum()/power.sum()),
            "envelope_cv":float(envelope.std()/envelope.mean())}


old = measure(OUT / "before/game__assets__audio__vehicles__scrape.wav")
new = measure(ROOT / "game/assets/audio/vehicles/scrape.wav")
assert new["centroid_hz"]<old["centroid_hz"]*.5
assert new["energy_below_900"]>.75
assert new["envelope_cv"]>old["envelope_cv"]*4
assert new["peak"]<.85
rows = []
for speed in [4,12,24]:
    stats = {name:measure(OUT / f"after-{speed}-{name}.wav") for name in ["mix","engine","scrape"]}
    ratio = 20*np.log10(stats["scrape"]["rms"]/stats["engine"]["rms"])
    assert -10<ratio<8
    assert stats["mix"]["peak"]<.94
    assert all(row["tail_peak"]==0 for row in stats.values())
    rows.append({"speed_mps":speed,"scrape_vs_engine_db":float(ratio),**stats})
before = json.loads((OUT / "before-hashes.json").read_text(encoding="utf-8-sig"))
changed = [Path(row["Path"]).name for row in before
           if hashlib.sha256(Path(row["Path"]).read_bytes()).hexdigest().upper()!=row["Hash"]]
assert changed==["scrape.wav"]
report = {"before":old,"after":new,"native_mix":rows,"changed_wavs":changed,"unchanged_wavs":len(before)-1}
(OUT / "audio-review.json").write_text(json.dumps(report,indent=2)+"\n")
print("IRREGULAR_SCRAPE:",round(old["centroid_hz"]),"to",round(new["centroid_hz"]),"Hz centroid;",
      round(old["envelope_cv"],3),"to",round(new["envelope_cv"],3),"envelope CV;",
      [(row["speed_mps"],round(row["scrape_vs_engine_db"],2)) for row in rows],"dB vs engine;",len(before)-1,"WAVs exact")
