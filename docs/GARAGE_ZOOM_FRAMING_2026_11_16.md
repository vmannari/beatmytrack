# Garage zoom keeps the car visible (2026-11-16)

GZF01: zoom must retain the car inside the preview and beside the stats panel.
GZF02: switching cars must retain the same camera at a given zoom, tilt and size.

The preceding car-switch fix retained a high target and allowed an unrestricted
dolly toward it. At the closest zoom the car's lower body crossed the bottom of
the preview; its fixed world-space horizontal offset also changed the screen
composition while zooming. The supplied Super Rally screenshot demonstrates this
failure. The preceding checks covered only default and modest zoom settings.

`game/ui/garage_selection_camera.gd` now aims at a lower shared target, scales
the lateral offset with distance, and derives a minimum camera distance from the
visible preview area. One shared clearance cylinder covers all six stock cars at
every turntable angle (2.55 m radius, 2.85 m top, deck-height bottom). The camera
does not inspect or refit to the selected car. Its home position reserves 18%
zoom travel beyond the minimum distance; closer requests stop at the fit limit.
The actual zoom value clamps too, allowing immediate zoom-out after that limit.
The stats width, preview aspect, 16 px edge space and 48 px bottom allowance enter
the fit. The shared whole-car limit intentionally bounds close-up magnification.

`game/tests/test_garage_zoom_framing.gd` projects every visible mesh's bounding-box
corners using the real Garage camera. It checks six cars, 1280×720, 2400×1066 and
960×540 windows, four zoom requests, two low-angle rotations and the upper tilt
limit. The original camera fails **106/432** bounds/stability observations. All
original checks remain, with added stats clearance, stock-envelope containment,
visible zoom travel and wheel/pinch limit-and-return assertions. The stock survey
finds maximum radius 2.473 m and top 2.789 m. Existing selection regression stays
**44/0 headless**.

Actual runs use the pinned Godot 4.7.2 build through `scripts/dev.ps1`, disposable
APPDATA/LOCALAPPDATA under `build/garage-zoom-framing-20261116`, empty API/auth
environment settings and the following test command. Command receipts and raw
logs are retained in [evidence](evidence/garage-zoom-framing-2026-11-16/).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_zoom_framing.gd -CommandTimeoutSeconds 240
# Native variants add -Graphical -RenderingMethod gl_compatibility (or mobile).
# Use -TestArgument --evidence-root=<evidence-directory> for native captures.
# Selection regression: res://tests/test_garage_selection_feedback.gd
```

The initial corrected headless bounds run passes **432/0**. The final runtime
passes **726/0 desktop Compatibility**, including wheel behavior. Six close-zoom
views are also qualified by **762/0 desktop Mobile**, including the added pinch
limit and immediate zoom-out checks. Both native runs and the selection regression
exit cleanly. Six close-zoom
views per native renderer use the screenshot's wide window dimensions; reviewed
examples are [Super Rally](evidence/garage-zoom-framing-2026-11-16/compatibility/super_rally-zoom-in.png)
and [Forklift](evidence/garage-zoom-framing-2026-11-16/compatibility/forklift-zoom-in.png).

The source-only reversible checkpoint records the exact preceding camera source,
the added regression and this report. Its patch and byte-exact round-trip receipt
are in the evidence directory. The main index and unrelated working edits remain
outside it; development-wrapper generated build identities are excluded. Standard
build retention applies to the disposable profiles and private checkpoint.

Reload and owner appearance review remain. No physical-device test was performed.
These stock-car bounds do not qualify every fitted kit or future vehicle. No
owner-save/process, vehicle geometry, handling, backend, export or deployment
action was performed.
