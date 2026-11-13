# Vehicle and track asset optimisation — 2026-11-08

The owner approved implementing the recommendations in
[the asset review](ASSET_OPTIMISATION_REVIEW_2026_11_08.md). This pass reduces
fixed car draws, packs repeated road/kerb/Winter vertices without changing their
encoded appearance, and adds conservative authored distance levels for trees
and tyre walls. The accepted simple cars remain the production models.

## Requirements and implementation

| ID | Implemented behaviour | Sources |
|---|---|---|
| AOP01 | Deduplicate complete encoded GPU vertices; preserve ordered triangle corners, normal/tangent codes, colours, UVs, materials, bounds and existing LODs. Cooperative road publication retains cancellation. | `game/rendering/mesh_vertex_packing.gd`, `game/track/native_track_visual.gd`, `game/track/winter_scenery.gd` |
| AOP02 | Protect full near tree/tyre geometry and editor detail. Distance trees omit inner needle sprays and upper woody stems; every main foliage layer and outer spray remains. Distant tyres retain all 24 tread cuts and Winter snow caps, with 16 carcass/bead segments. | `game/track/creator_prop_visual.gd`, `game/track/prop_geometry.gd`, `game/track/scenery_mesh_lods.gd`, `game/track/winter_scenery.gd`, `game/track/native_track_visual.gd` |
| AOP03 | Merge compatible fixed car details through immutable transform wrappers. Keep body, kit, wheel, light, Hover rotor and rudder controls; preserve transformed custom shader parts. | `game/vehicle/visual_geometry.gd` |
| AOP04 | Rebuild guarded prepared cars, modules, Garage/header templates, six native pictures and three existing scenery maps; qualify integrated appearance, articulation, washing and caches. | Generated resources, tests and evidence below. |

Raw packing operates after original normals and snow colours are authored.
It does not decode and re-encode normal vectors, which caused small shading
changes in the review prototype. Compressed/skinned/blend-shape meshes retain
their existing representation. Desert road deformation retains its already
indexed input. Night roads are packed after light-section grouping. No physics,
canonical cells, route, kerb contact geometry, dimensions or camera tuning is
changed by this task.

Car batching retains every triangle. GPU transform arithmetic moves into mesh
vertices for eligible fixed parts, so a few edge samples can differ at floating
point precision. Paint and braking finishes retain their mutable material
ownership. Internal comparison controls are test hooks, with no graphics option.

## Measurements and pictures

The [interactive comparisons](evidence/asset-optimisation-2026-11-08/comparisons.html)
show the unmodified before/after screenshots, including close and moving cars.
Full measurements and source pins are in
[summary.json](evidence/asset-optimisation-2026-11-08/summary.json).

Stock race-view draw observations in Compatibility:

| Vehicle | Before | After | Reduction |
|---|---:|---:|---:|
| Rally | 61 | 57 | 6.6% |
| Kart | 65 | 49 | 24.6% |
| Forklift | 50 | 32 | 36.0% |
| Volt | 91 | 43 | 52.7% |
| Hover | 20 | 20 | unchanged |
| Super Rally | 67 | 67 | unchanged |

These are complete fixture draw observations, including its rendering passes.
The cars keep their original triangle counts. Fitted variants vary; no reduction
is claimed for a variant whose compatible parts were already combined.

The five-biome `to_the_trees` packing control keeps the same authored distance
levels in both versions. Shared raw vertex/attribute/index buffer bytes become:

| Biome | Before | After | Reduction |
|---|---:|---:|---:|
| Pine | 15,958,032 | 11,646,634 | 27.0% |
| Night | 10,809,978 | 5,899,540 | 45.4% |
| Winter | 12,360,604 | 7,662,328 | 38.0% |
| Storm | 10,796,826 | 5,842,772 | 45.9% |
| Desert | 14,410,618 | 14,410,618 | unchanged |

Every expanded full/LOD triangle corner remains byte-exact in these controls.
Road/kerb/finished-Winter packing images are pixel-exact in both desktop
renderers. Winter tree buffers alone fall 114,480 to 91,308 bytes without its
new distance level; fence buffers fall 48,384 to 41,496. Bushes with no profitable
duplicate vertices are retained.

