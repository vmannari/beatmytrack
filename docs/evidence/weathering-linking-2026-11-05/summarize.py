"""Report the measured candidates, including regressions and unchanged-program variation."""
import hashlib,json,re,statistics,struct
from pathlib import Path
p=Path(__file__).resolve().parent
def read(name): return json.loads((p/name).read_text())
def family(path):
    data=path.read_bytes(); offset=4; strings=[]
    for _ in range(3):
        size=struct.unpack_from('<I',data,offset)[0];offset+=4
        strings.append(data[offset:offset+size].decode());offset+=size
    code=strings[1]+strings[2]
    return ('toon' if '#define DIFFUSE_TOON' in code else 'burley') if 'weather_hash' in code else 'other'
result={'broad':read('candidates-gl/timings.json'),'plain_abba':read('rear-abba/timings.json')}
native=read('rear-native-abba-analysis.json')+read('rear-native-baab-analysis.json')
result['native_trials']=native
result['native_medians']={}
for policy in ('baseline','toon_rear'):
    rows=[r for r in native if r['policy']==policy]
    result['native_medians'][policy]={'whole_car_ms':statistics.median(r['ms'] for r in rows),
        'toon_link_ms':statistics.median(r['links_us']['toon']/1000 for r in rows),
        'burley_link_ms':statistics.median(r['links_us']['burley']/1000 for r in rows)}
result['app']={}
for label in ('app-baseline','app-candidate','app-candidate-repeat','app-baseline-repeat'):
    if not (p/(label+'-receipt.json')).exists(): continue
    log=(p/(label+'.log')).read_text(errors='replace'); links={};counts={}
    for line in log.splitlines():
        if not line.startswith('NATIVE_CALL api=glLinkProgram'): continue
        fields=dict(re.findall(r'(\w+)=([^ ]+)',line));kind=family(p/label/'jobs'/(fields['key']+'.job'))
        links[kind]=links.get(kind,0)+int(fields['us']);counts[kind]=counts.get(kind,0)+1
    result['app'][label]={'rows':[json.loads(l[len('FIRST_USE_ROW '):]) for l in log.splitlines() if l.startswith('FIRST_USE_ROW ')],
        'link_ms':{k:v/1000 for k,v in links.items()},'programs':counts,
        'assertions':re.findall(r'FIRST_USE_GRAPHICS: (\d+) checks, (\d+) failures',log)}
result['receipts']={}
for file in sorted(p.glob('*-receipt.json')):
    r=read(file.name)
    result['receipts'][file.stem]={'exit_code':r.get('exit_code'),'sources_unchanged':r['before']==r.get('after'),
        'elapsed_seconds':r.get('elapsed_seconds')}
archive=p/'before/game/vehicle'
result['runtime_unchanged']={f.name:hashlib.sha256(f.read_bytes()).hexdigest()==hashlib.sha256((p.parents[2]/'game/vehicle'/f.name).read_bytes()).hexdigest() for f in archive.iterdir() if f.is_file()}
(p/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ('native_medians','app','runtime_unchanged')},indent=2))
