# Elastic carousel ends

2026-10-01. Requirements R01/V03/V04/G03/Q01.

`game/ui/track_carousel.gd` adds resisted overscroll beyond the first and last track. The actual scroll value stays valid; only the card grid shifts within its clipped viewport. The gap approaches a 64-logical-pixel limit with increasing resistance. Release returns it to zero with a 0.38-second spring easing. Mouse-wheel attempts beyond an end produce a smaller 24-pixel nudge. External snap cancellation resets the offset. Ordinary card snapping and incremental card reuse remain.

`game/ui/track_browser.gd` preserves the visual offset when positioning the virtual card window. `game/tests/capture_premium_menus.gd` exercises both ends through touch events, verifies the gap survives rendering, returns to its aligned boundary, and never selects a card or toggles a favorite.

Actual pinned entry-point commands: `CheckScript -ScriptPath res://ui/track_carousel.gd` passed; `TestCatalog` passed 21 checks; final `CaptureMenus` passed 1765 checks at three landscape sizes. The first capture run encountered the previously documented three intermittent standings-layout failures; final run passed without weakening assertions. Catalog median boundary cost remained 0.399 ms on desktop.

Inspected [first edge](evidence/carousel-edge-2026-10-01/carousel-edge-1-960x540.png) and [last edge](evidence/carousel-edge-2026-10-01/carousel-edge--1-960x540.png). [Final graphical log](evidence/carousel-edge-2026-10-01/checks.log). No Android export, deployment or physical-phone test was performed. Owner acceptance of spring feel remains.
