import hashlib
import json
from pathlib import Path

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
source=sha(ROOT/'game/vehicle/electric_reference_body.gd')
latest={entry['job']:entry for entry in json.loads((OUT/'commands.json').read_text())}
required=['bake','hood','preview','body','nose-prepared','model','shadows','garage',
          'pictures','liveries','news','import','preview-mobile','app','racing','parse-own']
for job in required:
    assert latest[job]['exit_code']==0 and latest[job]['source_sha256']==source,job
hood=json.loads((OUT/'hood-measurements.json').read_text())
assert (hood['checks'],hood['failures'])==(15,0)
mesh_root=ROOT/'game/assets/vehicles/electric_reference_hood_v1'
manifest=json.loads((mesh_root/'manifest.json').read_text())
for name,value in manifest['sources'].items(): assert sha(ROOT/'game/vehicle'/name)==value,name
before=json.loads((ROOT/'game/assets/vehicles/electric_reference_v3/manifest.json').read_text())
assert before['sources']['electric_reference_body.gd']==sha(OUT/'task-base/game/vehicle/electric_reference_body.gd')
for folder in ['before-preview','preview','preview-mobile']:
    result=json.loads((OUT/folder/'captures.json').read_text())
    assert len(result['captures'])==16 and result['failures']==0
counts_line=next(line for line in (OUT/'racing.log').read_text().splitlines() if line.startswith('RACING_MODEL_COUNTS electric '))
counts=json.loads(counts_line.split('electric ',1)[1])
assert counts['detailed']['triangles']<120000 and counts['simple']['triangles']<45000
checkpoint=json.loads((OUT/'checkpoint.json').read_text())
assert checkpoint['forward_exact'] and checkpoint['reverse_exact']
assert checkpoint['hashes']['game/vehicle/electric_reference_body.gd']==source
report=dict(date='2026-10-29',requirements=['EHR01','EHR02','R01','Q01'],
            source_sha256=source,prepared_sources=manifest['sources'],verified_jobs=required,
            hood=hood,nose_procedural_checks=64,nose_prepared_checks=64,
            model_checks=15,actual_app_checks=58,racing_checks=23,
            prepared_mesh_count=len(manifest['meshes']),racing_geometry=counts,
            native_captures={'before_compatibility':16,'after_compatibility':16,'after_desktop_mobile':16},
            native_pictures_refreshed=52,
            retained_findings=['Concurrent reference v2-to-v3 preparation was preserved; the correction uses its own asset directory.',
                               'Initial audit selected an obsolete v2 control and failed two crown comparisons; final v3 control is fenced by the exact task-start body hash.',
                               'Intermediate crown renders/source and initial measurement log retained.'],
            limitations=['Reload/rebuild and owner appearance acceptance remain.',
                         'No physical-device query/test, APK, owner-save/live/backend mutation, deployment or owner restart.',
                         'No shared-index staging/commit/merge; concurrent source/context and current build identities retained.',
                         'No exact-photo, aerodynamic, phone-performance or full-project-parser claim; App desktop hitches retained.'],
            checkpoint={key:value for key,value in checkpoint.items() if key!='hashes'})
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'source_sha256':source,'verified_jobs':len(required),'hood_checks':hood['checks'],
                  'patch_sha256':checkpoint['patch_sha256']}))
