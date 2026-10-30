"""Require final-source receipts before recording the local delivery."""
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
source = ROOT/'game/vehicle/electric_coachwork.gd'
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
current = sha(source)
receipts = json.loads((OUT/'commands.json').read_text())
latest = {item['job']: item for item in receipts}
required = ['bake', 'preview', 'refinement', 'bonnet', 'cabin', 'shape', 'flow',
            'shadows', 'garage', 'pictures', 'liveries', 'news', 'import',
            'preview-mobile', 'model', 'app', 'racing', 'parse-own']
for job in required:
    assert latest[job]['exit_code'] == 0, (job, latest[job])
    assert latest[job]['source_sha256'] == current, job
assert latest['construction']['source_sha256'] == current
assert latest['construction']['exit_code'] == 1
construction = json.loads((OUT/'construction/construction.json').read_text())
assert (construction['checks'], construction['failures']) == (33, 2)
failed_labels = [line for line in (OUT/'construction.log').read_text().splitlines() if line.startswith('FAIL:')]
assert failed_labels == ['FAIL: controlled canopy crown and height full',
                         'FAIL: controlled canopy crown and height simple'], failed_labels
results = {}
for job, filename in [('refinement', 'refinement.json'), ('cabin', 'cabin.json'),
                      ('bonnet', 'convex-hood.json'), ('shape', 'rear-shape.json'),
                      ('flow', 'rear-flow.json')]:
    results[job] = json.loads((OUT/job/filename).read_text())
    assert results[job]['failures'] == 0, job
for folder in ['before', 'preview', 'preview-mobile']:
    captures = json.loads((OUT/folder/'captures.json').read_text())
    assert len(captures['captures']) == 16 and captures['failures'] == 0
checkpoint = json.loads((OUT/'checkpoint.json').read_text())
assert checkpoint['forward_exact'] and checkpoint['reverse_exact']
assert checkpoint['hashes']['game/vehicle/electric_coachwork.gd'] == current
report = dict(date='2026-10-29', requirements=['VRF01','VRF02','VRF03','R01','Q01'],
              source_sha256=current, prepared_root='res://assets/vehicles/electric_coachwork_v21',
              verified_final_source_jobs=required, results=results,
              retained_legacy_construction=construction,
              legacy_failure_reason='Two historical minimum roof heights conflict with the requested lower cabin; original assertions retained.',
              native_model_checks=34, native_app_checks=58, racing_checks=23,
              visible_triangles={'full':119238,'simple':38224}, shadow_triangles=3527,
              captures={'before_compatibility':16,'after_compatibility':16,'after_desktop_mobile':16},
              refreshed_native_pictures=52,
              limitations=['Owner appearance acceptance and reload/rebuild remain.',
                           'No physical-device query/test, APK or aerodynamic measurement.',
                           'No phone-performance or full-project-parser claim; App desktop hitches retained.',
                           'No owner-save/live/backend mutation, deployment or owner-process restart.',
                           'No shared-index staging/commit/merge; concurrent work preserved.'],
              checkpoint={key:value for key,value in checkpoint.items() if key!='hashes'})
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'source_sha256':current,'verified_jobs':len(required),
                  'patch_sha256':checkpoint['patch_sha256']}))
