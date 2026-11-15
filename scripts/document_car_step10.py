"""Write the completed CST01-CST04 requirements and measured review."""
import json,re
from run_car_step10 import ROOT,OUT
MARKER='CAR-STEP10-20261115'
REPORT='docs/CAR_STEP10_2026_11_15.md'
data=json.loads((OUT/'measurements.json').read_text())
plan=json.loads((OUT/'selected-plan.json').read_text())
closure=json.loads((OUT/'closure.json').read_text())
def result(label):
    receipt=json.loads((OUT/(label+'-receipt.json')).read_text())
    assert receipt['exit_code']==0 and not receipt['errors'],label
    lines=(OUT/(label+'.log')).read_text(errors='replace').splitlines()
    found=[line for line in lines if re.search(r'\d+ (checks|scripts|resources)',line)]
    return found[-1] if found else 'Clean receiving run; see receipt'
names={'compact':'Rally','kart':'Kart','forklift':'Forklift','electric':'Volt','hovercraft':'Hover'}
table='| Car | Task start | After Volt repair | Final stock | This reduction |\n|---|---:|---:|---:|---:|\n'
for row in plan['rows']:
    start=next(x['triangles_before'] for x in data['geometry'] if x['vehicle']==row['vehicle'] and x['mode']=='stock')
    table+=f"| {names[row['vehicle']]} | {start:,} | {row['before']:,} | {row['after']:,} | {100*row['new_saving']/row['before']:.2f}% |\n"
checks='| Validation | Actual result |\n|---|---|\n'
labels=['source-models-final','prepared-models-final','volt-regression-clearance','protected-landmarks','surface-recipe-guards','old-recipe-guards','panel-batch-final','rally-retained','driving','parser']
labels += [kind+'-'+method for method in ('gl_compatibility','mobile') for kind in ('native-final','app-final','steering-final','icons','wash')]
labels += ['modules-'+car for car in names]+['prepared-final']
for label in labels:checks+=f'| {label} | {result(label)} |\n'
cost='| Car | Front primitives before / after | Front draws before / after | Distant primitives before / after |\n|---|---:|---:|---:|\n'
for car in names:
    pairs=data['renderers']['gl_compatibility']['pairs']
    front=next(x for x in pairs if x['vehicle']==car and x['mode']=='stock' and x['view']=='front')
    distant=next(x for x in pairs if x['vehicle']==car and x['mode']=='stock' and x['view']=='distance')
    cost+=f"| {names[car]} | {front['visible_primitives_before']:,} / {front['visible_primitives_after']:,} | {front['draw_calls_before']} / {front['draw_calls_after']} | {distant['visible_primitives_before']:,} / {distant['visible_primitives_after']:,} |\n"
