from collections import defaultdict
import json,re
from pathlib import Path
LAB=Path(__file__).resolve().parent/'race-trace'
frames=json.loads((LAB/'frames.json').read_text())
calls=[]
for line in (LAB/'output.log').read_text(encoding='utf-8',errors='replace').splitlines():
    match=re.search(r'NATIVE_CALL api=(\w+) us=(\d+) utc_end_us=(\d+)',line)
    if match:calls.append(dict(api=match[1],us=int(match[2]),end=int(match[3])))
rows=[]
for frame in sorted(frames,key=lambda x:x['us'],reverse=True)[:12]:
    begin=frame['utc_end_us']-frame['us'];end=frame['utc_end_us'];totals=defaultdict(int);overlaps=[]
    for call in calls:
        overlap=max(0,min(end,call['end'])-max(begin,call['end']-call['us']))
        if overlap:totals[call['api']]+=overlap;overlaps.append((max(begin,call['end']-call['us']),min(end,call['end'])))
    merged=[]
    for a,b in sorted(overlaps):
        if merged and a<=merged[-1][1]:merged[-1][1]=max(merged[-1][1],b)
        else:merged.append([a,b])
    covered=sum(b-a for a,b in merged)
    rows.append(dict(frame=frame,native_us_by_api=dict(totals),native_covered_us=covered,native_covered_percent=100*covered/frame['us']))
result=dict(frame_count=len(frames),timed_calls=len(calls),largest_frames=rows,
    car_slices=[s for s in (LAB/'output.log').read_text(encoding='utf-8',errors='replace').splitlines() if 'CAR_SLICE' in s])
(LAB/'attribution.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
