# Livery menu refinement — 2026-10-13

The owner rejected the first livery menu as clumsy and below the project's AAA quality target. The new composition gives the existing live car the main area and places a dedicated customisation workbench on the right. Patterns, Colours and Stickers have separate tools, with named visual choices and less competing UI.

| Requirement | Delivered behaviour |
|---|---|
| LM01 | The car occupies the larger pane. The existing showroom, room, car, turntable, viewport, camera position, zoom, yaw and condition survive tool changes. Other garage sections return to their established layout. Top view explicitly raises the menu camera for hood/roof inspection while retaining zoom and turntable angle. |
| LM02 | A scrolling two-column library shows all twenty patterns and four existing colour recipes as named photographs of the selected car model. A quiet gold frame/check identifies the selected design. One click previews and saves the choice; edited pattern colours retain their design selection. |
| LM03 | Colours separates Body, Accent and Detail, with visible selected-role swatches, fifteen coordinated quick colours and the existing native custom picker. Changing a colour affects only that role and retains the pattern/stickers. |
| LM04 | The sticker library shows twelve named emblems directly, with actual Hood/Roof availability, immediate selection, bounded Place sticker/Remove actions and a separate placement view. The live car remains unobstructed. Placement provides direct mouse/touch dragging, size in percent, rotation in degrees, Centre and Back. Removing a sticker leaves the other panel intact. |
| LM05 | Browsing uses mipmapped offline photographs and existing vector emblem textures. No per-pattern live 3D viewport, model rebuild, physics/scoring change, new save contract or runtime service was added. Local per-car paint, dirt/washing, body kits and garage reflections remain independent. |
| V03/V04/V05/G01/R01/Q01 | Real native UI interactions, both desktop renderers, three window sizes, saved race presentation and existing garage integration checks. Owner quality and physical-phone acceptance remain open. |

## Files and original artwork

`game/ui/garage_page.gd` moves the existing preview/tools into the two-pane layout only during Customise, then restores the normal garage composition. It owns the existing cosmetic actions, the explicit Top view action and sticker placement state.

`garage_livery_menu.gd` builds the sidebar and its distinct tools. `livery_tile.gd` renders named cards with selection/focus frames; `livery_colour_chip.gd` renders paint chips. `sticker_placement.gd` respects the caller's panel size. Existing livery shaders, vehicle geometry, canonical simulation and local save schemas were not changed by this refinement.

`game/tests/bake_livery_previews.gd` produced **120 native 320×200 photographs**, covering five actual original car models and twenty-four recipes. `game/assets/liveries/previews_v2/` contains their PNGs and mipmapped import sidecars. The PNG files total **7,082,787 bytes**. The existing models, livery artwork and native studio lighting supply the photographs; no reference art, downloaded images, real sponsor logos, AI provider or external font was introduced. Each menu builds only the current car's twenty-four static preview cards. These depict the recipe on the original car; the main live showroom retains the player's actual colours, stickers, condition and fitted parts.

`test_livery_patterns.gd` now exercises the refined tools and writes this task's evidence. Existing `test_garage_livery.gd`, `test_garage_carousel.gd` and `test_garage_studio.gd` navigate to Colours for colour-specific checks; the carousel also explicitly opens Patterns before testing its library. Their paint, failure rollback, condition and canonical assertions were retained. The studio test was adapted but was not executed for this task; its geometry/profile checks lie outside this UI revision.

## Actual validation

Pinned build: `4.7.2.stable.official.ed1daf0bf`, invoked through `scripts/dev.ps1` using process-local PowerShell ExecutionPolicy Bypass. Tests used isolated records/cache directories and disabled online API configuration.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_livery_patterns.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_livery_patterns.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
```

| Actual check | Result |
|---|---|
| Offline photo bake | 120 captures completed; final closer framing and mipmap import succeeded |
| Refined livery suite, Compatibility | 355 checks, 0 failures |
| Refined livery suite, Mobile/Vulkan | 355 checks, 0 failures |
| Existing garage livery, graphical Compatibility | 115 checks, 0 failures |
| Existing car transitions, graphical Compatibility | 23 checks, 0 failures |
| Existing garage/carousel/care/trophy integration, graphical Compatibility | 178 checks, 0 failures |
| Full project script compilation | 664 scripts, 0 failures |

The refined suite includes actual model-card mouse clicking/local commit, selected-role palette editing, unchanged car/viewport/camera/zoom on tool changes, compact sticker actions, unobstructed placement, native touch movement without page navigation, panel-independent removal and explicit Top view retaining zoom/yaw. It retains all five-car/twenty-pattern material, migration, persistence, dirt/clean/factory restoration and ordinary saved-race checks from the original livery task. Patterns, Colours and placement are captured at 1280×720, 960×540 and 1600×720 on both renderers.

A concurrent cache change retained the sidebar and its separate tool/panel views. That work is preserved in the merged UI components. Final integration initially found three stale hidden-control lookups, plus a selection refresh that could target the last-created gallery rather than the active hood/roof gallery. Visible controls are now queried through the active pane; returning to a cached panel rebinds its own tile set. Two additional checks verify the independent hood/roof selection after returning to each cached gallery. The carousel's no-handling-slider invariant now checks visible controls, because cached inactive sticker sliders remain in the tree. The final 355-check runs pass on both renderers.

During review, the initial native photographs left too much studio background; their final camera framing fills the cards more clearly. A draft placement overlay obscured part of the car and was replaced by the sidebar placement view. The first sticker footer used the source icon's large intrinsic size; explicit icon scaling restored normal action height and added regression coverage. The first carousel run failed two assertions because it assumed Patterns was active after returning from a remembered Colours tool. The revised test explicitly clicks the new Patterns tab and retains the complete library assertion; the final 178-check run passes. No assertion was removed to achieve a pass.

Review captures:

- [Before: old bottom strip, Mobile](evidence/livery-menu-refinement-2026-10-13/before-mobile/livery-ui-960.png).
- [After: named patterns, Compatibility](evidence/livery-menu-refinement-2026-10-13/gl_compatibility/livery-ui-960.png) and [Mobile](evidence/livery-menu-refinement-2026-10-13/mobile/livery-ui-960.png).
- [Colours](evidence/livery-menu-refinement-2026-10-13/gl_compatibility/colours-ui-960.png), [sticker gallery](evidence/livery-menu-refinement-2026-10-13/gl_compatibility/sticker-choices.png), [placement](evidence/livery-menu-refinement-2026-10-13/gl_compatibility/stickers-ui-960.png), [Top view](evidence/livery-menu-refinement-2026-10-13/gl_compatibility/top-view.png) and [saved race presentation](evidence/livery-menu-refinement-2026-10-13/gl_compatibility/gameplay.png).

The evidence directory preserves source baselines, actual final command logs, both-renderer captures and the scoped Git checkpoint receipt. The current working branch/index and concurrent changes remain intact. `git diff --check` passes for the refinement.

## Acceptance limits

AAA remains the owner's review target. Physical-phone visual quality, touch scrolling/placement, small thumbnail readability and sustained garage frame/thermal cost were not tested. No phone commands, Android export/install, full Validate run, backend/production deployment or online write was performed for this task. The larger live viewport changes the number of rendered pixels; these desktop checks do not establish phone FPS or a performance improvement.
