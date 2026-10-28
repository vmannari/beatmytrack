# Garage test-drive blank screen — 2026-10-26

The owner reported that Garage Test drive showed a nearly empty screen, at least with the electric car. The native reproduction showed only the HUD: the car and parking hall had been built but their geometry remained hidden. The same defect reproduced with all seven cars.

Requirements: **GTF01** reveal the real car and hall before removing the loading cover; **GTF02** cancel safely on navigation, account/car/track changes or teardown; **GTF03/R01/Q01** retain ordinary driving, pause/reset/background behavior, exact saved cosmetics, Garage return and unscored isolation.

## Cause and change

`Game._ready()` uses `world_render_preparation.hold(world)` during cooperative native loading. This deliberately hides newly encountered geometry until staged first draws complete. Ordinary race startup calls `prepare()`; `_start_garage_free_drive()` omitted that call and removed its loading cover with the geometry still hidden. Headless rendering skips this stage, so headless success alone could not detect the defect.

The production change is nine added lines in `game/core/app.gd`: run the existing graphics preparation beneath the Garage loading cover, using the same current-installation callback and cleanup behavior as ordinary racing. No new rendering path or scene is introduced. The geometry, handling, camera, input, hall sources and canonical simulation were not edited.

The new `game/tests/test_garage_test_drive.gd` exercises electric-first entry, actual mouse/touch activation, visible descendant meshes, completed held-geometry preparation, saved cosmetics, driving, pause/reset/background release, retained Garage return and unchanged records/condition. The new `game/tests/test_garage_test_drive_cancellation.gd` reuses the existing native lifecycle observer to interrupt Garage graphics preparation on navigation, vehicle/selection/scope changes and App teardown.

## Evidence and actual validation

The pinned engine is `4.7.2.stable.official.ed1daf0bf`; native checks use the Windows RTX 3090. Mobile here means the desktop Mobile/Vulkan renderer. Each runner invocation uses its own workspace APPDATA/LOCALAPPDATA, local fixture saves, disabled API URL and Dummy audio. Exact commands, durations, exit codes, source hashes and retained intermediate failures are in [report.json](evidence/garage-test-drive-fix-2026-10-26/report.json), individual command JSON files and logs beside it.

- Before the fix: **140 native checks, 21 failures**. Every car failed pending-geometry, actual car-mesh visibility and actual hall-mesh visibility assertions.
- Final Compatibility: **169 checks, 0 failures**, covering all seven cars and an additional electric entry capture plus viewport projection checks.
- Mobile/Vulkan: **161 checks, 0 failures**, covering all seven cars; the final electric-only capture run adds **25 checks, 0 failures**, including projection with the fixture camera matched to its manually advanced driving pose.
- Native Garage cancellation: **18 checks, 0 failures**, across the five interruption cases.
- Existing App regression: **141 checks, 0 failures** after import refresh.
- All-script parser: **1,279 scripts, 0 failures**. The final native runs additionally compile the final focused fixtures.
- Pinned `scripts/dev.ps1 Import`: exit **0**; refreshed seven concurrently added header images. The absent Android build-tools warning does not represent an Android build or device test.

The original [blank electric view](evidence/garage-test-drive-fix-2026-10-26/blank-electric.png), final [Compatibility entry](evidence/garage-test-drive-fix-2026-10-26/verified-compatibility/gl_compatibility-ready-electric.png), [Compatibility driving](evidence/garage-test-drive-fix-2026-10-26/verified-compatibility/gl_compatibility-driving-electric.png) and [Mobile entry](evidence/garage-test-drive-fix-2026-10-26/electric-mobile/mobile-ready-electric.png) are actual native captures. The entry pictures keep the production camera; the driving fixture snaps the existing camera after advancing two seconds of simulation within one display frame so its capture shows the driven car.

## Retained initial findings and limits

The older `test_parking_hall.gd` stops before driving on an outdated `GarageBack` lookup in the current customisation layout. Its original failure is retained in `original-parking-suite.log`; that suite and its assertions were not edited. The first added smoke test checked parent visibility and passed despite the blank native capture; descendant/pending checks were added and reproduced all 21 failures before the production edit.

Two initial sandbox attempts stalled while opening default user logs or reading the root certificate store. Subsequent checks used isolated workspace profiles outside that restriction. Only those two verified orphaned test-helper trees were stopped at cleanup; the owner's game/editor was not restarted.

The first fixed run retained one electric movement failure because the offscreen window had correctly paused on focus loss. The fixture now resumes through the existing pause method before driving, then explicitly verifies background pausing separately. Initial concurrent native runs also retained unimported header-image errors and a 15-second fixture timeout before the electric HUD was built. Importing those new assets removed their errors; the focused fixture now uses the existing Garage suite's 45-second per-entry allowance, matching the App loading watchdog. No visibility or driving assertion was weakened.

The runtime checkpoint contains only the nine Garage lines. Concurrent Free Race comparison and header work remains outside this change. Original and current source snapshots/hashes and a reverse-checkable task patch are retained beside the report; no staging or commit was performed.

Reload/rebuild is required for an already running or exported game. Owner driving acceptance and physical-device appearance/touch/loading performance remain. No physical-device attachment check or test, APK, real authentication/purchase, backend mutation, deployment, merge or owner-process restart was performed.
