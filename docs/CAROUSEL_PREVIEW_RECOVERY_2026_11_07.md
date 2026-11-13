# Carousel preview recovery, 2026-11-07

Two local preview recovery defects are corrected. The tablet's reported hang is captured, but the changes have **not been installed or qualified on the tablet**. Its current stuck session did not recover during the diagnostic attempts below, so these desktop results do not establish the complete cause of that session.

| Item | Change |
|---|---|
| CPR01 | The existing root touch relay observes releases as well as popup releases. A menu gesture can allow finger-down through to preview workers and consume finger-up; the old relay left that finger in their dictionaries and blocked rendering indefinitely. Forwarding removes only the released/cancelled finger. |
| CPR02 | An unchanged preview identity no longer prevents resubmitting a missing picture on refresh/re-entry. Exact remembered pictures still publish immediately; the existing service coalesces queued, active and IO requests. Late pictures of a different saved appearance remain rejected. |

Runtime changes are confined to `game/ui/preview_touch_input.gd` and `game/ui/garage_cached_thumbnail.gd`. Renderer, camera, saved appearances, image format, cache limits and capture policy are unchanged.

## Verification

Pinned official Godot `4.7.2.stable.official.ed1daf0bf`, private offline desktop profiles, Dummy audio:

| Accepted check | Assertions / failures |
|---|---:|
| Input, cancellation, two fingers, popup forwarding and missing-request recovery, headless | 20 / 0 |
| Same checks, native Compatibility | 20 / 0 |
| Actual App Garage delivery/lifecycle, headless | 11 / 0 |
| Actual App saved-car pictures, native Compatibility | 26 / 0 |
| Same saved-car flow, desktop Mobile/Vulkan | 26 / 0 |
| **Total** | **103 / 0** |

The final original-runtime control reproduces 6 failures in 20 checks, including retained consumed touches, the closed render gate, their later popup consequence and the missing same-key retry. A thumbnail-only control reproduces the missing-request failure independently. Controls replace script resources inside their private test process, without rewriting working sources. Final run receipts report no changes to monitored sources during execution; both runtime files match the delivered versions.

Native delivery checks cover all five exact-key carousel images, removal of each loading placeholder, saved Rally/Volt pigments, photograph-only cards and clearing a parked worker before reopening the retained Garage. Native tests use the tablet's privately read livery/condition fields in a fresh offline Guest profile; its account identity and history are not copied. The actual-App swipe fixture supplies an empty modal scope to isolate consumed input from notification layers and dummy-display popup behavior. This is not unrestricted whole-App gesture acceptance. Native captures were inspected; there is no Android renderer/performance or before/after pixel-equivalence claim.

[Accepted receipts and validation](evidence/carousel-preview-recovery-2026-11-07/validation.json). Raw process logs, initial attempts, private profiles, desktop captures and device observations remain under `build/carousel-preview-20261107/`. Reproduce an ordinary isolated check with:

```powershell
python scripts/check_carousel_preview.py repeat-input res://tests/test_preview_touch_consumption.gd --headless
python scripts/check_carousel_preview.py repeat-delivery res://tests/test_carousel_preview_delivery.gd --rendering-method gl_compatibility -- --output=res://../build/carousel-preview-20261107/repeat-delivery
```

Use fresh run/output names to preserve prior receipts. `--tablet-appearance` is an optional local-only replay requiring the private appearance fixture; normal regression runs do not require tablet access. Original-source control flags likewise require the task-local archived scripts.

## Tablet observations and remaining limits

OPD2403, serial `f0ba474a`, runs `0.3.0-creator.e14bec0e820302b39bbb8c16684bda60`, which is newer than the earlier loading-update note. The four relevant unchanged preview/cache/preloader/composition sources match that build's retained snapshot. Initial and later captures show Rally and Volt loading while Kart and Forklift have photographs. The current process log has no matched script/parse/fatal errors. Android reports no displays touched; that does not expose Godot's internal touch dictionaries.

A HOME/launcher resume preserves process `29296` and leaves the two placeholders. Store/Garage tab taps followed by an idle interval also leave the photographed loading state; actual intermediate navigation was not captured. These observations do not prove that the reproduced lost-release path caused this tablet session. Only car appearance fields were read for local reproduction. No APK was built/installed, app data cleared, track synced, car confirmed, purchase made, owner process force-stopped, desktop owner save edited, direct backend operation performed or Git staging/commit performed. Ordinary app lifecycle/menu behavior retains its normal online reads.

The packaged photograph preflight currently rejects a prepared-geometry revision mismatch. Restoring the two original runtime files virtually for the checker produces the identical failure; neither changed path is in its photograph source manifest. Generated build metadata/provenance and concurrent changes were left intact. Export readiness therefore remains unresolved separately from the passing runtime checks.

Initial evidence is retained: early actual-App fixtures encountered modal gating and were corrected to state their isolated scope; an early capture-count assertion incorrectly assumed no swipe cancellation/restart; popup presses initially targeted the main viewport while a modal was open. The old `test_garage_preview_recovery.gd` passes its popup checks but fails its obsolete expectation that an explicit preloader request finishes while the Cars section is visible (17 checks/1 failure); it is not counted above. One run also records a monitored test-file change. The final focused tests replace that obsolete acceptance route without altering production capture gates. All runs retain this environment's root-certificate-store diagnostic.

Client reload and a separately authorized rebuilt tablet update, reproduction of the current device case and owner acceptance remain.
