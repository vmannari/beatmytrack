# Five-car geometry simplification — 13 November 2026

The approved reductions are implemented for Rally, Kart, Forklift, Volt and
Hover. Challenger model/cache/picture publication is excluded; concurrent
Challenger work is preserved. The final five-car refresh and all final gates
pass. A fresh game launch, owner appearance review and physical-device
qualification remain.

[Native before/after sheet](evidence/car-simplification-2026-11-13/before-after.png),
[measurements and final command receipts](evidence/car-simplification-2026-11-13/summary.json),
[per-view pixel measurements](evidence/car-simplification-2026-11-13/native-comparisons.json).

## Delivered changes

| ID | Change | Preserved controls |
|---|---|---|
| CSP01 | Straight simple-model cylinders use one axial ring. Their radial samples, end caps and dimensions remain. The default reducer and excluded vehicle IDs retain the old axial policy. Newly fitted kits use the same reduction. | Wheel/steering/fan frames, full-quality references, all eight car configurations and simulation sources. |
| CSP02 | Rally's 438 boxed door/tailgate seam segments become three connected contour groups. Two triangles per segment replace twelve; 5,256 becomes 876 triangles. Original paths, widths and attachment positions feed the strips; they do not cast self-shadows. | Door/window boundaries, tailgate layout, proportions, paint and original full reference geometry. |
| CSP03 | Offline conservative index selection reduces individual static source pieces, then compacts only their referenced encoded vertex blocks. This covers Rally static detail, Kart's static helmet/wheels and Volt wheel detail. Reduction happens before batching and only within newly replaced kit frames. | Every retained encoded position, normal and UV; source bounds, material slots, light handles and separate articulation. The animated driver's native file, original helmet reference, ten poses, shoulder/seat/pedal fit and steering source are byte-exact. |
| CSP04 | Hover keeps its original close master. A separately authored skirt-seam distance level saves 1,152 rendered triangles. Fine and far samples stay in the same mesh/material batches, and the offline LOD preparation retains the authored level. | Close skirt, canopy, hull, fan guards, moving rotors/rudders and stock surface count. The reviewed coarser fan-ring/skirt prototypes were not applied to the close model. |
| CSP05 | Five-car stock/editable bases, fitted modules, Garage/header scenes, factory art, 245 livery pictures, five Garage pictures and five news photos refresh with source/identity guards. All 265 generated images have verified current native texture imports. | Challenger files and per-picture provenance are excluded from publication; strict default full-catalogue checks remain. |

`car_static_reduction.gd` loads the saved native reductions by the complete
encoded source-geometry fingerprint. It never runs index generation at runtime.
A missing or changed source key keeps the original geometry. The content lookup
cache is bounded to 128 entries and does not retain transient source assemblies
for negative lookups. Source regeneration is explicit through
`bake_car_static_reductions.gd`; 883 native recipe resources occupy 1,211,902
bytes on disk. Native resources are generated output, separate from the source
checkpoint.

The source-piece boundary matters: reducing already-combined fixed batches gave
Rally fitted cars different geometry from separately assembled modules. The
final implementation reduces each authored source piece before assembly, and
scopes incremental work to the changed kit's frames. All ten sampled
stock/fitted × fixed/editable construction pairs agree, followed by the complete
module matrices below.

## Final production stock measurements

The same inventory function measures task-start and final active assemblies.
Triangles are visible stored masters, before automatic distance selection.
Payload includes unique active mesh vertex/attribute/index/morph/shadow and LOD
buffers. It excludes textures, materials, global retained resources, allocator
overhead and lookup-cache storage. It is not process RAM, measured VRAM, APK
size or frame time. Shared meshes count once per car.

| Car | Before triangles | Final triangles | Reduction | Before buffers | Final buffers | Buffer change |
|---|---:|---:|---:|---:|---:|---:|
| Rally | 40,396 | 26,496 | **34.41%** | 1,693,548 B | 1,023,510 B | −39.56% |
| Kart | 34,752 | 31,612 | **9.04%** | 1,962,260 B | 1,870,564 B | −4.67% |
| Forklift | 51,132 | 37,812 | **26.05%** | 2,063,348 B | 1,705,560 B | −17.34% |
| Volt | 38,746 | 34,594 | **10.72%** | 1,066,620 B | 1,095,216 B | +2.68% |
| Hover | 22,548 | 22,548 close master | **1,152 fewer at distance** | 565,008 B | 637,388 B | +12.81% |

Stock visible surface counts remain 52/45/26/37/19 respectively. All five final
stock cases record actual prepared-base hits. Task-start cache-enabled cases
had only one base hit; therefore the buffer comparison also includes making
the intended prepared LOD policy effective for the other four cars. This is an
observed production snapshot comparison, not a controlled device-memory
experiment.

The static Kart helmet falls from 6,024 to 3,492 triangles; its two animated
suit/glove surfaces remain 6,456 triangles with ten steering poses. Original
driver and full helmet resource hashes remain exact. The source reference is
retained for full detail and future authoring.

Volt and Hover demonstrate the storage tradeoff: lower distant rendering work
requires additional index/detail data. No universal buffer saving is claimed.
Hover's native forced-level test measures **26,132 → 24,980 visible viewport
primitives**, a difference of exactly **1,152**, in both desktop renderers.
The viewport totals include the studio; the difference isolates the selected
authored level.

