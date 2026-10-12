# Carousel favorite alignment — 2026-10-10

Requirements: R01/Q01/V06 and owner request to center the carousel favorite glyph and make it approximately 15% smaller.

Changed `game/ui/track_tile.gd`: explicit centered icon alignment, scalable icon with 24 px maximum width (previous texture 28 px, 14.3% reduction). Existing 48×48 target and favorite behavior retained. Added isolated visual capture `game/tests/capture_carousel_favorite.gd`; outline, filled and focused states inspected in `docs/evidence/carousel-favorite-2026-10-10.png`.

Actual commands (pinned engine through entry point):
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_carousel_favorite.gd -Graphical`: exit 0, image save OK; final intended logical resolution inspected.
- Same entry point with `-Action TestScript -ScriptPath res://tests/test_menu_quality.gd`: 23 checks, 3 failures concerning cached Race/Garage/Create menu promotion. No baseline reproduction was performed, so these are unresolved broader failures.
- Same entry point with `-Action CaptureMenus`: 1846 checks, 21 failures in broader navigation/layout/filter fixture expectations; not accepted as passing.

Initial direct script invocation was blocked by PowerShell policy; process-only Bypass corrected invocation. Initial sandbox Godot log writes were denied; approved reruns used isolated fixture data. No physics/backend/deployment changes. No phone attachment check, device test, export or installation performed. Remaining acceptance: owner visual review and installed-device check after rebuilding. Reviewable scope is the three-line tile diff, capture fixture and this evidence/documentation; unrelated workspace changes retained.
