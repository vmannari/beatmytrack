# Play menu selection performance — 2026-09-18

Requirements: R01/G01/V03/V05/Q01. Owner reports slow opening and especially selecting another track in **PLAY** (the track browser, internally `tracks`). Measured on the attached DN2103 / Android 13 / Mali-G77 MC9 with pinned Godot 4.7.2. Existing player tracks and records are preserved.

## Reproduction and changes

The opt-in debug menu probe opens the actual Play screen, selects Ajorata, Knot, then Ajorata again. Baseline main-thread calls blocked for **1,859 ms opening**, **1,650 ms selecting Ajorata**, **2,402 ms selecting Knot**, and **1,643 ms returning to Ajorata**. Desktop phase measurements independently found both track compilation (395–636 ms) and preview scene construction (460–673 ms) expensive. These desktop measurements are not substituted for phone timings.

- `game/ui/track_browser.gd`: defer and slice metadata indexing; load/validate/compile requested tracks on one background thread; acknowledge selection immediately; retain only the latest pending request; discard superseded UI results; retain the existing tile nodes during selection. Draft repair/delete actions are preserved. Worker completion is joined safely on browser exit.
- `game/ui/track_catalog.gd`: bounded four-track compiled cache, invalidated by library changes and explicit Refresh.
- `game/ui/menu_icon.gd`, `game/ui/track_tile.gd`, `game/ui/track_browser.gd`: replace unsupported arrow/star font characters with original cached vector icons. Direct `Font.has_char` checks confirmed the menu font lacks U+2197, U+2192, U+2605 and U+2606. This avoids Android's fallback-font work for these controls.
- `game/track/native_track_visual.gd`: optional cooperative menu construction with approximately 6 ms slices between rows, road edges and objects. Gameplay and editor callers remain synchronous; the same mesh algorithms and content run in the same order. This is presentation scheduling, not a physics or camera change.
- `game/ui/track_showroom.gd`: defer preview construction until layout; render the unchanged static scene twice for a settled image; keep only a small texture and free the 3D viewport. A bounded eight-image cache uses content hash and dimensions. A loading caption appears until a cold preview is ready. No live 3D scene is rendered continuously behind a completed menu preview.
- `game/diagnostics/mobile_menu_probe.gd` and `game/core/app.gd`: explicit debug marker only, bounded menu timing with separate tap-call, drive-ready, preview-ready and internal frame metrics. It does not start races or write PBs. Navigation interrupts the diagnostic safely. The standard screenshot path now waits for completed static previews.
- `game/tests/test_menu_loading.gd`: rapid selection ordering, UI progress while compiling, compiled/image cache reuse, invalidation, exact sliced/synchronous mesh-array comparison, viewport release and cancellation during preview construction.
- `game/tests/test_track_deletion.gd`: await the now-asynchronous selection before exercising the existing deletion assertions.
- `scripts/dev.ps1`: include the headless menu-loading regression in full validation.

Rendering objects remain on the main thread; only isolated track data preparation runs in the worker. This follows the engine's [thread-safety boundaries](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html).

## Actual validation

Commands run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestDeleteTracks
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestSurfaces
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path game --script res://tests/test_menu_loading.gd
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_menu_loading.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 DeployAndroid -QuickValidation
```

Results: menu loading **13 graphical / 10 headless** checks pass; deletion **19** checks pass; surface modes **50** checks pass. Export focused checks pass: import/startup, driving **70**, catalog **18**, menu presentation **11**. The initial deletion run exposed a deferred callback after removal; guards fixed it and the rerun passes without script errors. The graphical geometry comparison includes authored curve/straight pieces. No full-suite green claim: earlier unrelated app-navigation/model-count failures remain documented in prior reports.

Known bounds: first-time compilation and preview generation still take time, while the menu remains available. Slice deadlines are checked between operations, not inside every engine mesh/upload call, so individual frame spikes remain possible. Leaving the browser during an active compile waits for that one worker to finish. Caches are bounded session caches, not persistent disk assets. Test scope is one attached phone and selected local tracks; human acceptance remains pending.

An uncompressed import experiment produced identical artwork pixels but did not improve the measured opening delay; the original import settings were restored. One automated run was interrupted by navigation and excluded; its diagnostic lifetime error was guarded before the final run.

## Final phone measurement and delivery

| Action | Baseline blocked call | Final blocked call | Final ready to Drive | Final preview complete |
|---|---:|---:|---:|---:|
| Open Play | 1,859 ms | **48.640 ms** | Existing selection available | Full index ready at 182.530 ms |
| Select Ajorata, cold | 1,650 ms | **2.263 ms** | 879.115 ms | 2,946.464 ms |
| Select Knot, cold | 2,402 ms | **2.691 ms** | 1,175.699 ms | 4,132.659 ms |
| Return to Ajorata, cached | 1,643 ms | **13.579 ms** | 13.593 ms | 63.392 ms |

The call times measure UI-handler blocking, not the time until a cold track finishes loading. The latter is reported separately. The font-icon replacement reduced opening from approximately 0.5 seconds in intermediate builds to 49 ms in the final build; browser construction itself was 41 ms. It also removed roughly 25 ms of star-font work from the detail panel. The selected-track title/loading state responds immediately; Drive becomes available after valid track data is ready, independently of the scenic image.

Cold preview construction still has occasional unsliced operations: maximum internal frame intervals were 148 ms for Ajorata and 249 ms for Knot, with p99 89/156 ms during their short preparation windows. These are improved interaction semantics, not a claim of constant 60 FPS while generating a new preview. Completed previews retain no live 3D viewport; repeated selections reuse cached data and images. Screenshot layout and route content were inspected on the attached phone. The arrow/star buttons now use their vector counterparts.

The final APK was exported, installed and launched successfully. The opt-in marker was removed and the app relaunched for normal use. Human opening/selection acceptance is pending. No player documents, favorites, PBs or selected-car preferences were edited by the diagnostic.

APK SHA-256: `7CEB1B1D5633DA04B2D05C670151672DA168B107A5CDE5FE3321CF6441949F4F`.

Evidence: [baseline timing](evidence/play-performance/baseline.json), [intermediate timing](evidence/play-performance/intermediate.json), [final phone timing](evidence/play-performance/final.json), [before screenshot](evidence/play-performance/before.png), [final phone screenshot](evidence/play-performance/phone.png), [desktop capture](evidence/play-performance/desktop.png). Graphical menu-loading 13 and deletion 19 checks were repeated after the actual icon replacements and pass. Standard capture was run with `--screen=tracks --capture=../docs/evidence/play-performance/desktop.png` and emitted `CAPTURE_SAVED`; both inspected captures show the vector-icon wiring.
