"""Graph measurements and actual qualification receipts for the narrow boundary."""
import hashlib
import json
from pathlib import Path

out = Path(__file__).resolve().parent
root = out.parents[3]
rows = []
for label in ['showroom','pictures','memory']:
    arms = {}
    for arm in ['control','candidate']:
        folder = out/('graph-'+label+'-'+arm)
        arms[arm] = {'result':json.loads((folder/'result.json').read_text()),'run':json.loads((folder/'run.json').read_text())}
    before = arms['control']['result']['load_us']
    after = arms['candidate']['result']['load_us']
    rows.append({'target':label,'before_us':before,'after_us':after,'reduction_percent':100*(1-after/before),'arms':arms})
runs = {}
for folder in sorted(out.iterdir()):
    if folder.is_dir() and folder.name.startswith('world-') and (folder/'run.json').exists():
        runs[folder.name] = {'run':json.loads((folder/'run.json').read_text())}
        if (folder/'result.json').exists(): runs[folder.name]['result'] = json.loads((folder/'result.json').read_text())
summary = {
    'requirement':'LHF-RACE02',
    'change':'Generic Node3D parameters for the two cooperative world-cache methods, matching the existing synchronous boundary.',
    'runtime':'game/track/prepared_world_cache.gd',
    'runtime_sha256':hashlib.sha256((root/'game/track/prepared_world_cache.gd').read_bytes()).hexdigest(),
    'before_sha256':hashlib.sha256((out/'prepared_world_cache.before.gd').read_bytes()).hexdigest(),
    'graphs':rows,'qualification':runs,
    'guards_or_asset_files_changed':False,
    'limitations':[
        'One fresh desktop headless process per arm/target; component script-loading measurement, not first-menu or phone latency.',
        'All car builders still load. EditorMemory independently references NativeTrackVisual and retains that graph.',
        'CarVisual fallback extraction was not pursued after this substantially smaller boundary removed approximately 1.2 seconds from preview graph loading.',
        'The source is outside the prepared vehicle dependency manifest; existing resource preflight qualifies its original scenes without a rebuild.',
        'Independent review found existing callers still provide the cooperative NativeTrackVisual methods and fields; Node3D no longer statically expresses that full interface.',
        'Conservative Garage/header photograph identities can advance for this source change even though geometry keys and bundled photographs remain valid.',
        'The lighter preview graph can defer or split later AppMemory world-script loading; whole-App savings require the parent combined timing evidence.',
    ]}
(out/'world-type-summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'graphs':[{k:row[k] for k in ['target','before_us','after_us','reduction_percent']} for row in rows],'qualification':list(runs)},indent=2))
