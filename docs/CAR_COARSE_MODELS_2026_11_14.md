# Coarse car models applied — 14 November 2026

The owner's selected coarse reduction budget is implemented for all six current
production reduced cars, including fitted parts. Prepared bases, modules, Garage
reference templates, the stock header template and six native Garage catalogue
photographs are refreshed. Full authoring mesh resources and canonical handling
inputs are retained. Reloading the game and physical-device appearance/performance
acceptance remain separate.

[Compatibility before/after](evidence/car-coarse-models-2026-11-14/gl_compatibility-before-after.png)
and [desktop Vulkan Mobile before/after](evidence/car-coarse-models-2026-11-14/mobile-before-after.png)
show actual native renders. [Current 30-case inventory](evidence/car-coarse-models-2026-11-14/inventory-final.json)
records the loaded production assets and actual prepared-base/module hits.

## Changes and measurements

| ID | Delivered change |
|---|---|
| CCG01 | Offline coarse index selection at the reviewed 0.01 engine error-key budget, followed by raw vertex compaction. |
| CCG02 | Apply the same source-piece recipes before batching fixed cars and editable modules. Runtime loads immutable saved meshes by complete encoded source fingerprint; no runtime simplification. |
| CCG03 | Six-car prepared-asset refresh with source/identity fences, normal full provenance checks, and guarded native catalogue photograph publication. |
| CCG04 | Encoded-attribute, culling-bound, material-slot, stock/fitted/module, native appearance, actual App Garage/race, driving and driver checks. |

| Car | Previous prepared stock | Final production stock | Change from previous prepared | Final sampled fitted |
|---|---:|---:|---:|---:|
| Rally | 26,496 | 21,884 | −17.41% | 29,730 |
| Kart | 31,612 | 24,554 | −22.33% | 25,944 |
| Forklift | 38,136 | 34,484 | −9.58% | 35,380 |
| Volt | 34,690 | 21,042 | −39.34% | 26,472 |
| Hover | 22,548 | 22,068 | −2.13% | 31,324 |
| Challenger | 49,968 | 25,918 | −48.13%* | 23,320 |

Triangles are visible stored masters before distance selection, excluding
shadow-only geometry. They include repeated instances. Adding one stock instance
of each car gives 203,450 → 149,950 triangles (−26.30%); this does not mean six cars
normally draw together or that frame time falls by 26.30%.

*The current unchanged-source Challenger constructor with coarse reduction
disabled produces 45,150 reduced / 77,204 full triangles, rather than the earlier
prepared 49,968 / 84,924. The refresh reconciles that existing prepared/source
discrepancy. Its controlled source comparison is 45,150 → 25,918 (−42.60%);
the table's larger saving includes that reconciliation. All native Challenger
source resources and its model generator remain exact to this task's start.
Full source construction receives no coarse reduction, but refreshed full scenes
are not claimed byte-identical to the earlier prepared scenes.

The reviewed prototypes simplified assembled meshes. Production reduction is
applied to individual source pieces so fixed construction, editable bases and
independently replaced kits retain matching geometry. Consequently the final
counts differ from the prototype table; no uniform percentage or exact match to
the prototype counts is claimed. Straight primitive sampling retains the prior
reducer's policy; the new coarse bank covers eligible ArrayMesh source pieces.
The 0.01 value is an engine error key, not a certified world-space displacement.

## Runtime and fitting behaviour

`car_coarse_reduction.gd` participates in the existing procedural fallback and
changed-kit construction paths. The lookup uses vehicle ID, the complete encoded
source vertex/attribute/index fingerprint and the fixed coarse policy. It is
bounded to 256 entries. A missing or changed source keeps its original geometry.
Every retained active surface material is rebound after lookup, preserving live
paint and instance-local finishes. Each prepared car loads its saved reduced
assembly directly.