text=f'''# Volt door repair and the next gradual car reduction (2026-11-15)

Volt's six door seams and four flush handles are visible again. The five finished racing models then receive another approximately 10% reduction. Challenger model authoring is excluded. Forklift stops 62 triangles short of its exact target, at 9.72%, to retain the reviewed surfaces.

{table}
The repair itself removes 1,218 redundant contour triangles: 2,144 to 926. The reduction baseline for Volt is therefore **15,797**, after the repair. Across five cars the requested iteration reduces **93,860 to 84,536 (-9.93%)**; including the repair, task-start **95,078 to 84,536 (-11.09%)**. Counts refer to stock racing masters. Equipped configurations cost more and are recorded separately in [measurements](evidence/car-step10-2026-11-15/measurements.json).

[Volt before/after close-up](evidence/car-step10-2026-11-15/volt-door-comparison.png), [five-car front comparison](evidence/car-step10-2026-11-15/front-comparison.png), [critical detail comparison](evidence/car-step10-2026-11-15/details-comparison.png). These are native engine renders using matched root transforms, cameras and lighting. Current prepared stock/fitted models have 90 paired views in each desktop renderer.

**CST01 — Repair the missing Volt details before reducing further.** The seams and handles existed, but 1,189 original vertices lay beneath the actual reduced door skin. Fourteen native racing strips are reprojected onto that skin, with complete curve coverage. A triangle-level clearance test caught nine near-contact samples in the first repair. An additional 0.25 mm outward allowance fixes those; all 7,443 coverage, exposure, backing and distance-policy checks pass. The final nominal local offset is 1.05 mm. Both original backing meshes retain their exact geometry keys. Separate protected batch groups carry their opt-in policy through both assembly passes and keep these skins and strips at their master geometry at distance.

**CST02 — Choose bounded, reviewed savings.** Original-corner retessellation and constrained source-surface remeshing preserve articulation frames, contact/extreme anchors, topology and source field witnesses. The unchanged independent gate samples every used vertex and triangle centroid in both directions against a 2 mm bound; selected candidates reach at most **1.798 mm**. This is a sampled geometric bound, not a proof of identical pixels. All 13 selected glazing meshes retain their complete original boundary-segment signatures, including Rally's windscreen and Volt's canopy joins. Glazing shaders are opaque and do not move vertices. A separate exact shader-code allowlist also covers the racing rubber and static cloth; unknown shaders and morph meshes are rejected. Kart's 28-sector tyres retain regular analytical profile rows. Only the driver's separate static suit is simplified; the helmet, animated driver poses and steering assembly remain protected.

The new `car_surface_v1` recipes run after the existing opaque detail pass. Every replacement is tied to a complete fresh frame, source geometry, result digest, exact bounds and material/shader identity. The complete frame is validated before any member changes. The older opaque-solid guard is retained. There is no live mesh simplifier in racing or icon capture. Prepared consumers restore the baked geometry. Rally's preferred reflector lamps and grille, Kart's helmet/steering, and Volt's backing panels/roof rails pass six stock/fitted landmark comparisons. All five full-quality prepared master GPU streams and articulation remain exact to the task-start prepared snapshots.

**CST03 — Qualify actual consumers and performance costs.** Both desktop Compatibility and Vulkan/Mobile execute the receiving Garage/race, steering, icon, washing and native comparisons. Canonical handling sources are unchanged. Source/kit fixtures retain their actual assertions. Stock encoded buffers fall from **3,715,882 to 3,380,332 bytes (-9.03%)**. Draw calls stay unchanged except Volt, which adds two protected groups to keep its repaired details visible. All fitted/full inventories are in the measurement file. Viewport counters include the receiving studio and its shadow work; they are not FPS or GPU-time measurements.

{cost}
The original icon gate requires at least 15% additional savings versus the current fitted masters. With smaller masters it initially reports 507 checks/1 budget failure. Existing icon-only LOD selection is adjusted from 0.35 to 0.25 for the five finished cars; Challenger retains 0.35. This selects stored distance levels, without modifying master geometry or the Garage/race policy. The original appearance, cache, cancellation and 15% assertions then pass in fresh profiles. Actual icon dimensions follow the current shared UI (512×288); the retained fixture still contains an older 176×112 text label. Per-car image/primitive measurements are retained in each icon evidence folder.

Concurrent Challenger edits initially invalidated all five source-checkout caches because its builder lacked an explicit dependency rule. All four production uses of that builder are guarded by the Challenger vehicle ID. One exact routing rule now isolates that file. An owned minimal-project control rejects the old rule with **87/5**, and the corrected rule passes **87/0**, while unknown geometry inputs remain shared. The final source/key/cache fence covers **{closure['consumed_inputs']:,} inputs for the five finished cars**. Challenger continues as WIP and is excluded from final readiness. The earlier complete 551-resource/2,267-check pass is retained as an earlier state; final scoped readiness is 468 resources/1,925 checks. No Challenger source is authored, and its continuing edits and prepared outputs are preserved.

{checks}
**CST04 — Publish a reversible, reviewable result.** Offline source resources precede recipes; exact publication hashes bind the authored changes. The final five bases/kits/Garage/header consumers, five catalogue images, five default header pictures and ten native imports are refreshed against the live five-car source/key fence. Catalogue provenance remains explicitly scoped when Challenger changes. Trackers and a private source-only Git checkpoint preserve surrounding concurrent documentation and the main index. The patch is checked forward/reverse byte-for-byte; derived scenes/pictures must be rebuilt after reversal. Standard build retention runs without a task pin. Physical-device testing, FPS acceptance, exports, backend requests, deployment and owner-save/process actions are excluded. Owner appearance acceptance remains before the next reduction.

The evidence retains rejected candidates, the first clearance failures, original protected-batch failures, and initial tool/fixture findings. These include fixture lifecycle/type errors, an indexed-tyre installer that originally assumed flattened corners, procedural-versus-packed full-buffer comparisons, an isolated transient Hover scene write failure, cached-profile icon counter findings, a minimal-project alias stub omission, the rejected broad Challenger key fence, and two tab-only lines caught by the initial checkpoint whitespace gate. The final prepared full-buffer comparison uses the matching prepared provider; source batching has separate frozen-original controls. The old assertions are retained, including the icon budget gate. Only task-owned failed fixture processes were stopped; owner processes were untouched.

Representative commands (exact engine arguments, paths, renderers and errors are in individual receipts):

```powershell
python scripts/run_car_step10.py volt-regression-clearance res://tests/test_car_step10_volt.gd --headless
python scripts/select_car_step10.py
python scripts/run_car_step10.py stage res://tests/stage_car_step10.gd
python scripts/publish_car_step10.py
python scripts/refresh_car_step10_assets.py
python scripts/check_car_step10_refresh_scope.py
python scripts/qualify_car_step10.py
python scripts/artwork_car_step10.py
python scripts/measure_car_step10_results.py
python scripts/record_car_step10.py
python scripts/close_car_step10.py
python scripts/checkpoint_car_step10.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

[Authored source bindings](evidence/car-step10-2026-11-15/authored-publication.json), [closure](evidence/car-step10-2026-11-15/closure.json), [source patch](evidence/car-step10-2026-11-15/source.patch) and [checkpoint receipt](evidence/car-step10-2026-11-15/source-checkpoint.json) retain the exact scope. Bootstrap and migration scripts describe this completed iteration; they are not a general-purpose repeatable optimiser.
'''
(ROOT/REPORT).write_text(text,encoding='utf-8')
summary=f'''CST01-CST04: Volt's buried door/handle strips refit to the actual skin, protected backing/batches and a 0.25mm clearance correction pass7443/0. Corrected racing baselines93860to84536(-9.93%): Rally14592/Kart18531/Forklift20314/Volt14217/Hover16882; Forklift9.72%, others10%. Repair additionally removes1218tri. Bounded offline field/topology/contact proofs max1.798mm within2mm; thirteen glazing boundaries and six landmark cases exact, five full prepared GPU masters exact. Five-car native90pairs/385checks per desktop renderer, App/steering/icons/wash and all-kit checks are retained in the report. Icon-only stored LOD bias0.25 retains the original15% gate; Challenger stays0.35. Missing Challenger-only builder dependency is isolated by87/5 original versus87/0 fixed controls; final468-resource1925-check and{closure['consumed_inputs']}-input five-car fence exclude its continuing WIP. Five catalogue/five header images and ten imports refresh. Scoped source-only checkpoint, standard retention and concurrent work/index preserved. No FPS/device/export/backend/deployment/owner-save/process claim. [Requirements, counts, native views, controls and limits]({REPORT}). Owner appearance review precedes the next iteration.'''
block=('<!-- '+MARKER+' -->\n## Volt details restored and the next gradual car reduction applied (2026-11-15)\n'+summary+'\n<!-- /'+MARKER+' -->\n\n').encode()
for name in ('AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md'):
    p=ROOT/name;old=p.read_bytes()
    pattern=('<!-- '+MARKER+r' -->\r?\n.*?<!-- /'+MARKER+r' -->\r?\n(?:\r?\n)?').encode()
    old=re.sub(pattern,b'',old,flags=re.S)
    p.write_bytes(block+old)
print('STEP10_DOCUMENTATION requirements, results, limits and three trackers')
