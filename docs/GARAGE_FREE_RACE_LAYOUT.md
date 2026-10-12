# Garage Free Race layout correction

Owner correction, 2026-10-11, using the supplied Free Race screenshot. Requirements: GC06 (Free Race composition), GC07 (bottom Select car confirmation), GC08 (actual 3D model carousel), GC09 (left Customise/Care/Tuning rail), preserving GC03-GC05/CW13/CW15/CW16/GL01-GL06/V06/G01/R01/Q01.

Garage now uses the same 60-unit left rail, 12-unit body gutter, main content column, full-card carousel and 60-unit bottom action row as Free Race. The central showroom spans the main column. The right-hand Garage card and illustrated car cards are replaced by the requested layout. Garage's bottom yellow **Select car** action includes the same right-aligned arrow as Free Race.

Clicking/tapping a car card previews its actual model, saved paint and dirt without changing the driving-car preference. Select car confirms the preview and opens Customise. The left rail then has icon buttons for Customise, Care and Tuning, with the active mode yellow, tooltips and a visible contextual heading where needed. Customise has livery/body/accent controls in a horizontal panel below the showroom. Care gives the showroom more room for washing, with Wash/Done beside Back to cars in the bottom action row. Tuning shows Coming later. Back to cars and Escape return to browsing. The active primary-menu shell stays alive; a background refresh preserves an unconfirmed preview.

Each carousel card contains a real `CarVisual` in an isolated 3D studio viewport with its local paint and condition. The card is read-only: no orbit, washing, snow melting or save side effects. Its viewport draws on layout/visibility/paint/condition changes and otherwise retains the render. Five native pixel checks demonstrate that rotating each underlying model without a refresh leaves its image byte-exact, then an explicit refresh changes each image. Cards use 2x MSAA; the interactive showroom retains 4x MSAA, orbit/pinch/zoom/reset and hit-tested washing. Whole-menu-camera framing uses 0.76 in the showroom and 0.70 in cards; it does not change gameplay cameras, physical geometry or handling. Paint and dirt remain local, optional and per-car; no condition/paint backend field or new telemetry event is introduced. Existing car selection/impression events retain their prior semantics.

## Files and actual checks

Runtime changes: `game/ui/garage_page.gd`, `game/ui/car_showroom.gd`, `game/ui/menu_icon.gd` (one original outlined Care droplet). Updated integration checks: `game/tests/test_garage_carousel.gd`, `test_menu_quality.gd` and `test_menu_page_swipe.gd`. The menu-quality fixture now confirms a car and retains the current track without racing; Garage's former race/circuit actions are superseded by the owner's Select car request. The swipe fixture targets the actual Garage heading rather than estimating a coordinate beside the showroom. Documentation: this file, the supersession note in `GARAGE_CAROUSEL.md`, `AGENTS.md`, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`. Concurrent client-quality, winter and other work is preserved.

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. Actual commands, with isolated test records:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://ui/garage_page.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_carousel.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_carousel.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument --mobile-evidence
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_livery.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_car_wash.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_view_controls.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_menu_quality.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_menu_page_swipe.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor
python build/checkpoint_garage_free_race_layout.py
```

Passes: Garage **150 checks on Compatibility and 150 on desktop Mobile/Vulkan**, livery **115**, washing **1,402**, view controls **59**, menu quality **23**, menu swipes **268**, app **99**; zero failures in these final runs. Washing reveals original blue paint: blue channel 0.0784 to 0.2471 on the final expanded Care view. Tests retain exact local partial masks, independent five-car persistence and unchanged canonical PB keys. Thirty actual screenshots cover browsing/confirmed car/Customise/Care/Tuning at 960x540, 1280x720 and 1600x720, across both desktop renderers.

Initial thumbnail checks incorrectly assumed the public update-mode getter changed to Disabled after a one-shot render; it retains the configured Once value. The check now proves actual frozen pixels and explicit refresh for all five models rather than inferring rendering from that cached getter. The renderer policy is described in the [official SubViewport documentation](https://docs.godotengine.org/en/stable/classes/class_subviewport.html); the cached getter is visible in [Godot's source](https://github.com/godotengine/godot/blob/master/scene/main/viewport.cpp). An initial concurrent graphical swipe run reported one reverse-navigation failure. An isolated diagnostic rerun passes; the final fixture uses the heading's actual rectangle and keeps all navigation assertions. Earlier failure logs are retained. No invariant is weakened to obtain a pass.

Actual inspected previews: [browsing, all five cars](evidence/garage-free-race-layout-2026-10-11/cars-1600.png), [confirmed car and left rail](evidence/garage-free-race-layout-2026-10-11/car-menu-1280.png), [Customise](evidence/garage-free-race-layout-2026-10-11/customise-1280.png), [Care](evidence/garage-free-race-layout-2026-10-11/care-1280.png), [Tuning](evidence/garage-free-race-layout-2026-10-11/tuning-960.png), [Mobile/Vulkan browsing](evidence/garage-free-race-layout-2026-10-11/mobile/cars-1280.png). No reference pixels or generated illustrations are used in the new cards.

The task-only two-commit Git checkpoint is in `build/garage_free_race_layout/checkpoint-repo`; scoped patch, source/evidence hashes and actual logs are in `docs/evidence/garage-free-race-layout-2026-10-11`. The main branch/index and concurrent edits are preserved.

Doctor reports no attached phone. No physical-device test, Android export/install, full Validate, physics regression/merge, backend operation or deployment was performed. Five 3D card worlds consume bounded memory and refresh cost; desktop frozen-render evidence does not establish phone performance. Restart and review the composition, swipe/confirmation behavior, all car models, colour popup and washing on a physical device. Owner visual/input and phone performance acceptance remain open.
