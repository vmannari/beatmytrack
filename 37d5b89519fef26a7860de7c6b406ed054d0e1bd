from collections import Counter
import hashlib
import json
from pathlib import Path

LAB=Path(__file__).resolve().parent
ROOT=LAB.parent.parent

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

cases=[]
for path in sorted((LAB/'results').glob('*/report.json')):
    d=read(path)
    rows=d['draws'];frames=d['frames']
    cases.append(dict(label=path.parent.name,scope=d['scope'],variant=d['variant'],checks=d['checks'],failures=d['failures'],
        ready_us=d['ready_us'],prepared_us=d['prepared_us'],draws=len(rows),
        max_draw_us=max(x['total_us'] for x in rows),max_frame_us=max(x['frame_us'] for x in frames),
        over_200ms_draws=sum(x['total_us']>200000 for x in rows),
        draw_helper_without_warm_in_stack=sum('warm' not in x['callers'] for x in rows),
        initial=d['initial'],final_pipeline=d['final_pipeline']))

def native(name, frame_path=None):
    data=[json.loads(line) for line in (LAB/(name+'-native.jsonl')).read_text().splitlines()]
    samples=[x for x in data if x['kind']=='sample']
    intervals=[]
    if frame_path:
        d=read(frame_path)
        frames=d['frames'] if isinstance(d,dict) else d
        intervals=[(x['utc_us']-x['frame_us'],x['utc_us']) for x in frames if x['frame_us']>200000]
        samples=[x for x in samples if any(a<=x['utc_us']<=b for a,b in intervals)]
    tops=Counter();cpu=Counter();godot=Counter()
    for x in samples:
        frames=x['frames']
        if frames:
            tops[frames[0]['module']]+=1;cpu[frames[0]['module']]+=x['cpu_delta_us']
        first=next((f for f in frames if f['module']=='Godot_v4.7.2-stable_win64'),None)
        if first:godot[hex(first['offset'])]+=1
    return dict(samples=len(samples),frame_windows=len(intervals),top_modules=dict(tops),top_module_cpu_delta_us=dict(cpu),
        nearest_Godot_offsets=dict(godot.most_common(12)),max_sample_thread_suspend_us=max((x['pause_us'] for x in samples),default=0))

race=read(LAB/'race/load-profile-gl_compatibility-Windows.json')
race_rows=[]
for row in race['loads']:
    race_rows.append({k:row[k] for k in ['source','cycle','wall_ms','max_frame_ms','draw_wait_max_us','draw_groups','longest','game','world']})
initial=read(LAB/'source-start.json')
sources={name:dict(start=digest,frozen=hashlib.sha256((LAB/'frozen-original'/name).read_bytes()).hexdigest(),current=hashlib.sha256((ROOT/'game'/name).read_bytes()).hexdigest()) for name,digest in initial.items()}
cache=LAB/'profiles/original-standalone/Circuit01Lab/shader_cache'
cache_files=list(cache.rglob('*.cache'))
summary=dict(cases=cases,native={
    'Garage_over_200ms':native('original-native-sample',LAB/'results/original-native-sample/report.json'),
    'parallel_hint_over_200ms':native('parallel-hint',LAB/'results/parallel-hint/report.json'),
    'race_entire_owned_probe':native('race'),
},race=dict(checks=race['checks'],failures=race['failures'],loads=race_rows,
    recorded_frames=len(read(LAB/'race/native-frames.json'))),
    cache=dict(files=len(cache_files),bytes=sum(p.stat().st_size for p in cache_files)),sources=sources)
(LAB/'analysis.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps(dict(cases=[{k:v for k,v in c.items() if k not in ['initial','final_pipeline']} for c in cases],
    native=summary['native'],race=[{k:v for k,v in r.items() if k not in ['game','world']} for r in race_rows],
    concurrent_sources=[k for k,v in sources.items() if v['start']!=v['current']],cache=summary['cache']),indent=2))
