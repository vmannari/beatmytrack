"""Correlate native calls with real draw intervals and captured source jobs."""
import collections,json,re,struct,sys
from pathlib import Path
evidence=Path(__file__).resolve().parent
label=sys.argv[1]
calls=[]; draws=[]; races=[]
for line in (evidence/(label+'.log')).read_text(errors='replace').splitlines():
    if line.startswith('NATIVE_CALL '):
        fields=dict(re.findall(r'(\w+)=([^ ]+)',line))
        calls.append({**fields,'us':int(fields['us']),'end':int(fields['utc_end_us'])})
    elif line.startswith('GRAPHICS_END '): draws.append(json.loads(line[len('GRAPHICS_END '):]))
    elif line.startswith('RACE_BEGIN '):
        _,theme,cycle,utc=line.split();races.append(dict(theme=theme,cycle=int(cycle),utc=int(utc)))
def job(key):
    path=evidence/label/'jobs'/(key+'.job')
    if not path.exists(): return {}
    data=path.read_bytes(); at=4; strings=[]
    for _ in range(3):
        size=struct.unpack_from('<I',data,at)[0];at+=4
        strings.append(data[at:at+size].decode());at+=size
    combined=strings[1]+strings[2]
    defines=re.findall(r'^\s*#define\s+([^\r\n]+)',combined,re.M)
    flags=re.findall(r'const bool\s+(\w+)\s*=\s*(true|false)',combined)
    return dict(vertex_bytes=len(strings[1]),fragment_bytes=len(strings[2]),defines=sorted(set(defines)),flags=dict(flags))
for draw in draws:
    overlapping=[call for call in calls if int(draw['utc_begin_us'])<=call['end']<=int(draw['utc_end_us'])]
    draw['native_us_by_api']=dict(collections.Counter())
    for call in overlapping:
        draw['native_us_by_api'][call['api']]=draw['native_us_by_api'].get(call['api'],0)+call['us']
    draw['programs']=sorted(set(call['key'] for call in overlapping if call['key']!='-'))
totals=collections.Counter()
programs=collections.defaultdict(lambda:collections.Counter())
for call in calls:
    totals[call['api']]+=call['us']
    if call['key']!='-': programs[call['key']][call['api']]+=call['us']
ranked=[dict(key=key,timings=dict(timings),source=job(key)) for key,timings in sorted(programs.items(),key=lambda pair:sum(pair[1].values()),reverse=True)]
result=dict(label=label,native_us=dict(totals),programs=ranked,draws=draws,races=races,native_threshold_us=2000)
(evidence/(label+'-analysis.json')).write_text(json.dumps(result,indent=2)+'\n')
print('Native seconds:',{key:round(value/1e6,3) for key,value in totals.items()})
for draw in sorted(draws,key=lambda row:row['us'],reverse=True)[:12]:
    print(draw['case'],draw['kind'],round(draw['us']/1e6,3),{key:round(value/1e6,3) for key,value in draw['native_us_by_api'].items()},[(source['path'],[material.get('origin',material.get('shader_path',material.get('class'))) for material in source['materials']]) for source in draw['sources'][:2]])
for row in ranked[:6]: print(row['key'][:12],row['timings'],row['source'].get('flags',{}))
