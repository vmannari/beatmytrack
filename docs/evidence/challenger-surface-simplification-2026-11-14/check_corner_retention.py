"""Keep the owner's rounded, downturned front corners after simplification."""
from pathlib import Path
import json,sys
import numpy as np

ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build/challenger-surface-simplification-2026-11-14'
profiles=json.loads((BUILD/'corner-sections.json').read_text())
checks=0;findings=[];rows=[]
def check(ok,label):
    global checks
    checks+=1
    if not ok:findings.append(label)
for row in profiles:
    if row['z']> -2.14:continue
    a=np.asarray([p['angle'] for p in row['samples']]);y=np.asarray([p['y'] for p in row['samples']])
    check(len(a)==241,f"{row['stage']}/{row['tier']}/{row['side']}: complete front-corner normal section")
    low,high=np.median(a[:20]),np.median(a[-20:]);contrast=high-low
    begin=np.flatnonzero(a>=low+contrast*.1);end=np.flatnonzero(a>=low+contrast*.9)
    width=float(y[end[0]]-y[begin[0]]) if len(begin) and len(end) else 0
    check(width>=.008,f"{row['stage']}/{row['tier']}/{row['side']}: at least 8 mm corner roll retained")
    rows.append({'stage':row['stage'],'tier':row['tier'],'side':row['side'],'transition_mm':width*1000,'largest_half_mm_normal_step_degrees':float(np.max(np.diff(a)))})
for row in rows:
    if row['stage']!='candidate':continue
    before=next(r for r in rows if r['stage']=='before' and r['tier']==row['tier'] and r['side']==row['side'])
    check(row['largest_half_mm_normal_step_degrees']<=before['largest_half_mm_normal_step_degrees']+.25,
          f"{row['tier']}/{row['side']}: no sharper front-corner reflection step")
(OUT/'corner-retention.json').write_text(json.dumps({'checks':checks,'failures':len(findings),'findings':findings,'sections':rows},indent=2))
print('CORNER_RETENTION:',checks,'checks,',len(findings),'failures')
print('\n'.join(findings))
sys.exit(1 if findings else 0)
