"""VSR01-VSR03: record measured repair, receiving checks and remaining limits."""
import json,re
from run_volt_smooth import ROOT,OUT
MARKER='VOLT-REFLECTION-SMOOTHING-20261115'
REPORT='docs/VOLT_REFLECTION_SMOOTHING_2026_11_15.md'
closure=json.loads((OUT/'closure.json').read_text(encoding='utf-8'))
proof=json.loads((OUT/'geometry-proof.json').read_text(encoding='utf-8'))
publication=json.loads((OUT/'publication.json').read_text(encoding='utf-8'))
changed_count=len(closure['changed_consumed_inputs'])
epoch_inputs=json.loads((OUT/'refresh-fence.json').read_text(encoding='utf-8'))['inputs']
labels=closure['verification_receipts']
table='| Check | Actual result |\n|---|---|\n'
for label in labels:
    receipt=json.loads((OUT/(label+'-receipt.json')).read_text(encoding='utf-8'))
    if label not in closure['unqualified_receipts']:assert receipt['exit_code']==0 and not receipt['errors'],label
    lines=(OUT/(label+'.log')).read_text(encoding='utf-8',errors='replace').splitlines()
    matches=[line for line in lines if re.search(r'\d+ (checks|resources|scripts)',line)]
    table+=f"| {label} | {matches[-1] if matches else 'Clean run; exact arguments in receipt'} |\n"
