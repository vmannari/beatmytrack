"""Summarize an owned Perfetto capture; never downloads or uploads trace data."""
import csv
import io
import json
import re
from pathlib import Path
import subprocess
import sys

if len(sys.argv)!=2: raise SystemExit('Usage: python analyze.py <capture-directory>')
directory=Path(sys.argv[1]).resolve()
receipt=json.loads((directory/'receipt.json').read_text(encoding='utf-8'))
pid=int(receipt['pid'])
processor=Path('C:/Users/ville/.local/share/perfetto/prebuilts/trace_processor_shell-adfa6bad3d72be3b.exe')
trace=directory/'trace.pftrace'
queries={
 'bounds':'SELECT start_ts,end_ts FROM trace_bounds',
 'clocks':"SELECT ts,clock_name,clock_value,snapshot_id FROM clock_snapshot WHERE clock_name IN ('REALTIME','MONOTONIC','BOOTTIME') ORDER BY ts,clock_name",
 'health':"SELECT name,idx,severity,value FROM stats WHERE value != 0 AND (severity IN ('error','notice','data_loss') OR name LIKE '%overwritten%' OR name LIKE '%discard%' OR name LIKE '%lost%' OR name LIKE '%overrun%')",
 'perf_session':'SELECT * FROM perf_session',
 'all_samples':'SELECT COUNT(*) AS samples FROM perf_sample',
 'target_process':f'SELECT pid,name,cmdline,start_ts,end_ts FROM process WHERE pid={pid}',
 'target_sched':f'SELECT COUNT(*) AS slices,ROUND(SUM(s.dur)/1e9,3) AS cpu_seconds,MIN(s.ts) AS first_ts,MAX(s.ts) AS last_ts FROM sched s JOIN thread t USING(utid) JOIN process p USING(upid) WHERE p.pid={pid} AND s.dur>0',
 'sample_count':f'SELECT COUNT(*) AS samples,MIN(s.ts) AS first_ts,MAX(s.ts) AS last_ts FROM perf_sample s JOIN thread t USING(utid) JOIN process p USING(upid) WHERE p.pid={pid}',
 'sample_unwind':f'SELECT s.unwind_error,COUNT(*) AS samples FROM perf_sample s JOIN thread t USING(utid) JOIN process p USING(upid) WHERE p.pid={pid} GROUP BY s.unwind_error',
 'threads':f'SELECT t.tid,t.name,COUNT(*) AS samples FROM perf_sample s JOIN thread t USING(utid) JOIN process p USING(upid) WHERE p.pid={pid} GROUP BY t.tid,t.name ORDER BY samples DESC',
 'frames':f'''WITH RECURSIVE stack(sample_id,callsite_id) AS (
   SELECT s.id,s.callsite_id FROM perf_sample s JOIN thread t USING(utid) JOIN process p USING(upid) WHERE p.pid={pid}
   UNION ALL SELECT stack.sample_id,c.parent_id FROM stack JOIN stack_profile_callsite c ON c.id=stack.callsite_id WHERE c.parent_id IS NOT NULL
 ) SELECT COALESCE(symbol.name,frame.name) AS name,mapping.name AS mapping,COUNT(DISTINCT stack.sample_id) AS samples
   FROM stack JOIN stack_profile_callsite c ON c.id=stack.callsite_id JOIN stack_profile_frame frame ON frame.id=c.frame_id
   JOIN stack_profile_mapping mapping ON mapping.id=frame.mapping LEFT JOIN stack_profile_symbol symbol ON symbol.symbol_set_id=frame.symbol_set_id
   GROUP BY COALESCE(symbol.name,frame.name),mapping.name ORDER BY samples DESC LIMIT 100''',
 'mapping_samples':f'''WITH RECURSIVE stack(sample_id,callsite_id) AS (
   SELECT s.id,s.callsite_id FROM perf_sample s JOIN thread t USING(utid) JOIN process p USING(upid) WHERE p.pid={pid}
   UNION ALL SELECT stack.sample_id,c.parent_id FROM stack JOIN stack_profile_callsite c ON c.id=stack.callsite_id WHERE c.parent_id IS NOT NULL
 ) SELECT mapping.name AS mapping,COUNT(DISTINCT stack.sample_id) AS samples
   FROM stack JOIN stack_profile_callsite c ON c.id=stack.callsite_id JOIN stack_profile_frame frame ON frame.id=c.frame_id
   JOIN stack_profile_mapping mapping ON mapping.id=frame.mapping GROUP BY mapping.name ORDER BY samples DESC LIMIT 100''',
 'frame_timeline':f'SELECT COUNT(*) AS slices FROM actual_frame_timeline_slice f JOIN process p USING(upid) WHERE p.pid={pid}',
 'gpu_render_stages':'SELECT COUNT(*) AS slices FROM gpu_slice',
 'gpu_counters':"SELECT ct.name,COUNT(*) AS samples FROM counter c JOIN counter_track ct ON c.track_id=ct.id WHERE LOWER(ct.name) LIKE '%gpu%' GROUP BY ct.name ORDER BY samples DESC LIMIT 50"
}
result={'pid':pid,'queries':{},'limitations':['CPU samples are statistical and reflect on-CPU presence, not GL call wall time.',
 'Opaque or stripped driver symbols limit source attribution.',
 'FrameTimeline may omit SurfaceView layers; its empty table does not establish smoothness.',
 'GPU source rows are device-wide and may be unavailable or unsupported; they are not attributed to the app.',
 'SurfaceFlinger timestamps and trace/log phase boundaries are not aligned by this analysis.',
 'The probe and trace use warmed application/driver caches; no fresh-driver-cache claim.']}
