# Challenger original body shape restored

The owner's latest correction is that the accumulated surface repairs have changed the overall appearance. The accepted implementation therefore restores the original dense body and bonnet, rather than continuing the replacement shoulder/nose/quarter loft. This is a restoration of the model's proportions. It is **not an AAA finish claim**: close native views still show some source faceting, particularly around the front wing and returned panel joins.

Evidence is in [challenger-reference-repair-2026-11-14](evidence/challenger-reference-repair-2026-11-14/). The folder spans 14–15 November; the final restoration is dated 15 November locally. Earlier captures and failed candidates in that folder are not the final asset.

## Final geometry

`scripts/challenger_exterior_geometry.py` restores the body paint and bonnet from the immutable `art_sources/challenger_hellcat_v1/source-panels.npz` and its component labels. The owner's original Blender download is no longer present. The retained source is not rewritten. Original game scale, the existing 14 cm nose extension, plan taper, corner transform, axle positions and right-half symmetry convention remain. Consequently, “original” here means the source exterior in that established game coordinate system, not a new photogrammetric reconstruction of the supplied photograph.

The source body uses 348,362 painted triangles and the bonnet 31,552 before reduction. The replacement keeps the original silhouette, bonnet crown, cowl, wheel openings and panel-edge stations. Body-only welding is limited to 1.5 mm. Both remaining boundaries and original seam stations that become interior after welding are protected during reduction. Shading comes from the dense source; transferred normals that face into their actual triangle are reversed without moving any vertices.

The authored central grille recess, perimeter and honeycomb are fitted to the original paint opening together. The four projector pockets stay in their original positions. Rear optics and side markers are seated on the retained body. Compact joining skins remain protected from generic reduction.

The bonnet marking now follows the actual projected factory footprint. Its two edges have explicit perpendicular insets of 1.25 and 3.75 mm and sit 1.8 mm above the actual hood. Producer-known pair identifiers are exported in two integer UV channels; the native baker converts them into the existing contour shader attributes. The native marking does not need runtime topology guessing or runtime ray fitting. Neutral UV/color allocation uses the final post-symmetry vertex count.

| Actual assembly | Triangles |
|---|---:|
| Full source construction | 83,522 |
| Reduced source construction, before coarse recipes | 49,584 |
| Production reduced fixed stock | 42,130 |
| Production reduced editable stock | 42,128 |

Both source allocations pass the retained 85k/full and 50k/reduced limits. This is not a new triangle-saving or frame-rate claim. The two-triangle editable difference is an existing hidden-face recipe on the separate spoiler frame; disabling that recipe makes both stock counts equal. It does not change the restored paint or bonnet.

## Original-shape evidence

The independent pinned-Blender survey compares native triangles to the immutable original source surface and checks its boundary and width sections. It passes **588/0**. The same final survey rejects the earlier broad replacement with **588/20**. No repository test assertions were weakened.

| Native painted surface | Maximum error | 95th-percentile error |
|---|---:|---:|
| Reduced body | 2.226 mm | 0.651 mm |
| Full body | 0.990 mm | 0.332 mm |
| Reduced bonnet | 0.538 mm | 0.295 mm |
| Full bonnet | 0.239 mm | 0.145 mm |

All 3,278 original positive-side panel-edge controls pass; maximum boundary displacement is below 1.480 mm. Native nose, cowl and rear width sections pass their original-source controls. Visible-size faces have no inward macro shading normals under the retained survey. These measurements concern geometry, not pixel equivalence to the real-car photograph or artistic acceptance.

The final proof is `factory-shape-factory-shape-final.json`; the rejected control is `factory-shape-factory-shape-broad-control-final.json`. The doubled prefix reflects the actual evidence command's label. Losslessly compressed decoded inputs are retained alongside them. The checked source-only patch covers exactly three production sources: the converter, the new geometry helper and the native baker. It applies and reverses byte-exactly in a private Git repository; it does not stage the shared index.

## Validation and publication

Final converter and native bake receipts pin their actual inputs. Publication checks the previously published native bytes, car configurations and unconsumed legacy files, writes the consumed allowlist, and publishes the manifest last with rollback. The live allowlist contains 44 meshes and four JSON files. Four unused legacy hood resources remain exact.

Confirmed focused results include source allocation **17/0**, native contours **172/0**, all fitted Challenger modules **1436/0**, physics/replay **3677/0**, and prepared opacity **30/0** in each desktop renderer. The livery refresh produces 49 native captures. The scoped base/kit/Garage/header/art/catalogue rebuild uses the current production sources and strict provenance checks.

Final washing **1655/0**, driving **72/0**, fitted-bonnet **316/0** and production parser **573/0** pass. Actual App Garage selection and local race pass **13/0 in each desktop renderer**. Complete prepared preflight passes **551 resources / 2267 checks / 0 failures** after the concurrent dependency update and actual asset rebuilds. This is a prepared-asset pass, not a whole-repository test-suite pass.

