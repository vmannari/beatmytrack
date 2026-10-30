from collections import Counter
import json,math,re
from pathlib import Path
LAB=Path(__file__).resolve().parent
rows=[]
for name in ['capture-1','capture-2','import-1','import-2','import-context-1','import-context-input','final-render-bridge']:
    path=LAB/'programs'/name
    if not (path/'report.json').exists():continue
    report=json.loads((path/'report.json').read_text());execution=json.loads((path/'execution.json').read_text())
    phases={}
    for phase in sorted({r['phase'] for r in report['frames']}):
        values=sorted(r['frame_us'] for r in report['frames'] if r['phase']==phase)
        draws=sorted(r.get('draw_us',0) for r in report['frames'] if r['phase']==phase)
        phases[phase]=dict(frames=len(values),p50_us=values[len(values)//2],p99_us=values[min(len(values)-1,math.ceil(len(values)*.99)-1)],max_us=max(values),draw_max_us=max(draws),over_33ms=sum(v>33333 for v in values))
    posts=execution['posts'];responses=report['responses'];latency=[response['utc_us']-post['utc_us'] for post,response in zip(posts,responses)]
    pairing_valid=len(posts)==len(responses) and all(r.get('sequence',i+1)==p.get('sequence',i+1) for i,(p,r) in enumerate(zip(posts,responses)))
    log=(LAB/(name+'.log')).read_text(encoding='utf-8',errors='replace')
    native_max={}
    for api,duration in re.findall(r'NATIVE_CALL api=(\w+) us=(\d+)',log): native_max[api]=max(native_max.get(api,0),int(duration))
    import_times=[int(t) for t in re.findall(r'PROGRAM_IMPORT .*?all_us=(\d+)',log)]
    worker_samples=[]
    for line in log.splitlines():
        if line.startswith('{"job":'):
            try:worker_samples.append(json.loads(line))
            except ValueError:pass
    item=dict(label=name,exit=execution['exit'],checks=report['checks'],failures=report['failures'],phases=phases,
        input=dict(posts=len(posts),responses=len(responses),all_posts_sent=all(x['sent'] for x in posts),
            paired_latency_max_us=max(latency,default=None),paired_latency_min_us=min(latency,default=None),
            pairing_valid=pairing_valid),native=json.loads((path/'native-report.json').read_text()),
        maximum_native_call_us=native_max,maximum_complete_interceptor_us=max(import_times,default=None),
        worker_progress_records=len(worker_samples),worker_sampled_peak_commit_bytes=max((r['peak_commit_bytes'] for r in worker_samples),default=None))
    rows.append(item)
(LAB/'program-analysis.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
print(json.dumps(rows,indent=2))
