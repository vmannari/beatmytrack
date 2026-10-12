"""Verify the owner's selected source, retained pitch and native rail-scrape mix."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/pol-rail-scrape-2026-10-11"
SOURCE = ROOT / "build/vehicle_audio_sources"


def read(path):
    with wave.open(str(path)) as source:
        rate = source.getframerate()
        channels = source.getnchannels()
        values = np.frombuffer(source.readframes(source.getnframes()),dtype="<i2").astype(float)/32768
    return values.reshape(-1,channels),rate


manifest = json.loads((ROOT / "game/assets/audio/vehicles/manifest.json").read_text())
clip = next(row for row in manifest["outputs"] if row["file"]=="scrape.wav")
assert clip["sources"]==["rail_scrape_pol_cc0.wav"]
record = next(row for row in manifest["sources"] if row["filename"]==clip["sources"][0])
assert record["author"]=="Pól" and record["source"]=="https://freesound.org/people/P%C3%B3l/sounds/385939/"
assert record["license"]=="CC0-1.0"
assert hashlib.sha256((SOURCE / "rail_scrape_pol_cc0.mp3").read_bytes()).hexdigest()==record["encoded_sha256"]
assert hashlib.sha256((SOURCE / "rail_scrape_pol_cc0.wav").read_bytes()).hexdigest()==record["sha256"]
values,rate = read(ROOT / "game/assets/audio/vehicles/scrape.wav")
original = np.frombuffer((SOURCE / "rail_scrape_pol_cc0.f32").read_bytes(),dtype="<f4").astype(float)
# The loop's unjoined first second corresponds to 0.85s into the source:
# 0.35s trim + 0.5s join head. Correlation checks the actual selected recording
# and unchanged pitch, independently of the bank's advertised provenance.
expected = original[round(.85*rate):round(1.85*rate)]
correlation = float(np.corrcoef(values[:rate,0],expected)[0,1])
assert correlation>.9999, "wrong source or unexpected pitch/timbre change"
assert float(np.max(abs(values)))<.85
rows = []
for speed in [4,12,24]:
    stats = {}
    for name in ["mix","engine","scrape"]:
        captured,capture_rate = read(OUT / f"after-{speed}-{name}.wav")
        segment = captured[round(.35*capture_rate):round(2.35*capture_rate)]
        stats[name] = {"rms":float(np.sqrt(np.mean(segment**2))),"peak":float(np.max(abs(captured))),
                       "tail_peak":float(np.max(abs(captured[-round(.2*capture_rate):])))}
    ratio = 20*np.log10(stats["scrape"]["rms"]/stats["engine"]["rms"])
    assert -10<ratio<8 and stats["mix"]["peak"]<.94
    assert all(row["tail_peak"]==0 for row in stats.values())
    rows.append({"speed_mps":speed,"scrape_vs_engine_db":float(ratio),**stats})
before = json.loads((OUT / "before-hashes.json").read_text(encoding="utf-8-sig"))
changed = [Path(row["Path"]).name for row in before
           if hashlib.sha256(Path(row["Path"]).read_bytes()).hexdigest().upper()!=row["Hash"]]
assert changed==["scrape.wav"]
report = {"source":record,"interior_source_correlation":correlation,"loop_seconds":len(values)/rate,
          "native_mix":rows,"changed_wavs":changed,"unchanged_wavs":len(before)-1}
(OUT / "audio-review.json").write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
print("POL_RAIL_SCRAPE:",round(correlation,8),"source correlation;",
      [(row["speed_mps"],round(row["scrape_vs_engine_db"],2)) for row in rows],"dB vs engine;",len(before)-1,"WAVs exact")
