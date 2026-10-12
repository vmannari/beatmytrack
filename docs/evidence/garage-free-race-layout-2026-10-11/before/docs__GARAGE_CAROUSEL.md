# Garage car carousel and car tools

Owner request, 2026-10-11. Requirements: GC01 (track-style car carousel), GC02 (selected-car menu), GC03 (liveries and colours), GC04 (Care with manual washing), GC05 (Tuning placeholder), with existing CW13/CW15/CW16/GL01-GL06/V06/G01/R01/Q01 boundaries.

Garage now opens on the actual selected car with a bottom illustrated carousel of all five vehicles. Cards reuse the track carousel's mouse/touch drag, wheel scrolling, bounded edge response and full-card snapping. Keyboard focus reveals offscreen cards. Tapping a card selects that vehicle for racing and opens its car menu without rebuilding the menu shell. Back returns through the car menu to the carousel; Escape follows the same hierarchy.

The car menu offers **Customise**, **Care** and **Tuning**. Customise provides Original, Rally, Midnight and Sandstone two-tone liveries, separate Body/Accent colour pickers and Reset paint. These use the existing cosmetic paint slots and local save format; additional decal patterns are not implemented. Changes preview on the actual rotatable model and persist independently for each car. Carousel thumbnails reuse the established cleared fictional illustrations; the showroom displays actual paint and dirt.

Care contains the existing optional manual Wash action. It opens in ordinary orbit mode; Wash explicitly starts the brush and Done ends it. Leaving Care, switching cars or hiding Garage stops washing and commits partial local condition. Clean cached pages do not create cosmetic saves. Snow melting, existing dirt age, rim washing, save-error handling and protection against overwriting newer race dirt remain. Tuning displays Coming later and has no handling controls.

Washing and liveries remain local, per-car cosmetics with no backend fields or requests. Existing telemetry observes only car identity/position for actually visible carousel cards and car selection; no paint, dirt or care information is collected. Free racing, five laps, performance configurations, canonical scores and PB keys are unchanged. The overview retains its selected-circuit and Race actions.

## Changed files

- `game/ui/garage_page.gd`: carousel, selected-car hierarchy, livery presets, Care routing and local lifecycle.
- `game/core/app.gd`: select cars without rebuilding Garage, refresh cached selection/circuit and adapt existing car impressions to visible cards.
- `game/tests/test_garage_carousel.gd` (+UID): actual touch flow, cancellation, edge ownership, keyboard navigation, responsive captures, five-car persistence and clean-cache checks.
- Existing `test_garage_livery.gd`, `test_car_wash.gd`, `test_menu_quality.gd`, `test_menu_page_swipe.gd`: navigate the new hierarchy and replace removed-dropdown references. Wash projection waits for Care layout; its screen-bound assertion now checks the full rectangle against the logical viewport. Free Race fixtures explicitly select their intended mode rather than inheriting the newer Rivalry default.
- This document, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.

## Actual verification

All commands used `scripts/dev.ps1` with pinned `4.7.2.stable.official.ed1daf0bf` and isolated test saves:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://ui/garage_page.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_carousel.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_carousel.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument --mobile-evidence
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_livery.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_car_wash.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_view_controls.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_menu_quality.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_menu_page_swipe.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_product_telemetry.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestRecords
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor
python build/checkpoint_garage_carousel.py
```

Final results: Garage carousel **120 checks on Compatibility and 120 on Mobile/Vulkan**, livery **115**, washing **1,402**, view controls **59**, menu quality **23**, primary-menu swipes **268**, telemetry **55**, records **54**, app **99**; zero failures. Import and script parsing also pass. A real dirty door pixel's blue channel rises from 0.0784 to 0.2314 when washed; exact partial wash masks survive navigation/restart and paint leaves dirt intact.

Initial fixture failures are recorded: missing full dirty-condition fields, an incorrect diagnostic method name, counting hidden carousel scrollbars as tuning controls, projecting the wash target before layout, using physical window width for logical screen bounds, stale dropdown references, and expecting an explicit condition entry for a never-dirty car. The menu-cache test's three failures also reproduce against the saved pre-change app; explicitly selecting Free Race fixes the fixture while retaining its assertions. The initial restricted checker could not open its Windows engine log; normal Windows access resolves it. An edit-time text encoding issue was corrected against the exact UTF-8 task baseline; final scoped diff review confirms only intended app changes. A concurrent client-quality observer integration is preserved in the working tree and excluded from this task patch. No assertion was weakened or invariant removed.

Thirty actual screenshots cover carousel/car menu/Customise/Care/Tuning at 960x540, 1280x720 and 1600x720 on both desktop renderers. Inspected examples: [carousel](evidence/garage-carousel-2026-10-11/cars-1280.png), [car menu](evidence/garage-carousel-2026-10-11/car-menu-960.png), [Customise](evidence/garage-carousel-2026-10-11/customise-960.png), [Care](evidence/garage-carousel-2026-10-11/care-1280.png), [Tuning](evidence/garage-carousel-2026-10-11/tuning-1280.png), [Mobile carousel](evidence/garage-carousel-2026-10-11/mobile/cars-960.png). Sources, scoped patch/hash ledger and retained actual logs are in the same evidence directory. A task-only two-commit Git checkpoint is in `build/garage_carousel/checkpoint-repo`; the main branch/index and unrelated work are preserved.

Doctor reports no attached Android devices. No phone test, Android export/install, full Validate, physics merge/regression, backend operation or deployment was performed. Desktop Mobile/Vulkan is not a phone-performance claim. Restart the client and manually review carousel swiping, all five selections, colours/livery feel, Care washing and Back navigation on a physical phone; owner visual/touch acceptance remains open.
