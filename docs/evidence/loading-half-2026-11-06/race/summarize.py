"""Collect actual race-retention runs and build the task-only source patch."""
import difflib
import hashlib
import json
from pathlib import Path
import statistics

out = Path(__file__).resolve().parent
root = out.parents[3]
runs = {}
for folder in sorted(out.iterdir()):
    if not folder.is_dir() or not (folder/'run.json').exists():
        continue
    runs[folder.name] = json.loads((folder/'run.json').read_text(encoding='utf-8'))
pairs = {}
for label, old_name, new_name in [
    ('initial', 'before-races-a', 'after-races-a'),
    ('same_project', 'control-races-c', 'candidate-races-c'),
]:
    if old_name not in runs or new_name not in runs:
        continue
    old = json.loads((out/old_name/'result.json').read_text())
    new = json.loads((out/new_name/'result.json').read_text())
    rows = []
    for a, b in zip(old['samples'], new['samples']):
        assert (a['theme'], a['cycle']) == (b['theme'], b['cycle'])
        def stages(row):
            marks = {mark['name']:mark['us'] for mark in row['marks']}
            return {phase:(marks[phase+'_end']-marks[phase+'_begin'])/1000
                    for phase in ['roads','game','graphics','effects']}
        rows.append(dict(theme=a['theme'],cycle=a['cycle'],
                         before_ms=a['wall_ms'],after_ms=b['wall_ms'],
                         reduction_percent=100*(1-b['wall_ms']/a['wall_ms']),
                         before_effect_ms=a['effects_finish_ms'],after_effect_ms=b['effects_finish_ms'],
                         before_reused=a['effect_counts']['reused'],after_reused=b['effect_counts']['reused'],
                         before_stages_ms=stages(a),after_stages_ms=stages(b)))
    medians = {}
    for theme in ['pine','winter','desert']:
        warm = [row for row in rows if row['theme']==theme and row['cycle']>0]
        before = statistics.median(row['before_ms'] for row in warm)
        after = statistics.median(row['after_ms'] for row in warm)
        medians[theme] = dict(before_ms=before,after_ms=after,reduction_percent=100*(1-after/before))
    pairs[label] = dict(before_run=old_name,after_run=new_name,rows=rows,warm_medians=medians)

summary = dict(
    requirement_ids=['LHF-RACE01','LHF-RACE02','LHF-RACEQ01'],
    requirement='Retain completed race-effect preparation before independent road caches within the existing allowance.',
    runtime_files=['game/editor/editor_memory.gd','game/track/prepared_world_cache.gd'],
    limits=dict(retained_mib=64,roads_mib=32,worlds_mib=64,effect_pool_mib=12),
    runs=runs,pairs=pairs,
    limitations=[
        'Desktop Compatibility, RTX 3090; no device test, backend request, export or deployment.',
        'One changed arbitration order; no rendering, track geometry, canonical simulation, countdown or lap-count changes.',
        'Initial timing pair used separate frozen projects; candidate arm overlapped another agent headless storage test. Retained but excluded as the primary timing comparison.',
        'Same-project pair changes only the optional memory policy through an evaluation adapter; first-use measurements are not cold-driver claims.',
        'Two warm entries per theme and policy are observations, not a statistical or phone-performance guarantee.',
        'Native scenery check retains the pre-existing two-ObjectDB/one-resource shutdown leak; assertions and pixel comparisons are not relaxed.',
        'The first new fixture run misused add_child on a borrowed node; corrected to reparent. Raw failure retained.',
        'The first same-project adapter replaced the lazy facade instead of its policy and failed before installation; corrected to replace only _policy. Raw failure retained.',
        'Initial strict reverse patch check rejected CRLF patch output for newly authored LF files; writer now emits LF. Strict reverse and isolated normalized forward application pass.',
    ])
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
patch = []
for relative in ['game/editor/editor_memory.gd','game/track/prepared_world_cache.gd','game/tests/test_race_effect_retention.gd','game/tests/profile_race_retention_policy.gd']:
    path = root/relative
    snapshots = {'game/editor/editor_memory.gd':'editor_memory.before.gd','game/track/prepared_world_cache.gd':'prepared_world_cache.before.gd'}
    before = (out/snapshots[relative]).read_text() if relative in snapshots else ''
    after = path.read_text()
    patch.extend(difflib.unified_diff(before.splitlines(True),after.splitlines(True),
                                    fromfile='a/'+relative if before else '/dev/null',tofile='b/'+relative))
(out/'task-source.patch').write_bytes(''.join(patch).encode('utf-8'))
print(json.dumps({'runs':len(runs),'pairs':pairs,'patch_sha256':hashlib.sha256((out/'task-source.patch').read_bytes()).hexdigest()},indent=2))
