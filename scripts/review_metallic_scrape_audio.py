"""Compare the metallic scrape derivative and its native vehicle mix."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/metallic-scrape-2026-10-10"


def measure(path):
    with wave.open(str(path)) as handle:
        rate = handle.getframerate()
        channels = handle.getnchannels()
        values = np.frombuffer(handle.readframes(handle.getnframes()),dtype="<i2").astype(float)/32768.0
    values = values.reshape(-1,channels)
    segment = values[round(.35*rate):round(2.35*rate)]
    rms = float(np.sqrt(np.mean(segment**2)))
    mono = segment.mean(axis=1)
    power = abs(np.fft.rfft(mono*np.hanning(len(mono))))**2
    hz = np.fft.rfftfreq(len(mono),1/rate)
    bands = {label:float(power[(hz>=low)&(hz<high)].sum()/max(power.sum(),1e-20))
             for label,low,high in [("body",150,900),("metal_mid",900,3500),("abrasion",3500,9000)]}
    return {"rms":rms,"peak":float(np.max(abs(values))),"tail_peak":float(np.max(abs(values[-round(.2*rate):]))),
            "seconds":len(values)/rate,"spectral_bands":bands}


rows = []
for speed in [4,12,24]:
    row = {"speed_mps":speed}
    row["mix"] = measure(OUT / f"after-{speed}-mix.wav")
    row["engine"] = measure(OUT / f"after-{speed}-engine.wav")
    row["scrape"] = measure(OUT / f"after-{speed}-scrape.wav")
    row["scrape_vs_engine_db"] = float(20*np.log10(row["scrape"]["rms"]/row["engine"]["rms"]))
    assert -8<row["scrape_vs_engine_db"]<8
    assert row["mix"]["peak"]<.94
    assert all(row[name]["tail_peak"]==0 for name in ["mix","engine","scrape"])
    rows.append(row)
before = json.loads((OUT / "before-hashes.json").read_text(encoding="utf-8-sig"))
changed = [Path(item["Path"]).name for item in before
           if hashlib.sha256(Path(item["Path"]).read_bytes()).hexdigest().upper()!=item["Hash"]]
assert changed==["scrape.wav"], changed
old = measure(OUT / "before-12-scrape.wav")
assert abs(20*np.log10(rows[1]["scrape"]["rms"]/old["rms"]))<.5, "timbre edit should retain comparable level"
report = {"captures":rows,"before_scrape":old,"changed_wavs":changed,"unchanged_wavs":len(before)-1}
(OUT / "native-mix-review.json").write_text(json.dumps(report,indent=2)+"\n")
print("METALLIC_SCRAPE:",[(row["speed_mps"],round(row["scrape_vs_engine_db"],3)) for row in rows],
      "dB vs engine;",len(before)-1,"WAVs exact; mix/tail/level checks pass")
