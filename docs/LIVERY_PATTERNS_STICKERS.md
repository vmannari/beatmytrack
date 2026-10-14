# Car livery patterns and panel stickers — 2026-10-13

The owner's request adds twenty distinct graphic patterns and hood/roof stickers to Garage → Customise. This is a local cosmetic change; AAA quality remains the owner's visual acceptance target.

| Requirement | Delivered behaviour |
|---|---|
| LV01 | Twenty original editable vector patterns, with actual-car previews and a scrolling swatch strip. Original/Rally/Midnight/Sandstone colour choices remain available. |
| LV02 | Body, Accent and Detail colours can be edited independently. Selecting a pattern supplies its authored three-colour palette and preserves panel stickers. |
| LV03 | Twelve original fictional emblems. One independently selected sticker per hood and roof. Compact, Pickup and Classic have roof controls; Formula/Kart use their existing nose panels and have no invented roof. |
| LV04 | Mouse/native touch placement, independent scale and rotation, Centre, None/removal and Reset livery. A panel preview uses the same body coordinates and custom colours as the car; geometry clips rotated/overhanging ink at the real panel footprint. Placement owns its gesture and cannot trigger page navigation. |
| LV05 | Version-two local livery records accept and migrate version-one colour pairs. Car selections, process reload, live paint and ordinary race construction retain their own cosmetics. Failed saves restore committed state through the existing atomic record writer. |
| LV06 | Opaque graphics replace existing paint surfaces, including batching and the simpler racing model. Body-space projection survives car motion. Dirt/snow/wetness cover the art; washing restores current graphics. Actual geometry, shadow proxies, glass, trim, lamps, handling, lap rules, scoring and PB identity remain independent. |
| V04/V05/G01/R01/Q01 | Both desktop renderers, real models, isolated saves, native UI/touch, existing wash/car/records/driving/rewind checks and review evidence. Physical-phone acceptance remains open. |

The twenty patterns, in contact-sheet order, are Apex Twin, Offset GT, Endurance, Rally Blocks, Heritage Sweep, Chevron, Velocity, Split Grid, Contour, Forged Hex, Digital Camo, Tiger, Flame, Lightning, Orbit, Prism, Sunburst, Scallop, Herringbone and Circuit.

The sticker collection is BMT Crest, Race 07, Compass, Summit, High Voltage, Phoenix, Ghost Rider, Orbital, Laurel, Piston Club, Checkered Flag and Desert Sun. These are decorative emblems; they do not grant or imply earned profile awards.

## Files and provenance

`scripts/build_livery_art.py` authors the SVG masks, coloured swatches and sticker paths in `game/assets/liveries/`. All paths and palettes were authored for this project; no reference pictures, real manufacturer/sponsor logos, external fonts, downloaded assets, generation APIs or runtime services are used. The masks store linear data channels; pigments and the shared padded sticker atlas use correct source-colour binding. Import sidecars generate mipmaps.

`game/vehicle/vehicle_livery.gd` owns strict local validation/migration. `livery_catalog.gd` owns the allowlisted content, per-car panel footprints and a four-mask cache. Existing live materials retain their active texture references; browsing does not retain twenty full-resolution masks in the catalogue. Small UI textures and the 1024×768 sticker atlas are shared.

`livery_graphics.gd`, `livery_finish.gdshader` and `livery_finish.gdshaderinc` bind existing paint surfaces after mesh batching. `car_visual.gd` applies the cosmetics. `vehicle_weathering.gd` and its shader incorporate the same pigment function beneath the established weathering finish and restore the current livery on cleaning/reset. No additional mesh, transparent overlay, decal pass, light or screen read is introduced. Decorated materials add texture/shader work; no GPU-time or phone-FPS improvement is claimed.

`garage_page.gd`, `sticker_placement.gd`, `sticker_panel.gdshader` and `menu_page_swipe.gd` implement the two-tab customiser, accurate placement map, direct manipulation and gesture ownership. Concurrent compact body-kit/customisation work was retained.