text=f'''# Volt paint reflections and wheel surrounds refined (2026-11-15)

The rear shoulder and front wheel-surround pinches are corrected by restoring the affected native paint curves and constructing one shared normal field across their adjoining charts. [Before/after views](evidence/volt-reflection-smoothing-2026-11-15/reflection-comparison.png) and [moving reflection comparison](evidence/volt-reflection-smoothing-2026-11-15/reflection-sweep.gif) show the same production paint, cameras and lighting.

**VSR01 — Correct the visible surface and reflection transitions.** The earlier repair restored only the rear portion of the side skin. Its adjacent quarter/deck panels and the front skin/bonnet still contained very sparse triangles. Returning only their original normals also left independently calculated patch boundaries. An analytical-normal prototype did not solve the front facets. A later prototype that retained the sparse side geometry still showed them and was rejected.

The selected source repair restores sixteen native paint charts: the side skins, bonnet, deck, wheel-arch strips, window belts, A pillars, rear quarter panels and rear pillars. Their 9,088 triangles retain the native positions, indices, winding and UVs. Only their shading basis changes. Area-weighted native face normals contribute to a common Gaussian field with a 24 mm standard deviation; opposite body halves are separated. Vertex tangents are projected into the resulting tangent planes. This is offline mesh authoring; no runtime fairing, finish shader, paint roughness, camera, handling or production GDScript is changed.

The independent geometry proof passes **{proof['checks']}/0**. The proof checks {proof['shared_stations']} matching cross-chart station pairs ({proof['before_comparable_station_pairs']} also covered by the old charts). Maximum encoded normal mismatch falls from **{proof['before_join_max_degrees']:.3f}° to {proof['after_join_max_degrees']:.4f}°**, below the unchanged 0.2° gate. The original model rejects that gate. Native coordinates/topology/UVs, unit normals and orthogonal tangent bases are checked separately. An initial proof assumed every native UV query was covered by the previous reduced mesh; three older charts contain omitted areas or the prior hybrid UV join. That invalid comparison assumption is retained as a 141/3 control. The final proof checks complete coverage of the restored native charts and compares old normals only where the old chart actually has a face; missing-query counts are recorded. No production visibility or fit threshold is relaxed.

**VSR02 — Keep doors, handles, factory proportions and other models.** All fourteen existing seam/handle strips retain their triangle connectivity, exact Y/Z paths and signed coverage coordinates. Their X positions are refitted to the restored rendered skin at the same 1.05 mm offset, with corresponding contour tangents and widths. The original 7,443 exposure/coverage checks pass at the original 0.30–2.00 mm limits. The protected skin/contour batches retain 5,086 triangles and their distance protection.

| Model | Task start | Corrected |
|---|---:|---:|
| Stock racing Volt | 15,254 | 21,309 |
| Equipped sample | 22,706 | 27,033 |
| Full-quality master | 114,648 | 114,648 |

The stock cost is **6,055 triangles (+39.69%)**. The equipped sample excludes the factory bonnet, so its increase is 4,327. This is an appearance repair, not another reduction iteration. Factory paint curvature takes priority over the rejected sparse surfaces. The full master retains its task-start GPU streams and articulation exactly. The existing fitted icon distance levels still reduce drawn primitives from 22,947 to 17,185 (25.11%) at the same camera. There is no FPS, phone performance or universal surface-quality claim.

The authored production scope is **{len(publication['files'])} Electric-only resources**: sixteen new paint meshes, fourteen refitted simple contour meshes, three exact detail frames and three exact surface frames. Registered non-contour raw members and all unrelated post-detail members remain exact; retained reduction rows are copied without broad context matching or weakened source checks. Old recipes are retained. No Challenger or other-car geometry or prepared model is authored. [Exact paths and before/after bindings](evidence/volt-reflection-smoothing-2026-11-15/publication.json).

**VSR03 — Review receiving renders and current assets.** A production Garage lighting/reflection sweep covers both front and rear corners through eight light/environment directions: 32 matched source pairs. Stock/equipped prepared views cover front/rear/sides, doors/handles, roof, distance and all four marked corner regions in each desktop renderer. Baseline snapshots receive the receiving Garage's pedestal height and reflection-layer membership, so the floor captures the reference car as well as the candidate. Pixel restoration assertions remain exact. The receiving App, equipped icon/capture/cache/cancellation, current washing flow, racing kit choices and canonical driving are exercised before the final concurrent livery edit. The table preserves that historical qualification alongside explicitly named current-source checks.

{table}
The earlier stable-epoch cache preflight checks 125 Volt resources/511 assertions. **Final prepared-cache readiness is unqualified**: a later shared livery edit changed {changed_count} consumed inputs after these receiving runs. The original source fence still rejects, and the overall closure intentionally exits nonzero. No prepared metadata is restamped. Final live source checks separately pass 17/0 for all sixteen authored paint hashes, 11/0 for stock/equipped/full geometry and full-master identity, and 7,443/0 for doors. The repaired source fallback remains available; these checks do not qualify the latest livery shader or prepared-cache performance. A shared livery-graphics edit and four artistic-livery inputs invalidated the first complete bake; the four failed prepared-hit checks correctly rejected those stale scenes. The final rebuild really constructs both quality families and all 120 kit scenes. A task-only shard filter divides independent body options between the same producer operations; it does not rewrite source hashes or restamp stale metadata. The intermediate stable input fence covered **{epoch_inputs:,} inputs**; the final rejected changes are recorded verbatim in the closure. No complete current-cache claim is made.

One reflection-sweep attempt retained two first-view stability/restoration findings; its repeat passes 129/0 without changing assertions. The prepared Compatibility restoration gate remains **149/1**: the unchanged reference differs at one pixel by 1/255 at (502,555). Both a repeat and symmetric warm-up retain that finding, and the literal pixel-equality assertion remains unchanged. This is an unqualified image-restoration control, not a clean Compatibility suite claim. The other 35 paired restorations pass; the original reference scene itself is not edited between captures. Desktop Mobile passes all 149 assertions. The 32-pair moving reflection sweep separately passes 129/0. Initial receipts and the noise measurement remain. One Compatibility washing run passes all 316 assertions but retains two-object/one-resource shutdown diagnostics; its receipt is retained. The fixture saves its selected Volt in the isolated records before App startup and drains post-draw cancellation callbacks before exit; the final repeats pass cleanly. Washing assertions and production code remain unchanged. Current receiving results, including the retained failed control, are listed above, separately from those original attempts. The first Garage capture also exposed a fixture lookup error after the car was reparented onto its pedestal; the final driver finds the light through the actual viewport. An initial comparison-sheet GIF pass held files open while revisiting frames; unique frame names resolve that tooling issue. No runtime fix or whole-suite claim follows from these fixture corrections.

Volt's catalogue and shared header pictures are rebuilt. Before that final edit, the existing global selection-portrait producer rendered its complete six-picture set to keep its then-current global identity coherent; this is derived UI artwork, including the current unchanged Challenger model, not Challenger model authoring. Its 25,608-input fence passed at generation, and eight native image imports were verified with exact project settings. Current picture/global-key freshness is not inferred after the subsequent shared livery edit. Concurrent livery/UI/Challenger/index work is preserved.

Representative actual commands (full engine arguments, isolated profiles, timings and diagnostics are in command receipts):

```powershell
python scripts/run_volt_smooth.py survey res://tests/survey_volt_smooth.gd --headless
python scripts/build_volt_smooth_field.py
python scripts/run_volt_smooth.py build-final res://tests/build_volt_smooth.gd --headless
python scripts/run_volt_smooth.py refit-final res://tests/refit_volt_smooth_contours.gd --headless
python scripts/check_volt_smooth_geometry.py
python scripts/run_volt_smooth.py stage-final res://tests/stage_volt_smooth.gd --headless
python scripts/publish_volt_smooth.py
python scripts/refresh_volt_smooth.py
python scripts/qualify_volt_smooth.py
python scripts/qualify_volt_smooth.py --receivers-only
python scripts/artwork_volt_smooth.py
python scripts/close_volt_smooth.py
python scripts/checkpoint_volt_smooth.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

[Source closure with the failed reference-render gate retained](evidence/volt-reflection-smoothing-2026-11-15/closure.json), [source patch](evidence/volt-reflection-smoothing-2026-11-15/source.patch) and [checkpoint receipt](evidence/volt-reflection-smoothing-2026-11-15/source-checkpoint.json) identify the source-only reversible checkpoint. Derived scenes and pictures need rebuilding after reversal. Standard retention runs without a task pin. No physical-device test, export, backend request, deployment, owner-save/process action or main-index staging is performed. Reload and owner appearance acceptance remain. A fresh cache/picture rebuild after the concurrent livery work settles remains outstanding; this checkpoint qualifies source authoring only.
'''
(ROOT/REPORT).write_bytes(text.encode('utf-8'))
summary=f'''VSR01-VSR03: sixteen native paint charts and one offline area-weighted 24mm normal field smooth front arches/cowl and rear quarter/deck transitions. Native positions/indices/UVs exact; proof{proof['checks']}/0, 58 shared stations80.300°to0.0356°. Fourteen contour paths/topology retained and refitted at1.05mm; door7443/0. Stock15254to21309(+6055), fitted27033/full114648; full GPU/articulation exact. Thirty-six Electric-only resources; unrelated frame members/reduction rows retained, no runtime/handling/other-car model authoring. Source/receiving checks, moving highlights and Mobile149/0 qualify; Compatibility149/1 retains one 1/255 restoration pixel with unchanged equality gate. All racing kits, intermediate125-resource preflight and pictures/imports were checked before a final shared livery edit. Final{closure['consumed_inputs']}-input fence rejects {changed_count} changed inputs; cache/global-picture readiness remains unqualified. Current source17/0+11/0 and doors7443/0 pass; no metadata restamping. Rejected sparse/analytical prototypes, initial UV/query, stale livery/cache and exact-pixel controls retained without weakened assertions. Six global selection portraits are derived artwork only. Exact private checkpoint and standard retention preserve concurrent work/index. No phone/FPS/AAA/export/backend/deployment/owner-save/process claim. [Repair, comparisons, measured cost, commands and limits]({REPORT}). Reload/owner review remains.'''
block=('<!-- '+MARKER+' -->\n## Volt wheel surrounds and paint reflections refined (2026-11-15)\n'+summary+'\n<!-- /'+MARKER+' -->\n\n').encode('utf-8')
for name in ('AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md'):
    path=ROOT/name;pattern=('<!-- '+MARKER+r' -->\r?\n.*?<!-- /'+MARKER+r' -->\r?\n(?:\r?\n)?').encode()
    path.write_bytes(block+re.sub(pattern,b'',path.read_bytes(),flags=re.S))
print('VSR_DOCUMENTATION measured correction, limitations and three preserved trackers')
