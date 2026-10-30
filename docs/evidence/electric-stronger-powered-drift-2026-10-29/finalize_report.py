import hashlib
import json
from pathlib import Path

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
source=hashlib.sha256((ROOT/'game/resources/cars/electric.tres').read_bytes()).hexdigest()
latest={entry['job']:entry for entry in json.loads((OUT/'commands.json').read_text())}
jobs=['drift','controls','acceleration','historical-drift','turning','driving','parse-own']
for job in jobs: assert latest[job]['exit_code']==0 and latest[job]['source_sha256']==source,job
drift=json.loads((OUT/'drift/power-increment.json').read_text())
assert drift['failures']==0
turns=drift['metrics']['turns']
canonical=json.loads((OUT/'canonical-verification.json').read_text())
driving=json.loads((OUT/'driving/over-under.json').read_text())
assert driving['failures']==0 and driving['metrics']['contacts']==0
assert canonical['electric']==drift['metrics']['electric']
assert canonical['time_ticks']==driving['metrics']['time_ticks']
fixture=json.loads((ROOT/'backend/tests/fixtures/verified_oval.json').read_text())
assert fixture['expected_manifest']['vehicles']['electric']==canonical['electric']
before=json.loads((OUT/'before/backend/tests/fixtures/verified_oval.json').read_text())
fixture['expected_manifest']['vehicles']['electric']=before['expected_manifest']['vehicles']['electric']
assert fixture==before
checkpoint=json.loads((OUT/'checkpoint.json').read_text())
assert checkpoint['forward_exact'] and checkpoint['reverse_exact']
report=dict(date='2026-10-29',requirements=['EPD01','EPD02','R01','Q01'],
            resource_sha256=source,handling=canonical['electric'],focused_checks=drift['checks'],
            failures=drift['failures'],cases=len(turns),representative=turns['50.0/1.0/0.65'],
            maximum_peak_degrees=max(turn['after']['peak'] for turn in turns.values()),
            minimum_speed_retained_percent=min(turn['after']['end_kph']/turn['before']['end_kph']*100 for turn in turns.values()),
            maximum_recovery_ms=max(turn['after']['recovery_ms'] for turn in turns.values()),
            controls_checks=102,acceleration_checks=417,historical_drift_checks=417,turning_checks=430,
            driving=driving,canonical_verification=canonical,verified_jobs=jobs,
            initial_failure='Five-lap fixture could not create its evidence output; directory created by runner and rerun passed. Initial log retained.',
            limitations=['Reload/rebuild and owner driving-feel acceptance remain.',
                         'Matching authorised backend handling-contract rollout remains before online use.',
                         'No physical-device query/test, APK, owner-save/live/backend mutation, deployment or owner restart.',
                         'No shared-index staging/commit/merge; concurrent model and generated identities preserved.'],
            checkpoint={key:value for key,value in checkpoint.items() if key!='hashes'})
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'handling':canonical['electric'],'checks':drift['checks'],
                  'race_inputs':canonical['input_count'],'patch_sha256':checkpoint['patch_sha256']}))
