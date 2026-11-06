"""Keep all attempts, assertions, errors and source scope beside the native proof."""
import hashlib
import json
from pathlib import Path
import re

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
runtime = ['game/rendering/graphics_preparation.gd','game/race/world_render_preparation.gd',
           'game/ui/garage_first_draw.gd','game/ui/garage_preloaded_studio.gd',
           'game/ui/garage_opening_showroom.gd','game/ui/header_car_appearance_cache.gd',
           'game/ui/garage_preview_cache.gd']
current = {path:hashlib.sha256((root/path).read_bytes()).hexdigest() for path in runtime}
summary = dict(runtime_sha256=current,runs={})
for receipt_path in sorted(evidence.glob('*-receipt.json')):
    label = receipt_path.name.removesuffix('-receipt.json')
    receipt = json.loads(receipt_path.read_text(encoding='utf-8'))
    result_path = evidence/(label+'.json')
    if not result_path.exists(): result_path = evidence/label/'report.json'
    result = json.loads(result_path.read_text(encoding='utf-8')) if result_path.exists() else {}
    log = (evidence/(label+'.log')).read_text(encoding='utf-8',errors='replace')
    checks,failures = result.get('checks'),result.get('failures')
    if checks is None:
        matches = re.findall(r'(\d+) checks,\s*(\d+) failures',log)
        if matches: checks,failures = map(int,matches[-1])
    summary['runs'][label] = dict(exit_code=receipt['exit_code'],checks=checks,failures=failures,
        source_changes=receipt['changed_sources'],
        runtime_changes=[path for path in runtime if receipt['before'].get(path)!=receipt['after'].get(path)],
        matches_final_runtime=all(receipt['after'].get(path)==current[path] for path in runtime),
        engine_errors=[line for line in log.splitlines() if 'ERROR:' in line or 'TIMEOUT' in line],
        warnings=[line for line in log.splitlines() if 'WARNING:' in line],
        rows=result.get('rows',result.get('samples',[])),first_laps=result.get('first_laps',[]))
labels = ['final-components-compat','final-components-mobile','final-buckets','final-editor',
          'final-warm','final-garage','final-header','final-thumbnails','final-entry',
          'same-owner-race-final','final-compat-laps']
selected = {label:summary['runs'].get(label) for label in labels}
summary['selected_final'] = dict(labels=labels,
    complete=all(run is not None for run in selected.values()),
    assertions=sum(run['checks'] or 0 for run in selected.values() if run is not None),
    all_pass=all(run is not None and run['exit_code']==0 and run['failures']==0
                 and run['matches_final_runtime'] and not run['source_changes']
                 and not run['warnings'] and all('root certificate store' in error for error in run['engine_errors'])
                 for run in selected.values()))
(evidence/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
print(json.dumps({label:{key:run[key] for key in ('exit_code','checks','failures','matches_final_runtime','runtime_changes')}
                  for label,run in summary['runs'].items()},indent=2))
