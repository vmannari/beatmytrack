"""VRC01-VRC03: record the local correction and its measured cost."""
import json,re
from run_volt_corners import ROOT,OUT
MARKER='VOLT-REAR-CORNERS-20261115'
REPORT='docs/VOLT_REAR_CORNERS_2026_11_15.md'
closure=json.loads((OUT/'closure.json').read_text())
geometry=json.loads((OUT/'geometry-proof.json').read_text())
before=json.loads((OUT/'before.json').read_text())
after=json.loads((OUT/'prepared.json').read_text())
def result(label):
    receipt=json.loads((OUT/(label+'-receipt.json')).read_text())
    assert receipt['exit_code']==0 and not receipt['errors']
    lines=(OUT/(label+'.log')).read_text(encoding='utf-8',errors='replace').splitlines()
    matches=[line for line in lines if re.search(r'\d+ (checks|scripts|resources)',line)]
    return matches[-1] if matches else 'Clean run; exact command in receipt'
table='| Model | Before | Corrected |\n|---|---:|---:|\n'
for row in after['rows']:
    old=next(x['inventory']['triangles'] for x in before['rows'] if x['mode']==row['mode'])
    table+=f"| {row['mode']} | {old:,} | {row['inventory']['triangles']:,} |\n"
labels=['source-models','prepared-models','door-clearance','all-kits','parser','driving','prepared-final']
labels += [kind+'-'+method for kind in ('native','app','icons','wash') for method in ('gl_compatibility','mobile')]
validation='| Check | Actual result |\n|---|---|\n'
for label in labels:validation+=f'| {label} | {result(label)} |\n'
text=f'''# Volt rear corners corrected (2026-11-15)

The sharp dents above both rear wheels are removed by locally restoring the original rear skin and its normals. The door seams and handles from the previous repair remain intact. [Matched left/right corner comparison](evidence/volt-rear-corners-2026-11-15/rear-corners-comparison.png).

**VRC01 - Correct the deformation locally.** Close-up diagnosis traces the dents to the heavily reduced side skins, already present before the latest 10% iteration. The original native rear skin replaces that reduced region from local Z=1.20 m, with a short transition ending at Z=1.42 m. The leading door surface is retained. Both halves use identical join subdivisions; polygons also split at the end of the transition so no fitted triangle extends into the native corner region. All existing camera, scale and articulation settings remain.

The independent proof passes **{geometry['checks']}/0**. Original encoded door vertices are retained; sampled door geometry differs by at most 0.000031 mm from the prior model. The restored rear region differs by less than 0.00002 mm from the native source, versus 2.07/2.99 mm for the rejected reduced skins. Native rear normals remain within 0.000063 after encoding. Both sides retain one connected surface, one boundary loop, Euler characteristic one and zero nonmanifold edges. The original deformed model rejects the native-surface gate. The first candidate also exposed a 5.9-9.3 micrometre triangle-plane error across the transition endpoint; splitting those polygons fixes it without relaxing the one-micrometre gate.

**VRC02 - Preserve the door repair and other geometry.** Two new side meshes retain the protected master policy through assembly and distance selection. Two existing exact detail recipes reference these meshes; two new surface-frame recipes preserve every other member and all existing reduction rows. Fourteen contour resources receive metadata-only backing identity updates, with their GPU data unchanged. This is twenty Electric-only production resources, with no production GDScript, handling, full-quality model or other-car authoring.

The existing clearance/coverage checks are retained in a new correction fixture with the intentionally changed whole-side hashes and protected triangle total. All **7,443** checks pass; before/after seam and handle GPU streams are also exact in stock/fitted source and prepared models. The original iteration fixture remains unchanged as a historical whole-side identity control. Full-quality GPU streams and articulation remain byte-exact to the task-start prepared snapshot.

{table}
The correction costs **1,037 racing triangles**. Volt's corrected stock model is still 1,761 triangles (10.35%) below the 17,015 count before the previous seam-repair/reduction iteration. No additional simplification is applied to offset the repair. This prioritizes the requested appearance correction. Actual encoded buffers and surface counts are retained in [prepared measurements](evidence/volt-rear-corners-2026-11-15/prepared.json); there is no FPS or physical-device performance claim.

**VRC03 - Qualify receiving consumers and publish a checkpoint.** The actual stock/fitted prepared models are captured from the front, rear, both sides, roof/door/handle close-ups, distance and three dedicated rear-corner views. Each desktop renderer has 32 matched before/after pairs, equal root transforms, stable references and exact baseline restoration. The receiving Garage/race, all racing kit choices, icon appearance/capture/cache/cancellation and washing assertions are exercised. The complete Volt prepared resource scope is validated separately; unrelated model readiness is not inferred.

{validation}
The cache rebuild and closure fence cover **{closure['consumed_inputs']:,} live consumed inputs**. A concurrent livery update temporarily removed its catalogue and changed shared code/artwork during the first bake. That parse attempt, the stale prepared-hit control and the rejected twenty-input fence are retained; no concurrent content is reverted or provenance restamped. A second complete bake rejected a further concurrent Hover SVG change. Both quality families are actually rebuilt against the final accepted inputs. The first wash-fixture run exposed leftover Rally-specific selectors after scoping it to Volt; those selectors were corrected to exercise Volt throughout, with the failed receipt retained and every wash assertion preserved. A first desktop Mobile icon run reached its unchanged 20-second readiness deadline during the ongoing cache rebuild; that failed run is retained separately from the final receiving check. No cold-start or device icon latency claim is made. The inherited synchronous standalone Garage insertion then stalled under Vulkan (281.484-second initial stop and three diagnostic stops, all exact task-owned helper PIDs). Early window sizing and a post-race draw barrier did not resolve that legacy path. The correction fixture uses the receiving App's progressive Garage opening and cached carousel settings (`game/core/features/garage.gd`), adds an explicit readiness gate and retains every original washing assertion and pixel threshold. That old synchronous insertion path remains unqualified; no production runtime change is made for it. All diagnostic receipts and the owned-process stop receipt are retained. Final washing passes 316 checks per renderer. The cached carousel emits existing native raw-image loading warnings for concurrently generated selection portraits; the six-picture/25,592-input portrait validator passes, and those images are preserved. No export claim is made. The new header/shared picture and legacy catalogue picture are regenerated, with native imports verified. Challenger remains excluded from authoring. Other source/code/index changes are preserved.

Representative actual commands; exact engine arguments, isolated profiles, errors and timings are in per-command receipts:

```powershell
python scripts/run_volt_corners.py baseline res://tests/capture_volt_corners_baseline.gd
python scripts/run_volt_corners.py survey res://tests/survey_volt_corners.gd --headless
python scripts/run_volt_corners.py build-bounded-rear res://tests/build_volt_corners.gd --headless
python scripts/check_volt_corners_geometry.py
python scripts/run_volt_corners.py stage-repair-retry res://tests/stage_volt_corners.gd --headless
python scripts/publish_volt_corners.py
python scripts/refresh_volt_corners.py
python scripts/qualify_volt_corners.py
python scripts/artwork_volt_corners.py
python scripts/close_volt_corners.py
python scripts/checkpoint_volt_corners.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

[Publication bindings](evidence/volt-rear-corners-2026-11-15/publication.json), [closure](evidence/volt-rear-corners-2026-11-15/closure.json), [source patch](evidence/volt-rear-corners-2026-11-15/source.patch) and [checkpoint receipt](evidence/volt-rear-corners-2026-11-15/source-checkpoint.json) record the exact task scope. The private source-only checkpoint applies/reverses byte-for-byte without using the shared index. Derived assets require rebuilding after a reversal. Standard retention runs without a task pin. No phone/device test, export, backend request, deployment or owner-save/process action is performed. Reload and owner appearance acceptance remain.
'''
(ROOT/REPORT).write_bytes(text.encode('utf-8'))
summary=f'''VRC01-VRC03: local native rear skins/normals remove both haunch dents; leading door encoded vertices and geometry are preserved. Independent14/0 rejects the old2.07/2.99mm corner error; restored rear error<0.00002mm, stable surface topology, one-micrometre gate retained after split-end correction. Twenty Electric-only resources retain exact frame/reduction members, unchanged contour GPU data and protected distance policy. Stock14217to15254(+1037), fitted22706/full114648; full GPU/articulation exact and door7443/0. Actual source/prepared, all racing kits, 32 paired native views and receiving App/icons/wash per desktop renderer pass as recorded. Final{closure['consumed_inputs']}-input scoped fence, regenerated pictures/imports, exact source checkpoint and standard retention preserve concurrent livery/Challenger/UI/index work. Initial missing-catalogue/stale-key/input controls retained. No phone/FPS/export/backend/deployment/owner-save/process claim. [Correction, comparisons, counts, commands and limits]({REPORT}). Reload/owner appearance review remains.'''
block=('<!-- '+MARKER+' -->\n## Volt rear corner distortion corrected locally (2026-11-15)\n'+summary+'\n<!-- /'+MARKER+' -->\n\n').encode('utf-8')
for name in ('AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md'):
    path=ROOT/name;data=path.read_bytes();pattern=('<!-- '+MARKER+r' -->\r?\n.*?<!-- /'+MARKER+r' -->\r?\n(?:\r?\n)?').encode()
    path.write_bytes(block+re.sub(pattern,b'',data,flags=re.S))
print('VOLT_CORNER_DOCUMENTATION requirements, measured results and three trackers')
