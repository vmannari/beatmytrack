# Garage loading previews — 3 November 2026

The plain grey loading silhouettes now use a blue/teal ghost finish, luminous contour, soft background/ground glow and a passing light sweep. A more noticeable slow pulse and translated **Loading preview…** caption identify the temporary state. The main view and compact cards share the style, with separate spacing so the small caption clears the car-name footer.

Requirements: GLS01 improve the loading previews' colour/composition; GLS02 make their loading state clear through motion and text; GLS03 verify actual rendering, localization and retained deferred-view behavior.

Three runtime files change: `game/ui/garage_loading_car.gd`, its shader, and `garage_cached_thumbnail.gd` to opt into compact spacing. The existing actual-car alpha atlas remains the source. The background and ghost animate in the canvas shader; there are no added 3D worlds, per-frame script callbacks or CPU tweens. `Loading preview…` already exists in all twelve catalogues; `GameText.bind` refreshes the caption when language changes. Finished photographs, native materials, startup/navigation preparation and appearance ownership are unchanged.

The real-App review extends `test_garage_deferred_views.gd` with rendered motion sampling and caption bounds/width checks for all twelve locales. It retains the parent test's startup, header, early entry, car-preview, queued-workshop, navigation, pressure/owner, saved-paint, original-reflection and thumbnail-delivery checks.

| Actual run | Result |
| --- | --- |
| Native Compatibility | **269 checks / 0 failures** |
| Native desktop Mobile | **269 checks / 0 failures** |

Both processes exit zero and retain unchanged hashes for the seven recorded sources across each run. **538 checks / 0 failures**, sixteen native captures at 1280×720, 960×540 and 1600×900, including Finnish/German/Japanese text views. Actual sampled animation changes 14,283 / 11,787 pixels on the respective three-pixel sampling grids across the inspected car-region frames. This is evidence of visible animation, not an FPS benchmark. Both logs retain the sandbox's Windows root-certificate-store error; no script/shader errors or timeout were recorded. No clean-environment claim is made.

Views:

- [Compatibility loading preview](evidence/garage-loading-style-2026-11-03/compat/loading-1280x720.png), [small window](evidence/garage-loading-style-2026-11-03/compat/loading-960x540.png).
- [Finnish](evidence/garage-loading-style-2026-11-03/compat/loading-fi.png), [German](evidence/garage-loading-style-2026-11-03/compat/loading-de.png), [Japanese](evidence/garage-loading-style-2026-11-03/compat/loading-ja.png).
- [Desktop Mobile loading](evidence/garage-loading-style-2026-11-03/mobile/loading-1280x720.png), [completed native views](evidence/garage-loading-style-2026-11-03/mobile/pictures-ready-1280x720.png).

Actual commands from the workspace root:

```powershell
python docs/evidence/garage-loading-style-2026-11-03/run_check.py compat
python docs/evidence/garage-loading-style-2026-11-03/run_check.py mobile --renderer mobile
python docs/evidence/garage-loading-style-2026-11-03/summarize.py
python docs/evidence/garage-loading-style-2026-11-03/checkpoint.py
```

The runner uses the pinned `4.7.2.stable.official.ed1daf0bf` executable through `scripts/run_no_crash_dialog.py`, private application/records/library/cloud folders, Dummy audio, disabled API and a 300-second owned-process deadline. Its receipts retain commands, profiles and source hashes. Native views use an RTX 3090 on Windows; the renderer runs are sequential validation, not a performance comparison. The [summary](evidence/garage-loading-style-2026-11-03/summary.json) records capture hashes. Choose new labels for reruns to preserve these artifacts.

The task-only patch includes the three runtime changes, new visual-review fixture, helpers, report and short AGENTS/DEVELOPMENT_STATUS entries. Forward/reverse application and normalized content round trips are checked in an owned workspace directory; the main Git index is not written. Other work remains preserved.

Reload and owner appearance acceptance remain. No physical-device query/test, APK, backend/live access, real authentication/purchase, owner-save change, owner-process restart, deployment or main-index write. No loading-time or FPS improvement is claimed.