At race distance, the protected tree levels remove about 22% of visible tree
triangles. A six-stack tyre wall falls 7,200 to 5,568 triangles (22.7%); its Winter
version falls 8,736 to 7,104 (18.7%). Near master corners remain exact. Small
shadow differences can remain in close tyre screenshots because shadow views
also select detail levels. The extra tyre sampling adds about 27 KiB per shared
mesh after near packing; it is shared across instances. This is a distance
triangle reduction with a measured storage cost, not a universal memory saving.

Godot's instanced primitive counter changes accounting when a mesh gains LODs.
An identical-index LOD control renders every instance pixel-exact but reports
one stack's primitives. The corrected wall totals above use that explicit
control; the apparent 83–87% counter drop is not reported as a gain.

Other reviewed assets retain their accepted geometry. There is no broad
decimation of buildings, banks, terrain relief, foliage outlines, effects or
textures. Existing guarded container, snow-castle and ice-car reductions remain.

## Commands and qualification

Pinned engine: `4.7.2.stable.official.ed1daf0bf`, using
`scripts/run_no_crash_dialog.py`. Every test has a private profile, empty backend
URL/configuration and Dummy audio; native fixture windows are off screen.
Exact invocations, owned PIDs, durations and return codes are retained in
[commands.json](evidence/asset-optimisation-2026-11-08/commands.json).
Recipes and source/log archives are in the same evidence directory.

Representative actual commands (from the repository root):

```powershell
python build/asset-optimisation-2026-11-08/run.py packing-unit-complete res://tests/test_mesh_vertex_packing.gd
python build/asset-optimisation-2026-11-08/run.py protected-tree-complete res://tests/test_protected_tree_lods.gd
python build/asset-optimisation-2026-11-08/run.py cars-final-gl res://../build/asset-optimisation-2026-11-08/native.gd --renderer gl_compatibility -- --mode=cars --suffix=-final
python build/asset-optimisation-2026-11-08/run.py modules-all-final res://tests/test_modular_car_assets.gd --timeout 900 -- --all-kits
python build/asset-optimisation-2026-11-08/run.py prepared-pipeline-verify res://tests/check_prepared_assets.gd --pipeline -- --verify
```

| Qualification | Checks / failures |
|---|---:|
| Encoded packing, large index-width conversion, cancellation and authored levels | 12 / 0 |
| All-biome expanded raw corner/canonical world comparisons | 432 / 0 |
| Protected tree/tyre, editor, worker and spatial checks | 166 / 0 |
| Six stock/fitted cars, close/race/paint/lights/moving, each renderer | 344 / 0 each |
| Actual rebuilt prepared models versus procedural, each renderer | 362 / 0 each |
| Live wheel/light bindings / exact-master LOD policy | 68 / 4294, all zero failures |
| Final tree/tyre native comparisons, each renderer | 38 / 0 each |
| Five-biome packed native worlds, each renderer | 30 / 0 each |
| Retained scenery signatures, geometry, spatial/cache and Game checks | 368 / 0 |
| Terrain / road-cache / driving / race memory policy | 3885 / 90 / 72 / 20, all zero failures |
| Hit-tested car wash / reduced Garage wash surfaces | 1655 / 54, all zero failures |
| Actual App composition and editor/race round trip | 141 / 0 |
| Shipping parser | 554 scripts / 0 |
| Complete six-vehicle module matrix, both tiers and all options | 9043 / 0 |
| Exact embedded-image fixture identity, native | 3 / 0 |
| Prepared resource preflight | 551 resources, 2267 / 0 |
| Native picture provenance | 6 images, 157 current source hashes |

The permanent new regressions are `test_mesh_vertex_packing.gd` and
`test_protected_tree_lods.gd`. The previous blanket “tree is unapproved” check in
`test_scenery_mesh_lods.gd` is replaced by the stronger full-master/editor/worker/
spatial checks for the newly approved protected tree level. Existing rejected
generic tree decimation is not promoted.

