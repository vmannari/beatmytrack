import hashlib
import json
from pathlib import Path

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
sources={name:sha(ROOT/('game/vehicle/'+name)) for name in ['electric_coachwork.gd','electric_car_model.gd','vehicle_livery.gd']}
latest={entry['job']:entry for entry in json.loads((OUT/'commands.json').read_text())}
required=['bake','preview','refinement','bonnet','shape','flow','shadows','garage',
          'pictures','liveries','news','import','preview-mobile','model','app','racing','parse-own','body']
for job in required:
    assert latest[job]['exit_code']==0 and latest[job]['source_sha256']==sources['electric_coachwork.gd'],job
manifest=json.loads((ROOT/'game/assets/vehicles/electric_coachwork_v23/manifest.json').read_text())
assert manifest['source_sha256']==sources['electric_coachwork.gd']
assert manifest['model_sha256']==sources['electric_car_model.gd']
assert latest['body']['model_sha256']==sources['electric_car_model.gd']
assert latest['body']['livery_sha256']==sources['vehicle_livery.gd']
results={}
for job,filename in [('refinement','refinement.json'),('bonnet','convex-hood.json'),('shape','rear-shape.json'),('flow','rear-flow.json')]:
    results[job]=json.loads((OUT/job/filename).read_text())
    assert results[job]['failures']==0
body=json.loads((OUT/'body-checks.json').read_text())
assert body['failures']==0
construction=json.loads((OUT/'construction/construction.json').read_text())
assert (construction['checks'],construction['failures'])==(33,2)
labels=[line for line in (OUT/'construction.log').read_text().splitlines() if line.startswith('FAIL:')]
assert labels==['FAIL: controlled canopy crown and height full','FAIL: controlled canopy crown and height simple'],labels
assert latest['construction']['source_sha256']==sources['electric_coachwork.gd']
assert latest['construction']['model_sha256']==sources['electric_car_model.gd']
for renderer in ['preview','preview-mobile']:
    captures=json.loads((OUT/renderer/'captures.json').read_text())
    assert captures['failures']==0 and len(captures['captures'])==16
checkpoint=json.loads((OUT/'checkpoint.json').read_text())
assert checkpoint['forward_exact'] and checkpoint['reverse_exact']
report=dict(date='2026-10-29',requirements=['ERN01','ERN02','ERN03','ERN04','R01','Q01'],
            source_hashes=sources,prepared_root='res://assets/vehicles/electric_coachwork_v23',
            verified_final_source_jobs=required,body_checks=body,results=results,
            retained_construction=construction,
            construction_limit='31/33; two unchanged former minimum-roof-height assertions conflict with the previously requested lower cabin.',
            native_model_checks=34,native_app_checks=58,racing_checks=23,
            full_visible_triangles=118714,simple_visible_triangles=38324,shadow_triangles=3673,
            prepared_meshes=len(manifest['meshes']),refreshed_native_pictures=52,
            final_review_captures={'compatibility':16,'desktop_mobile':16},
            paint={'factory_body':'b8bbb9','factory_accent':'272f33','saved_green_and_custom_preserved':True},
            limitations=['Reload/rebuild and owner appearance acceptance remain.',
                         'No physical-device query/test, APK, exact-photo match, aerodynamic or phone-performance claim.',
                         'No owner-save/live/backend mutation, deployment or owner-process restart.',
                         'No shared-index staging/commit/merge; concurrent work preserved.',
                         'No full-project-parser claim; desktop App hitches retained.'],
            checkpoint={key:value for key,value in checkpoint.items() if key!='hashes'})
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'source_hashes':sources,'verified_jobs':len(required),'body_checks':body['checks'],
                  'patch_sha256':checkpoint['patch_sha256']}))
