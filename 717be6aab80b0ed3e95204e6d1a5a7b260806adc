# Forklift front body panel — 2026-11-12

FFP01 closes the exposed front of the body identified in the owner's screenshot.
A body-coloured formed bulkhead connects the two side noses behind the mast.
Its recessed centre clears the hydraulic routing, and the raised lower corners
follow the front wheel openings. The existing paint material colours the panel.
FFP02 preserves the mast, forks, wheels, steering, operator fittings and handling.
FFP03 refreshes the native shadows, photographs and prepared assemblies.

| Native Garage view | Before | After |
|---|---|---|
| Front | [Original](evidence/forklift-front-panel-2026-11-12/before/front.png) | [Corrected](evidence/forklift-front-panel-2026-11-12/after/front.png) |
| Front quarter | [Original](evidence/forklift-front-panel-2026-11-12/before/front-quarter.png) | [Corrected](evidence/forklift-front-panel-2026-11-12/after/front-quarter.png) |
| Low front | [Original](evidence/forklift-front-panel-2026-11-12/before/front-low.png) | [Corrected](evidence/forklift-front-panel-2026-11-12/after/front-low.png) |

The production source change is `_front_panel()` and its construction call in
`game/vehicle/forklift_model.gd`. Its 48/96 segments add 388/772 triangles in
reduced/full geometry. A 60 mm backing gives the tight bends real thickness;
the ends sit inside the side skins, 2 mm ahead of their previous end caps.
The existing mesh-finish regression now includes every `Formed*` mesh in its
closed-volume, winding and outward-normal checks. The original draft exposed
four failures here; the corrected panel passes all 101 checks. Both receipts
are retained in the evidence folder.

The existing profile-art baker gains a vehicle filter. Two small native entry
points provide fixed front comparison views and reuse the shared catalogue
recipe. The three scoped Python runners use the pinned `scripts/dev.ps1`
entry point, private disposable profiles and an empty backend URL.

Actual commands:

```text
python scripts/run_forklift_front_panel.py before res://tests/capture_forklift_front_panel.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --output=res://../docs/evidence/forklift-front-panel-2026-11-12/before
python scripts/run_forklift_front_panel.py geometry-final res://tests/test_forklift_model_finish.gd -TestArgument --evidence-dir=res://../docs/evidence/forklift-front-panel-2026-11-12/finish-final
python scripts/refresh_forklift_front_panel.py
python scripts/refresh_forklift_front_panel.py --repair
python scripts/verify_forklift_front_panel.py
python scripts/run_forklift_front_panel.py scoped-preflight res://tests/check_prepared_assets.gd -TestArgument --exclude-vehicle=compact --exclude-vehicle=kart --exclude-vehicle=electric --exclude-vehicle=hovercraft --exclude-vehicle=super_rally
python scripts/check_garage_previews.py --vehicles=forklift
python scripts/run_forklift_front_panel.py import-final IMPORT
```

The shared dependency rules require a coherent refresh of the other prepared
car assemblies after model/livery changes. Their authored sources are preserved.
The initial news-photo baker wrote its default legacy framing receipt; the new
receipt was copied here and that task-start-clean legacy file restored exactly.
The runner now accepts multiple native arguments, including a scoped evidence
destination. Concurrent Kart picture changes are preserved.

The full refresh guard rejected concurrent Challenger paint-buffer and Rivalry
renderer changes. The first repair scope check then detected two additional
Challenger contour-buffer changes before writing anything. After stable input
samples, only the affected Super Rally bases, kits and Garage model were rebuilt;
Forklift profile/news art and the shared catalogue were refreshed against the
current sources. That first 21,062-input repair fence passes with zero drift. Its
preflight passes 2,267 checks on 551 resources, and all six catalogue photographs
have 157 current source hashes. Of 24 immediate pre-gallery unrelated image
controls, 21 remain byte-exact; the Super Rally catalogue, header and news images
reflect its concurrent body changes. Editor import passes, and all 53 Forklift image imports match their
new source bytes.

A final audit then detected another concurrent update of the four Challenger
paint/contour buffers. The first repair receipt is retained separately. A second
scoped repair is rejected when those four buffers change again; no whole-project
readiness is claimed while that writer remains active. These native inputs route
only to Super Rally in the existing dependency manifest. The Forklift sources,
prepared geometry and qualified behavior remain unchanged. Final qualification
therefore uses the strict Forklift prepared-resource scope and its own catalogue
image, preserving the concurrent Challenger source work.

| Final validation | Actual result |
|---|---|
| Closed geometry, winding and normals in both detail variants | 101 checks, 0 failures |
| Saved Garage model, Compatibility / desktop Vulkan Mobile | Four fixed native views each; inspected front and wheel clearance |
| Every Forklift prepared kit versus procedural sources | 1,726 checks, 0 failures |
| Garage selection, all 56 part choices, equip/reload and actual race/ghost | 131 checks, 0 failures; headless |
| Driving / washing | 72 / 1,655 checks, 0 failures |
| Production parser | 554 scripts, 0 failures |
| First full preflight / catalogue provenance | 551 resources, 2,267 checks, 0 failures / six pictures, 157 source hashes; superseded for global readiness by later concurrent Challenger writes |
| Final Forklift scoped preflight / catalogue provenance | 110 resources, 453 checks, 0 failures / one picture, 157 current source hashes |
| Refreshed texture imports | All 53 match their source image bytes |

All eight task-start car-configuration controls and the main Git index remain
byte-exact. The final source audit records the four concurrent Challenger buffer
changes and unchanged Forklift inputs. The source-only checkpoint
and native-file hash inventory are retained beside the logs and comparisons;
generated project/profile copies are not retained as evidence. Build retention
cleanup is run at completion.

Reload and owner appearance acceptance remain. No physical-device test, APK,
owner-save/process change, backend request, deployment or main-index write was
performed. Desktop native views do not establish device performance.
