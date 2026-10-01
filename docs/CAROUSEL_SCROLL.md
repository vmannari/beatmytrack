# Track-row scroll optimisation

2026-10-01. Requirements R01/V03/V04/G03/Q01.

Crossing a card boundary previously destroyed and rebuilt all twelve active cards. Each replacement recreated buttons and theme resources, resampled its route and invalidated its drawing. `game/ui/track_browser.gd` now retains overlapping cards, removes only cards outside the active window and inserts newly exposed cards in order. Moving one boundary normally creates one card instead of twelve. Query changes and resize still invalidate the window, preserving fresh metadata, favorites and dimensions. The twelve-card memory bound and full-card snapping remain.

`game/tests/test_catalog.gd` verifies retained instances, reverse-scroll order and the bounded window across a 5,000-track catalog. A 100-boundary benchmark measures synchronous scroll/update work, excluding deferred rendering and GPU cost. On this desktop, before/after median was **2.760 / 0.404 ms**, p95 **4.762 / 0.639 ms**, maximum **5.199 / 0.780 ms**. This is roughly 85% less median boundary-update work, not a claim about Android frame rate.

Actual commands through pinned Godot:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestCatalog`: baseline 18 checks passed; updated 21 checks passed. [Updated log](evidence/carousel-scroll-2026-10-01/catalog-tests.log).
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureMenus`: 1630 checks, 3 failures. Swipe tracking, snapping, no accidental selection/favorites and carousel layout checks passed. The three failures are the existing intermittent wide-screen standings position mismatch (1296 vs 1298), also encountered before this change. No invariant was relaxed. [Full log](evidence/carousel-scroll-2026-10-01/menu-capture.log).
- Android SDK `adb devices`: one phone attached. No Android export, installation or physical-device scroll test was performed for this change.

Inspected [compact track-row screenshot](evidence/carousel-scroll-2026-10-01/track-row-960x540.png). Remaining acceptance: phone frame-time profiling and owner swipe feel, plus resolution of the separate standings-layout test failure. Physics and gesture timing are unchanged.
