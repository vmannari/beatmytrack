"""CME05: exact final source fence, measurements, receipts and review report."""
import hashlib
import json
import re
from pathlib import Path
from qualify_car_mechanics import IDS, ROOT, OUT, sources

required=['models-source-final','models-prepared-final','native-storage-proof-final','lod-storage-final',
          'prepared-final','parser-final','driving','recipe-guards']
required+=['modules-current-'+car for car in IDS]
required+=[kind+'-'+method for kind in ['native-matched','steering-final','app-final']
           for method in ['gl_compatibility','mobile']]
required+=['distance-final-gl_compatibility','distance-mobile-isolated-final']
receipts={}
for label in required:
    row=json.loads((OUT/(label+'-receipt.json')).read_text())
    assert row['exit_code']==0 and not row['errors'] and not row['stop_reason'],label
    receipts[label]=row
before=json.loads((OUT/'qualification-inputs.json').read_text());after=sources()
changed=[k for k in before.keys()|after.keys() if before.get(k)!=after.get(k)]
assert not changed,changed
pub=json.loads((OUT/'publication.json').read_text())
for name,row in pub['files'].items():
    assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==row['after'],name
    assert 'electric' not in name and 'challenger' not in name and 'super_rally' not in name
old=json.loads((OUT/'before.json').read_text())['rows']
new=json.loads((OUT/'prepared-models.json').read_text())['rows']
rows=[]
far=dict(compact=144,kart=104,forklift=0,hovercraft=408)
for car in IDS:
    one=next(r['inventory'] for r in old if r['vehicle']==car and r['mode']=='stock')
    two=next(r['inventory'] for r in new if r['vehicle']==car and r['mode']=='stock')
    rows.append(dict(vehicle=car,before_triangles=one['triangles'],after_triangles=two['triangles'],
                     near_saving=one['triangles']-two['triangles'],additional_distance_saving=far[car]))
distance={}
for method in ['gl_compatibility','mobile']:
    native=json.loads((OUT/('prepared-'+method)/'comparisons.json').read_text())
    assert native['failures']==0 and len(native['pairs'])==64
    dist=json.loads((OUT/('distance-'+method)/'comparisons.json').read_text())
    assert dist['failures']==0 and len(dist['pairs'])==30
    assert all(p['restored_exact'] and p['stable_reference'] for p in dist['pairs'])
    assert all(p['draw_calls_before']==p['draw_calls_after'] for p in dist['pairs'])
    distance[method]={car:max(p['visible_primitives_before']-p['visible_primitives_after']
                              for p in dist['pairs'] if p['vehicle']==car)
                       for car in ['compact','kart','hovercraft']}
    assert distance[method]=={k:far[k] for k in distance[method]}
imports=json.loads((OUT/'image-import-receipt.json').read_text())
assert imports['verified_images']==14 and not imports['editor_diagnostics'] and imports['project_settings_exact']
identity=json.loads((OUT/'identity-final.json').read_text())
initial=json.loads((OUT/'identity-after.json').read_text())
assert all(identity['modular_car_sha256'][car]==initial['modular_car_sha256'][car] for car in IDS)
driver=json.loads((OUT/'selected-plan.json').read_text())['driver']
review=json.loads((OUT/'geometry-review.json').read_text())
assert review['rejected']==0 and max(r.get('surface_upper_bound_m',0) for r in review['parts'].values())<=.002
rim=json.loads((OUT/'rim-review.json').read_text());assert rim['surface_upper_bound_m']<.012
closure=dict(requirements=['CME01','CME02','CME03','CME04','CME05'],rows=rows,
             exact_current_inputs=len(after),changed_inputs=changed,authored_native_files=len(pub['files']),
             driver=driver,renderer_distance_savings=distance,clean_receipts=receipts,
             physical_device_test=False,fps_claim=False,main_index_staging=False,
             excluded_source_authoring=['electric','super_rally'])
(OUT/'closure.json').write_text(json.dumps(closure,indent=2)+'\n')

