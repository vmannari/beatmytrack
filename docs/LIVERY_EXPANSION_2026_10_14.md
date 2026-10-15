# Midnight, new wraps and fictional sponsors

LE01–LE04 / LV01–LV06 / LM01–LM05 / V03–V06 / G01 / R01 / Q01. The owner requests Midnight as the only plain-paint preset, more liveries, and sponsor stickers from fictional companies.

Patterns now has **Midnight plus 32 wraps**: the previous twenty and twelve new designs. Original, Rally and Sandstone are removed from the browser and their fifteen obsolete photographs are removed. Existing saved pigments, factory reset, custom colours and old pattern/sticker IDs remain valid; this changes preset choices rather than deleting player cosmetics. Plain paint with custom colours continues to highlight Midnight's design card.

The twelve additions are Monza Fan, Nightfall, Crossfire, Coastal Wave, Topo Rally, Saber, Checker Fade, Pinstripe Club, Delta Wing, Fracture, Pulse and Aero Cut. These use original three-channel-role vector masks, independent palettes and different broad shapes. `scripts/build_livery_art.py` is the editable source. No external art, font, image generator or new dependency is used.

Stickers has **Emblems / Sponsors** galleries beneath the physical Hood / Roof selector. Each contains twelve named cards. The twelve sponsors are invented for the game: Zelvora Dynamics, Vorqen Fuels, Talvexa Tyres, Orynth Labs, Keldrift Tools, Velqor Audio, Myrvanta Oil, Quorven Racing, Draxelle Parts, Selyth Aero, Auvrion Energy and Rhexori Works. Symbols and geometric wordmark letter paths are authored in the same generator. Exact-name searches on 2026-10-14 returned no results for the four grouped queries recorded in `provenance.json`; the designs are fictional game sponsors, not representations of real companies.

New sponsor placement on an empty panel starts at 180° so the words face someone standing in front of the car. Replacing an existing decal retains its custom position, size and rotation. Hood and roof remain independent, with local per-car saves, mouse/touch placement and the same size/rotation tools. Roof is offered only on the three actual roofed models.

The retained workbench has at most six cached content roots for one roofed car: Patterns, Colours and four panel/category galleries. There is still one disposable placement editor. Changing cars invalidates these controls. Browsing retains the actual car, camera, showroom, condition and fitted parts; it creates no per-pattern live viewport. All 165 recipe photographs are offline native-model renders at 320×200 with mipmaps, totalling 9,759,080 source PNG bytes. The existing four-mask material cache and sixteen-photo kit cache remain bounded independently.

The shared sticker atlas grows from 1024×768 to 1024×1536. Its original twelve indices and 16-pixel gutters remain in place. The finish binds the texture's actual dimensions instead of assuming three rows. Sponsors use the same opaque paint replacement beneath dirt/snow and require no added car meshes, shadow geometry or drawing passes. Saved livery version 2 and version-one pigment migration are unchanged. Canonical handling, PB identity, timing and scoring are unchanged.

Changed source files: `scripts/build_livery_art.py`; `game/ui/garage_page.gd`, `garage_livery_menu.gd`; `game/vehicle/livery_graphics.gd`, `livery_finish.gdshaderinc`; `game/tests/bake_livery_previews.gd`, `test_livery_patterns.gd`, `test_garage_carousel.gd`. Assets are the two catalogues, extended atlas, twelve new masks/previews, twelve sponsor SVGs and current native photographs under `game/assets/liveries/`, with their import settings. Documentation and an isolated review checkpoint accompany these files. Concurrent body-kit, editor, terrain and backend changes remain outside this task's source delta.

Commands run with pinned `4.7.2.stable.official.ed1daf0bf`:

```powershell
python scripts/build_livery_art.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_livery_patterns.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_livery_patterns.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_livery.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_carousel.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_customisation_speed.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
```

Final livery checks pass **546 Compatibility + 546 Mobile/Vulkan**. They cover distinct mipmapped masks, all patterns on all five actual simple-model constructions, expanded atlas bindings under weathering, washing restoration, old pigment migration, sponsor reloads, native card selection, Midnight's pigments, six retained gallery roots, separate panel/category selection, explicit top view, touch dragging, three viewport sizes and the ordinary race construction using saved cosmetics. Native bake completes all 165 photographs. Paint/save rollback regression passes **115 checks**, the existing carousel passes **178**, and the retained-control/prepared-kit check passes **1,398**. Command receipts are recorded in `delivery.json`.

Initial import stopped at an already locked `~bmt_windows_audio_v4.dll`. Initial graphics checks exposed missing mipmaps and newly baked PNGs not yet imported. A bounded asset-only project under `build/livery-import-2026-10-14` imported the same source paths with the pinned engine, and only livery import sidecars/cache bytes were copied back. `asset-import.log` and `asset-mipmap-import.log` contain the successful imports; the shipping extension and other editor processes were left alone. The initial full-project import is not reported as passing.

Initial carousel checks used the retired Midnight index 2 and treated expanded kit gallery scrollbars as handling controls. The fixture now selects Midnight at index 0 and still rejects all visible Slider/SpinBox handling controls, while allowing ordinary scrollbars. No production kit behavior or handling invariant was changed. A retained-cache check initially could not hash a concurrently written kit resource. Whole-project parser attempts encountered concurrent stale editor/menu test signatures; details and final outcomes are kept in the command receipts, not represented as a clean full-project regression.

Actual engine captures are under `docs/evidence/livery-expansion-2026-10-14/{gl_compatibility,mobile}/`: `all-patterns.png`, `all-sponsors.png`, individual wraps/sponsors, three-size livery/colour/sticker/sponsor menus, placement, physical-car variants and ordinary gameplay. Final large and 960×540 sponsor views were inspected: the car remains unobstructed, named cards scroll, actions remain reachable, lettering faces forward and all twelve logos render distinctly.

The task-only checkpoint, binary patch and SHA256 manifest are in `delivery.json`. HEAD and the real Git index are not moved by this checkpoint. No phone commands or physical-device test, APK/export/install, backend writes or deployment were performed. Owner review of the new motifs/fictional identities and physical-phone legibility, placement and frame pacing remain acceptance checks; desktop results do not establish AAA or phone performance acceptance.
