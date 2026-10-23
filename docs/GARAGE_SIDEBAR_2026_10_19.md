# Garage sidebar refinement — 2026-10-19

GSI01: replace the Garage music, car and News icons with clear original artwork. GSI02: refine the entire selected-car icon set into one visual family. GSI03: centre the icons and retain aligned buttons across navigation, focus and pointer states. G01/R01/Q01: retain the actual Garage workflows, check native presentation and preserve a task-only source checkpoint.

`game/ui/garage_mode_icons.gd` now uses original rounded vector strokes on a shared 64-unit grid: a car side silhouette, paintbrush, cleaning droplet, wrench, musical notes, trophy and folded newspaper. The original seven-key texture cache, mipmaps and 256-pixel raster size remain. No third-party artwork, generated image, download or dependency was added.

`game/ui/garage_page.gd::_build_rail` explicitly centres a 36-unit icon, removes empty-text spacing and supplies matching content margins for every button state. Hover, pressed and inset keyboard-focus treatments share the same geometry. The original 60-unit rail width and 60/52-unit button heights remain. The original button rectangles were already equal; the correction addresses the offset/uneven glyph presentation and inherited state padding. The selection and selected-car rails retain their original destinations, order and spacing. Music still opens the existing Record player.

`game/tests/test_garage_sidebar.gd` exercises the real app with isolated workspace records and a disabled API. It checks equal button dimensions, left edges, target sizes, bounds, fixed positions across all six selected-car destinations, consistent state margins, mouse/touch activation, retained actual car/viewport and unchanged car-condition records. Native views cover 960×540, 1280×720 and 1600×720 on both desktop renderers.

Actual results:

| Check | Result |
|---|---|
| Focused sidebar, headless | 415 checks, 0 failures |
| Focused sidebar, Compatibility | 426 checks, 0 failures |
| Focused sidebar, desktop Mobile/Vulkan | 426 checks, 0 failures |
| Existing Garage menu transitions, headless | 135 checks, 0 failures |
| Existing Garage Record player/music workflow, headless | 64 checks, 0 failures |
| Project script parser | 907 scripts, 0 failures |

Actual entry-point commands used pinned Godot `4.7.2.stable.official.ed1daf0bf`, a process-only PowerShell execution-policy Bypass, disposable workspace APPDATA and the temporary `build/run_garage_sidebar.ps1` wrapper:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_sidebar.ps1 -Renderer gl_compatibility -Before -Evidence res://../docs/evidence/garage-sidebar-2026-10-19/before
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_sidebar.ps1 -Script res://tests/test_script_parse.gd
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_sidebar.ps1 -Renderer gl_compatibility -Evidence res://../docs/evidence/garage-sidebar-2026-10-19/final/gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_sidebar.ps1 -Renderer mobile -Evidence res://../docs/evidence/garage-sidebar-2026-10-19/final/mobile
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_sidebar.ps1 -Evidence res://../docs/evidence/garage-sidebar-2026-10-19/final/headless
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_sidebar.ps1 -Script res://tests/test_garage_records.gd
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_sidebar.ps1 -Script res://tests/test_garage_menu_motion.gd -Evidence res://../docs/evidence/garage-sidebar-2026-10-19/regression-motion
```

Initial attempts and limitations are retained. Direct script execution hit the host execution policy. Native engine initialization then hit sandbox restrictions on the original user log directory and Windows certificate store. Disposable workspace APPDATA and approved local native execution resolved these. The initial before-capture run reported three failed 960-pixel pointer checks because `Input.parse_input_event` interpreted logical coordinates as window coordinates. The fixture now uses viewport-local `push_input(..., true)` and real touch events; these were fixture corrections. Those three failures are not presented as original product regressions. An additional legacy `test_garage_livery.gd` headless attempt was stopped: its unconditional `RenderingServer.frame_post_draw` wait needs a graphical renderer. That attempt is not counted as passed.

Before/after native screenshots, raw logs, archived originals, final source hashes and `task.patch` are under `docs/evidence/garage-sidebar-2026-10-19/`. The patch is relative to the saved working sources, preserving pre-existing changes to Garage and the rest of the workspace. Existing car selection, customisation, washing, music, trophies, News, saved data and showroom resources remain in place.

Owner visual acceptance and physical-device readability/touch acceptance remain. No phone attachment check or device test was performed. No APK, backend/account mutation or deployment action was performed.
