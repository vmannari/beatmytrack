"""Summarize explicit receipts without counting failed diagnostics as passes."""
import hashlib
import json
from pathlib import Path
import re
import statistics

EVIDENCE=Path(__file__).resolve().parent
ROOT=EVIDENCE.parents[2]
result={'runs':{},'visuals':{},'construction':{},'construction_by_run':{},'assets':{}}
for receipt_path in sorted(EVIDENCE.glob('*-receipt.json')):
    if receipt_path.name in ('source-receipt.json',): continue
    receipt=json.loads(receipt_path.read_text(encoding='utf-8'))
    if 'exit_code' not in receipt: continue
    label=receipt_path.name.removesuffix('-receipt.json')
    log=(EVIDENCE/(label+'.log')).read_text(encoding='utf-8')
    counts=re.findall(r'(\d+) checks, (\d+) failures',log)
    result['runs'][label]={'exit_code':receipt['exit_code'],'counts':counts[-1] if counts else None,
        'changed_sources':receipt.get('changed_sources',[]),
        'errors':[line for line in log.splitlines() if 'ERROR:' in line or 'FAIL:' in line]}
    visual=EVIDENCE/label/'report.json'
    if visual.exists() and label.startswith('visuals-'):
        data=json.loads(visual.read_text(encoding='utf-8'))
        result['visuals'][label]={'checks':data['checks'],'failures':data['failures'],'cases':len(data['rows']),
            'maximum_mean_channel_delta_255':max(row['difference']['mean_rgb_delta'] for row in data['rows']),
            'maximum_pixels_over_8_fraction':max(row['difference'].get('pixels_over_8_fraction',0) for row in data['rows'])}
    if label.startswith('construction-'):
        rows=[json.loads(line.split(' ',1)[1]) for line in log.splitlines() if line.startswith('MODULAR_CAR_PROFILE ')]
        result['construction_by_run'][label]={}
        for vehicle in sorted({row['vehicle'] for row in rows}):
            selected=[row for row in rows if row['vehicle']==vehicle]
            result['construction_by_run'][label][vehicle]={'all_samples':selected,
                'warm_procedural_median_ms':statistics.median(row['wall_ms'] for row in selected if not row['modular'] and row['repetition']>0),
                'warm_prepared_median_ms':statistics.median(row['wall_ms'] for row in selected if row['modular'] and row['repetition']>0)}
        if label=='construction-runtime-final': result['construction']=result['construction_by_run'][label]
baseline=json.loads((EVIDENCE/'baseline.json').read_text(encoding='utf-8'))
result['assets']['scene_bytes_before']=sum((EVIDENCE/'before'/path).stat().st_size for path in baseline['assets'])
result['assets']['scene_bytes_after']=sum((ROOT/path).stat().st_size for path in baseline['assets'])
result['assets']['changed_scenes']=[path for path in baseline['assets'] if hashlib.sha256((ROOT/path).read_bytes()).hexdigest()!=baseline['hashes'][path]]
for label in ('pipeline-final','pipeline-idempotent','pipeline-geometry-picture-provenance','pipeline-picture-bindings','pipeline-idempotent-final','verify-final','pipeline-runtime-guards-final','pipeline-runtime-idempotent','verify-runtime-final'):
    folder=EVIDENCE/label
    commands=folder/'commands.json'
    if commands.exists(): result[label]=json.loads(commands.read_text(encoding='utf-8'))
accepted=('modular-runtime-final-all-options','garage-runtime-final-headless','header-runtime-final-headless',
          'visuals-runtime-final-compat','visuals-runtime-final-mobile',
          'garage-runtime-final-compat','garage-runtime-final-mobile')
result['accepted_runs']={label:result['runs'][label] for label in accepted}
assert all(run['exit_code']==0 and run['counts'][1]=='0' for run in result['accepted_runs'].values())
assert all(not any('root certificate store' not in error for error in run['errors']) for run in result['accepted_runs'].values())
assert all(row['base_hits']==1 and row['kit_hits']==4 for data in result['construction'].values() for row in data['all_samples'] if row['modular'])
result['selected_assertion_total']=sum(int(run['counts'][0]) for run in result['accepted_runs'].values())+1925+128+2+18+68+5
(EVIDENCE/'summary.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({key:result[key] for key in ('visuals','construction')},indent=2))
