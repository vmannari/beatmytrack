# Brown grass tire tracks

Owner request, 2026-10-14: tire tracks on grass should be more brownish.

Requirements: GT01 warm brown grass-track pigment; V05 preserve the existing ribbon geometry, shading and bounded draw; G01/R01 preserve canonical driving and other surfaces; Q01 record actual verification and limitations.

`game/vehicle/skid_trails.gd` changes surface-kind 1 RGB from `(0.23, 0.285, 0.125)` to `(0.32, 0.205, 0.11)`, giving the crushed-grass rut a warm exposed-soil tint. A grass-only `source_color` uniform keeps the pigment brown on both renderers; raw instance colour initially appeared pale tan on Mobile. The existing packed surface ID selects this uniform without changing the instance layout or adding textures/draws. Base opacity remains 0.60. Pressure/opacity interpolation, groove lighting, widths, relief, four-wheel sampling, the 16,384-slot ring, visibility and first-draw preparation remain untouched. All other surface styles, including Desert and Winter, are unchanged.

`game/tests/test_soil.gd` updates the existing grass-colour assertion from green-dominant to red > green > blue, retaining its original opacity bound. This reflects the owner's superseding colour requirement. `game/tests/capture_grass_tire_marks.gd` and its UID supply matched native rolling/braking/road views using the saved task baseline, identical live-car wheel dimensions and one held car pose per pair.

Actual commands used pinned Godot 4.7.2 through `scripts/dev.ps1`, with process-local workspace APPDATA after normal user logs were denied:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/grass-tire-colour-userdata'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_soil.gd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_tire_ribbons.gd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_grass_tire_marks.gd -Graphical -RenderingMethod gl_compatibility
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_grass_tire_marks.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
git diff --check -- game/vehicle/skid_trails.gd game/tests/test_soil.gd
```

Final soil checks: 163 pass, zero failures. Final ribbon checks: 14 pass, zero failures. Final Compatibility and Mobile/Vulkan captures each save six matched native views with 396 segments per view: grass rolling, grass braking and asphalt control, before and after. Both grass profiles change visible pixels; the asphalt controls are byte-exact on each renderer. Canonical state snapshot, track cells and content hash remain exact. The final brown Compatibility rolling/braking and Mobile braking views were visually inspected. Source checkpoints confirm the runtime changes are limited to grass pigment selection/binding; scoped whitespace verification passes. Actual captures and command logs are retained in `docs/evidence/grass-tire-colour-2026-10-14/`.

Initial attempts are not passing results: normal user-log writes were denied, so APPDATA was isolated inside the workspace; Windows certificate-store access required an approved graphical rerun. An in-progress road-height refactor temporarily called removed `ROAD_HEIGHT.shoulder()` and blocked loading; that unrelated code subsequently compiled without changes from this task. Two early road-control comparisons used the baseline renderer's default wheel dimensions instead of the live car's dimensions; matching them restored exact pixels without changing the assertion. A later capture lost window focus and photographed the automatic pause overlay; the frozen fixture now clears that overlay per frame. The initial raw-tint Mobile view was pale tan and prompted the grass-only source-colour binding. A one-off Python pixel-analysis attempt lacked PIL and installed nothing; a System.Drawing diagnostic identified the mismatched road-track bounds. Initial capture source and failed runner logs are retained.

No road-height code was changed by this task. No full regression, phone test, Android export/install or deployment was performed; phone attachment was not checked. Owner review of the brown tint and physical-phone appearance remain acceptance checks. The task-only source checkpoint and saved baseline are under `docs/evidence/grass-tire-colour-2026-10-14/`; unrelated workspace edits and the Git index are retained.
