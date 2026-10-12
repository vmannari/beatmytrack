# Garage manual angle and zoom - 2026-10-10

Requirements: GL05 (manual horizontal/vertical angle), GL06 (zoom in/out and reset), GL01-GL04/G01/V06/R01/Q01. The owner requests more manual control over the actual Garage car view.

Dragging the car horizontally turns the camera through a full 360-degree orbit; dragging vertically changes elevation from 5 to 80 degrees. Perspective remains 38 degrees with the previous approximately 17.7-degree view as default. The camera now follows a spherical orbit around the same model target. At default elevation and zoom, the previous camera position is preserved exactly.

Two fingers spread/close to zoom in/out. Mouse wheel and trackpad magnification provide desktop zoom. Three compact toolbar actions provide Zoom out, Zoom in and Reset view, with minimum 48x48 logical touch targets and existing menu styling/icons. Zoom changes camera distance between 0.48 and 1.80 times normal; the model's scale never changes. Close zoom intentionally allows detail inspection/cropping. Reset restores azimuth, elevation and normal zoom. Changing cars rebuilds its normal showroom framing; view adjustments remain through livery edits and cached menu navigation but are not saved as new preferences.

Pinching cannot rotate the view. Lifting one finger suppresses the first remaining-finger drag before resuming rotation, preventing a transition jump. Canceled touches and hiding the preview clear gesture state; emulated mouse movement cannot duplicate touch rotation. The menu's existing showroom ownership and press-mode toolbar buttons keep these gestures from navigating between primary pages. Navigation swipes remain available outside the preview and toolbar.

Changed files: `game/ui/car_showroom.gd` (spherical orbit, two-axis drag, bounded distance zoom and touch lifecycle), `game/ui/garage_page.gd` (three-action toolbar), new `game/tests/test_garage_view_controls.gd`, `docs/GARAGE_LIVERY.md`, this document, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md. No gameplay camera, physical model, canonical simulation, livery persistence, PB/ticket contracts or backend changes. Existing unrelated workspace changes are preserved. [Scoped Git checkpoint](evidence/garage-view-controls-2026-10-10/scoped-change.patch).

Actual commands used pinned Godot `4.7.2.stable.official.ed1daf0bf` through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with normal Windows access for engine logs/certificates. Both Garage fixtures use isolated local storage and an empty API URL.

| Actual command | Actual outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_garage_view_controls.gd -Graphical` | Final **59 checks, zero failures**: real viewport two-axis touch/mouse drag, wheel in/out, trackpad factor, both pinch fingers, zoom without orbit, pinch release/cancel/late input, emulation suppression, actual mouse and touch toolbar actions, changed-view reset, hidden gesture cleanup, bounds/default restore for all five cars, six captures and button bounds at 960x540/1280x720 |
| `-Action TestScript -ScriptPath res://tests/test_garage_livery.gd -Graphical` | **115 checks, zero failures** with the new toolbar/gesture implementation; real car materials, saved/reopened independent colors, livery controls, original orbit compatibility, picker/reset/write failure, driving color application and unchanged PB key |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | **440 scripts, zero failures** |
| `adb devices -l` | OnePlus Pad 2 OPD2403/f0ba474a attached; **no phone attached** |
| Scoped `git diff --check` / reverse checkpoint check | Exit 0 |

Initial button checks did not dispatch wheel release events, leaving synthetic viewport mouse focus held by the preview. The fixture now sends complete wheel and mouse press/drag/release sequences before testing the toolbar. The runtime implementation was not changed to accommodate the incomplete fixture. The final checks also verify Reset view from a changed angle/zoom and gesture cleanup on hiding the view. No invariant/assertion was removed.

Inspected actual captures: [default 960](evidence/garage-view-controls-2026-10-10/default-960.png), [higher close view 1280](evidence/garage-view-controls-2026-10-10/high-close-1280.png), and [low wide view 960](evidence/garage-view-controls-2026-10-10/low-wide-960.png). All six fixture PNGs are under the same evidence directory; the vehicle and colors are actual local game assets.

No physical-device test, Android export/install, full Validate, backend deployment or production action was performed. The prior broad menu regression failures documented in GARAGE_LIVERY.md were not rerun or claimed fixed. Remaining acceptance: owner sensitivity/view-range review, physical pinch/desktop trackpad behavior and device frame pacing. Reload/rebuild the client to use this local change.
