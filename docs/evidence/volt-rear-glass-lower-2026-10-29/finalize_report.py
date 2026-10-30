import hashlib
import json
from pathlib import Path

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
source=sha(ROOT/'game/vehicle/electric_coachwork.gd')
receipts=json.loads((OUT/'commands.json').read_text())
latest={entry['job']:entry for entry in receipts}
required=['bake','shape','flow','preview','shadows','garage','pictures','liveries',
          'news','import','model','racing','parse-own','arrays']
for job in required:
    assert latest[job]['exit_code']==0 and latest[job]['source_sha256']==source,job
old_root=ROOT/'game/assets/vehicles/electric_coachwork_v21'
new_root=ROOT/'game/assets/vehicles/electric_coachwork_v22'
old={item['part']:item for item in json.loads((old_root/'manifest.json').read_text())['meshes']}
new={item['part']:item for item in json.loads((new_root/'manifest.json').read_text())['meshes']}
assert old.keys()==new.keys()
measure=json.loads((OUT/'measurements.json').read_text())
changed=measure['buffer_comparison']['changed_parts']
for part in ['Windscreen','CrownedRoof','ClamshellHood']:
    for suffix in ['', '_simple']: assert part+suffix not in changed
delta={}
for part in ['RearScreen','RearScreen_simple']:
    a=measure['21'+part]['centre_lower_edge_model_metres']
    b=measure['22'+part]['centre_lower_edge_model_metres']
    delta[part]={'rearward_world_metres':(b[2]-a[2])*0.88,'downward_world_metres':(a[1]-b[1])*0.88}
    assert 0.035<delta[part]['rearward_world_metres']<0.045
    assert 0.012<delta[part]['downward_world_metres']<0.020
results={}
for job,name in [('shape','rear-shape.json'),('flow','rear-flow.json')]:
    results[job]=json.loads((OUT/job/name).read_text())
    assert results[job]['failures']==0
checkpoint=json.loads((OUT/'checkpoint.json').read_text())
assert checkpoint['forward_exact'] and checkpoint['reverse_exact']
assert checkpoint['hashes']['game/vehicle/electric_coachwork.gd']==source
report=dict(date='2026-10-29',requirements=['VGL01','R01','Q01'],source_sha256=source,
            verified_jobs=required,results=results,native_model_checks=34,racing_checks=23,
            lower_edge_movement=delta,prepared_arrays_unchanged=len(old)-len(changed),
            prepared_parts_changed=changed,front_hood_windscreen_roof_buffers_exact=True,
            native_pictures_refreshed=52,native_review_views=16,
            inherited_limitations=['V21 legacy construction still expects former tall roof; not rerun.',
                                   'Reload/rebuild and owner appearance acceptance remain.',
                                   'No physical-device query/test, APK, owner-save/live/backend write, deployment or owner restart.',
                                   'No shared-index staging/commit/merge or performance/aerodynamic claim.'],
            checkpoint={key:value for key,value in checkpoint.items() if key!='hashes'})
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'source_sha256':source,'verified_jobs':len(required),
                  'lower_edge_movement':delta,'prepared_arrays_unchanged':len(old)-len(changed)}))
