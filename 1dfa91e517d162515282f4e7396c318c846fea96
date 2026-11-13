# Garage paint list with profile car icons — 2026-10-26

GPL01–GPL04/R01/Q01 implement the owner's request for painting to use the Parts menu style, with a tiny car like the profile button.

Appearance > Patterns now uses the shared full-width numbered list: all 49 existing choices, a category heading/count, descriptions, aligned authoritative prices, a green equipped check, a restrained yellow selection outline, Previewing state and explicit Buy & Equip. The existing Appearance header/wallet and Patterns/Colours/Stickers tabs remain. The large sidebar photograph, duplicate selected-part section and separate cancel button are absent. Colours and sticker tools keep their existing behavior.

Each row has a small transparent car using the profile button's actual simple model, camera, lights and composite shader. The icon shows that vehicle, candidate paint, saved panel stickers and fitted parts. The equipped row uses the actual saved palette, matching the profile car; choosing it restores that paint without resetting custom colours. Other choices use their original preset palettes. The main Garage remains the live interactive preview, with the existing body framing and drag rotation. Choosing paint preserves the player's camera angle and zoom. Hold to compare temporarily displays equipped paint; outside release restores the selection. Changing selection, account or navigation cannot restore a stale held preview.

Only visible rows request icons. One temporary native profile studio renders 176×112 images, displayed at 64×40 or 56×36. A 24-entry cache is keyed by renderer, vehicle, complete paint and parts. Offscreen rows release their texture references; hiding the list cancels pending jobs and releases its studio. The worker uses frame callbacks owned by its node and disconnects on exit. Rows retain no viewport. The initial queued-free implementation briefly left multiple studios attached: five original lifecycle failures are retained in `initial/world-lifetime-console.log`. The frame-driven worker detaches each completed studio before queuing its deletion; the original one-world bound passes. Freeing the menu during cold rendering is also exercised.

The initial 960×540 screenshot exposed wrapping description text below an 82-unit row. Paint rows now retain 100 units at that size, and an explicit description-containment check passes at all three tested sizes. The original screenshot is retained as `initial/compact-description-before.png`. Parts retain their preceding row sizing.

Runtime changes are `garage_livery_menu.gd`, `garage_page.gd`, `garage_part_option.gd`, `garage_parts_list.gd`, `profile_car.gd` and the new `garage_paint_icons.gd`. New coverage is `test_garage_paint_list.gd`. Only superseded photo/grid/type assertions are adapted in `test_customisation_carousel.gd`, `test_earned_coins.gd` and `test_livery_patterns.gd`. Retained purchase confirmation, account scope, authoritative wallet, save, visibility, all-car framing and camera guards remain. No economy values, saved formats, vehicle geometry, race camera or simulation are changed by this task. The preceding rear-aero/body-kit stability fix remains.

Actual isolated commands use the pinned Godot 4.7.2 entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-list-2026-10-26/run.ps1 -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-list-2026-10-26/run.ps1 -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-list-2026-10-26/run.ps1 -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-list-2026-10-26/run.ps1 -Test test_customisation_carousel -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-list-2026-10-26/run.ps1 -Test test_customisation_carousel -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-list-2026-10-26/run.ps1 -Test test_earned_coins -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-list-2026-10-26/run.ps1 -Test test_garage_customisation_speed -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-list-2026-10-26/run.ps1 -Test test_script_parse -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-list-2026-10-26/run.ps1 -Import
python docs/evidence/garage-paint-list-2026-10-26/record.py
```

Final focused checks: **151 headless / 192 Compatibility / 192 desktop Mobile**, zero failures. The focused suite injects mouse/touch at the small icon, tests saved-palette restoration, preview/compare/account lifecycle, last-option selection, all seven vehicles, three window sizes, cache/world bounds, in-flight teardown and the real App with its profile header. Sampled RGBA pixels match an independent instance of the shared profile presentation within the unchanged 0.02 mean absolute difference limit. Both renderers produce transparent fixed-size car icons. The actual App uses the covered asynchronous Garage preparation and isolated records, with no live wallet fixture. The standalone transaction fixture is isolated and cannot issue real purchases.

Retained configurator: **647 per desktop renderer**. Earned coins: **56**, customisation speed/lifecycle: **1446**, parser: **1241**, and pinned import pass. Exact arguments, exit codes, logs, screenshots and source hashes are recorded in [report.json](evidence/garage-paint-list-2026-10-26/report.json). The broader historical `test_livery_patterns` suite was not run: its automatic-commit and pre-focus camera expectations precede the approved live configurator. Its one row type is updated so the project still parses. No unrelated known cleanliness-fixture failure is reclassified as passing.

One intermediate project parse encountered a concurrent challenge-test override signature update. Its failed command/log remain under `initial/concurrent-challenge-signature-*`; this task did not edit the challenge sources. The matching override was present on the subsequent check.

[Native screenshot review](evidence/garage-paint-list-2026-10-26/review.html) includes actual App views at 960×540, 1280×720 and 1720×900, held comparison and all seven vehicles. `record.py` produces `task-only.patch` against the captured task-start sources, and checks `git apply --check --reverse`. This is a reviewable checkpoint; nothing is staged or committed. Concurrent Garage/startup, Rivalry, vehicle, handling and track changes are retained and excluded from the patch.

Reload is required to see the source changes. Owner appearance/scroll/compare acceptance and physical-device touch/performance review remain. New descriptions use English fallback through the existing translation binding. No physical-device attachment check or device test was performed. No APK, authentication, real purchase, live-account mutation, deployment, merge or owner-process restart was performed.
