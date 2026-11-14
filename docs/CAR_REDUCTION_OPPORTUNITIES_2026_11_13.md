# Further car simplification opportunities — 13 November 2026

There is useful room for another geometry pass. The strongest first change is
removing axial rings from straight cylinders: the measured Forklift candidate
removes **13,320 visible master triangles / 26.05%** while retaining its radial
outline, end caps, dimensions, materials and moving transforms. The same operation
removes 2,088 Rally triangles and 2,016 Volt triangles. These are candidates tested
in memory; this review does not publish production changes.

Challenger is excluded from construction, candidate generation and rendering.
No Challenger source, cache metadata, model, material or picture is written.
The review also leaves the newly accepted Kart shoulders, fit, driver poses,
steering and fuel arrangement unchanged.

[Native current/candidate comparisons](evidence/car-reduction-review-2026-11-13/candidate-comparisons.png)
and [reconciled measurements](evidence/car-reduction-review-2026-11-13/summary.json).

## Ranked implementation opportunities

| Priority | Target | Measured opportunity | Recommendation |
|---|---|---|---|
| 1 | Straight cylindrical hardware | Forklift **51,132 → 37,812 triangles (−26.05%)**; Rally **40,396 → 38,308 (−5.17%)**; Volt **38,746 → 36,730 (−5.20%)**; Kart **34,752 → 34,176 (−1.66%)** | Reduce `CylinderMesh.rings` to 1 for straight rods, pins, bolts, wheel wells/hubs and similar parts. Retain radial segments and caps. Integrate in the five-car offline producers; do not alter a shared runtime reducer that would also change Challenger. |
| 2 | Rally seam markers | Two doors and tailgate contain **438 separate box segments / 5,256 triangles**, 13.01% of this car | Replace box segments with connected fitted strips and remove buried/end faces. An ideal two-triangle strip per current segment would use 876 triangles, an upper opportunity of 4,380 fewer (10.84% of the car), before joins/returns. This is a counted design opportunity, not a rendered prototype. Retain width, continuity, body fit and window boundaries. |
| 3 | Static Kart helmet | Current helmet **6,024 triangles**; conservative candidate removes **2,532** while leaving the 6,456-triangle animated suit/glove mesh unchanged | Retopologise or author a reduced helmet with locked attachment, visor boundary and silhouette. The entire car's conservative static candidate is **34,752 → 31,612 (−9.03%)**. Do not simplify the moving cloth or grips during this pass. |
| 4 | Rally static surfaces | Conservative index candidate **40,396 → 30,704 (−23.99%)**; coarser candidate **30,232 (−25.16%)** | Start with roof, wheel detail and large fixed batches. Keep body joins, hood edges, glazing, optics and live lights locked. The small extra saving from the coarser candidate does not justify using it everywhere. |
| 5 | Volt wheels and panels | Conservative candidate **38,746 → 34,892 (−9.95%)**, mostly wheel detail; coarser **27,408 (−29.26%)** includes large body batches | Implement wheel simplification first. Consider a separate race-distance body level with the original close view; retain fitted seams and common panel boundaries. The coarser body prototype changes more close-view pixels. |
| 6 | Hover small tubes and ring detail | Thin skirt-seam resampling saves **1,152 triangles (5.11%)**; fan rim/guard-ring resampling saves **1,920 (8.52%)**; skirt resampling separately saves **1,920 (8.52%)** | Prefer distance-specific seam/guard detail. Keep the existing close hull, canopy, duct interfaces and moulded skirt. These prototypes produce larger close-view differences than the straight-cylinder operation. |

Candidate savings overlap. **Do not add the rows or their percentages.**
The 18,000-triangle total for the axial-only operation is across one instance of
each of the five cars, not a claim that all five render together or a frame-time
measurement. Source counts include repeated instances; raw unique mesh payloads
count shared resources once and will not fall by the same percentage.

## Native comparison evidence

The five cars were compared in the actual `CarShowroom` studio in desktop
Compatibility and Vulkan Mobile, with front, rear and distant elevated views.
The distant view is a studio camera proxy, not an actual `Game` race. Viewports
are 1,000 × 760; all candidates are restored between captures. Unchanged repeats
and restoration controls have zero pixels differing by more than eight levels
in any RGB channel. That threshold is diagnostic, not an owner art-acceptance
criterion.

For the axial-only candidate, the maximum significant changed pixels in any
tested view are:

| Car | Compatibility | Vulkan Mobile |
|---|---:|---:|
| Rally | 0 | 0 |
| Kart | 1 | 1 |
| Forklift | 3 | 2 |
| Volt | 0 | 0 |
| Hover control, no cylinders changed | 0 | 0 |

Some images differ by a few low-level pixel values; byte identity is not claimed.
This supports implementing axial reductions first. It does not establish
perceptual equivalence in every colour, kit, moving pose, light or viewing angle.

