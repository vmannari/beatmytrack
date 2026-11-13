# Garage paint preview flash, 2026-11-07

Saving paint no longer replaces the ready Garage car with a loading preview. The cause was the optional profile/header picture capture: after the paint save and idle delay, App placed `HeaderPicturePreparation` over the live showroom and blocked its input while constructing a second car renderer.

The original runtime reproduces **28 checks / 5 failures**, including one header capture beginning inside Garage and **14 rendered frames with the loading cover**. The final same-flow checks pass on desktop Compatibility and Mobile, with zero covered frames and zero header captures starting in Garage.

| Requirement | Implementation and evidence |
|---|---|
| GFL01 | Keep applied paint and the ready showroom visible and turnable. App admits native header captures only in its existing settled menu destinations after the retained Garage is hidden. The header capture no longer creates a loading cover or clears the showroom gesture. |
| GFL02 | Finish the newest saved profile picture after leaving Garage. Exact disk reads still work inside Garage; existing coalescing, saved-appearance keys, navigation/owner cancellation, one-world bound, idle/input and memory/race gates remain. |
| GFLQ01 | Actual-App reproduction and regression, both desktop renderers, retained paint checks, navigation cancellation, screenshots, private profiles and a checked task-only patch. |

Changed files:

- `game/core/app.gd`: capture eligibility and removal of the loading overlay; navigation pins remain.
- `game/ui/header_car_appearance_cache.gd`: comments describe the menu draw boundary; capture/cache implementation is unchanged.
- `game/tests/test_garage_paint_flash.gd`: new actual-App rapid palette/save/idle/navigation/PNG-reuse regression.
- `game/tests/test_header_capture_fences.gd`: update the superseded Garage eligibility expectation and retain the other gates, adding the hidden/outgoing Garage boundary.
- `game/tests/test_deferred_header.gd`: exercise deferred Garage work, menu-draw-before-construction, exact publication/PNG reuse, returning-to-Garage cancellation and account replacement.
- `game/tests/profile_header_garage_regression.gd`: early Garage readiness is independent of an optional missing header image; `--expect-ready` still checks the preceding idle-menu preparation. The receipt now records `garage_ready_ms` and `entry_header_ready` separately.

Actual accepted results using pinned official Godot `4.7.2.stable.official.ed1daf0bf`, Dummy audio and fresh offline desktop profiles:

| Check | Assertions / failures |
|---|---:|
| Actual-App paint flash, headless | 18 / 0 |
| Same flow, native Compatibility | 28 / 0 |
| Same flow, desktop Mobile/Vulkan | 28 / 0 |
| Header capture fences, headless | 32 / 0 |
| Deferred header reads/account scope, headless | 19 / 0 |
| Deferred header, native Compatibility including `--garage` | 51 / 0 |
| Existing paint transition, headless, all five cars and weathered/sticker case | 64 / 0 |
| Early Garage entry, headless | 6 / 0 |
| **Total** | **246 / 0** |

Each native paint-flow run saves two rapid palette choices, lets repaint/debounce/input idle expire, checks exact saved paint and the retained car/world/camera, turns the car, visits Care and Cars, then leaves for Tracks. Exactly one latest-appearance header capture completes there; Garage return reads its exact persisted PNG without a second capture. The deferred-header check additionally returns to Garage between capture admission and renderer construction: the old picture cannot publish. Existing tests keep race, pressure, held touch, recent input, text focus, owner, stale navigation and completed-IO gates.

Inspected native screenshots: [Compatibility paint remains visible](evidence/garage-paint-flash-2026-11-07/compatibility-paint-visible.png), [Mobile paint remains visible](evidence/garage-paint-flash-2026-11-07/mobile-paint-visible.png), [profile picture after leaving](evidence/garage-paint-flash-2026-11-07/header-after-leaving.png), [return to Garage](evidence/garage-paint-flash-2026-11-07/garage-return.png). These are behavior evidence, not a pixel-equivalence or device-performance claim.

Reproduce with fresh run names to retain earlier receipts:

```powershell
python docs/evidence/garage-paint-flash-2026-11-07/run.py repeat-headless res://tests/test_garage_paint_flash.gd
python docs/evidence/garage-paint-flash-2026-11-07/run.py repeat-compatibility res://tests/test_garage_paint_flash.gd --renderer gl_compatibility
python docs/evidence/garage-paint-flash-2026-11-07/run.py repeat-mobile res://tests/test_garage_paint_flash.gd --renderer mobile
python docs/evidence/garage-paint-flash-2026-11-07/run.py repeat-fences res://tests/test_header_capture_fences.gd
python docs/evidence/garage-paint-flash-2026-11-07/run.py repeat-deferred res://tests/test_deferred_header.gd --renderer gl_compatibility --garage
python docs/evidence/garage-paint-flash-2026-11-07/run.py repeat-paint res://tests/test_garage_paint_transition.gd
python docs/evidence/garage-paint-flash-2026-11-07/run.py repeat-early res://tests/profile_header_garage_regression.gd --early
```

[Validation receipts, source hashes and checkpoint](evidence/garage-paint-flash-2026-11-07/validation.json) retain exact commands, exit codes and unchanged monitored sources for all runs. Full profiles/raw captures remain in `build/garage-paint-flash-20261107/`. The task-only source patch is checked forward and backward in a disposable repository, with final content hashes compared, and reverse-checked against the working tree. The main Git index is untouched; prior App edits and concurrent work are preserved.

Initial findings are retained: the first headless fixture reported an extra navigation failure because it checked visibility before the page transition finished. Waiting for that existing transition corrects the fixture; the original native control still reproduces all five production failures. Every run records this environment's root-certificate-store diagnostic; it does not prevent the offline checks from completing. No diagnostic is counted as a clean engine log.

The small header icon may show its existing neutral silhouette until a settled menu can generate the new saved picture, unless its exact PNG already exists. The full Garage paint transition and first-entry loading behavior remain as before. Client reload and owner appearance/input acceptance remain. No physical-device query or test, APK build/install, deployment, owner-save/process change or live backend request was performed.
