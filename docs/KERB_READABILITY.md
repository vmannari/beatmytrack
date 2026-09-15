# Kerb depth readability - 2026-09-15

V02/V04/V05: owner reports raised kerbs still look flat. Existing toon lighting made the crown and bevel almost equally bright. Track-kit-18 adds material-level facet contrast: an off-white/red crown, darker sloped faces and a narrow shaded foot. Existing lighting and cast shadows still apply. Native raster kerbs use a softer height-based transition to avoid accentuating their small boundary triangles.

Runtime changes are limited to `game/track/kerb.gdshader` and the visual-kit version in `game/track/native_track_visual.gd`. No mesh, footprint, 10 cm physical height, tyre response, physics/compiler identity, camera, grass, asphalt or global-light changes. No external assets or dependencies. Other ongoing car suspension/menu work was preserved.

## Actual verification
All commands used the pinned Godot 4.7.2 through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `CaptureStyle -StyleDocument <APPDATA>/Circuit01Lab/tracks/track_5765ff853b63dea5.json`, before and after: start plus twelve normal-gameplay-camera route views succeeded, flat road normals remained upward, native cells preserved. Existing owner document read only. Reviewed the bend and bridge-area captures at their actual 1494x1009 driving scale.
- `Snapshot -Track slicks_freeway_test`: actual native-track capture inspected. Initial strong facet shading over-emphasized raster triangles; final shader uses a softer height-based ramp on native source kerbs.
- `TestPieces`: 164 checks, zero failures, including normals, physical UV spacing, raised seams, unchanged cells and the five-lap zero-contact witness.
- `TestKerbs`: 31 checks, zero failures, including unchanged measured crossing response and exact snapshot replay at four batch sizes.
- `git diff --check` and staged patch check: passed.

[Before, normal camera](evidence/kerb-readability/before-corner.png) / [After, same camera](evidence/kerb-readability/after-corner.png). [Second bend](evidence/kerb-readability/after.png). [Native circuit](evidence/kerb-readability/native.png). Actual command logs are alongside the images.

## Acceptance limits
This pass makes the existing raised geometry readable through deliberate cel-shaded face values. It does not make the kerbs taller or increase the bump. Native outlines retain their source raster stair-stepping. Owner visual acceptance and continuous-motion/bright-light readability remain open. No physical-phone test or Android export performed; device attachment was not enumerated. No claim of measured phone performance.
