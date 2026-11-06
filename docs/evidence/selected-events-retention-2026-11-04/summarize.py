"""Keep all attempts, source revisions, assertions and engine diagnostics."""
import hashlib
import json
from pathlib import Path
import re

evidence=Path(__file__).resolve().parent
root=evidence.parents[2]
runtime=['game/core/app.gd','game/core/features/selected_track.gd','game/core/features/daily.gd',
         'game/core/features/rivalry.gd','game/race/selected_event.gd','game/ui/track_of_day_page.gd',
         'game/editor/road_preparation.gd','game/editor/editor_memory.gd','game/track/native_track_visual.gd',
         'game/track/prepared_world_cache.gd','game/track/winter_snow_wind.gd']
current={path:hashlib.sha256((root/path).read_bytes()).hexdigest() for path in runtime}
summary={'runtime_sha256':current,'runs':{}}
for path in sorted(evidence.glob('*-receipt.json')):
    label=path.name.removesuffix('-receipt.json')
    receipt=json.loads(path.read_text(encoding='utf-8'))
    log=(evidence/(label+'.log')).read_text(encoding='utf-8',errors='replace')
    result_path=evidence/(label+'.json')
    if not result_path.exists(): result_path=evidence/label/'report.json'
    result=json.loads(result_path.read_text(encoding='utf-8')) if result_path.exists() else {}
    checks,failures=result.get('checks'),result.get('failures')
    if checks is None:
        matches=re.findall(r'(\d+) checks,\s*(\d+) failures',log)
        if not matches: matches=re.findall(r'checks=(\d+) failures=(\d+)',log)
        if matches: checks,failures=map(int,matches[-1])
    summary['runs'][label]={'exit_code':receipt['exit_code'],'checks':checks,'failures':failures,
        'source_changes':receipt['changed_sources'],
        'runtime_changes':[name for name in runtime if receipt['before'].get(name)!=receipt['after'].get(name)],
        'matches_final_runtime':all(receipt['after'].get(name)==current[name] for name in runtime),
        'matches_final_event_runtime':all(receipt['after'].get(name)==current[name] for name in runtime[:6]),
        'matches_final_scenery_runtime':all(receipt['after'].get(name)==current[name] for name in runtime[6:]),
        'engine_errors':[line for line in log.splitlines() if 'ERROR:' in line or 'TIMEOUT' in line],
        'warnings':[line for line in log.splitlines() if 'WARNING:' in line],
        'rows':result.get('rows',[]),'renderer':result.get('renderer')}
labels=['final-scenery-compat','mobile-settled','accepted-events-native','accepted-events-headless',
        'accepted-daily-install','accepted-memory','accepted-selective-budget',
        'accepted-surface-leases','final-wind-compat']
summary['accepted_assertion_runs']={label:summary['runs'].get(label) for label in labels}
summary['accepted_assertions']=sum(run['checks'] or 0 for run in summary['accepted_assertion_runs'].values() if run)
summary['accepted_assertions_pass']=all(run and run['exit_code']==0 and run['failures']==0 for run in summary['accepted_assertion_runs'].values())
(evidence/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
print(json.dumps({name:{key:run[key] for key in ('exit_code','checks','failures','matches_final_runtime')} for name,run in summary['runs'].items()},indent=2))