The bank contains 2,442 native recipe resources, 3,608,999 bytes on disk. Runtime
does not generate indices or compact buffers. Retained vertex positions,
normals and UV records are copied as encoded bytes. Original culling bounds,
material slots, wheel/steering frames, live lights, and moving driver meshes
remain. The original driver resources and all ten steering poses are unchanged.
Hover's layered hull/reflection exclusions and authored distant seam level remain.

Geometry compaction and additional native recipe storage have different effects.
No blanket RAM, VRAM, package-size, loading, thermal, battery or FPS improvement
is inferred from the triangle count. Existing automatic LODs overlap these master
savings. Device frame-time measurement remains necessary.

## Verification

| Check | Result |
|---|---:|
| Source pieces: exact retained encoded attributes, culling bounds, slots, fixed/editable stock and fitted construction | 3,253 / 0 |
| Complete module matrices, Rally / Kart / Forklift / Hover / Challenger | 1,443 / 1,160 / 1,726 / 1,292 / 1,438; zero failures |
| Complete Volt module matrix | 1,936 / 0; six-car total 8,995 / 0 |
| Final current-source stock/fitted/replacement/ghost matrix after the late source refresh and exclusion guard | 2,095 / 0 |
| Prepared provenance and articulation preflight | 551 resources; 2,267 / 0 |
| Native before/after and exact restoration, Compatibility | 320 / 0 |
| Native before/after and exact restoration, desktop Vulkan Mobile | 338 / 0 |
| Actual six-car App Garage/race, each desktop renderer | 56 / 0 each |
| Current full/reduced, stock/fitted, Garage inventory | 30 cases / 0 failures |
| Canonical driving | 72 / 0 |
| Material/paint/glass bindings | 115 / 0 |
| Original Kart driver split records and poses | 16 / 0 |
| Kart native source/steering controls, headless | 157 / 0 |
| Existing five-car washing/state integration, headless | 1,383 / 0 |
| Challenger geometry/opacity declarations/physical positions, headless | 17 / 0 |
| Final production compilation | 567 scripts / 0 failures |
| Six native Garage photographs | 6 images / 169 current source hashes |
| Final current native texture imports | 6 / 0; no editor diagnostics |
| Retained Hover authored distant seam level, each renderer | 2 / 0; exactly 1,152 fewer primitives |

The complete module matrices compare full/reduced stock/fitted assemblies and
every individual catalogue option against ordinary construction. They also check
encoded attributes, materials, culling bounds, articulation, rest-pose ghosts,
recolouring, brake lights and weathering. They are stronger than comparing only
the stock triangle totals. Arbitrary multi-category combinations and every
possible lighting/pose are not exhaustively rendered.

Native comparisons use factory paint in the actual CarShowroom at 1,000 × 760,
with front, rear and distant elevated cameras and forced car masters. All 36
final restoration comparisons are pixel-exact. Native averages/pixel counts are
diagnostics, not a universal perceptual equivalence claim. Close edge curves,
helmet/wheel detail and body highlights can differ as expected for the approved
coarse quality. The complete vehicle is framed in the new close comparisons.

The actual App tests use private records/cloud folders, enter the real Garage,
start a practice race with each car, compare loaded geometry to the production
model and retain complete canonical tunes. Kart wheel and ten-pose driver
presentation are exercised. Pinned engine is
`4.7.2.stable.official.ed1daf0bf`, RTX 3090. Vulkan Mobile is a desktop renderer;
no physical phone/tablet was queried, tested or exported to.

## Refresh, controls and reproducibility

