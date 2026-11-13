# Remaining vehicle and track asset optimisation — 8 November 2026

There are worthwhile gains left. The strongest measured candidates are better
road/kerb buffer packing, indexing finished Winter meshes and restoring prepared
resources after current source edits. Further car work should target expensive
surfaces and selected components. A blanket geometry reduction is less attractive
after the accepted simpler models became the production choice.

This is a review and offline prototype study. It changes no production runtime
source, model, texture, cache policy, physics or quality setting.

## Scope

| Requirement | Coverage |
| --- | --- |
| AOR01 | All six current catalogue IDs, representing five authored chassis. Super Rally shares Rally geometry. Stock/fitted and race/editable Garage constructions give 24 live cases; six stored resources are inspected separately rather than assumed active. |
| AOR02 | All 58 placed-object kinds in all five biomes: 290 combinations. Trees, bushes, rocks, tyres, barriers, fences, buildings, Egyptian/Winter crafts, night objects, vehicles and equipment are included. |
| AOR03 | Complete native worlds for the existing ten-piece `to_the_trees` fixture in Pine, Desert, Night City, Winter and Storm, including roads, kerbs, bridge structure, terrain, banks and generated low cover. Three camera views per biome on both desktop renderers. |
| AOR04 | Offline packing and tyre-shape candidates, native original/candidate/restoration controls, exact ordered-position checks, source/cache diagnostics and a prioritised recommendation. |

Catalogue totals describe intact, active mesh geometry at default object scale
and span. Dirt/water stamps have no separate placed-object mesh in that path.
Contact-lighting overlays, inactive breakage phases and particle/light runtime
costs are not included in those geometry totals. Every kind is inventoried;
every possible authored placement, damage state and track population is not.

## Recommended order

1. **Refresh the currently rejected prepared resources after source work settles.**
   All 24 live car cases constructed their reduced geometry procedurally, with
   zero prepared-base/module hits and no mesh LOD buffers. Later direct guard
   inspection found matching construction keys but mismatched runtime source
   fingerprints for all six IDs. Existing stored files do contain LODs; treating
   their older shapes/counts as the current active model would be misleading.
   The ice-car scenery map also rejects its current source signature in all five
   biomes, while container and snow-castle maps accept. Preserve those guards and
   regenerate/revalidate the affected data. These are observations about this
   changing source checkout, not a diagnosis of an installed tablet build.
2. **Pack road and kerb vertices before their first GPU encoding.** The strongest
   measured road surface keeps all 39,962 triangles and ordered positions while
   reducing buffer bytes by 72.5%. Other road surfaces offer smaller savings.
   Retain road/kerb profiles, joins, UVs, shading, terrain alignment and all
   canonical drivable geometry.
3. **Index Winter meshes after snow colours are authored.** Tree, tyre and fence
   prototypes save actual mesh-buffer space without removing triangles. Keep
   snow's source-ordinal colouring intact, preserve encoded normals and retain
   shared instancing and existing spatial/caching limits.
4. **Investigate car surface batching and selected heavy components.** Volt has
   the highest current surface/draw count; Forklift has the largest stock base
   geometry. Keep paint, condition, glass, lamps, suspension, steering, wheels,
   fitted parts and the newly accepted kart driver working independently.
5. **Add authored distance variants where population justifies them.** A gentler
   tyre variant looks close at racing scale and removes 22.7% of submitted model
   triangles. Keep the original near shape. Tree variants must protect branch
   layering and foliage tips; building variants must protect structural detail.

## Measured packing candidates

These are raw mesh-buffer payloads, not process RAM, package size or FPS. Tyre
stack resources are shared by their MultiMesh instances; bytes are counted once,
not once for every visible tyre.

