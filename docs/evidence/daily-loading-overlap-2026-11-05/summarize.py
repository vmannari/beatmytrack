"""Keep all attempts and select final scoped acceptance by runtime hashes."""
import hashlib
import json
from pathlib import Path
import re

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
runtime = ['game/core/features/race.gd', 'game/race/daily_start_preparation.gd']
final_hashes = {path: hashlib.sha256((root/path).read_bytes()).hexdigest() for path in runtime}
summary = {'runtime_sha256': final_hashes, 'runs': {}}
for receipt_path in sorted(evidence.glob('*-receipt.json')):
    label = receipt_path.name.removesuffix('-receipt.json')
    receipt = json.loads(receipt_path.read_text(encoding='utf-8-sig'))
    log = (evidence/(label+'.log')).read_text(encoding='utf-8', errors='replace')
    path = evidence/(label+'.json')
    result = json.loads(path.read_text(encoding='utf-8')) if path.exists() else {}
    matches = re.findall(r'(\d+) checks,? (\d+) failures', log)
    checks, failures = (int(value) for value in matches[-1]) if matches else (0, 0)
    run = {'exit_code':receipt['exit_code'], 'checks':result.get('checks', checks),
           'failures':result.get('failures', failures), 'elapsed_seconds':receipt['elapsed_seconds'],
           'changed_sources':receipt['changed_sources'],
           'final_runtime':all(receipt['before'].get(path) == value == receipt['after'].get(path)
                               for path, value in final_hashes.items()),
           'diagnostics':[line for line in log.splitlines() if line.startswith(('ERROR:', 'WARNING:', 'SCRIPT ERROR:'))]}
    if result.get('rows'): run['rows'] = result['rows']
    summary['runs'][label] = run
selected = {'final-focused-headless-v3','final-focused-native-v2','final-timing-v3','final-worker-v2',
            'final-daily-app','final-daily-metadata','final-daily-event','final-selected-events-v2'}
accepted = [label for label, run in summary['runs'].items()
            if label in selected
            and run['exit_code'] == 0 and run['failures'] == 0 and run['final_runtime']
            and not run['changed_sources']
            and not any(line != 'ERROR: Failed to read the root certificate store.' for line in run['diagnostics'])]
summary['accepted_clean_runs'] = accepted
summary['accepted_checks'] = sum(summary['runs'][label]['checks'] for label in accepted)
(evidence/'summary.json').write_text(json.dumps(summary, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'accepted_clean_runs':accepted, 'accepted_checks':summary['accepted_checks'],
                  'runs':{key:{k:r[k] for k in ('exit_code','checks','failures','final_runtime','changed_sources','diagnostics')}
                          for key,r in summary['runs'].items()}}, indent=2))