for label,query in queries.items():
    try:
        run=subprocess.run([str(processor),'query',str(trace),query],stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                           text=True,encoding='utf-8',errors='replace',timeout=120,check=False)
        rows=list(csv.DictReader(io.StringIO(run.stdout))) if run.returncode==0 else []
        result['queries'][label]={'exit':run.returncode,'rows':rows,'stderr':run.stderr[-4000:]}
    except Exception as exc: result['queries'][label]={'error':repr(exc)}
clock_rows=result['queries'].get('clocks',{}).get('rows',[])
clock_offsets={}
for row in clock_rows:
    try: clock_offsets.setdefault(row['clock_name'],[]).append((int(row['clock_value']),int(row['ts'])-int(row['clock_value'])))
    except (ValueError,KeyError): pass
result['clock_offset_ranges_ns']={name:max(x[1] for x in values)-min(x[1] for x in values) for name,values in clock_offsets.items()}
phases=[]
log=directory/'probe-logcat.txt'
if log.exists() and clock_offsets.get('REALTIME') and result['clock_offset_ranges_ns']['REALTIME']<5000000:
    active={}
    for line in log.read_text(encoding='utf-8',errors='replace').splitlines():
        stamp=re.match(r'^\s*(\d+\.\d+)',line)
        if not stamp: continue
        realtime_ns=int(float(stamp.group(1))*1e9)
        nearest=min(clock_offsets['REALTIME'],key=lambda entry:abs(entry[0]-realtime_ns))
        trace_ns=realtime_ns+nearest[1]
        begin=re.search(r'BMT_PERF_BEGIN\s+(\S+)',line)
        if begin: active[begin.group(1)]=trace_ns
        end=re.search(r'BMT_PERF_CASE\s+(\{.*\})',line)
        if end:
            try: phase=json.loads(end.group(1)).get('phase')
            except json.JSONDecodeError: continue
            if phase in active:
                phases.append({'phase':phase,'start_ns':active.pop(phase),'end_ns':trace_ns,'complete':True})
    bounds=result['queries'].get('bounds',{}).get('rows',[])
    if bounds:
        end_ns=int(bounds[0]['end_ts'])
        phases.extend({'phase':phase,'start_ns':start,'end_ns':end_ns,'complete':False} for phase,start in active.items() if start<end_ns)
result['phases']=phases
if phases:
    clauses=' '.join("WHEN s.ts >= %d AND s.ts < %d THEN '%s'" % (phase['start_ns'],phase['end_ns'],phase['phase'])
                     for phase in phases if re.fullmatch(r'[A-Za-z0-9_]+',phase['phase']))
    if clauses:
        query=f'''SELECT CASE {clauses} ELSE 'outside' END AS phase, COUNT(*) AS samples
                  FROM perf_sample s JOIN thread t USING(utid) JOIN process p USING(upid)
                  WHERE p.pid={pid} GROUP BY phase ORDER BY phase'''
        run=subprocess.run([str(processor),'query',str(trace),query],stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                           text=True,encoding='utf-8',errors='replace',timeout=120,check=False)
        result['queries']['phase_samples']={'exit':run.returncode,'rows':list(csv.DictReader(io.StringIO(run.stdout))) if run.returncode==0 else [],'stderr':run.stderr[-4000:]}
    first=next((phase for phase in phases if phase['phase']=='load_star_first'),None)
    if first:
        query=f'''WITH RECURSIVE stack(sample_id,callsite_id) AS (
          SELECT s.id,s.callsite_id FROM perf_sample s JOIN thread t USING(utid) JOIN process p USING(upid)
          WHERE p.pid={pid} AND s.ts >= {first['start_ns']} AND s.ts < {first['end_ns']}
          UNION ALL SELECT stack.sample_id,c.parent_id FROM stack JOIN stack_profile_callsite c ON c.id=stack.callsite_id WHERE c.parent_id IS NOT NULL
        ) SELECT COALESCE(symbol.name,frame.name) AS name,mapping.name AS mapping,COUNT(DISTINCT stack.sample_id) AS samples
          FROM stack JOIN stack_profile_callsite c ON c.id=stack.callsite_id JOIN stack_profile_frame frame ON frame.id=c.frame_id
          JOIN stack_profile_mapping mapping ON mapping.id=frame.mapping LEFT JOIN stack_profile_symbol symbol ON symbol.symbol_set_id=frame.symbol_set_id
          GROUP BY COALESCE(symbol.name,frame.name),mapping.name ORDER BY samples DESC LIMIT 100'''
        run=subprocess.run([str(processor),'query',str(trace),query],stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                           text=True,encoding='utf-8',errors='replace',timeout=120,check=False)
        result['queries']['first_load_stacks']={'exit':run.returncode,'rows':list(csv.DictReader(io.StringIO(run.stdout))) if run.returncode==0 else [],'stderr':run.stderr[-4000:]}
