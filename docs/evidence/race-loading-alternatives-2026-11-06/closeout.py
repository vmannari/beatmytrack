"""Verify the feasibility probe and record the investigation without runtime edits."""
import hashlib,json,statistics
from pathlib import Path
p=Path(__file__).resolve().parent;root=p.parents[2]
def read(name):return json.loads((p/name).read_text())
result=read('layout-artifact-fixed.json');receipt=read('layout-artifact-fixed-receipt.json')
assert result['checks']==45 and result['failures']==0 and len(result['rows'])==3
assert receipt['exit_code']==0 and receipt['before']==receipt['after'] and not receipt['script_errors']
initial=read('layout-artifact-receipt.json')
assert initial['exit_code']!=0 and initial['script_errors']
rows=[]
for row in result['rows']:
    assert len(row['samples'])==5
    rows.append({'fixture':row['fixture'],'build_ms':row['build_us']/1000,'bytes':row['payload_bytes'],
        'median_restore_ms':statistics.median(r['total_us'] for r in row['samples'])/1000,
        'minimum_restore_ms':min(r['total_us'] for r in row['samples'])/1000,
        'maximum_restore_ms':max(r['total_us'] for r in row['samples'])/1000})
g=Path(read('frozen-project.json')['project'])
assert (g/'tests/probe_layout_artifact.gd').read_bytes()==(p/'probe_layout_artifact.gd').read_bytes()
sources=['game/core/app.gd','game/core/features/race.gd','game/race/selected_track_preparation.gd',
    'game/race/checkpoint_layout_cache.gd','game/race/track_session.gd','game/track/prepared_world_cache.gd',
    'game/rendering/graphics_preparation.gd','game/vehicle/vehicle_weathering.gd']
source_state={name:{'sha256':hashlib.sha256((root/name).read_bytes()).hexdigest(),
    'matches_review_snapshot':(root/name).read_bytes()==(g/name.removeprefix('game/')).read_bytes()} for name in sources}
summary={'checks':45,'failures':0,'rows':rows,'sources_stable_during_probe':True,
    'initial_parse_failure_retained':initial['script_errors'],'reviewed_sources':source_state,
    'limits':['headless component only','freshly written files / warm OS cache','no restart or device measurement',
        'no production artifact validator','no full-race or graphics speedup measured'],'runtime_modified':False}
(p/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
marker=b'<!-- RACE-LOADING-ALTERNATIVES-20261106 -->'
block='''<!-- RACE-LOADING-ALTERNATIVES-20261106 -->
## Alternative race-loading implementations investigated (2026-11-06)
RLA01-RLA03: Investigation only. Frozen headless exact-layout artifact probe45/0 across Star/Over-and-Under/Knot; current Star build3.633s versus19.030ms median geometry-key/read/decode/install,159200bytes. Freshly written files, no cold-storage/restart/device/whole-loading claim; full artifact validation remains unimplemented. Recommend bounded persistent layouts first, native variant-use/existing-binary-cache audit next, then selective/parallel in-context preparation and native lane arithmetic. Pinned engine eagerly initializes base variants and already caches binaries; broad weathering splits remain rejected. Scenery artifacts, threaded feature loading and Mobile renderer tradeoffs distinguished from existing improvements. Initial decoder-signature parse failure retained; shipping sources unchanged. [Evidence, implementation options, primary references and task-only checkpoint](docs/RACE_LOADING_ALTERNATIVES_2026_11_06.md). No device query/test, APK, owner-save/process change, backend/live request, deployment or main-index write; concurrent work preserved.
<!-- /RACE-LOADING-ALTERNATIVES-20261106 -->

'''.encode()
for name in ('AGENTS.md','DEVELOPMENT_STATUS.md'):
    file=root/name;old=file.read_bytes()
    if marker not in old:file.write_bytes(block+old)
print(json.dumps(summary,indent=2))
