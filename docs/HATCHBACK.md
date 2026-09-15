# Menu hatchback and scenery restoration ? 2026-09-15

## Requirements and changes
V02/V04/V05, preserving V01/G01. Owner rejects the previous grass/road changes and asks for the menu's three-door hatchback instead of the sedan silhouette.

- Restored `game/track/surface_detail.gdshaderinc`, `game/track/track_theme.gd` and `game/core/game.gd` byte-for-byte from `30286b5^`. This restores original grass detail, asphalt grain, palette and race lighting.
- `game/vehicle/car_visual.gd`: replaced symmetric cabin with an asymmetric three-door hatch. Roof/cabin extend to the tail, eliminating the trunk deck. Added long door windows, rear quarter windows, dark B-pillars, sloped rear glass, rear wiper/hatch seam, cream rear-quarter graphics, flared arches and shaped lower body. Existing cream/blue, four round headlights and alloy details retained. Original code-authored fictional geometry; no new external asset.
- `game/track/native_track_visual.gd`: track-kit-16 records restoration.
- `game/tests/capture_style.gd`: three isolated model-review views after normal gameplay captures. Model-review camera exists only in the capture tool; driving camera unchanged.
- This document, status/plan entries and `docs/evidence/hatchback/`.

## Actual commands and results
Pinned Godot 4.7.2 through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:
- `CaptureStyle -StyleDocument <APPDATA>/Circuit01Lab/tracks/track_5765ff853b63dea5.json`: start, twelve route views and three model views saved successfully. Road normals all upward; native collision cells preserved. Existing owner document read only.
- `TestDriving`: final 70 checks, zero failures. Existing ObjectDB exit warning reports two leaked instances; resource cleanup has not been investigated in this visual task.
- Python byte comparison against `git show 30286b5^:<path>`: all three restored files exactly match.
- `git diff --check`: passed.

Actual desktop Compatibility captures: [gameplay](evidence/hatchback/gameplay.png), [front](evidence/hatchback/front.png), [rear](evidence/hatchback/rear.png), [side](evidence/hatchback/side.png). Front/rear model and gameplay captures inspected. Separate model views are inspection views, not racing cameras.

## Acceptance limits
The native mesh now follows the menu's hatchback body layout and livery. It remains a simplified gameplay mesh: illustrated interior, tyre tread and fine body surfacing are not reproduced. Owner visual acceptance and phone readability/performance remain open. No physics, collision dimensions, wheelbase or gameplay camera changes. No physical-phone test or APK export performed; device attachment was not enumerated.