table='\n'.join('| '+dict(compact='Rally',kart='Kart',forklift='Forklift',hovercraft='Hover')[r['vehicle']]+f" | {r['before_triangles']:,} | {r['after_triangles']:,} | {r['near_saving']:,} | {r['additional_distance_saving']:,} |" for r in rows)
report=f'''# Mechanical car optimisation — 17 November 2026

Appearance remains the priority. This pass reduces the four scoped racing masters by **423 triangles**, from61,449 to61,026 (-0.69%), and removes another **656 submitted triangles at distance** across Rally, Kart and Hover. These are geometry measurements, not an FPS claim. Challenger and Volt source authoring are outside this pass.

| Car | Racing before | Racing after | Near saving | Additional distance saving |
|---|---:|---:|---:|---:|
{table}

## Requirements and resulting changes

**CME01 — Mechanical detail and unused storage.** Fifty Forklift chain pins become bounded five-sided closed pins,20 to16 triangles each (-200). Their native normals/tangents follow the offline affine fit; every vertex remains inside the original culling bounds. Certified bidirectional surface upper bound1.982414mm retains the original2mm gate. The other two chain pins stay unchanged. Another149 Forklift and74 Kart triangles are removed only inside certified closed opaque solids, with0.5mm burial and exact same-frame geometry/finish bindings. Missing fitted-kit witnesses skip the change. Every retained encoded corner remains exact. Of66 screened source candidates,38 source identities are used by the staged replacements; repeated kit restoration is not a count of unique visible parts.

Kart's moving driver remains3,545 triangles with all10 poses and the original helmet. Exact raw-record compaction removes86 unused vertices:2,153 to2,067, saving19,792 bytes from516,870 to497,078. The published native asset passes22 exact ordered-corner/pose comparisons plus name, finish and bounds checks. No triangle or FPS saving is attributed to this storage change.

**CME02 — Wheel interiors.** Kart's inner bore uses294 rather than320 triangles per rim only at distance (-104 across four wheels). Outer lips, spokes, tyres and every close master byte are retained. One initial angular gap exceeded the unchanged12mm distant bound; that collapse was rejected. Extra vertices at the irregular station bring the certified bound to8.582mm, with one closed component, no boundaries/nonmanifold edges and the original Euler characteristic.

**CME03 — Hover stationary rings.** Eight duct-rim/guard rings use2,010 to1,602 triangles at distance (-408). Near masters, hull, skirt and fan blades are retained. Engine-generated candidates introduced nonmanifold edges and were rejected. Offline endpoint collapses preserve the original closed torus topology; measured upper bounds4.128–6.401mm use conservative distance thresholds at least four times those bounds. Only component indices change; all other batch triangles remain exact.

**CME04 — Rally fine grille.** The fine lattice keeps192 near triangles and uses48 original front-face triangles at distance (-144). Main louvers, surround, dark backing, closure repairs and preferred lamps remain exact. This keeps real near geometry and existing finishes without another texture, alpha layer or material draw.

**CME05 — Publication and review.** Seven compact native index-table resources bind to exact final batch digests. They apply during offline baking, survive batching/packing and preserve existing farther levels. Runtime does no new mesh generation or registry lookup. Same-threshold regional indices are excluded from previous-output reuse, so rebakes cannot silently retain an older candidate;9 reuse checks cover7 prepared groups. The source publication contains63 native files plus the offline LOD helper. [Exact paths and hashes](evidence/car-mechanics-2026-11-17/publication.json) and the checked source patch identify the scope.

## Actual validation

Current source29/0 and prepared32/0, native storage/bounds61/0, all-kit Rally1,441/0, Kart1,156/0, Forklift1,726/0 and Hover1,288/0. Prepared preflight343 resources/1,415 checks passes. Each desktop renderer passes64 matched plain stock/fitted pairs276/0,30 distance-control pairs149/0, steering170/0 and actual Garage/race App40/0. Near distance controls are pixel exact. The renderer submits exactly144/104/408 fewer primitives for Rally/Kart/Hover; draw calls remain equal. Production parser583/0, full-project parser2,343/0 at its earlier checkpoint, driving72/0 and recipe guards8/0 pass. Four catalogue/four header pictures, six derived global portraits and14 imports are refreshed. Final current-source fence: **{len(after):,} inputs, zero changes**, including the offline helper.

The additional distance tables cost37,542 index bytes across the tested stock mesh instances (sharing can reduce allocation). The seven compressed source tables total31,376 bytes. These costs are separate from the driver's19,792-byte saving; no paired whole-prepared-memory or phone/FPS improvement is claimed.

## Review views

[Compatibility stock](evidence/car-mechanics-2026-11-17/gl_compatibility-stock-review.png), [Compatibility fitted](evidence/car-mechanics-2026-11-17/gl_compatibility-fitted-review.png), [Mobile stock](evidence/car-mechanics-2026-11-17/mobile-stock-review.png), [Mobile fitted](evidence/car-mechanics-2026-11-17/mobile-fitted-review.png). Full native PNGs and comparisons are in the matching `prepared-*` and `distance-*` evidence folders. Decorated runs are additional paint integration views; their plain baseline is not presented as an appearance-matched paint comparison.

## Commands and retained controls

Commands, renderer, elapsed time, exit status and diagnostics for every required run are embedded in [closure.json](evidence/car-mechanics-2026-11-17/closure.json). Main invocations:

```text
python scripts/run_car_mechanics.py <label> res://tests/<fixture>.gd <engine options>
build/tools/blender-4.5.15-windows-x64/blender.exe --background --factory-startup --python-exit-code 1 --python scripts/check_car_mechanics.py
build/tools/blender-4.5.15-windows-x64/blender.exe --background --factory-startup --python-exit-code 1 --python scripts/check_car_mechanics_rim.py
python scripts/publish_car_mechanics.py
python scripts/refresh_car_mechanics_assets.py
python scripts/qualify_car_mechanics.py
python scripts/artwork_car_mechanics.py
python scripts/import_car_mechanics_images.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compare_car_mechanics.ps1
python scripts/close_car_mechanics.py
```

Initial fixture null indices/path/directory mistakes, rejected Hover topology, the oversized rim gap, the pin culling/affine controls and a missing regional-table metadata/reuse control remain recorded. The pin's first bound-fitted profile exceeded2mm and was rejected; the final profile retains the same gate. A parallel Mobile near reference/restoration rejection is retained before a clean isolated repeat with the original equality checks. An importer overlapped a generated-version write; the final importer ran separately and retained the exact project-settings check. No runtime restoration/determinism or teardown fix is claimed.

The first broader refresh encountered separate Volt kit authoring; Volt fitted checks and whole-tree readiness are unqualified here. The four-car source routing retains the explicit identity-script digest: an initial filter mistakenly dropped that unchanged input from only one side of the comparison, and was corrected symmetrically. Current source, identity and all-module gates remain strict. An unreferenced task pin prototype was moved into the task's retained build output, preserving its bytes.

## Remaining acceptance and checkpoint

Reload the client to consume the refreshed assets. Owner appearance review and physical-device performance/appearance acceptance remain. Physical-device testing was not performed. No export, backend/deployment action, owner-save/process change or root Git staging occurred. A task-only private Git checkpoint verifies forward/reverse bytes; reversing source requires rebaking derived consumers/pictures. Concurrent work and the shared index are preserved. Standard retention ran:30.12GiB remains recent/protected/locked, with no new task pin or deleted entries.
'''
lines=[];code=False
for line in report.splitlines():
    if line.startswith('```'):code=not code
    if not code and not line.startswith('```'):
        line=re.sub(r'(?<=[A-Za-z])(?=[0-9])|(?<=[0-9])(?=[A-Za-z])',' ',line)
        line=re.sub(r'\bCME 0 ([1-5])\b',r'CME0\1',line)
        line=re.sub(r'\bCME 0([1-5])\b',r'CME0\1',line)
        line=re.sub(r'(?<=[A-Za-z]),(?=[0-9])',', ',line)
        line=re.sub(r':(?=[0-9])',': ',line)
    lines.append(line)
(ROOT/'docs/CAR_MECHANICS_2026_11_17.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('MECHANICS_CLOSURE',len(after),'stable inputs;',len(pub['files']),'native source files')
