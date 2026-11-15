# Garage selection follows the supplied reference

15 November 2026. GSR01 replaces the text badge with the reference's solid yellow circle and dark check. GSR02 applies the restrained inactive-card treatment while retaining the current five-card row. GSR03 preserves browsing, confirmation, accessibility and shared-picture behavior.

The equipped car now has an antialiased 24px yellow circle with a stronger dark check, inset 8px at the upper right. Native vector drawing keeps the symbol crisp without a new raster asset, font glyph or imported resource. The earlier Selected pill is removed. The reference's captions beneath its comparison cards are explanatory and are not added to the Garage.

The existing yellow border and title continue to follow the browsed car immediately. The check identifies the confirmed/equipped car. Inactive cards have a neutral slate frame, off-white titles and quieter pictures. This is local CanvasItem tinting: the carousel still shares the exact underlying texture with the profile, and the profile picture and live showroom retain their own appearance. The actual car button keeps all input; the decorative check passes input through. Its localized accessible name still announces Selected, including after a live language change.

Only `game/ui/garage_page.gd` changes at runtime. The current five-card layout, short row, live 3D area, production cars, saved paint, headers and picture caches retain their existing ownership. The three status documents receive a scoped summary. A temporary actual-App capture utility is archived in the evidence directory and removed from `game/tests/` after use.

Native views: [selected Rally card](evidence/garage-selected-reference-2026-11-15/gl_compatibility-review/compact-1280-card.png), [full Garage](evidence/garage-selected-reference-2026-11-15/gl_compatibility-review/compact-1280.png), [selected Kart](evidence/garage-selected-reference-2026-11-15/gl_compatibility-review/kart-1280-card.png), [compact Garage](evidence/garage-selected-reference-2026-11-15/gl_compatibility-review/kart-960.png), [equipped Kart while browsing Volt](evidence/garage-selected-reference-2026-11-15/gl_compatibility-review/kart-equipped-browsing-volt.png), [desktop Mobile](evidence/garage-selected-reference-2026-11-15/mobile-review/compact-1280.png), and [task-start pill](evidence/garage-selected-reference-2026-11-15/gl_compatibility-before/stock-1280.png).

Actual checks use the pinned Godot 4.7.2 with disposable APPDATA/LOCALAPPDATA and empty backend configuration. The runner verifies the engine version before every direct invocation. Full command arrays, logs, receipts and observations are in `docs/evidence/garage-selected-reference-2026-11-15/`.

| Check | Actual result |
| --- | --- |
| Task-start Compatibility App/picture/layout controls | 96 checks, 0 failures |
| Final Compatibility five-card App, shared pictures, saved/custom appearance and Kart controls | 122 checks, 0 failures |
| Selection feedback, headless | 20 checks, 0 failures |
| Final native Compatibility selection feedback | 23 checks, 0 failures |
| Production parser | 580 scripts, 0 failures |
| Actual-App visual review, each desktop renderer | Six cars, four viewport sizes, twelve languages, 22 recorded states per renderer; no layout/equipped-state findings |
| Initial desktop Mobile App | 115 checks, 7 failures; late readiness, missing custom capture and null-texture fixture error |
| Desktop Mobile repeat | Readiness guard fails again; only that owned disposable test process is stopped before further fixture steps |

The visual review confirms exactly one equipped icon on the correct car, a strict 8px inset, no badge text, a 24×24 circle, localized accessible status and clearance from the car title. Screenshots were inspected. Existing App controls retain five complete cards at 1280×720, four at 960×540, row heights 115/96px and live 3D areas 423/269px. Shared stock/custom texture identity, one custom capture, disk reuse, saved state and input controls pass. No test assertion was removed or weakened.

Initial desktop Mobile startup is extremely delayed: the visual review eventually reaches Garage readiness after 156.6s and completes all 22 review states, while the App fixture reports readiness after 219.4s. That fixture continues past its 45s readiness guard, reports seven failures across readiness/live suit/custom capture/saved state, and calls `get_image()` on an absent custom texture. A sequential repeat fails the readiness guard again and is stopped at 103.6s, targeting only the two recorded processes of that disposable test. These runs do not establish a cause. The native visual review passes, while App startup remains unqualified; all failed assertions, the fixture error and the owned-stop receipt are retained. Physical-device testing was not performed. Owner visual acceptance and desktop Mobile/phone qualification remain.

Commands use `python docs/evidence/garage-selected-reference-2026-11-15/run.py NAME SCRIPT --direct`, with these final scripts:

```text
gl_compatibility-final       res://tests/test_garage_five_kart_picture.gd
gl_compatibility-selection-final res://tests/test_garage_selection_feedback.gd
headless-selection          res://tests/test_garage_selection_feedback.gd
headless-parse              res://tests/check_model_refinement_parse.gd
gl_compatibility-review     res://tests/capture_garage_selected_reference_review.gd
mobile-final                res://tests/test_garage_five_kart_picture.gd
mobile-review               res://tests/capture_garage_selected_reference_review.gd
mobile-repeat               res://tests/test_garage_five_kart_picture.gd
```

To repeat the visual capture, temporarily copy the archived `capture_review.gd` to the recorded `game/tests/` path and remove it afterward. The task-only source patch applies and reverses byte-exactly in a private disposable Git repository. Concurrent Rally-marker/status/model/cache edits are preserved; current surrounding status text is present on both sides of the patch. No shared-index staging, reset or commit is performed. Standard build retention is applied and its receipt is retained; recent/protected output may exceed the 20 GiB target. No task pin is added.

Reload the game for appearance review. No physical-device query/test, export, backend request, deployment, owner-save modification or owner-process restart was performed. This task makes no FPS, loading-time or device-quality claim.
