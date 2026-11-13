# Garage carousel loading state (2026-10-28)

The owner reports an empty Compact card and confirms that other cars are affected. The shared carousel deliberately cleared factory photographs for saved custom appearances; it provided no visible state while the exact replacement was being rendered. A native cold-entry reproduction delivered all seven images through the normal queue, so this pass does not claim to have reproduced a permanently stuck renderer.

| Requirement | Result |
| --- | --- |
| GCD01 | Every uncached car shows the existing Garage car emblem and localized `Loading preview…` message instead of an empty picture area. The original image request still runs normally. |
| GCD02 | Only a matching published image dismisses the loading state. Appearance invalidation restores it; stale results cannot dismiss it. Exact factory, prepared and cached images still publish normally. |
| R01 | Expand the actual-App regression to resolve all seven saved liveries/conditions through the untouched queue, scrolling to the remaining cars before testing stale results and PNG recovery. |

Runtime changes are confined to `game/ui/garage_cached_thumbnail.gd`; the existing `game/tests/test_garage_entry_carousel.gd` is strengthened. Loading controls ignore mouse input and require no processing, animation, new viewport or showroom. The existing emblem and translated message are reused. Camera, materials, cache identity, capture scheduling, input/idle gates and saves are unchanged.

Actual commands, logs, metrics, source hashes and screenshots are indexed in [report.json](evidence/garage-carousel-delivery-2026-10-28/report.json). Tests use the pinned engine through `scripts/dev.ps1`, synthetic persistence under the workspace and an empty backend URL:

```text
python docs/evidence/garage-carousel-delivery-2026-10-28/run_checks.py LABEL test_garage_entry_carousel.gd MODE
python docs/evidence/garage-carousel-delivery-2026-10-28/run_checks.py check-thumbnail res://ui/garage_cached_thumbnail.gd check
```

The expanded regression passes 55 headless checks and 85 checks each in desktop Compatibility and desktop Mobile. Both native runs deliver all seven customized images without clearing or replacing the queue, then pass stale-publication, exact PNG recovery, renderer retirement, navigation and owner replacement checks. The task-start delivery probe passes 69 checks and reproduces the initial blank waiting areas. The first sandboxed attempt fails before the regression because Windows certificate-store access is denied; isolated local reruns pass. No automatic approval rejection occurred.

Native views:

- [Task-start blank waiting cards](evidence/garage-carousel-delivery-2026-10-28/baseline-native/gl_compatibility-saved-cars-settled.png).
- [Loading state alongside a completed Compact](evidence/garage-carousel-delivery-2026-10-28/fixed-mobile/mobile-saved-cars-settled.png).
- [First four saved appearances delivered](evidence/garage-carousel-delivery-2026-10-28/fixed-compatibility/gl_compatibility-delivery-0.png).
- [Remaining saved appearances delivered](evidence/garage-carousel-delivery-2026-10-28/fixed-mobile/mobile-delivery-10000.png).

This is a presentation correction for the wait, with broader delivery coverage. It does not make cold customized pictures instantaneous or change sequential native rendering. The matched native run records initial visible image arrivals around 2.1–3.0 seconds after entry dispatch; later cars are measured after scrolling. Those observations are not device timing guarantees. Reload the game to apply the change. Owner acceptance of this loading presentation and physical-device appearance/input/latency remain.

`task.patch` contains only this pass's runtime and regression changes relative to the exact task-start files, with an isolated Git forward/reverse check. Concurrent initial-livery/backend/account/localization edits are preserved. Task-start build metadata is archived. A concurrent wrapper advances the generated identity/version during this pass, so the newer metadata is preserved instead of restoring over it. The initial isolated patch check fails because the generated patch uses CRLF against an LF fixture; serializing the patch as LF passes the forward/reverse checks without changing runtime code or assertions. No device attachment query or physical-device test, APK/AAB, authentication/purchase, owner-save/live backend mutation, deployment, owner-process restart, main-index staging, commit or merge is performed.
