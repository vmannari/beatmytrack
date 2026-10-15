# Garage carousel pictures and closer framing

Owner request, 2026-10-14. GCP01: carousel pictures show the current Garage. GCP02: cars are slightly more zoomed in. GCP03: retain static rendering, actual models, local cosmetics and existing selection/navigation. Existing GC06-GC28, GCS01-GCS04, GMM01-GMM04, GRD01-GRD03, CW13/CW15/CW16, V05/V06/G01/R01/Q01 remain applicable.

The carousel previously omitted the workshop, poster, trophy alcove, drain and record-player station. Its cards now instantiate the same prepared architecture as the main Garage, including the recent workbench cleanup. One immutable PackedScene replaces the two full/simplified architecture caches. Cards retain their actual per-car paint, kits and condition, fixed platform, original static lighting policy and display-resolution viewport.

Carousel framing scale changes from 0.94 to 0.84: the camera is 10.64% closer, giving approximately 11.9% greater linear magnification at the target plane. All five cards retain their common framing, car pose and platform size. This changes only the card camera, with no live showroom or racing-camera adjustment.

The cards also receive the existing bounded floor and pedestal reflections. Their reflection targets use UPDATE_ONCE, refresh with the photograph and stop when hidden; the live showroom retains UPDATE_ALWAYS. The carousel remains five static native renders with explicit repaint on cosmetic changes/resizing/visibility, with no continuous car animation or simulation ownership. No bitmap production assets, new shaders, external services or dependencies were added.

[Before/after carousel comparison](evidence/garage-carousel-refresh-2026-10-14/before-after-carousel.png). Actual full-app captures: [Compatibility](evidence/garage-carousel-refresh-2026-10-14/after/gl_compatibility/garage-1600.png), [Mobile/Vulkan](evidence/garage-carousel-refresh-2026-10-14/after/mobile/capture_garage_reference/garage-1600.png). Both were inspected, with all five cards visible. The existing clean capture script also records 960, 1280, 1600 and 1720 widths and each main car.

Actual validation uses pinned Godot `4.7.2.stable.official.ed1daf0bf`, through `scripts/dev.ps1`, with isolated records in `build/garage-carousel-refresh-2026-10-14/user`:

- Baseline and updated Compatibility reference captures: 25 + 25 checks, zero failures. Updated Mobile/Vulkan reference: 25 checks, zero failures.
- Existing actual-app carousel suite: 178 Compatibility + 178 Mobile/Vulkan checks, zero failures. Covers frozen photo pixels, explicit model refresh, touch scrolling, focus, complete cards, preview/confirmation, local paint/washing and hidden-page/navigation behavior.
- Existing reflection suite: 25 + 25 checks, zero failures. Actual deck/floor reflection pixels change, car swapping retains the rig, hiding stops captures and showing resumes the live rig.
- Scoped parsing of the four changed runtime scripts and task-only whitespace check. Native runs also compile and use all four scripts.
- RGB screenshot comparison of the upper menu/live pane: 960 is exact; the other widths differ by 1, 1 and 5 pixels, confined to the existing animated record-player area/reflection. Separate-time captures are not an exact animation comparison. `pixel-comparison.json` records the unmasked rectangles/counts. An initial RGBA comparison incorrectly ignored RGB differences through alpha; the final comparison converts to RGB and records them explicitly.

Commands actually run (the helper sets isolated APPDATA and retains test logs):

```powershell
# Baseline and updated Compatibility clean captures used this entry point,
# with --evidence-root pointing to the before/after gl_compatibility directories.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_garage_reference.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-root=res://../docs/evidence/garage-carousel-refresh-2026-10-14/after/gl_compatibility' -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_carousel.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-root=res://../docs/evidence/garage-carousel-refresh-2026-10-14/after/gl_compatibility/carousel' -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_carousel_refresh.ps1 -Renderer mobile -ScriptName test_garage_carousel
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_carousel_refresh.ps1 -Renderer gl_compatibility -ScriptName test_garage_reflections
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_carousel_refresh.ps1 -Renderer mobile -ScriptName test_garage_reflections
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_carousel_refresh.ps1 -Renderer mobile -ScriptName capture_garage_reference
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://ui/garage_environment.gd -CommandTimeoutSeconds 60
# Same scoped CheckScript command for car_showroom, garage_page and garage_reflections.
.tools/review/Scripts/python.exe build/review_garage_carousel_refresh.py
python build/checkpoint_garage_carousel_refresh.py
```

Initial attempts encountered sandbox denial of the default user log directory and Windows certificate store; the native captures passed after an approved local rerun with isolated records. One direct PowerShell invocation hit the host execution policy; explicit process-level Bypass corrected it. An unavailable default-Python Pillow import was resolved by using the existing workspace review interpreter; no package was installed. These attempts are not passed checks.

Changed runtime files: `game/ui/garage_environment.gd`, `game/ui/garage_page.gd`, `game/ui/car_showroom.gd`, `game/ui/garage_reflections.gd`. Updated this report and the GCP notes in `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`; supporting runners/review script and the task-only checkpoint are in `build/garage-carousel-refresh-2026-10-14` / `build`. The isolated two-commit Git checkpoint and patch exclude concurrent record-player/menu changes and leave the main branch/index intact. Its ledger records source and capture hashes.

No physical-phone test, APK export/install, backend write or deployment was performed. Owner appearance review and phone quality/performance remain acceptance checks. The fuller room and two reflection captures increase one-time card rendering work; no phone frame-rate claim is made. Canonical driving/scoring, actual main camera, local save contracts and production behavior remain outside this cosmetic change.


## SELECT caption follow-up, 2026-10-14

GCP04/V05/G01/R01/Q01: the owner requests the car-confirmation button read **SELECT** in capitals. Changed only its caption and the existing carousel assertion; click behavior, styling and layout are retained. Actual Compatibility native carousel: 178 checks, zero failures, including the exact caption, placement and selection behavior. [Native 1280 screenshot](evidence/garage-carousel-refresh-2026-10-14/select-label/gl_compatibility/test_garage_carousel/cars-1280.png); 960 and 1600 captures are adjacent. Command: `powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_carousel_refresh.ps1 -Renderer gl_compatibility -Phase select-label -ScriptName test_garage_carousel`. Changed files: `game/ui/garage_page.gd`, `game/tests/test_garage_carousel.gd`, this note and the project status/instruction notes. A separate task-only two-commit checkpoint is in `build/garage-select-label-2026-10-14/checkpoint-repo`; `select-label/task-only.patch` and `checkpoint.json` record it, with a clean scoped whitespace check and untouched main branch/index. No phone test/APK/deployment; owner appearance acceptance remains.
