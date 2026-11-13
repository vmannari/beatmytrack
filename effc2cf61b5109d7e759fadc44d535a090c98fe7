# Garage pictures ready before entry (2026-10-28)

Saved PNGs alone still left a visible decode/upload interval after opening the carousel. The app now prepares the current owner's exact pictures before exposing Garage, keeps those textures in a shared pool, and gives the carousel the same textures during construction. Opening it starts no picture reads or capture worlds when that pool is ready.

| Requirement | Implementation |
| --- | --- |
| GRP01 | Prepare current catalogue pictures during the existing startup screen, with a bounded 45-second wait. Bundled stock photos and validated saved PNGs publish immediately; only missing custom appearances require the original native capture. Entry remains gated if cold work outlasts that budget. |
| GRP02 | Share one bounded, owner-specific texture dictionary with Garage. Every card receives its exact image before its first draw. Retained cards adopt newly prepared textures when refreshed. |
| GRP03 | Warm committed appearance changes ahead of entry. Menu buttons, neighbor commits, swipe reveal and the Cars submenu all check readiness. Pending navigation is fenced by owner and navigation generation; choosing another destination cancels it. |
| GRP04 | Preserve foreground, race, input and memory-pressure restrictions. Retire the temporary capture world; count shared textures once within the existing residency budget. Pressure evicts the optional pool and invalidates suspended Garage shells so reentry cannot resume a freed page. |
| GRP05 | Exercise the actual App with isolated saved custom paint/wear, separate processes, changed appearance, cancellation, pressure recovery and another records owner. |

Runtime scope is five files: `game/core/app.gd`, `game/ui/garage_preloader.gd`, `game/ui/garage_preview_cache.gd`, `game/ui/garage_cached_thumbnail.gd` and `game/ui/garage_page.gd`. `game/tests/test_garage_ready_pictures.gd` is a new native integration regression. The original photograph renderer, car models, camera, materials, physics and PNG identity/validation remain authoritative. Concurrent App/editor/Rivalry and Garage workshop changes are preserved in the checkpoint baseline.

This removes pictures filling in after carousel entry; it does not remove the computation needed for a new custom appearance. That work moves to startup or preparation ahead of entry. An uncached appearance requested immediately after a change keeps the current menu visible until ready. The startup deadline does not discard an explicit navigation request: it waits with owner/navigation cancellation until the exact pictures are ready. The main interactive Garage can still have construction/shader hitches. Headless execution bypasses native picture preparation because its dummy renderer cannot produce photographs.

## Actual verification

The [machine report](evidence/garage-ready-pictures-2026-10-28/report.json) includes commands, logs, measurements and source hashes. All engine runs use pinned Godot 4.7.2 through `scripts/dev.ps1`, isolated profiles and an empty backend URL.

| Run | Actual result |
| --- | --- |
| Compatibility `gl-v4` seed / separate-process reuse | 39 / 128 checks, zero failures. Restart uses zero new captures with identical saved pixels. Startup 5211.820 / 338.111 ms. |
| Desktop Mobile `mobile-v1` seed / reuse | 39 / 126 checks, zero failures, including all first-frame and recovery assertions. Concurrent visual-source changes invalidate the pictures between processes, so this pair is not proof of unchanged-revision disk reuse. Startup 34413.742 / 34264.074 ms, six captures each. |
| Final actual menu-navigation Compatibility seed | 39 checks, zero failures; every picture ready before the first draw. Startup 4375.999 ms; Garage navigation dispatch 207.102 ms. Its follow-up process encounters a concurrently missing `hovercraft_model.gd`, before running the assertions. |
| Compatibility retry after model restoration | 126 checks, zero failures, using the actual menu-navigation route. Concurrent art changes require six captures; startup 21531.045 ms. |
| First final desktop Mobile seed | Cold custom captures exceed the unchanged 45-second startup budget; first-entry readiness assertions fail. The fixture then dereferences the absent page. This is retained as an unresolved cold-cost limit; the later fixture exits cleanly with diagnostics on this failure. |
| Final desktop Mobile menu/swipe pair `final-mobile-v2` | 68 / 155 checks, zero failures. Retained neighbor reveal/commit, changed paint, cancellation, pressure and owner isolation pass. Startup 40982.438 / 37758.920 ms. A concurrent visual revision change again requires six captures, so the pair proves first-frame readiness rather than unchanged-revision disk reuse. |
| Final Compatibility menu/swipe pair `final-gl-v2` | 68 / 157 checks, zero failures with the final cancellable wait. Unchanged visual revision reuses all six exact pictures with zero captures. Startup 4853.595 / 278.070 ms; Garage dispatch 247.286 / 544.867 ms. All final owned runtime hashes remain unchanged through the reuse process; a separate Hovercraft source edit is recorded. |
| Retained App regression | 141 checks, one failure in editor canceled-touch gesture cleanup. This is recorded separately from the passing picture assertions; no broad App pass is claimed. |
| Preferred App source check | Pass in the earlier parse run; subsequent native tests also compile the changed runtime. Final shared-workspace verification depends on the independent model files being present. |