The conservative generated-index candidates have at most 19 significant changed
pixels per Rally image, 9 per Kart image, 1 per Forklift image and zero per Volt
image in the two-renderer sample. Their more aggressive variants reach 51, 45
and 62 significant pixels for Rally, Kart and Volt respectively. These are
small image changes, but fitted boundaries and highlights still need specific
production acceptance checks.

Hover's authored-grid candidates were tested in Compatibility only. Reduced
ring sampling reaches 899 significant close-view pixels, reduced skirt sampling
488, and reduced seam sampling 227. At the distant elevated view these fall to
69, 69 and 7 respectively. Thus they are useful distance-detail investigations,
with the existing close appearance retained. No acceptance threshold is passed
merely because the full-image average error is low.

## What the prototypes actually do

The axial prototype duplicates each cylinder resource and changes only its
longitudinal ring count. It does not reduce the radial outline or replace the
material. The Forklift has 227 affected cylinders. All prototypes keep surface
counts unchanged; they demonstrate triangle opportunities, not fewer draws.

The two index prototypes call the existing offline `car_mesh_lods.gd` generator
and promote suitable generated indices to the candidate master surface.
Encoded vertices, normals, UVs and materials are kept. Moving blend-shape meshes
and reflection layers are skipped; existing Hover layer exclusions remain.
The labels `lod1mm` and `lod3mm` describe engine local-space error metrics of
0.001 and 0.003. They are **not independently measured maximum geometric errors**,
and node scaling can change the world-space relationship.

These experiments do not change production LOD thresholds. Promoting a lower
index level reduces stored master triangles but leaves unused vertices in the
prototype; a production base reduction needs a separate raw-byte-preserving
compaction step. Keeping the original close mesh and adding a distance level
can reduce distant rendering work while increasing the stored payload. Selected
runtime LODs, shadows and actual device timings must be measured separately.

Hover's three additional prototypes independently halve the authored grid
columns on fan rings, skirt seams or the pressure skirt. Their original vertex
attributes are retained. They are deliberately separate so the owner can assess
the detail that changes; no combined Hover saving is qualified.

## Current construction and integration limits

The fresh current inventory differs from the previous refinement snapshot:
Kart now has 34,752 triangles, and Forklift 51,132 including its new front panel.
The source and cache-enabled construction counts agree for all five cars.
Only Kart records a prepared-base hit; the other four cache-enabled cases use
fallback construction. A mode labelled `prepared` in the raw JSON means caching
was enabled, not that a hit was assumed. Therefore this review does not claim
that every current prepared base or stored LOD is valid.

After the production changes settle, rebuild and validate the scoped bases,
fitted modules, Garage/header resources and pictures together. Keep Challenger
out of the bake scope, retain strict default full-catalogue gates, and preserve
its existing provenance rather than updating its signatures. Before a release,
verify actual prepared hits, original-versus-candidate geometry/materials,
fitted combinations, driver steering/contacts, live lights, shadows, washing,
ghosts and desktop Garage/race appearance. Then qualify frame times, memory and
thermals on the tablet. No FPS, measured VRAM or device saving is claimed here.

## Commands, source controls and scope

Pinned Godot: `4.7.2.stable.official.ed1daf0bf`, desktop RTX 3090.
Vulkan Mobile is a desktop renderer here. Runs use private profiles, dummy audio
and empty backend URL/auth values.

```powershell
python scripts/run_car_reduction_review.py inventory-generated --headless
python scripts/run_car_reduction_review.py axial-compat --rendering-method gl_compatibility -- --axial-only
python scripts/run_car_reduction_review.py axial-mobile --rendering-method mobile -- --axial-only
python scripts/run_car_reduction_review.py lod-compat --rendering-method gl_compatibility
python scripts/run_car_reduction_review.py lod-mobile --rendering-method mobile
python scripts/run_car_reduction_review.py hover-compat --rendering-method gl_compatibility -- --hover-only
python scripts/summarise_car_reduction_review.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compare_car_reduction_review.ps1
```

Final reconciliation: **1,060 checks / zero failures**, with 99 native
current/candidate image pairs and repeat/restoration controls. Each final run
records 20,688 production/index inputs with zero changes during execution.
The end-to-end closeout also detects four Challenger body-paint/contour resources
changed between runs. Those concurrent changes are recorded and preserved;
all other pinned inputs, including the five reviewed cars and main index,
remain exact across the review. No global unchanged-tree claim is made.
The first inventory examined only pre-existing LODs; its 45-check receipt/log
remain, while the final 120-check inventory also generates candidates offline.
The source manifests are byte-verified compressed JSON, with reconstruction
hashes in `compressed-source-pins.json`.

This task adds review helpers, pictures and this report. It does not publish
production model/cache changes, stage the main index, edit owner saves, restart
owner processes, query/test a physical device, export an APK or deploy anything.
