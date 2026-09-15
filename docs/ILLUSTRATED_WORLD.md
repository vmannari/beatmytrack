# Illustrated gameplay world ? 2026-09-15

## Scope and requirements
V02/V04/V05, with V01 camera and G01 handling preserved. Owner requests gameplay closer to the illustrated menu. This first presentation slice adds cream/blue two-tone bodywork, pillars, window trim, hood seams, wipers, door handles, grille slats, round lamps and wheel spokes to the original fictional compact. Shared materials reduce grass contrast and directional asphalt grain; Pine uses cooler asphalt and restrained green. Race lighting uses softer warm sunlight and blue ambient fill. Visual kit is track-kit-15. No canonical physics, track cells, car scale or camera edits.

## Changed files
- `game/vehicle/car_visual.gd`: original code-authored vehicle detail; no external asset.
- `game/core/game.gd`: race light colours/energy.
- `game/track/track_theme.gd`, `surface_detail.gdshaderinc`, `native_track_visual.gd`: palette, texture treatment, visual version.
- This document, status/plan entries, and `docs/evidence/illustrated-world/`.

## Actual validation
Commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with pinned Godot 4.7.2:
- `CheckScript -ScriptPath res://vehicle/car_visual.gd`: passed.
- `TestDriving`: final 70 checks, zero failures. Exit reports four ObjectDB instances leaked; this has not been investigated or treated as a clean resource-lifetime result.
- `TestPieces`: 158 checks, zero failures; golden native cells preserved, five laps, zero contacts.
- `CaptureStyle -StyleDocument <APPDATA>/Circuit01Lab/tracks/track_5765ff853b63dea5.json`: final start plus twelve route captures succeeded, all audited road normals upward and native cells preserved. Existing owner file read only.
- `git diff --check`: passed.

Reviewed actual desktop Compatibility start capture: [before](evidence/illustrated-world/before.png), [after](evidence/illustrated-world/after.png). Additional [corner capture](evidence/illustrated-world/corner.png). Logs retained alongside images.

An initial normals diagnosis was incorrect: Godot clockwise front-face winding was already correct. A trial reversal produced black outline fill and was reverted after graphical review. A new spoke-orientation warning was corrected with a non-collinear up vector; final capture has no such warning.

## Remaining acceptance
This is an incremental native-3D style pass, not a claim of illustration-level model fidelity. Car silhouette refinement, matching all prop detail to the illustration, continuous-motion aliasing, theme-wide visual review and owner acceptance remain open. Added small meshes increase draw calls; phone GPU/thermal cost is unmeasured. No physical-phone test or APK export performed; device attachment was not enumerated. No generated or third-party asset was added; existing grass bitmap provenance remains in PAINTED_GRASS_PROMPT.md.
