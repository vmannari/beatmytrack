# Garage environment reduced by about 70% — 2026-11-14

The owner's requested reduction is applied to the Garage room, props and physical display platform. The default environment falls from **134,089 to 41,467 master triangles, a 69.08% reduction**. The workshop is published as the actual runtime asset, rather than depending on a distant LOD setting. Vehicle geometry and handling are outside this change.

G7001: reduce environment geometry by about 70%. G7002: retain recognizable props, object placement, lights, car presentation, record animation and interaction attachments. G7003: publish prepared assets under the existing source/output checks and qualify the live Garage.

| Component | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| Spare-wheel rack and wheels | 28,840 | 6,672 | 76.87% |
| Workbench and tools | 22,431 | 4,770 | 78.74% |
| Plant, planter and soil | 14,739 | 3,726 | 74.72% |
| Trophy display wall | 11,800 | 3,679 | 68.82% |
| Tool storage | 10,964 | 4,084 | 62.75% |
| Compressor | 9,827 | 3,185 | 67.59% |
| Record station, vinyl and 14 sleeves | 8,202 | 4,539 | 44.66% |
| Architecture, roof and shared fixtures | 9,728 | 4,274 | 56.06% |
| Drain | 3,904 | 1,152 | 70.49% |
| Other props, including poster | 8,360 | 2,916 | 65.12% |
| **Prepared workshop** | **128,795** | **38,997** | **69.72%** |
| Physical display platform | 5,280 | 2,456 | 53.48% |
| Floor and six contact-shadow quads | 14 | 14 | 0% |
| **Default complete environment** | **134,089** | **41,467** | **69.08%** |

These are stored master counts, not GPU frame submissions or FPS measurements. Cutaway, LOD and culling reduce visible geometry; the two reflection views add work. Earned awards, record contents and the selected car change the complete scene total. The counts follow the [preceding audit](GARAGE_TRIANGLES_2026_11_14.md); [final inventory and costs](evidence/garage-70-2026-11-14/counts.json) retain the individual groups.

The compressed workshop is 1,918,871 → 587,377 bytes. Unique ArrayMesh payload, including stored LOD index buffers, is 6,401,998 → 1,985,052 bytes (68.99% less). This measure excludes PrimitiveMesh parameter resources. The scene has 109 mesh instances/96 unique meshes versus 108/95: the hole-mark surface adds a finish batch, so this is not a draw-call reduction claim.

## Construction changes

Small thin boxes use closed six-face geometry. Broad shutter panels, long structural rails and larger bodies retain their bevels; shutter bevels were restored after reviewing the flatter draft. Turned profiles keep their authored rows and analytic normals with fewer azimuth samples. Default tubes use eight or twelve sides, with explicit authored polygon counts retained. Rolled rings use four cross-section segments. The main platform cylinder retains its 96-sided silhouette; its smaller rolled rings use 64 major samples.

The 182 pegboard hole marks are represented by one two-triangle surface and an original procedural shader, preserving their centres and spacing. This exchanges geometry for fragment shading and a masked finish batch. No external images or models are introduced.

Spare tyres use 24 circumference samples, fewer wider raised tread blocks, lighter rim lips and flat brake-vent marks. The plant retains its leaf count and branching arrangement with six-by-two leaf grids, fewer branch samples and 24-sided planter profiles. Eight chips remain on the textured soil. Laurel stems/leaves and the flat brand lettering use less geometry; the record station retains its independently animated vinyl, sleeve holders and artwork.

Opaque closed cylinders also receive exact cap retriangulation: the same convex cap boundary needs four fewer triangles across the two ends. Original position/UV records, side triangles, cap area, winding and primitive culling bounds are retained. The existing conservative enclosed-face and unused-vertex cleanup still runs. Cone and open-cylinder cases are excluded.

## Qualification and appearance tradeoff

The dedicated budget/geometry regression passes **70 checks, zero failures**. It compares the prepared candidate with fresh procedural construction, compares every named non-mesh object's transform/class with the original room, retains the eight principal objects, six award attachments and record-animation nodes, and verifies cap area, bounds, original records and winding for seven polygon counts. The original cleanup suite passes **20/0**. Production parsing passes **573 scripts/0**.

Native paired views cover all six stock cars at front/rear/close positions plus ten object views, with both reflection images for each pose: **84 before/after image pairs per renderer**, **202/0 fixture checks** each on desktop Compatibility and desktop Mobile. Each pair uses the same live car instance and finish. Layout and principal objects remain recognizable in the inspected images; close views visibly show coarser curves, leaves and fewer bevels.

The prior small-change pixel gate is preserved: mean RGB error below 0.25/255 and fewer than 0.5% of pixels changing by more than eight levels. It passes **54/84 Compatibility** and **53/84 Mobile** pairs, so this change does **not** claim appearance equivalence. The largest mean error is 1.659437/255 in the Compatibility record close-up; its >8-level fraction is 5.241428%. The normal Compact front view measures 0.539261/255 and 2.082031% Compatibility; 0.450557/255 and 1.662760% Mobile. Full metrics remain in the final native logs. The controlled candidate's geometry/finishes equal the published workshop through the exact source-versus-prepared checks; actual App tests load the published asset directly.

The unchanged historical `test_garage_prop_detail.gd` reports **78 checks/22 failures**, all old fine-detail/chord-error/sample-count policy expectations superseded by the owner's much larger reduction target. No historical assertion is weakened. An earlier six-sided tiny-tube draft also lost two exact axial extents; eight sides restore those extents. Initial cap-bound checks exposed float rounding in primitive versus generated AABBs; retaining the original bound metadata resolves both without relaxing the tests. An intermediate 41,507-triangle candidate misses the unchanged new budget and is rejected; reducing soil chips gives the final 41,467.

