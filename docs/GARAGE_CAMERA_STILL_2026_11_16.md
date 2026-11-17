# Garage camera stays still when browsing cars (2026-11-16)

GCS01: selecting a different car must preserve the Garage room view. GCS02:
player zoom and tilt remain usable, and browsing retains its existing selection,
saved appearance and cancellation behavior.

`game/ui/garage_selection_camera.gd` previously chose three camera distances and
two target heights by vehicle ID. Forklift, Volt and Hover therefore moved the
camera when replacing the car. Selection now uses one shared distance multiplier
(0.96) and target height (1.40 plus deck height), retaining the preceding Forklift
framing so its mast fits. The existing zoom, elevation and responsive panel offset
still apply. This changes only the car-selection composition.

`game/tests/test_garage_selection_feedback.gd` now checks all six cars immediately
after replacement and after the reveal, at both the default view and an adjusted
zoom/tilt/rotation. Native runs capture all six cars from the shared view. Existing
mouse/touch feedback, latest-choice cancellation, confirmation and saved-state
assertions remain in place.

Actual checks used the pinned Godot 4.7.2 build through `scripts/dev.ps1`, isolated
APPDATA/LOCALAPPDATA under `build/garage-camera-still-20261116`, and empty
`BMT_API_URL`/`BMT_DEV_AUTH_KEY`. Full invocations, durations and exits are retained
in [command receipts](evidence/garage-camera-still-2026-11-16/).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_selection_feedback.gd -CommandTimeoutSeconds 240
# Native variants add: -Graphical -RenderingMethod gl_compatibility
# or: -Graphical -RenderingMethod mobile
# Captures use: -TestArgument --evidence-root=<isolated-evidence-directory>
```

The original camera fails 12 of 44 checks, specifically Forklift/Volt/Hover in
both default and adjusted views. The corrected camera passes **44/0 headless**
and **53/0 on each desktop renderer (Compatibility and Mobile)**, including the
original selection assertions. All three final runs exit cleanly.
The initial test-authoring attempt passed an unsupported argument to
`invalidate_render`; that parse rejection is retained as `before.log`. The
corrected test requests each settling redraw explicitly; assertions were not
weakened.

Reviewed native examples: [Rally](evidence/garage-camera-still-2026-11-16/compatibility/fixed-compact.png)
and [Forklift](evidence/garage-camera-still-2026-11-16/compatibility/fixed-forklift.png).
The door, workbench and room stay aligned while the cars retain their actual
relative sizes. Six default-view captures per renderer are retained.

The exact task-start runtime/test sources are used for the private source
checkpoint; unrelated working changes and the main Git index remain outside it.
The reversible patch and byte-exact verification are recorded in
`evidence/garage-camera-still-2026-11-16/source-checkpoint.json`. Generated build
identity changes from the development wrapper are excluded. Standard build
retention applies to disposable profiles and the private checkpoint.

Reload and owner appearance review remain. No physical-device test was performed;
desktop Mobile rendering is not Android qualification. Owner saves and existing
processes were not changed. No vehicle geometry, handling, backend, export or
deployment changes belong to this fix.
