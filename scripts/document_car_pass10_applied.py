"""C305-C308: record the owner's appearance-first scope and actual applied result."""
import json
from run_car_pass10 import ROOT,OUT
def data(name):return json.loads((OUT/name).read_text())
def main():
    accepted=data('accepted-plan.json');closure=data('closure.json');m=data('measurements.json');integrity=data('authored-integrity.json')
    assert accepted['user_instruction']=='Preserve the current appearance; accept a smaller reduction where needed'
    assert m['totals']['triangles_before']==82012 and m['totals']['triangles_after']==80316
    names={'compact':'Rally','kart':'Kart','forklift':'Forklift','electric':'Volt','hovercraft':'Hover'}
    table='| Car | Before | Applied | Reduction |\n|---|---:|---:|---:|\n'
    for r in accepted['rows']:table+=f"| {names[r['vehicle']]} | {r['before']:,} | {r['after']:,} | {r['reduction_percent']:.2f}% |\n"
    assert all(p['draw_calls_before']==p['draw_calls_after'] for renderer in m['renderers'].values() for p in renderer['pairs'])
    status=dict(accepted_scope_achieved=True,original_ten_percent_achieved=False,owner_instruction=accepted['user_instruction'],production_models_changed=True,stock_before=82012,stock_after=80316,triangles_removed=1696,rows=accepted['rows'],Challenger_model_authoring=False,full_masters_preserved=True,physical_device_test=False)
    (OUT/'applied-status.json').write_text(json.dumps(status,indent=2)+'\n')
    text=f'''# Appearance-first car reduction applied, 16 November 2026

The owner chose **“Preserve the current appearance; accept a smaller reduction where needed.”** The previously reviewed126-source candidate set is now applied to the five finished racing models. This resolves the pending choice in the [review checkpoint](CAR_PASS10_REVIEW_2026_11_16.md). **1,696 triangles are removed:82,012→80,316(-2.07%).** The original additional10% target is not claimed. Challenger remains excluded.

{table}
![Actual prepared models, before and after](evidence/car-pass10-2026-11-16/five-car-applied-comparison.png)

**C305 — Apply the accepted appearance-first scope.** The exact reviewed plan is bound by its SHA256 and the owner instruction in [accepted-plan.json](evidence/car-pass10-2026-11-16/accepted-plan.json). No stronger driver, morph or concealed-face prototype is introduced. Full-quality master GPU/articulation signatures remain exact; full counts remain Rally100,356/Kart72,544/Forklift148,048/Volt114,648/Hover71,932. Kart's racing-driver native file is byte-exact, and its helmet is unchanged. Rally's repaired grille backing and preferred optical style, and Volt's protected side charts, rear corners, doors/handles and roof joins remain. The bonnet contour retains its original backing and0.35–1.50mm exposure assertions.

**C306 — Publish native resources with complete-frame protection.** The publication contains169 authored resource paths, including39 manifests and130 native resources. It replaces329 surface-recipe rows,26 newly added, while retaining679 unrelated rows. The unchanged driver keeps its exact detail recipes. All274 preceding authored paths outside this publication remain byte-exact; every published path is under the permitted vehicle asset roots and excludes Challenger. Exact before/after hashes and backups qualify the resource-first, manifest-last publication. See [publication.json](evidence/car-pass10-2026-11-16/publication.json) and [authored-integrity.json](evidence/car-pass10-2026-11-16/authored-integrity.json).

Static readback remains126/0 with the original2mm sampled-distance, topology, boundary, contact and attribute/field gates. The largest selected sampled deviation is1.96979mm. Volt's hood/deck centroid normal-field errors remain below1°. The source-built stock/fitted/full checks pass4,646/0; actual prepared receiving models pass40/0. Door/handle regression passes7,443/0. These geometric checks are sampled, not a continuous Hausdorff proof.

**C307 — Qualify actual consumers and costs.** All independently replaceable kits pass source/prepared comparisons: Rally1,441/0, Kart1,156/0, Forklift1,726/0, Volt1,934/0 and Hover1,288/0. Bases, every full/simple kit module, Garage and the compact header template are actually rebuilt. Final five-car preflight covers468 resources/1,925 checks with zero failures. The complete source fence retains{closure['consumed_inputs']:,} inputs with zero changes. Both desktop renderers, Compatibility and Vulkan/Mobile, pass90 paired stock/fitted views385/0,32 Volt moving-highlight pairs130/0, actual five-car Garage/race App48/0, steering170/0, icons507/0 and wash1,403/0. Parser581/0, driving72/0, recipe guards793/0 and protected batching9/0 also pass.

The initial prepared fixture ran before all Volt modules finished and retained a missing-kit-hit failure; the completed receiving check passes unchanged. Initial Mobile captures retain one, then two, exact-restoration failures; initial moving highlights retain two. The fixture had requested one redraw and then waited global frames in a read-only showroom, whose automatic settle callbacks are disabled. It now requests each of the existing eight settling redraws. Equality, stability, retry limits, cameras and precision are unchanged; no runtime renderer code changes. The final settled checks pass in both renderers. Initial failing receipts survive, and the repeat ordinary gallery and initial reflection gallery are archived. A first archive attempt stopped because optional Pillow is unavailable; the original ordinary gallery was overwritten by its fresh run, while its failing logs and available restoration image remain. These limitations are recorded rather than claiming every initial image was retained.

Matched **source-built** encoded mesh payloads, including stored LODs, fall3,352,010→3,307,526bytes(-1.33%). The current prepared payload is3,225,966bytes; there is no fresh paired prepared-before payload measurement, so its packing difference is not presented as this pass's gain. Material surfaces and measured draw calls are unchanged in every native comparison. These are geometry/buffer/desktop-counter results, not an FPS, GPU-time, loading-time or phone-performance claim. Details and all fitted inventories are in [measurements.json](evidence/car-pass10-2026-11-16/measurements.json).

Five catalogue/five header pictures and the global six-selection-portrait set are actually regenerated. Catalogue/portrait provenance,16 imports and final source/car identities pass. Challenger's portrait is derived UI artwork; Challenger model authoring and model-readiness qualification remain excluded. A concurrent dependency edit adds only Challenger to the compact plate asset/shader routing rules. Its exact starting policy is recovered by hash from Git, and complete rule/exclusion/order equality after restricting to the five finished cars proves their routing unchanged. The file is preserved outside this task's patch; five-car keys and consumed-input checks stay exact. See [dependency-scope.json](evidence/car-pass10-2026-11-16/dependency-scope.json). Generated build-version updates preserve every other project setting.

**C308 — Retain a reversible combined checkpoint.** The final private source checkpoint combines the offline review and accepted application. Forward/reverse byte equality and whitespace checks preserve concurrent work and the shared index. Reversal restores preceding authored model resources; derived scenes/pictures require rebuilding. The older review checkpoint and its unmet-target status remain historical evidence. Standard retention runs without a task pin; [build-retention-applied.log](evidence/car-pass10-2026-11-16/build-retention-applied.log) records27.09GiB unchanged because remaining entries are recent/protected/locked. Source/consumer gates, [applied-status.json](evidence/car-pass10-2026-11-16/applied-status.json), [closure.json](evidence/car-pass10-2026-11-16/closure.json) and [source-checkpoint-applied.json](evidence/car-pass10-2026-11-16/source-checkpoint-applied.json) retain the exact scope.

Reload for owner appearance review. No physical-device test, FPS acceptance, export, backend/deployment, owner-save/process action or main-index staging/commit/merge was performed.

Commands actually run (individual receipts retain full arguments/outcomes):

```powershell
python scripts/run_car_pass10.py stage-accepted res://tests/stage_car_pass10.gd --headless
python scripts/run_car_pass10.py candidate-fit res://tests/test_car_pass10.gd --headless -- --candidates
python scripts/publish_car_pass10.py
python scripts/refresh_car_pass10_assets.py
python scripts/check_car_pass10_publication.py
python scripts/qualify_car_pass10.py
python scripts/receive_car_pass10_app.py
python scripts/artwork_car_pass10.py
python scripts/measure_car_pass10_results.py
python scripts/check_car_pass10_dependency_scope.py
python scripts/close_car_pass10.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compare_car_pass10_applied.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```
'''
    (ROOT/'docs/CAR_PASS10_APPLIED_2026_11_16.md').write_text(text,encoding='utf-8',newline='\n')
    marker='CAR-PASS10-APPLIED-20261116'
    block=f'''<!-- {marker} -->
## Appearance-first smaller car reduction applied after owner choice (2026-11-16)
C305-C308 resolves the pending C301-C304 review: owner prioritises appearance and accepts smaller savings. Racing82,012→80,316(-2.07%): Rally13,114(-1.70%)/Kart16,396(-1.40%)/Forklift17,794(-1.78%)/Volt18,867(-1.07%)/Hover14,145(-4.79%). Full masters, driver native/helmet and earlier Rally/Volt repairs retained. Static126/0, source4646/0, prepared40/0, doors7443/0/all kits pass. Native169-path publication retains679 unrelated rows;274 preceding paths outside scope exact. Each desktop renderer:90pairs385/0, moving highlights32pairs130/0, App48/0, steering170/0, icons507/0, wash1403/0; parser581/0/driving72/0/recipe793/0. Initial readiness/restoration findings retained; read-only capture now requests all8 settling redraws, exact gates unchanged. Source-built payload-1.33%; prepared bytes separately measured, no paired prepared-before/FPS claim. Prepared468-resource1925/0, {closure['consumed_inputs']}-input fence,5 catalogue/5 header/6 derived portraits and16 imports pass. Concurrent Challenger-only plate-routing addition has exact five-car policy proof and remains outside patch. Combined exact private checkpoint and standard retention preserve concurrent work/index; no task pin. [Applied counts, comparisons, commands and limits](docs/CAR_PASS10_APPLIED_2026_11_16.md). Reload/owner/device acceptance remains; no Challenger model authoring, phone/FPS/export/backend/deployment/owner-save/process or main-index action.
<!-- /{marker} -->

'''
    for name in ('AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md'):
        path=ROOT/name;raw=path.read_bytes();assert ('<!-- '+marker+' -->').encode() not in raw;path.write_bytes(block.encode()+raw)
    print('C308_DOCUMENTED owner-accepted reduction applied; historical review retained')
if __name__=='__main__':main()