All passing first-frame checks require a non-null exact-key texture, hidden loading placeholder, no per-card native world, zero entry picture captures and no new PNG reads. The six ready images occupy 25,165,824 bytes (24 MiB) and are counted once. The older direct-entry runs observe 244.095-1474.884 ms Garage dispatch: these include synchronous live-page construction, not missing-picture fill-in, and are not an instant-menu or device timing claim. The cold Mobile startup observation is material and remains an unresolved first-capture/shader cost.

Earlier attempts retain the initial missing fixture directory, cumulative IO assertion error and actual suspended-menu eviction defect. The latter two are corrected without relaxing the first-frame image assertions. A prior Compatibility restart legitimately recaptured after concurrent visual-source changes; the fixture now records the generated visual revision and compares saved pixels only when it is unchanged. Final tests also exercise retained-neighbor reveal and commitment through the real swipe callbacks. No production deadline is increased to make the cold run pass.

- [Final Compatibility first carousel draw](evidence/garage-ready-pictures-2026-10-28/final-gl-v2-reuse/first-draw.png).
- [Compatibility reused pictures](evidence/garage-ready-pictures-2026-10-28/gl-v4-reuse/ready-carousel.png).
- [Final desktop Mobile first carousel draw](evidence/garage-ready-pictures-2026-10-28/final-mobile-v2-reuse/first-draw.png).

```text
python docs/evidence/garage-ready-pictures-2026-10-28/run_checks.py parse res://core/app.gd check
python docs/evidence/garage-ready-pictures-2026-10-28/run_pair.py gl_compatibility gl-v4
python docs/evidence/garage-ready-pictures-2026-10-28/run_pair.py mobile mobile-v1
python docs/evidence/garage-ready-pictures-2026-10-28/run_pair.py gl_compatibility final-gl
python docs/evidence/garage-ready-pictures-2026-10-28/run_checks.py final-gl-reuse-retry test_garage_ready_pictures.gd gl_compatibility --phase=reuse --profile=THE_FINAL_GL_PROFILE
python docs/evidence/garage-ready-pictures-2026-10-28/run_pair.py mobile final-mobile-v2
python docs/evidence/garage-ready-pictures-2026-10-28/run_pair.py gl_compatibility final-gl-v2
python docs/evidence/garage-ready-pictures-2026-10-28/run_checks.py retained-app test_app.gd headless
python docs/evidence/garage-ready-pictures-2026-10-28/build_checkpoint.py
```

The source-only checkpoint excludes concurrent model/handling/prepared-asset work, App/editor/Rivalry and workshop changes, and generated build metadata. Forward/reverse Git application checks validate the scoped patch; they do not stage the main index or certify the whole workspace.

Reload/rebuild and owner appearance/latency acceptance remain. No physical-device attachment query/test, APK, real authentication/purchase, owner-save/live backend mutation, deployment, owner-process restart, main-index staging, commit or merge was performed.
