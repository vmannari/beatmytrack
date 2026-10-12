"""Actual Windows process output checks, including mute and overlapping peaks."""
from pathlib import Path
import csv,json
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"build/audio-output-2026-10-09/controls"
events=json.loads((OUT/"events.json").read_text())
audio=np.frombuffer((OUT/"loopback.pcm").read_bytes(),dtype="<i2").reshape(-1,2)/32768.0
with (OUT/"packets.csv").open() as f:
    packets=list(csv.DictReader(f))
rows=[]
for event in events:
    sections=[]
    for packet in packets:
        if int(packet["flags"])&4: continue
        offset,count=int(packet["frame_offset"]),int(packet["frames"])
        timestamps=float(packet["utc_us"])+np.arange(count)/48000*1e6
        selected=(timestamps>=event["unix_us"]+20000)&(timestamps<event["unix_us"]+600000)
        if selected.any(): sections.append(audio[offset:offset+count][selected])
    data=np.concatenate(sections)
    rows.append(dict(mode=event["mode"],peak=float(np.max(np.abs(data))),rms=float(np.sqrt(np.mean(data**2))),full_scale_samples=int(np.sum(np.abs(data)>=.999)),native=event["native"]))
by={r["mode"]:r for r in rows}
for mode in ["vehicle-mute","master-mute","paused","countdown"]:
    assert by[mode]["peak"]<1e-4,(mode,by[mode])
assert .26<by["volume-30"]["rms"]/by["full"]["rms"]<.34,"actual output must follow 30% Vehicle gain"
assert by["full"]["peak"]>.1,"full impact must produce actual output"
assert by["overlap"]["peak"]<=.795,"four-voice output retains the impact ceiling"
assert all(r["full_scale_samples"]==0 for r in rows),"mixed engine/impact output must not clip"
assert by["engine-mix"]["rms"]>0.01,"real engine/impact mix is present"
report=dict(checks=9,failures=0,rows=rows,limits="Own-process Windows output, not an acoustic microphone measurement.")
(OUT/"review.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps(report,indent=2))