An initial Mobile comparison times out during animated car switching. The static comparison fixture hides its view while replacing the car, avoiding an unrelated reveal-shader construction, then restores it for every capture. Actual App tests separately exercise the live behavior. Final paired runs exit cleanly on both renderers.

| Actual live behavior after workshop publication | Compatibility | Desktop Mobile |
| --- | ---: | ---: |
| First capture, selected car and cancellation | 90/0 | 90/0 |
| Opening reflections | 18/0 | 18/0 |
| Opening tools | 16/0 | 16/0 |
| Actual App Garage entry/input | 45/0 | 45/0 |

The App fixture uses disposable offline storage and the previously qualified foreground adapter for its offscreen window. Production foreground checks remain intact. First-capture 90/0 and App 45/0 both repeat after cache publication in both renderers. The final App fixture observes first live entry at 1.377s Compatibility/2.165s desktop Mobile; these are individual health samples, not matched performance controls or attribution to triangle reduction. Initial live checks occur while shared car-code cache inputs are stale and are excluded from any performance comparison.

No vehicle source is authored by this pass. Separate concurrent work reduces five cars while this task runs. The final inventory observes Rally 10,294, Kart 10,294, Forklift 10,504, Volt 9,987, Hover 10,300 and Challenger 42,196. An intermediate audit still observes the earlier five counts and Challenger 42,196 versus the preceding audit's 38,612; those vehicle changes are preserved. The final environment comparisons repeat with the current cars and always use the same car for their two phases.

## Publication, commands and limits

The workshop producer's existing private candidate, error logger, 28-source fence, exclusive output lock and manifest-last rollback publish the reduced scene. The exact source-versus-prepared budget check passes again against the published asset. The read-only workshop gate confirms all 28 current source hashes.

Current shared car-code changes invalidate all 551 prepared resources' complete-source guards during the initial checks. A private full-cache attempt rejects 12 native diagnostics from a newly declared but not-yet-present `car_10k_v1` input directory. No rejected candidate is published. The new source assets and 387 changed generated outputs are detected and preserved. An intermediate live preflight reports 324 findings while the other producer is still writing.

The concurrent five-car producer excludes Challenger, so a private repair rebuilds its bases/kits and the current six rest scenes/stock header. An initial combined preflight retains 42 findings while other outputs are still in progress. The final combined private preflight passes **551 resources/2,267 checks/0 failures**, and source/output fences publish **89 changed cache resources** while preserving the other five cars' base/module bytes. This is actual producer reconstruction, with no metadata restamping or model-source authoring. The final live 551-resource preflight also passes **2,267/0**.

Six native catalogue photographs refresh against the combined current resources. The read-only photo validator confirms **six exact images/173 current source hashes**; six native image imports are generated in a private editor project and copied only after source checks. The workshop validator confirms its exact scene and **28 current inputs**. Final native pairs, live entry/capture, budget and production parsing run with **26,197 relevant source/output files unchanged**. [Final fence](evidence/garage-70-2026-11-14/final-fence.json), [cache publication](evidence/garage-70-2026-11-14/repair-publication.json) and [final checks](evidence/garage-70-2026-11-14/final-verification.json) retain the receipts.

The generated client identity is refreshed after photograph publication, with exact modular-car key controls. Every file in the closed native fence remains exact except those two deliberately generated identity/project files; [identity controls](evidence/garage-70-2026-11-14/final-identity-controls.json) record them. A [13-file normalized source-only checkpoint](evidence/garage-70-2026-11-14/checkpoint.json) applies and reverses exactly in a private fixture; generated resources and unrelated shared work are excluded. Required build retention cleanup is applied: no eligible entries are removed, with 30.31 GiB remaining under recent/protected/locked exclusions and the 24-hour active-work grace. No task pin is created.

Representative commands (all engine launches use the pinned 4.7.2 executable through `run_no_crash_dialog.py`):

```powershell
python scripts/run_garage_70.py published-budget --headless --reference-room=res://../build/garage-70-2026-11-14/before/workshop_v1.scn
python scripts/run_garage_70.py paired-gl-final --script res://../build/garage-70-2026-11-14/paired.gd
python scripts/run_garage_70.py paired-mobile-final --renderer mobile --script res://../build/garage-70-2026-11-14/paired.gd
python scripts/run_garage_70.py publish-workshop --headless --script res://tests/bake_garage_architecture.gd --output="C:\Codes\Godot\Beat my track\game\assets\garage"
python scripts/check_garage_workshop.py
python build/garage-70-2026-11-14/repair_challenger.py --resume
python scripts/check_garage_previews.py
```

[Native Compatibility before](evidence/garage-70-2026-11-14/gl_compatibility/before/compact-front.png) · [after](evidence/garage-70-2026-11-14/gl_compatibility/after/compact-front.png). [Tyres before](evidence/garage-70-2026-11-14/gl_compatibility/before/tyres.png) · [after](evidence/garage-70-2026-11-14/gl_compatibility/after/tyres.png). [Mobile plant before](evidence/garage-70-2026-11-14/mobile/before/plant.png) · [after](evidence/garage-70-2026-11-14/mobile/after/plant.png). The evidence folder retains concise commands, metrics, source transcripts and selected native comparisons; disposable control scenes, full projects and shader caches remain under `build/`.

Restart/reload and owner appearance acceptance remain. No physical-device test, export, live backend operation, deployment, owner-save/process action or main-index staging/commit. Triangle and buffer reductions alone do not establish a first-load, FPS or device-speed improvement. Existing historical policy failures prevent a whole-suite clean claim.
