"""Review immediate grass response, kerb recordings and preserved prior sound assets."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/grass-kerb-audio-2026-10-11"


def measure(path):
    with wave.open(str(path)) as handle:
        rate = handle.getframerate()
        channels = handle.getnchannels()
        values = np.frombuffer(handle.readframes(handle.getnframes()),dtype="<i2").astype(float)/32768
    values = values.reshape(-1,channels)
    first = np.flatnonzero(np.max(abs(values),axis=1)>.0008)
    return {"seconds":len(values)/rate,"peak":float(np.max(abs(values))),
            "rms":float(np.sqrt(np.mean(values**2))),
            "onset_s":float(first[0])/rate if len(first) else None,
            "tail_peak":float(np.max(abs(values[-round(.15*rate):])))}


baseline = json.loads((OUT / "baseline.json").read_text())
onset = json.loads((OUT / "grass-onset.json").read_text())
assert len(baseline)==len(onset)==5
for before,after in zip(baseline,onset):
    assert before["car"]==after["car"]
    assert before["ratio"]<.25 and after["ratio"]>.85
    assert after["first"]>.35
traces = json.loads((OUT / "native-contact-timing.json").read_text())
rows = []
for trace in traces:
    name = trace["case"]
    stats = {label:measure(OUT / (name+suffix+".wav"))
             for label,suffix in [("mix",""),("grass","-grass"),("kerb","-kerb")]}
    assert stats["mix"]["peak"]<.94
    assert all(row["tail_peak"]==0 for row in stats.values())
    if name=="grass-entry":
        assert stats["kerb"]["peak"]==0
        assert abs(stats["grass"]["onset_s"]-trace["first_grass_s"])<.10
        assert trace["grass_first_level"]>.15
    else:
        assert stats["grass"]["peak"]==0
        assert stats["kerb"]["peak"]>.10
        assert abs(stats["kerb"]["onset_s"]-trace["first_kerb_s"])<.10
    rows.append({**trace,**stats})
before = json.loads((OUT / "before-hashes.json").read_text(encoding="utf-8-sig"))
for item in before:
    assert hashlib.sha256(Path(item["Path"]).read_bytes()).hexdigest().upper()==item["Hash"]
report = {"grass_before":baseline,"grass_after":onset,"native":rows,"unchanged_wavs":len(before),"new_wavs":["kerb_roll.wav"]}
(OUT / "audio-review.json").write_text(json.dumps(report,indent=2)+"\n")
print("GRASS_KERB_REVIEW: first-frame",round(baseline[0]["ratio"]*100,1),"to",round(onset[0]["ratio"]*100,1),
      "% of settled grass; three native mixes/isolated contacts/headroom/silent tails pass;",len(before),"prior WAVs exact")
