# Garage parts catalogue and main-view focus — 2026-10-25

GCF01 uses the Parts Customise panel for a two-column vertical catalogue. Native option photos are now in larger 156-unit short-window / 220-unit normal cards. The separate selected-part photo and its extra viewport are removed from Parts. The list expands through the panel above the existing preview state, explicit equip and Cancel controls. Appearance patterns keep their existing carousel.

GCF02 smoothly frames the actual Garage car at the affected hood, rear aero, wheel or bodywork, using the existing camera and a 0.42-second presentation tween. Paint selection frames the body; sticker selection frames its hood or roof surface. Drag rotates the actual car around the focused region, and zoom remains relative to that region. Cancel, hiding or leaving the tools restores the preceding camera transform and orbit state. Reset view exits focus. Room views and canonical driving cameras are unchanged.

GCF03 preserves Workshop side navigation, actual paint/part option photos, the sixteen-photo bound, one temporary photo studio, free preview, explicit equip and purchase confirmation, account/reply fences, local saves and the cleanliness gate. No image assets or runtime dependencies were added.

Runtime files are `game/ui/garage_cosmetic_shelf.gd`, `garage_page.gd`, `car_showroom.gd` and the new presentation helper `garage_customisation_camera.gd`. `game/tests/test_customisation_carousel.gd` now checks the catalogue and main Garage framing in place of the superseded small-carousel/detail-viewport/unchanged-preview-camera assertions. Existing ownership, delayed replies, cancellation, save, photo-pixel/cache and input checks remain. Added checks cover projected region centres, manual drag/zoom, exact restoration, paint/roof focus, keyboard-visible last cards and release while focused. Test stage markers and all unsuccessful trials remain in the evidence.

The original dynamic sizing path produced native crash traces in the composed Garage. Fixed card minimums with native grid expansion and guarded layout avoid that path. A compact grid-area failure and a 156-unit card in a 151-unit viewport were corrected through tighter spacing and removal of the redundant divider, retaining the original full-card bound. Resize reveal now follows the focused card. The obsolete carousel-motion capture was replaced with actual camera-motion frames. A detached-camera cleanup error found during interactive verification was corrected by checking scene ownership before camera look-at operations.

Initial stable focus-only tests passed 312 headless / 354 Compatibility / 354 desktop Mobile. Independent existing cleanliness 262, retained customisation 1,396 and sidebar 472 checks pass. Final interactive drag/zoom checks pass 320 headless / 362 Compatibility / 362 desktop Mobile. Per-run exact commands/exit codes are recorded in [report.json](evidence/garage-parts-focus-2026-10-25/report.json). Desktop Mobile means the Windows Vulkan renderer, not a physical device.

Commands use pinned Godot 4.7.2 through scripts/dev.ps1, disposable workspace APPDATA and offline test records; host access is used for the Windows certificate store:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-parts-focus-2026-10-25/run.ps1 -Mode headless -Attempt '-verified'
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-parts-focus-2026-10-25/run.ps1 -Mode gl_compatibility -Attempt '-verified'
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-parts-focus-2026-10-25/run.ps1 -Mode mobile -Attempt '-verified'
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-parts-focus-2026-10-25/run.ps1 -Test test_garage_clean_customisation -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-parts-focus-2026-10-25/run.ps1 -Test test_garage_customisation_speed -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-parts-focus-2026-10-25/run.ps1 -Test test_garage_sidebar -Mode headless
scripts/dev.ps1 -Action CheckScript -ScriptPath res://ui/garage_page.gd -CommandTimeoutSeconds 30
git diff --check -- AGENTS.md game/ui/car_showroom.gd game/ui/garage_page.gd game/ui/garage_cosmetic_shelf.gd game/ui/garage_customisation_camera.gd game/tests/test_customisation_carousel.gd
git apply --stat docs/evidence/garage-parts-focus-2026-10-25/task-only.patch
```

Review [native views and camera motion](evidence/garage-parts-focus-2026-10-25/report.html). The [task-only patch](evidence/garage-parts-focus-2026-10-25/task-only.patch) is relative to exact task-start sources and excludes earlier unrelated edits; no staging or commit is implied.

Reload the client to review. Owner appearance, touch and uncached-photo/rendering-cost acceptance remain. No phone/tablet attachment check or physical-device test was performed. No owner-process restart, APK, deployment, actual purchase or live mutation.