At the recorded passing source pin, the 24 bases, 520 modules, six Garage
templates and one header template validate against complete sources. Generated binary hashes
are recorded in `generated-assets.json`. The three existing scenery corner maps
were rebaked; the previously stale ice-car map now accepts its current source.

## Retained findings and limits

Initial scenery checks exposed a missing distant Winter snow cap, absent
unindexed Winter tree LOD publication, missing tree spatial centres, and the
instance counter accounting difference. These are corrected and the original
failures/logs remain. Near tyre master bytes and the identical-LOD render control
provide separate geometry and instancing evidence.

The first broad car bake reached its 600-second module bound. Per-vehicle bakes
then completed under current source guards. Livery import metadata changed
during the earlier bake, changing its artwork tree hash. No source guard was
bypassed: current bases/modules/Garage/header and pictures were rebuilt and the
whole pipeline preflight passes. An intervening generated build identity had
missing dictionary initialisers; its raw file is retained. Regeneration fixes
that file, and the affected Garage wash check was rerun cleanly. The small
packing unit fixture initially joined incompatible attribute formats; its owned
test process was stopped, the fixture corrected, and the exact-corner checks pass.

Initial desktop Mobile runs each retain one strict original-frame restoration
failure (car paint/lights and Desert world). Their optimisation comparison
pixels pass. The unchanged-car control is 93/0, and final warmed repeats retain
the original strict gates and pass 240/0 and 30/0. Warm render caches are copied
only from this task's private profiles; these runs are appearance tests, not
cold-loading measurements. An inherited source-guard probe initially targeted
the review's evidence path; that prior receipt was restored byte-for-byte and
the current observation retained separately.

The full module matrix retained twelve Kart material comparisons and one
rollback hit-count failure. The three embedded driver textures have identical
pixel data but are rehomed into PackedScene subresource paths. The fixture now
compares embedded image class, dimensions, format, mipmap state and every pixel;
external texture paths remain checked. Its isolated native regression accepts
the address change and rejects a changed pixel or dimensions (3/0). Dummy
headless upload/readback cannot exercise those controls and its 3/2 attempt is
retained. The rollback descriptor now explicitly selects the full quality used
by its control, preserving the original three-attachment/fourth-failure gate.

During qualification, concurrent Super Rally work briefly referenced a missing
`night_lens()` helper and then corrected a typed-array hood initializer. The
transient compile errors and script-error-bearing attempts are retained, even
when their wrapper exit code was zero. Their corrected source was copied into
the isolated project. All six final module matrices are clean, including those
hood options. The older sibling batching step also exposed four newly authored
brake-lamp references being merged away. Both batching stages now preserve live
handles, with in-tree checks and fresh native/prepared proofs.

The final rebuild regenerates every scene from source. Its task-only recipe
reuses approved LOD streams only when complete master buffers, material
appearance, local pose, render flags and requested bias match exactly; changed
masters use the original offline generator. The 4294-check policy pass preserves
all masters and enforces protected surfaces and original quality biases.
Complete live/isolated source maps and revisions matched before publication.
Only then were verified assets copied back; no frozen source replaced live work.
The final live preflight, six-picture provenance, App and parser pass. Failed
source matches and superseded owned bake attempts remain in the evidence.
The first post-publication photograph check correctly rejected prepared-base
hashes changed by final LOD-policy serialization. Native photographs and their
provenance were refreshed against those exact live bases; the complete repeated
preflight passes without changing its guard.

Raw buffers, triangles and draws are component evidence. No FPS, loading-time,
resident-memory, thermal or Android performance gain is claimed. A fresh PC
reload and owner inspection remain; physical device appearance, input, sustained
frame time and memory acceptance have not been tested. No device query/test,
APK/export/install, owner-save/process change, live/backend request or deployment
was performed. Concurrent source work remains preserved.

A source-only, forward/reverse-checked Git checkpoint and the main-index hash
receipt are in `task-only.patch` / `checkpoint.json` in the evidence directory.
Generated resources remain in the workspace with their separate manifest; the
checkpoint does not overwrite concurrent binaries or modify the main Git index.
