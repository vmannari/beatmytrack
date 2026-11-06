"""Small review summary; raw measurements and failed attempts remain alongside it."""
import collections,json,statistics
from pathlib import Path
p=Path(__file__).resolve().parent
result={'native':{},'pixels':{},'first_draw':{}}
for label in ('pine-native-baseline','pine-native-prune','final-native'):
    a=json.loads((p/(label+'-analysis.json')).read_text())
    profile=json.loads((p/label/'profile.json').read_text())
    features=collections.Counter()
    for program in a['programs']:
        if program['source'].get('flags'):
            features.update(f for f in program['source']['defines'] if f=='CUSTOM_RADIANCE_USED')
    result['native'][label]={'calls_over_2ms_us':a['native_us'],'rows':profile['rows'],
        'surface_features':dict(features),'capture':json.loads((p/label/'native-report.json').read_text()),
        'world_draw_us':sum(d['us'] for d in a['draws'] if d['kind']=='world' and d['case']=='pine-0'),
        'particle_draw_us':sum(d['us'] for d in a['draws'] if d['kind']=='particles' and d['case']=='pine-0')}
for path in p.glob('*/report.json'):
    report=json.loads(path.read_text())
    if 'themes' not in report: continue
    themes={}
    for theme,row in report['themes'].items():
        gpu={mode:statistics.mean(s['gpu_ms']['p50'] for s in row['stages'] if s['mode']==mode) for mode in ('baseline','optimized')}
        themes[theme]={'proofs':row['proofs'],'gpu_p50_ms_mean':gpu,'sources':[row['baseline_programs'],row['candidate_programs']]}
    result['pixels'][path.parent.name]={'checks':report['checks'],'failures':report['failures'],'themes':themes}
for path in p.glob('*/first-draw.json'):
    report=json.loads(path.read_text())
    rows={}
    for theme in sorted(set(r['theme'] for r in report['rows'])):
        rows[theme]={mode:[r['elapsed_ms'] for r in report['rows'] if r['theme']==theme and r['mode']==mode] for mode in ('baseline','candidate')}
    result['first_draw'][path.parent.name]=rows
(p/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({key:list(value) for key,value in result.items()}))