| Candidate | Original → candidate | Buffer saving | Geometry/appearance evidence |
| --- | --- | ---: | --- |
| One actual Pine road surface | 4,795,440 → 1,318,252 bytes; 119,886 → 26,962 vertices | 72.51% | All 39,962 triangles and ordered positions retained. Both tested views are pixel-exact on both desktop renderers. |
| Actual kerb mesh | 531,216 → 402,840 bytes; 18,972 → 13,032 vertices | 24.17% | Every ordered position/triangle retained. Dedicated integrated kerb pixel/motion qualification remains for implementation. |
| Winter pine tree | 114,480 → 91,308 bytes; 4,770 → 3,407 vertices | 20.24% | Same submitted triangles. Racing images exact in both desktop renderers; close images differ by at most 2/255 in sparse pixels. |
| Shared Winter tyre stack | 104,832 → 63,960 bytes; 4,368 → 2,301 vertices | 38.99% | Same submitted triangles, openings and snow. Racing images exact; close maximum difference 1/255 Compatibility, 2/255 Mobile. |
| Winter fence | 48,384 → 41,496 bytes; 2,016 → 1,561 vertices | 14.24% | Same triangles; both inspected views exact on both renderers. |

The exploratory SurfaceTool route decodes and re-encodes normals. Decoded normal
differences reach about 0.000128; it is **not GPU-byte-exact**, even where rendered
pixels match. A production pass should index the final CPU arrays before their
first upload, or preserve/remap raw attributes using the existing pattern in
`track/spatial_mesh_chunks.gd`. Preserve LOD streams and metadata when applicable.
Do not blindly replace arbitrary shared meshes with the review helper.

## Current cars

The live baseline is the accepted reduced constructor, not the former detailed
master. Counts below are stock race cases, before distance LOD, outlines or
reflection passes. Native draw counts are isolated Compatibility observations.

| Vehicle | Base triangles | Surfaces/material passes | Isolated visible draws |
| --- | ---: | ---: | ---: |
| Rally | 39,756 | 55 | 65 |
| Kart | 22,951 | 60 | 70 |
| Forklift | 50,744 | 44 | 54 |
| Volt | 38,282 | 85 | 95 |
| Hover | 22,644 | 18 | 20 |
| Super Rally | Same authored chassis as Rally | Same geometry groups | Shared chassis, not an additional independent design |

The four largest Forklift meshes contribute 32,424 triangles, about 64% of its
stock base total. Those groups are a better starting point for selective authored
detail levels than a uniform reduction. Stock Volt's 85 surfaces make material
and transform-frame grouping worth investigating; its fitted sample uses fewer
groups despite more triangles. Existing sibling/frame batching already merges
compatible parts, so a further pass must address remaining compatibility and
material differences rather than merely calling the same batcher again.

Most car vertices are already indexed. The extra indexing probe finds little
or no additional vertex reuse for Kart, Volt and Hover; the car opportunity is
not a repeat of the large road packing gain. Hover's layered glass/deck/duct
surfaces remain protected by the established car LOD policy. Keep its pressure
skirt/rotor savings and author any additional levels with seam checks.

## Trees, tyres and other objects

Pine trees have 1,550 model triangles each; Winter trees have 1,590. Broadleaf is
1,208 and a bush 648. Their cost multiplies across scenery populations. These are
opaque authored geometry, not alpha-card foliage. Index finished Winter data
first; then test branch-aware distance variants within the existing batch/tile
system. The older automatic tree candidate lost visible sprays/layers and remains
an unsuitable default. Spatial culling and bounded caches already exist; retain
their conservative fallbacks rather than adding a draw for every object or
raising budgets to force a result.

For six paired tyre stacks, the present model submits 7,200 triangles. Two
review-only alternatives keep the hollow bead, shoulder profile and all 24 tread
cuts:

| Authored variant | Wall triangles | Reduction | Recommendation |
| --- | ---: | ---: | --- |
| 16 carcass sides / 16 bead sides | 5,568 | 22.67% | First candidate for racing-distance use. Slightly more angular near view. |
| 12 carcass sides / 16 bead sides | 4,704 | 34.67% | Farther-only experiment; stronger close-view faceting. |