latency=directory/'surface-latency.jsonl'
if latency.exists():
    timestamps=set(); polls=0; successful=0; samples_by_poll=[]; host_poll_ns=[]
    for line in latency.read_text(encoding='utf-8').splitlines():
        row=json.loads(line); polls+=1; host_poll_ns.append(row['host_monotonic_ns'])
        poll_times=set()
        if row.get('exit')!=0: continue
        successful+=1
        lines=row.get('raw','').splitlines()
        for entry in lines[1:]:
            fields=entry.split()
            if len(fields)!=3 or not all(field.isdigit() for field in fields): continue
            present=int(fields[1])
            if 0<present<2**63-1: timestamps.add(present); poll_times.add(present)
        samples_by_poll.append(poll_times)
    ordered=sorted(timestamps)
    gaps=[(right-left)/1e6 for left,right in zip(ordered,ordered[1:]) if right>left]
    poll_gaps=sorted((right-left)/1e9 for left,right in zip(host_poll_ns,host_poll_ns[1:]) if right>left)
    top=sorted(((right-left,left,right) for left,right in zip(ordered,ordered[1:]) if right>left),reverse=True)[:10]
    result['surface_latency']={'polls':polls,'successful_polls':successful,'unique_present_timestamps':len(ordered),
                               'intervals':len(gaps),'max_ms':max(gaps) if gaps else None,
                               'over34_ms':sum(gap>34 for gap in gaps),
                               'host_poll_gap_max_s':max(poll_gaps) if poll_gaps else None,
                               'top_gap_same_poll':[{'gap_ms':gap/1e6,'start_ns':start,'end_ns':end,
                                                     'matching_poll_count':sum(start in entry and end in entry for entry in samples_by_poll)} for gap,start,end in top],
                               'note':'Only sampled SurfaceView ring entries; missed windows can produce false gaps. Phase alignment and completeness unverified.'}
    if phases and clock_offsets.get('MONOTONIC') and result['clock_offset_ranges_ns']['MONOTONIC']<5000000:
        converted=[]
        for stamp in ordered:
            nearest=min(clock_offsets['MONOTONIC'],key=lambda entry:abs(entry[0]-stamp))
            converted.append(stamp+nearest[1])
        bounds=result['queries'].get('bounds',{}).get('rows',[])
        if bounds:
            trace_start,trace_end=int(bounds[0]['start_ts']),int(bounds[0]['end_ts'])
            inside=sum(trace_start<=stamp<=trace_end for stamp in converted)
            result['surface_latency']['mapped_inside_trace']=inside
            result['surface_latency']['mapped_outside_trace']=len(converted)-inside
            if converted and inside/len(converted)>=0.90 and all(trace_start<=p['start_ns']<=trace_end for p in phases):
                result['surface_latency']['phase_gaps']={}
                for phase in phases:
                    times=[stamp for stamp in converted if phase['start_ns']<=stamp<phase['end_ns']]
                    values=[(right-left)/1e6 for left,right in zip(times,times[1:]) if right>left]
                    result['surface_latency']['phase_gaps'][phase['phase']]={'complete':phase['complete'],'present_samples':len(times),
                         'max_ms':max(values) if values else None,'over34_ms':sum(gap>34 for gap in values)}
                result['surface_latency']['note']='Clock snapshots and trace-range coverage checked; logcat boundaries remain approximate. Ring gaps can be polling artifacts, not proven missed presentation.'
            else:
                result['surface_latency']['note']='Clock mapping failed trace-range coverage; no phase-specific presentation claim.'
(directory/'analysis.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({'output':str(directory/'analysis.json'),'sample_count':result['queries']['sample_count'],
                  'surface_latency':result.get('surface_latency')},indent=2))
