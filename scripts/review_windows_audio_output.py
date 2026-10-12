"""Compare own-process WASAPI packet timestamps with Godot collision requests."""
from pathlib import Path
import csv
import json
import sys
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(sys.argv[1]).resolve() if len(sys.argv)>1 else ROOT / "build/audio-output-2026-10-09"
events = json.loads((OUT / "events.json").read_text())
samples = np.frombuffer((OUT / "loopback.pcm").read_bytes(),dtype="<i2").astype(np.float64).reshape(-1,2)/32768.0
with (OUT / "packets.csv").open() as handle:
    packets = list(csv.DictReader(handle))
rate = 48000
rows = []
for event in events:
    request = event["unix_us"]
    found = []
    pretrigger_peak = 0.0
    for packet in packets:
        if int(packet["flags"]) & 4:
            continue # Invalid timestamp is never accepted as timing evidence.
        offset,count = int(packet["frame_offset"]),int(packet["frames"])
        start = float(packet["utc_us"])
        if start+count/rate*1e6<request-50000 or start>request+500000:
            continue
        values = np.max(np.abs(samples[offset:offset+count]),axis=1)
        timestamps = start+np.arange(count)/rate*1e6
        before = (timestamps>=request-50000)&(timestamps<request)
        if before.any(): pretrigger_peak = max(pretrigger_peak,float(np.max(values[before])))
        threshold = .01
        indexes = np.flatnonzero(values>threshold)
        for index in indexes:
            timestamp = start+float(index)/rate*1e6
            if request<=timestamp<=request+500000:
                found.append(timestamp)
                break
    if pretrigger_peak>.01:
        raise ValueError("Pre-trigger audio contaminates trial "+str(event["trial"])+": "+str(pretrigger_peak))
    if not found:
        raise ValueError("No valid own-process output near trial "+str(event["trial"]))
    onset = min(found)
    rows.append(dict(trial=event["trial"],request_unix_us=request,output_unix_us=onset,latency_ms=(onset-request)/1000.0,
                     engine_reported_ms=event["reported_latency_ms"],next_mix_ms=event["next_mix_ms"]))
report = dict(process_only=True,microphone=False,other_application_audio=False,rows=rows,
              median_ms=float(np.median([x["latency_ms"] for x in rows])),minimum_ms=min(x["latency_ms"] for x in rows),maximum_ms=max(x["latency_ms"] for x in rows),
              limits="Windows process-loopback, before physical speaker/headphone/Bluetooth hardware.")
(OUT / "timing-report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps(report,indent=2))