## Final verification

Pinned engine: `4.7.2.stable.official.ed1daf0bf`; desktop RTX 3090. Vulkan Mobile
is a desktop renderer here, not a physical Android test. Engine runs use
private profiles, dummy audio and empty backend URL/auth values.

| Gate | Final result |
|---|---:|
| Complete full/simple, stock/fitted/module/ghost matrices | Rally 1,443; Kart 1,160; Forklift 1,726; Volt 1,936; Hover 1,292 — **7,557/0** |
| Scoped prepared-asset validation | **468 resources / 1,925 checks / zero failures** |
| Current direct source pieces / actual prepared integration | **441/0 and 38/0**, including retained encoded attributes, exact source controls, bounded lookup cache and five base hits |
| Actual five-car Garage/race App | **48/0 per desktop renderer**; matching current geometry, canonical tunes and Kart steering |
| Native prepared steering | **170/0 per desktop renderer** |
| Actual rendered Hover distance level | **2/0 per desktop renderer**, exactly 1,152 fewer primitives |
| Driver contact / cockpit / moving steering clearance | **27/0, 286/0, 1,134/0** |
| Actual native washing / surface eligibility | **1,675/0 and 54/0** |
| Driving / personal ghost logic | **72/0 and 38/0** |
| Production script compilation | **557 scripts / zero failures** |
| Current inventory | **53/0** |
| Native photo provenance / texture imports | **Five pictures / 161 current source hashes; 265 imports current** |

Forty final prepared studio views, twenty actual App Garage/race pictures and
native steering captures are retained. The contact sheet compares the same
task-start and final Compatibility views. The pixel measurements are diagnostic;
byte-identical images and universal perceptual equivalence are not claimed.

The final refresh fences **21,398 consumed inputs**, with zero changes during
the refresh or final handoff reconciliation. Vehicle-specific routing uses the
existing dependency manifest; shared and unknown inputs remain guarded.
Concurrent Challenger-only resources are recorded separately and not restored.
All eight car configuration controls, Kart steering/model sources, Forklift
model source, original driver/helmet resources and the main index remain exact.

## Commands and regeneration order

```powershell
python scripts/run_car_simplification.py piece-bake-scoped res://tests/bake_car_static_reductions.gd --headless
python scripts/run_car_simplification.py factory-art-final res://tests/bake_model_refinement_art.gd --rendering-method gl_compatibility
python scripts/refresh_car_simplification.py --art-only
python scripts/refresh_car_simplification.py
python scripts/import_car_simplification_images.py
python scripts/run_car_simplification.py modules-compact res://tests/test_modular_car_assets.gd --headless -- --vehicle=compact --all-kits
# The same complete matrix ran for kart, forklift, electric and hovercraft.
python scripts/run_car_simplification.py app-compat res://tests/test_car_simplification_app.gd --rendering-method gl_compatibility
python scripts/run_car_simplification.py app-mobile res://tests/test_car_simplification_app.gd --rendering-method mobile
python scripts/summarise_car_simplification.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compare_car_simplification.ps1
```

Regenerate native recipes after changing their source geometry, then refresh
the scoped prepared assets and pictures, import the images and run the gates.
Do not prune recipe resources while prepared scenes still reference them.
The source-only patch/manifest records the authored implementation separately
from generated assets and concurrent work; its forward/reverse roundtrip is
checked in a private small source checkout without staging the main index.

## Retained attempts and limits

The initial hash helper passed an empty buffer to the engine hash API; it now
skips empty streams, and the accepted bake exits cleanly. A first source-fence
rejection records the helper edit and concurrent Challenger writes. The final
scope uses declared dependencies and checks all five revisions rather than
asserting unrelated Challenger revision stability. Full-catalogue defaults were
not weakened, and Challenger caches were not rewritten or rekeyed by this task.

The first module matrix rejected nine Rally fitted/ghost/material assertions
because of the batching-dependent reduction. Moving reduction to source pieces
and restricting incremental reduction to the new kit frames fixes the cause;
the original assertions pass unchanged. An initial contour fixture expected
individual mesh names after batching; it now checks retained attachment groups
and current geometry/attribute controls.

Superseded native recipe cleanup briefly left stale Electric prepared scenes
referencing retired task-created files. The stale simple scenes were retired
and all affected outputs rebuilt. Rejected loader diagnostics remain; accepted
imports, prepared gates, module matrices and App runs have no such errors.
Ninety superseded task-only recipe resources were removed; the final recipe set
and every expected prepared output are present.

Parallel off-screen App tests can lose focus and pause. Their first steering
fixture mutated state on the same paused tick, which the unchanged presentation
cache correctly reused. Advancing the private fixture tick makes each requested
steering state observable; the steering assertions are retained and production
steering is untouched. Subsequent two-renderer App and native steering gates pass.

A fresh launch and owner appearance acceptance remain. Physical-device frame
times, memory, thermals and deployment were not performed. No APK, backend
request, owner-save edit, owner-process restart, main-index staging or deployment
was performed. Known certificate-store startup diagnostics remain in applicable
logs. Generated build output is handled by the owner retention policy.
