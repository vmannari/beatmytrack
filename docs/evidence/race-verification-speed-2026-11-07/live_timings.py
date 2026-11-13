"""Read-only post-race latency attribution; raw logs stay in ignored build/."""
import importlib.util
import json
import statistics
from pathlib import Path

WORK=Path(__file__).resolve().parent
ROOT=WORK.parents[1]
OUT=ROOT/'docs/evidence/race-verification-speed-2026-11-07'
spec=importlib.util.spec_from_file_location('last_release',ROOT/'build/backend-compat-deploy-20261107/deploy.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
r.d.WORK=WORK;r.d.OUT=OUT;r.d.STATE=WORK/'state.private.json';r.d.state={}
query='resource.labels.worker_pool_name="bmt-stg-e7a444ab-worker" AND timestamp>="2026-11-06T10:15:39Z"'
rows=json.loads(r.service.call('logging','read',query,'--limit=2000','--format=json'))
r.d.write(WORK/'worker-logs.private.json',rows)
events=[]
for row in rows:
    payload=row.get('jsonPayload',{})
    if not payload and row.get('textPayload','').startswith('{'):
        try:payload=json.loads(row['textPayload'])
        except ValueError:pass
    if payload:
        events.append((row['timestamp'],payload))
complete=[(stamp,p) for stamp,p in events if p.get('message')=='verification_complete' or p.get('event')=='verification_complete']
summary={'rows':len(rows),'structured_events':len(events),'verification_completions':len(complete),
         'event_names':sorted({str(p.get('message',p.get('event',''))) for _,p in events})}
for field in ('queue_wait_seconds','verification_seconds','verification_compute_ms'):
    values=[p[field] for _,p in complete if isinstance(p.get(field),(float,int))]
    if values:summary[field]={'count':len(values),'median':statistics.median(values),'max':max(values),'values':values[:40]}
summary['recent']=[{'timestamp':stamp,**{k:p.get(k) for k in ('queue_wait_seconds','verification_seconds','verification_compute_ms','verification_method')}} for stamp,p in complete[:15]]
r.d.write(OUT/'live-worker-timings.json',summary)
print(json.dumps(summary,indent=2),flush=True)