```powershell
python scripts/run_car_coarse_models.py recipes-final res://tests/bake_car_coarse_reductions.gd --headless
python scripts/run_car_coarse_models.py source-check-final res://tests/test_car_coarse_reductions.gd --headless
python scripts/refresh_car_coarse_models.py
python scripts/refresh_car_coarse_models.py --pictures
python scripts/import_car_coarse_images.py
python scripts/run_car_coarse_models.py modules-electric res://tests/test_modular_car_assets.gd --headless -- --vehicle=electric --all-kits
# Equivalent full matrices run for each other active vehicle.
python scripts/run_car_coarse_models.py app-gl res://tests/test_car_coarse_app.gd --rendering-method gl_compatibility
python scripts/run_car_coarse_models.py app-mobile res://tests/test_car_coarse_app.gd --rendering-method mobile
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compare_car_coarse_models.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Engine helpers use private APPDATA/LOCALAPPDATA, empty backend URL/auth values,
Dummy audio, the pinned engine and owned bounded processes. The prepared refresh
initially fenced 23,899 sources/native inputs with zero changes and identical
before/after modular geometry identities. Following the late refresh, the final
production-contract fence qualifies 23,604 consumed inputs with zero changes;
16 known nonconsumed world/UI changes are recorded separately. It preserves default full-catalogue
preflights. Existing illustration, paint-sample and news artwork remain; the six
prepared Garage catalogue photographs are refreshed from current models.

The main Git index changed concurrently after the starting receipt; this task
does not stage or write it. Handling configurations, original Kart resources,
Challenger native sources/generator, Forklift generator and steering controls
are independently checked. No simulation/tune, owner save, owner process, backend
request, deployment, export or device installation is part of this change.

Authored production files are `car_visual.gd`, `car_coarse_reduction.gd` and the
prepared dependency manifest. Added offline bake/verification/capture/App helpers,
runner/refresh/import/comparison scripts, generated recipes/prepared outputs,
this report and repository status notes form the rest of the change. A source-only
checkpoint and concise command/control receipts accompany the generated outputs.

## Retained findings

The first source-check fixture compared editable surface counts against a fixed
assembly, producing six fixture failures; matching construction modes passes.
The first native fixture hid its reference before inventory, producing zero
reported before counts; counting before hiding corrects the receipt. Initial
Vulkan first-use settling produces three exact-restoration failures. Requiring
bounded repeated stable native draws retains the exact criterion; final Mobile
restoration passes without an appearance threshold relaxation. An initial
world-scale-normalised reduction experiment was discarded in favour of the
reviewed constant local engine error key; accepted bank recipes are regenerated.

The broad all-test script parser finds two unrelated App probe overrides with an
outdated `_start_race` signature (`test_menu_quality.gd` and
`test_metadata_race_preparation.gd`). They omit the current optional daily-request
parameter. No App source or those fixtures were authored here. A retry with an
unsupported `--production-only` argument is also retained and not counted as a
pass. The existing dedicated production parser passes all 567 current shipping scripts;
all new task helpers compile and run in their completed commands. There is no
whole-repository test-pass claim.

The initial qualified refresh was superseded by a concurrent `sand_dust.gd`
change, which correctly invalidated shared car keys (the live standard-entry
preflight rejected 1,102 stale key/source/header findings). A subsequent attempt
encountered a temporary write conflict on the Electric full editable scene and
was retried. The final runtime lookup also explicitly enforces the existing
reflection/Hover eligibility rules and authored-far exclusion; current source
verification remains 3,253/0.

Ongoing world/UI work then changed scripts outside the car dependency contract.
The final fence uses the unchanged production `PreparedAssetSources` routing
manifest and its conservative category defaults, and records those known
nonconsumed changes separately. Model, particle, shader and resource changes
that the production contract consumes remain guarded. Complete current-source
and current-key preflights are retained unchanged; no stale car key is waived.

Final handoff records 1,397 exact original model/driver/configuration controls,
12 production prepared-base hits and 24 fitted-module hits. The final focused
matrix passes 2,095/0, both actual App renderer runs pass 56/0 again, and the
retained Hover distance level saves exactly 1,152 primitives in each renderer.
All six texture imports match their current source images with zero editor
diagnostics. The source checkpoint checks forward and reverse application after
UTF-8/LF normalisation, separately from generated assets and shared journal notes.

The prescribed retention cleaner ran successfully at handoff: zero failures,
23.141 GiB remains. Recent/protected/locked output is exempt from its 20 GiB
target. This task has no permanent project copy or shader-cache evidence;
private profiles and the minimal source-check checkout remain disposable build
output under the normal retention policy.
