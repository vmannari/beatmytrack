# Simple dynamic window reflections - 2026-09-22

Requirements V02/V04/V05/Q01/R01: owner authorized lightweight reflections and deployment to the connected phone, explicitly excluding profiling for now.

## Implementation

The compact's shared glass material is now a ShaderMaterial using `game/vehicle/window_reflection.gdshader`. It reflects the view direction around the window normal and converts it into world space. A cheap analytic sky gradient and broad cloud shapes remain fixed in world directions, so the reflection changes as the car or camera turns. Fresnel strengthens grazing-angle reflection. Glass remains dark, opaque and depth-tested; lighting remains toon-based. There are no reflection probes, screen reads, scene captures, textures, time animation, runtime services or simulation changes. These are generic sky reflections, not reflections of nearby individual trees or barriers. Other vehicle models retain their existing materials.

`game/vehicle/compact_glazing.gd` binds the shared shader; `game/tests/capture_compact_detail.gd` adds four fixed-camera heading samples (0/30/60/90 degrees). Shader normal/view transforms follow the [official spatial-shader contract](https://docs.godotengine.org/en/latest/tutorials/shaders/shader_reference/spatial_shader.html). Reflections are view-dependent and orientation-dependent; straight translation under a static sky need not change them.

## Actual commands and outcomes

All builds/runs used pinned Godot 4.7.2.stable.official.ed1daf0bf through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`.

- `-Action CaptureCompactDetail`: ten desktop views saved; turning samples inspected. The first shader pass was too uniform, so added a broad world-fixed cloud band before final capture/export. Graphical Compatibility renderer compiles and draws the shader successfully.
- `-Action TestVehicleBatch`: 30 checks, zero failures for all five cars. Compact remains 50 batched meshes / 20,208 triangles; no added reflection geometry or mesh submissions.
- `-Action DeployAndroid -QuickValidation -DeviceSerial PRQKU4U4PREQNRWG`: import/startup succeeded; 74 driving, 18 catalog and 22 menu checks passed. Matching Android template exported and signed/verified the APK. `adb install -r` returned Success; launch returned Status: ok, COLD. Full regression suite not run by QuickValidation.
- ADB `devices -l` identified authorized DN2103. Post-install `pidof` found running app, process-filtered startup log showed APP_READY, and `screencap`/`pull` captured the visible menu. No error matched the checked startup patterns. This is launch verification, not phone validation of glass during driving.
- APK SHA256: `FEFDA55159E0D65F6962AFC49058266CB526FC308CB8D4465F9798039E9D8056`.

No profiling was performed, as requested. Human on-phone reflection appearance and driving checks are left to the owner. No frame-rate or thermal claim is made. Existing app data was retained by replacement installation; no track upload, data clearing or profiling marker was requested or added.

## Files and evidence

Changed: `game/vehicle/compact_glazing.gd`, new `game/vehicle/window_reflection.gdshader` (+ UID), `game/tests/capture_compact_detail.gd`, this report and development/phase status. [Task-only patch](evidence/window-reflections/implementation.patch) isolates reflection changes from existing workspace edits. Deployment includes the current local build, including the preceding compact model refinements.

[Heading 0](evidence/window-reflections/reflection-turn-0.png), [30](evidence/window-reflections/reflection-turn-30.png), [60](evidence/window-reflections/reflection-turn-60.png), [90](evidence/window-reflections/reflection-turn-90.png), [phone launch](evidence/window-reflections/phone-launch.png). Focused capture/batching and quick-check logs are saved in that evidence directory; export details remain under `build/android-export.log`.


## Side reflections, matching rear bumper and rim depth - 2026-09-22

Owner accepted front reflection and requested side-window reflections, matching rear bumper and deeper rims. Requirements V02/V04/V05/Q01/R01. Side panes already shared the reflection material but mostly sampled the dark lower hemisphere. The shader now has broad generic landscape tones below the horizon and stronger reflected fill for upright glass. Side glass gains a 5.5 cm centre bow with varying normals; world-fixed reflections respond to heading. These remain approximate sky/landscape reflections, not actual scenery captures.

`compact_detail.gd` reuses the front bumper sweep with mirrored rear geometry, replacing the old rear block/grey strip. Wheel centres and lugs sit deeper, spokes slope from the recessed centres to the outer lip, and a conical metallic barrel creates real rim depth. `car_visual.gd` moves the dark wheel backing inward to expose that recess. All wheel elements remain under the rolling pivots. Canonical handling/collision and camera are unchanged.

Changed files: `game/vehicle/window_reflection.gdshader`, `compact_glazing.gd`, `compact_detail.gd`, `car_visual.gd`, this report and development/phase status. [Isolated patch](evidence/compact-depth/implementation.patch), [rear/bumper/wheels](evidence/compact-depth/rear.png), [side](evidence/compact-depth/side.png); four turning samples are in the same directory.

Actual commands through pinned `scripts/dev.ps1`: `CaptureCompactDetail` saved ten views, rear and side inspected; `TestVehicleBatch` passed 30 checks (compact 52 batched meshes / 21,528 triangles). `DeployAndroid -QuickValidation -DeviceSerial PRQKU4U4PREQNRWG` passed import/startup, 74 driving, 18 catalog and 22 menu checks; export signed/verified, replacement install Success, launch Status: ok. ADB pidof confirms app running (23268). APK SHA256 `D0185A52F1C088E615364A3C484979FB7C13B2A1E3AADFD3E6A68346D7B2A381`. Evidence logs are in `docs/evidence/compact-depth/`.

No profiling performed, preserving the owner's instruction. Human phone appearance/driving checks remain with the owner; successful install/launch is not an acceptance claim. Full replay suite not rerun for these presentation-only changes.
