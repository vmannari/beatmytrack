# Larger Garage paint view — 2026-10-26

GPF01–GPF03/R01/Q01 address the owner's screenshot: the main paint-view car is too small and leaves much of the available height unused.

The paint camera inherited the ordinary Garage's 9.09° elevation. Its fit also reserved the eight corners of a single whole-car box, including empty space above the nose and around the roof. Paint now opens at a minimum 30° elevation, retaining the horizontal viewing direction and any already higher angle. It fits the corners of each visible mesh instead of that empty whole-box space. Cached local points are rebuilt only for a different car or fitted-part set. The paint fit reserves 64 logical units above and below the projected car, with the existing maximum 82% vertical envelope and 88% horizontal envelope. The camera changes; the vehicle geometry and viewport sizes do not.

For the Compact in the standalone fixture, projected visible-mesh bounds occupy **43.00% → 58.08%** of viewport height at 960×540, **44.44% → 64.78%** at 1280×720, and **44.16% → 67.36%** at 1720×960. These are projected mesh-bound measurements, not pixel segmentation. Matched actual-App screenshots and measurements are retained separately.

Patterns and Colours share this larger view. Repeated paint choices preserve the fitted camera and player orbit/zoom; resizing preserves viewing direction and zoom. Leaving editing restores the exact preceding Garage transform and orbit values. The low Body kits preset keeps its prior angle, eight-corner fit and padding; Hood, aero, rims and sticker close-ups retain their presets. The user's height correction supersedes only the old requirement to inherit the paint entry's vertical angle. Horizontal direction, same-category stability, genuine-dirt locks, account/purchase/save fences and exact return-camera guards remain.

Runtime scope is `game/ui/garage_customisation_camera.gd`. The retained `test_customisation_carousel.gd` paint-framing assertion now checks the raised angle and unchanged horizontal direction; its visibility check projects every visible mesh's bounds rather than corners in empty whole-car box space. The original safe rectangle, 48% minimum space-use guard, exact return values and all Body kits assertions remain. The new `test_garage_paint_framing.gd` independently projects all visible mesh bounds, checks all seven vehicles at three sizes, adds explicit height bounds, verifies paint/Colours selection stability and player resize behavior, and captures the actual App after asserting Garage readiness.

The unchanged original runtime reproduces **151 headless checks / 42 failures** and **171 Compatibility checks / 48 failures**. Raising the angle alone leaves seven headless/eight native failures. Per-mesh fitting with the old padding leaves one Kart short-window failure; the final 64-unit control clearance resolves it without relaxing the height or clipping assertions. Those original proposals, sources, commands, captures and measurements remain under `initial/`. Two early attempts also encountered a concurrent paint-animation method-signature update; the logs are retained, the matching override subsequently arrived, and this task did not modify the animation, thumbnail or shared showroom sources.

Actual isolated commands use pinned Godot 4.7.2 through `scripts/dev.ps1`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-framing-2026-10-26/run.ps1 -Before -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-framing-2026-10-26/run.ps1 -Before -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-framing-2026-10-26/run.ps1 -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-framing-2026-10-26/run.ps1 -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-framing-2026-10-26/run.ps1 -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-framing-2026-10-26/run.ps1 -Test test_customisation_carousel -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-framing-2026-10-26/run.ps1 -Test test_customisation_carousel -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-framing-2026-10-26/run.ps1 -Test test_garage_preview_stability -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-framing-2026-10-26/run.ps1 -Test test_script_parse -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-framing-2026-10-26/run.ps1 -Import
python docs/evidence/garage-paint-framing-2026-10-26/record.py
```

Final focused **151 headless / 171 Compatibility / 171 desktop Mobile** and retained configurator **647 per desktop renderer** pass. Retained stability **646**, parser **1260** and pinned import pass. Exact outcomes are recorded in [report.json](evidence/garage-paint-framing-2026-10-26/report.json). Tests use isolated records and an offline transaction fixture; actual App images use the ordinary guest flow. No live account or wallet is involved.

[Native before/after review](evidence/garage-paint-framing-2026-10-26/review.html) includes both desktop renderers, three landscape sizes and all seven cars. `record.py` records exact commands, exits, coverage comparisons and source hashes, and generates `task-only.patch` against captured task-start sources. Tracker review bases retain subsequent concurrent entries while excluding this task's one status block; the original captured trackers remain under `before/`. `git apply --check --reverse` validates this reviewable checkpoint; nothing is staged or committed. Concurrent paint animation, paint-list, startup, Rivalry, vehicle, handling and track work are preserved and excluded.

Reload and owner appearance/rotation acceptance remain, along with physical-device touch and performance review. No physical-device attachment check or device test was performed. No APK, real authentication/purchase, live mutation, deployment, merge or owner-process restart was performed.