Each renderer has twenty final reduced-model views and six full-model close views. Their `model-path.json` records an actual production base-cache hit, with `candidate=false`; none of the shading diagnostic flags is used. Native views and actual-App captures are retained under `final/`. See the final [side view](evidence/challenger-reference-repair-2026-11-14/final/views-restored-prepared/gl_compatibility/simple/white-left.png), [front quarter](evidence/challenger-reference-repair-2026-11-14/final/views-restored-prepared/gl_compatibility/simple/red-front-quarter.png) and [actual Garage](evidence/challenger-reference-repair-2026-11-14/final/app-restored/gl_compatibility/garage.png). Concurrent five-car budget work, Garage environment work, dependency edits, generated identity and index changes are preserved.

Actual principal commands, run from the workspace root with pinned tools and private offline profiles:

```text
python docs/evidence/challenger-reference-repair-2026-11-14/run_preparation.py
python docs/evidence/challenger-reference-repair-2026-11-14/run_check.py native-final res://tests/bake_challenger_hellcat.gd --headless --audio-driver Dummy -- --source=res://../build/challenger-reference-repair-2026-11-14/converted/ --dest=res://../build/challenger-reference-repair-2026-11-14/native/
build/tools/blender-4.5.15-windows-x64/blender.exe --background --factory-startup --disable-autoexec --python-exit-code 1 --python docs/evidence/challenger-reference-repair-2026-11-14/check_factory_shape.py -- build/challenger-reference-repair-2026-11-14/decoded-restoration-final.json factory-shape-final
python docs/evidence/challenger-reference-repair-2026-11-14/publish_restoration.py
python docs/evidence/challenger-reference-repair-2026-11-14/guarded_assets.py
python docs/evidence/challenger-reference-repair-2026-11-14/refresh_restored_prepared.py
python docs/evidence/challenger-reference-repair-2026-11-14/refresh_restored_pictures.py
```

The wrappers retain full commands, output, exit codes, private profile locations and source fences. The full rebuild is supplementary to the scoped rebuild; a rejected full rebuild does not qualify its output merely because its producers exit successfully.

## Rejected attempts and limits

The first broad procedural replacement was published earlier in this task and is superseded by the factory restoration. Its source-only checkpoint and decoded geometry remain as the rejection control. Early source surveys incorrectly used nearest-vertex distance; the final survey uses true triangle-surface distance. That correction exposed a real seam-protection omission, which was fixed in geometry without relaxing the boundary limit.

An early restored bonnet contour misses 40 vertices around the cowl in each tier and fails four retained checks. The projected footprint and mitered inset correct the actual marking; the final live model passes all 172 checks. A private candidate wrapper still reads the old imported outline and reports two fit failures; a direct independent native survey and the final live fixture both pass. This wrapper is not used as final acceptance.

Recomputing or spatially averaging front-wing normals in diagnostic views does not remove the source's returned join/faceting cleanly. A source-profile normal chart also introduces worse boundary transitions. Those diagnostic variants are not published. Fine surface cleanup remains an artistic limitation of this restoration.

The retained coarse-source fixture reports a fixed/editable count failure caused by the two spoiler triangles described above. Its exact encoded-attribute and material checks pass; the count assertion remains unchanged. The stable hidden-face-disabled control is retained. Earlier actual-App race preparation timeout and headless cleanup diagnostics remain in their original logs and are not silently replaced by unrelated passing results.

A final full refresh initially rejects 550 stale checks outside the Challenger scope. Its subsequent all-car rebuild encounters a concurrent dependency-manifest update during final identity generation: source snapshots are equal, but the newly read model keys differ, and the stricter identity guard rejects the run. Later validation must use the current inputs and actual rebuilt assets; no metadata-only restamping is used to bypass this rejection.

The later scoped rebuild uses the new manifest, passes its unchanged-source/key fences and qualifies **84 resources / 349 checks / 0 failures**. The subsequent complete prepared check passes **551/2267/0**. The earlier rejected receipts remain; no earlier output is retroactively accepted by changing its metadata.

The final catalogue-only refresh keeps the expanded **25,656-input** fence exact before/after, retains the live model keys, passes complete prepared validation **551/2267/0** and validates **six actual pictures / 173 sources**. All 58 current native image imports match their source MD5s with zero editor diagnostics; the workshop matches its exact scene and 28 source hashes. `final-state.json` binds the current checkout to those results. `retained-restoration.json` records the native allowlist, four unused legacy controls, source checkpoint and archived evidence. Standard `scripts/clean_build.ps1 -Apply` retention completes, reducing build storage **31.25 to 30.36 GiB** across three entries; recent/protected/locked output remains above the standard target. The result is recorded in `retention-command.json` and `retention.log`; no task pin is created.

No device query/test, APK/export, backend request, deployment, owner-save modification or owner-process restart is performed. Handling configurations and the Challenger runtime builder are retained. The desktop captures are not device performance evidence. Reloading the game is required for an already-running owner process to see the new native assets. Owner appearance acceptance remains separate from the numerical checks.
