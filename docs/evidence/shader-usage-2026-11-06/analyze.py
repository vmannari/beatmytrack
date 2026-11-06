"""Count all observed native programs and draw use, retaining unobserved caveats."""
import collections,json,re,struct,sys
from pathlib import Path
p=Path(__file__).resolve().parent; label=sys.argv[1]
native=json.loads((p/label/'native-report.json').read_text())
log=(p/(label+'.log')).read_text(errors='replace')
def job(key):
    path=p/label/'jobs'/(key+'.job')
    if not path.exists():return {'family':'unavailable','defines':[]}
    data=path.read_bytes();at=4;strings=[]
    for _ in range(3):
        n=struct.unpack_from('<I',data,at)[0];at+=4;strings.append(data[at:at+n].decode());at+=n
    code=strings[1]+strings[2]
    family='other'
    if 'BMT_USAGE_CONTROL_' in code:family='control'
    elif 'weather_hash' in code:family='weathering-toon' if '#define DIFFUSE_TOON' in code else 'weathering-burley'
    elif 'road_material_coverage' in code or 'surface_detail' in code:family='world-surface'
    elif 'gl_Position' not in strings[1]:family='other'
    defines=sorted(set(re.findall(r'^\s*#define\s+([^\r\n]+)',code,re.M)))
    prologue=strings[1].split('#ifdef USE_MULTIVIEW')[0]
    prologue_defines=sorted(set(re.findall(r'^\s*#define\s+([^\r\n]+)',prologue,re.M)))
    default_full=all(x in prologue_defines for x in ('DISABLE_REFLECTION_PROBE','USE_RADIANCE_MAP','BASE_PASS','APPLY_TONEMAPPING')) and not any(x.startswith('DISABLE_LIGHT_') for x in prologue_defines)
    return {'family':family,'defines':defines,'prologue_defines':prologue_defines,'default_full_signature':default_full,'vertex_bytes':len(strings[1]),'fragment_bytes':len(strings[2])}
programs={}
for r in native['records']:
    key=native.get('binary_sources',{}).get(r['key'],r['key'])
    row=programs.setdefault(key,{'key':key,'kind':r['kind'],'source':job(key),'instances':0,'draws':0,'binds':0,'link_us':0,'import_us':0,'status_us':0,'first_draw_utc':0,'linked_utc':r['linked_utc'],'has_links':False})
    row['has_links']=row['has_links'] or r['kind']=='linked'
    row['instances']+=1
    for field in ('draws','binds','status_us'):row[field]+=r[field]
    row['link_us' if r['kind']=='linked' else 'import_us']+=r['link_us']
    if r['first_draw_utc'] and (not row['first_draw_utc'] or r['first_draw_utc']<row['first_draw_utc']):row['first_draw_utc']=r['first_draw_utc']
    row['linked_utc']=min(row['linked_utc'],r['linked_utc'])
linked=[r for r in programs.values() if r['has_links'] and r['source']['family']!='control']
unused=[r for r in linked if not r['draws']]
families={}
for family in sorted({r['source']['family'] for r in linked}):
    rows=[r for r in linked if r['source']['family']==family];un=[r for r in rows if not r['draws']]
    families[family]={'linked':len(rows),'not_drawn':len(un),'link_ms':sum(r['link_us'] for r in rows)/1000,'not_drawn_link_ms':sum(r['link_us'] for r in un)/1000}
summary={'label':label,'installed':native['installed'],'failures':native['failures'],'context_mismatches':native['context_mismatches'],
    'controls_passed':'USAGE_CONTROLS unused_bound=1 used_fast_array=1 PASS' in log,
    'unique_linked_programs':len(linked),'not_drawn_programs':len(unused),
    'link_ms':sum(r['link_us'] for r in linked)/1000,'not_drawn_link_ms':sum(r['link_us'] for r in unused)/1000,
    'link_status_ms':sum(r['status_us'] for r in linked)/1000,
    'draws':sum(r['draws'] for r in native['records']),
    'binary_imports':native['binary_imports'],'preexisting_programs':sum(r['kind']=='preexisting' for r in programs.values()),
    'mapped_imports':sum(r['kind']=='binary' and r['key'] in native.get('binary_sources',{}) for r in native['records']),
    'families':families,'programs':list(programs.values()),
    'phases':re.findall(r'USAGE_PHASE (\w+) (\d+)',log)}
cases=[];pending=None
for line in log.splitlines():
    if line.startswith('RACE_BEGIN '):
        _,theme,cycle,utc=line.split();pending={'theme':theme,'cycle':int(cycle),'utc':int(utc)}
    elif line.startswith('FIRST_USE_ROW ') and pending:
        row=json.loads(line[len('FIRST_USE_ROW '):]);end=pending['utc']+row['wall_us']
        rr=[r for r in native['records'] if r['kind']=='linked' and pending['utc']<=r['linked_utc']<=end]
        un=[r for r in rr if not programs[r['key']]['draws']]
        cases.append({**pending,'wall_ms':row['wall_us']/1000,'linked':len({r['key'] for r in rr}),
            'not_drawn_through_run':len({r['key'] for r in un}),'link_ms':sum(r['link_us'] for r in rr)/1000,
            'not_drawn_link_ms':sum(r['link_us'] for r in un)/1000});pending=None
summary['cases']=cases
defaults=[r for r in unused if r['source'].get('default_full_signature')]
summary['not_drawn_default_full_signature']={'count':len(defaults),'link_ms':sum(r['link_us'] for r in defaults)/1000}
if summary['phases']:
    ready=int(next(t for name,t in summary['phases'] if name=='ready'))
    prepared=[r for r in linked if r['linked_utc']<=ready]
    late=[r for r in prepared if r['first_draw_utc']>ready]
    summary['opening_lap']={'linked_by_ready':len(prepared),'not_drawn_by_ready':sum(not r['first_draw_utc'] or r['first_draw_utc']>ready for r in prepared),
        'first_used_after_ready':len(late),'first_used_after_ready_keys':[r['key'] for r in late],
        'new_linked_after_ready':sum(r['linked_utc']>ready for r in linked)}
(p/(label+'-analysis.json')).write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='programs'},indent=2))
