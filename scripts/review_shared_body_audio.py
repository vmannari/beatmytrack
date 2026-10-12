from pathlib import Path
import csv,json
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/shared-collision-audio-2026-10-09'
timing=[]
for variant in ['before','after']:
    folder=OUT/variant
    events=json.loads((folder/'events.json').read_text())
    report=json.loads((folder/'timing-report.json').read_text())
    for clip in ['impact_2','chassis']:
        values=[r['latency_ms'] for e,r in zip(events,report['rows']) if e['clip']==clip]
        timing.append(dict(variant=variant,clip=clip,minimum_ms=min(values),median_ms=float(np.median(values)),maximum_ms=max(values)))
assert all(e['route']=='windows_raw' for e in json.loads((OUT/'after/events.json').read_text()))
by={(r['variant'],r['clip']):r for r in timing}
assert by['after','chassis']['maximum_ms']<by['before','chassis']['minimum_ms']-90
assert by['after','impact_2']['median_ms']<by['before','impact_2']['median_ms']
folder=OUT/'controls'
audio=np.frombuffer((folder/'loopback.pcm').read_bytes(),dtype='<i2').reshape(-1,2)/32768.0
events=json.loads((folder/'events.json').read_text())
with (folder/'packets.csv').open() as f: packets=list(csv.DictReader(f))
rows=[]
for event in events:
    segments=[]
    for packet in packets:
        if int(packet['flags'])&4: continue
        offset,count=int(packet['frame_offset']),int(packet['frames'])
        timestamps=float(packet['utc_us'])+np.arange(count)/48000*1e6
        selected=(timestamps>=event['unix_us']+20000)&(timestamps<event['unix_us']+600000)
        if selected.any(): segments.append(audio[offset:offset+count][selected])
    x=np.concatenate(segments)
    rows.append(dict(mode=event['mode'],peak=float(np.max(np.abs(x))),rms=float(np.sqrt(np.mean(x*x))),full_scale_samples=int(np.sum(np.abs(x)>=.999))))
by_mode={r['mode']:r for r in rows}
for name in ['chassis-vehicle-mute','chassis-master-mute','chassis-paused']: assert by_mode[name]['peak']<1e-4,name
assert .27<by_mode['chassis-30']['rms']/by_mode['chassis-full']['rms']<.33
assert by_mode['chassis-impact-mute']['rms']>by_mode['chassis-full']['rms']*.9
assert by_mode['impact-vehicle-mute']['peak']>.1
assert all(r['full_scale_samples']==0 for r in rows)
assert by_mode['overlap']['peak']<=.892
result=dict(timing=timing,controls=rows,checks=11,failures=0,limits='Own-process digital output; no microphone/physical acoustic latency measurement.')
(OUT/'review.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,indent=2))