The original carcass has 20 sides and its bead 24. The prototype reproduces that
original builder exactly at those original settings before testing alternatives.
Retaining both authored sampling levels can increase stored resource memory;
these triangle reductions are not simultaneous RAM savings.

Other substantial individual props include warehouse 9,790 triangles, igloo
6,926, pyramid 6,988, snow lantern 6,116 and grandstand 4,720. Container and snow
castle already have the accepted selective LODs. Restore the stale ice-car map
before treating its full current count as an unoptimised design. Warehouse
braces, grandstand seats, masonry courses/capitals and crate construction need
authored protection; previous generic reductions removed those details. Small
rounded lantern/ornament variants are reasonable future candidates, but this
review does not invent a saving percentage without a prototype.

The representative worlds retain 116,166–387,564 base triangles and roughly
9.3–16.0 MB of unique raw buffers in the inspected active mesh resources. Night
has many spatial sections; actual visible draws are much lower than its total
declared surfaces. Desert's meshes are already indexed in this fixture, so it
does not inherit the 72.5% Pine packing result. Further Desert/bank savings need
adaptive visual sampling that preserves edges, relief and road joins.

Twenty-two shared track/effect texture headers are also inventoried. Their PNG
bytes and hypothetical uncompressed RGBA8+mipmap upper bounds are supplementary
data, not resident GPU measurements. No blanket texture-resolution reduction is
recommended without mobile compression/residency and appearance measurements.
Shader, lights, transparency and particles can dominate particular effects even
when model geometry is small; those runtime costs need targeted profiling.

## Evidence, reproducibility and limits

The [comparison sheet](evidence/asset-review-2026-11-08/comparisons.png), full
[evidence directory](evidence/asset-review-2026-11-08/) and `summary.json` retain
measurements, source archives/hashes, native pictures, commands and outcomes.
Reproduction helpers are in `build/asset-review-2026-11-08` and copied into the
evidence recipes. Run with pinned `4.7.2.stable.official.ed1daf0bf` through the
task runner; every launch uses the crash-dialog wrapper, private profiles, empty
backend URL/configuration and Dummy audio. Native windows are off screen.

Current car/construction checks are 48/0; the all-kind catalogue is 580/0; actual
world checks are 30/0 per desktop renderer; exact packing positions are 22/0.
Final native candidate checks are 52/0 per desktop renderer: 814 checks total,
zero failures across these qualifying results. The image observations remain in
their individual reports.
Original controls are restored exactly; candidate appearance metrics are
observations, not relaxed appearance thresholds or automatic owner acceptance.

Initial findings remain recorded: the old car profiler assumes every performance
variant has a separate Garage template and failed on `super_rally.scn`; only its
task-owned process tree was stopped, then a family-aware harness completed.
An exploratory prospective-vertex total mixed per-instance and per-resource
counts; it is normalised from retained per-mesh rows. Raw buffers, geometry and
native images are unchanged. The first road "close" camera fitted the whole
long road mesh and was too wide; final close inspection uses the actual start
position and a tighter extent. A coarse 8-pixel image grid then undercounted tiny
racing-scale props; full-resolution detection retains the same >64-pixel guard.
An optional Mobile car-warm-up run reached its owned 300-second bound; final
candidate checks run separately. That timeout is not presented as a model result.

The recorded raw GPU/CPU timer fields are diagnostic only. Some early world runs
overlapped desktop work and driver warm-up, so no controlled frame-time ranking
or FPS improvement is inferred. All figures are PC component/fixture evidence,
not Android results. Concurrent variant/presentation/generated-identity edits
are retained in source-change receipts and excluded from the review checkpoint.

No device query/test, APK/export/install, owner-save/process change, live/backend
request or deployment was performed. Implementation, integrated motion/shadow/
paint/wash/cache qualification and owner/device performance acceptance remain.
