"""Analyze a bounded passive GL cache trace against observed App callback frames."""
import collections
import json
from pathlib import Path

lab = Path(__file__).resolve().parent
run = lab / 'run-trace'
trace = json.loads((run / 'trace.json').read_text(encoding='utf-8'))
frames = json.loads((run / 'output/frame-spans.json').read_text(encoding='utf-8'))
events = sorted(trace['events'], key=lambda event: event[4])
names = {1:'binary_length_query', 2:'binary_extraction', 3:'binary_import', 4:'program_delete'}
summary = {}
for kind, name in names.items():
    group = [row for row in events if row[0] == kind]
    durations = sorted(row[5] for row in group)
    summary[name] = {'calls':len(group), 'total_us':sum(durations), 'max_us':max(durations,default=0),
                     'requested_bytes':sum(max(0,row[3]) for row in group) if kind in (1,2,3) else None,
                     'threads':sorted({row[1] for row in group})}
generation = collections.Counter()
extractions = collections.Counter()
repeated_us=0
repeated_bytes=0
for kind, thread, program, size, began, duration in events:
    if kind == 4: generation[program] += 1
    elif kind == 2:
        key=(program,generation[program])
        if extractions[key]:
            repeated_us+=duration
            repeated_bytes+=max(0,size)
        extractions[key] += 1
summary['program_extractions'] = {'unique_lifetimes':len(extractions),
    'repeated_lifetimes':sum(count > 1 for count in extractions.values()),
    'repeat_calls':sum(max(0,count-1) for count in extractions.values()),
    'repeat_call_cpu_us':repeated_us,'repeat_requested_bytes':repeated_bytes,
    'max_extractions_one_lifetime':max(extractions.values(),default=0)}
def overlap(start,end,kind=None):
    clipped = []
    for event in events:
        if kind is not None and event[0] != kind: continue
        a=max(start,event[4]); b=min(end,event[4]+event[5])
        if b>a: clipped.append((a,b))
    clipped.sort()
    total=0; last=-1
    for a,b in clipped:
        if a>last: total+=b-a;last=b
        elif b>last: total+=b-last;last=b
    return total
frame_rows=[]
for cycle in sorted({frame['cycle'] for frame in frames}):
    selected=[f for f in frames if f['cycle']==cycle]
    if not selected: continue
    worst=max(selected,key=lambda f:f['duration_us'])
    end=worst['end_us']; start=end-worst['duration_us']
    frame_rows.append({'cycle':cycle,'duration_us':worst['duration_us'],'status':worst['phase'],
                       'binary_length_overlap_us':overlap(start,end,1),
                       'extraction_overlap_us':overlap(start,end,2),
                       'import_overlap_us':overlap(start,end,3)})
output={'schema':1,'scope':'after extension initialization until teardown; Windows Compatibility only',
        'installed':trace['installed'],'events_total':trace['events_total'],'events_dropped':trace['events_dropped'],
        'event_fields':['kind','thread_id','process_local_program_handle','requested_or_reported_bytes','utc_start_us','cpu_call_duration_us'],
        'limitations':['Program handles are context/process-local and not source hashes.',
                       'Extraction size is requested size when GL caller passes a null written-length pointer.',
                       'GL call overlap is approximate due to independent clock calibration.',
                       'Other GL operations and cache file IO are not traced.',
                       'Frames are process callbacks, not physical presentation.',
                       'Trace does not include GL calls before GDExtension initialization.'],
        'metrics':summary,'worst_observed_frames':frame_rows}
(lab / 'analysis.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
print(json.dumps(output,indent=2))
