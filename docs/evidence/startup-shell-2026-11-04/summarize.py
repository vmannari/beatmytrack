"""Keep accepted frozen results separate from iterations and retained controls."""
import json
from pathlib import Path
import re

evidence = Path(__file__).resolve().parent
accepted = ['cold-closure-final','app-owned','music-owned','daily-owned','race-owned',
            'closure-lifetime-final','header-rich-seed-final','header-rich-reuse-final',
            'flow-control','flow-candidate-owned','flow-mobile-owned','rivalry-menu-seeded']
timings = [p.stem for p in sorted(evidence.glob('timing-*.json')) if not p.stem.endswith(('receipt','running'))]
report = {'timings':{},'checks':{},'retained':{},'pixels':{}}
for label in timings+accepted+['swipe-final','swipe-control']:
    receipt_path = evidence/(label+'-receipt.json')
    if not receipt_path.exists(): continue
    receipt = json.loads(receipt_path.read_text(encoding='utf-8'))
    log = (evidence/(label+'.log')).read_text(encoding='utf-8')
    output_path = evidence/(label+'.json')
    data = json.loads(output_path.read_text(encoding='utf-8')) if output_path.exists() else {}
    rows = re.findall(r'(?:APP_TESTS:|STARTUP_MUSIC:|DAILY_ELIMINATION_APP:|RACE_LOADING:|MENU_PAGE_SWIPE:|FEATURE_LIFETIME|RIVALRY_SHELL)\s*(\d+) checks, (\d+) failures',log)
    if label.startswith('cold-'):
        rows += re.findall(r'SHELL_READY (\d+) checks (\d+) failures',log)
    if rows: data.update(checks=int(rows[-1][0]),failures=int(rows[-1][1]))
    if label.startswith('header-rich-'):
        path = evidence/(label+'-views/report.json')
        if path.exists(): data.update(json.loads(path.read_text(encoding='utf-8')))
    row = dict(exit_code=receipt['exit_code'],changed_sources=receipt['changed_sources'],result=data,
               engine_errors=[line for line in log.splitlines() if 'ERROR:' in line and 'root certificate store' not in line])
    if label in timings: report['timings'][label] = row
    elif label in accepted: report['checks'][label] = row
    else: report['retained'][label] = row
for label in ('swipe-final','swipe-control'):
    log = (evidence/(label+'.log')).read_text(encoding='utf-8')
    report['retained'][label]['failure_labels'] = [line for line in log.splitlines() if line.startswith('FAIL:')]
report['retained']['swipe_failure_labels_identical'] = report['retained']['swipe-final']['failure_labels'] == report['retained']['swipe-control']['failure_labels']
for path in evidence.glob('pixels-*.json'):
    if path.stem.endswith(('receipt','running')): continue
    report['pixels'][path.stem] = json.loads(path.read_text(encoding='utf-8'))
report['accepted_checks'] = sum(row['result'].get('checks',0) for row in report['checks'].values())
report['accepted_failures'] = sum(row['result'].get('failures',0) for row in report['checks'].values())
(evidence/'summary.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'timings':len(report['timings']),'accepted_runs':len(report['checks']),
                 'checks':report['accepted_checks'],'failures':report['accepted_failures'],
                 'swipe_failure_labels_identical':report['retained']['swipe_failure_labels_identical']}))