`scripts/build_identity.ps1` required a small launcher fix: byte arrays emitted through an `if` expression were enumerated into objects, causing ambiguous SHA256 overloads and slow source hashing. Direct typed byte-array assignment resolves it. Generated build identities and unrelated concurrent changes are excluded from the scoped implementation checkpoint.

## Actual validation and evidence

Pinned engine: `4.7.2.stable.official.ed1daf0bf`, launched through `scripts/dev.ps1` with PowerShell's process-local ExecutionPolicy Bypass. Normal sandbox launches could not write the external Godot diagnostic log; permitted elevated local runners completed. No machine-wide execution policy was changed.

Commands run:

```powershell
python scripts/build_livery_art.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_livery_patterns.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_livery_patterns.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
```

The new test passes **333 checks in each renderer**: 20 distinct mipmapped artworks, strict bounds and migrations, 100 five-car/pattern combinations, existing-surface application without added geometry, live changes beneath dirt, clean/factory restoration, independent atomic saves/reloads, ordinary race construction, real touch movement without navigation, physical-roof availability and captures at 1280×720, 960×540 and 1600×720. Final result logs are copied into this task's evidence directory.

Existing tests, also run through `-Action TestScript -ScriptPath res://tests/<file>`:

| Test | Actual result |
|---|---|
| test_script_parse.gd | 644 scripts, 0 failures |
| test_garage_livery.gd, graphical Compatibility | 115 checks, 0 failures |
| test_garage_car_transition.gd, graphical Compatibility | 23 checks, 0 failures |
| test_car_wash.gd, headless | 1383 checks, 0 failures |
| test_racing_car_models.gd, headless | 57 checks, 0 failures; original detailed/simple triangle counts and five racing shadow casters retained |
| test_records.gd, headless | 54 checks, 0 failures |
| test_driving.gd, headless | 72 checks, 0 failures; exact same-engine JSON replay |
| test_rewind.gd, headless | 61 checks, 0 failures |

The first local fixture failed because JSON versions reload as floating-point values and strict array membership rejected them. Numeric version comparison and normalized integer version output corrected this; assertions were retained. The first graphical fixture used a relative resource path for a cloud-cache directory and a mismatched contact-sheet image format; both fixture errors were corrected. An initial headless invocation of the existing graphical-only garage-livery test timed out waiting for `frame_post_draw`; its proper graphical run passed. Initial launcher hash failures are recorded above. No failed assertion was removed to achieve a pass.

Reviewed real render evidence:

- [All twenty cars, Compatibility](evidence/livery-stickers-2026-10-13/gl_compatibility/twenty-patterns.png) and [Mobile/Vulkan](evidence/livery-stickers-2026-10-13/mobile/twenty-patterns.png).
- [Compact with hood/roof stickers](evidence/livery-stickers-2026-10-13/gl_compatibility/compact-stickers.png), [960×540 sticker controls](evidence/livery-stickers-2026-10-13/gl_compatibility/stickers-ui-960.png), [sticker choices](evidence/livery-stickers-2026-10-13/gl_compatibility/sticker-choices.png) and [ordinary gameplay camera](evidence/livery-stickers-2026-10-13/gl_compatibility/gameplay.png).
- The same folders contain every individual pattern, all five actual cars, livery/sticker UI at three sizes and the equivalent Mobile captures. The contact sheet preserves capture aspect ratio.

`git diff --check` passes for the implementation files. `-Action Doctor` found the attached DN2103; no physical-phone livery interaction/render/performance test, Android export/install, full Validate suite, production/backend deployment or online write was performed for this task.

## Remaining acceptance

Owner review of the twenty wraps and twelve stickers, including desired AAA quality, is still required. Check physical-phone touch targeting, small decal readability, distant detail stability, thermal/frame cost and the new shader on the phone's renderer. Full motion/performance acceptance is broader than the static paired desktop captures. Reset livery restores factory colours and removes the pattern and both stickers; per-car body kits and accumulated cosmetic condition remain independent.

The scoped Git checkpoint and baseline/task patch are recorded in `evidence/livery-stickers-2026-10-13/delivery.json`; the shared working branch and unrelated staged work are preserved.
