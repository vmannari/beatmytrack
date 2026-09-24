# Desert road grain and gravel shoulder

2026-09-24; V02/V04/V05/Q01; kit 60. Owner rejected the smooth road and requested a distinct border like the grass biome's sand strip.

The previous shoulder sampled dune artwork, hiding its existing strip geometry. Desert shoulders now use separate darker gravel shading from the existing baked surface-factor texture. The road-edge blend uses this same gravel, and the outer edge blends irregularly into dunes. The existing bounded shoulder extends behind desert kerbs as well as unkerbed edges. Its normals no longer carry full dune relief throughout the gravel. Road grain and worn patches have stronger multiscale contrast.

Changed `game/track/surface_detail.gdshaderinc`, `creator_road.gdshader` and `native_track_visual.gd`. Existing geometry batching and mipmapped assets are reused; one additional baked sample on packed road, no new textures/material draws. Additional shoulder triangles follow kerbed sections within the existing strip batch. Driving boundaries, grip, dust, daylight and camera are unchanged. No measured phone performance claim.

[Inspected gameplay screenshot](evidence/desert-shoulders/road-and-border.png).

Actual pinned-engine commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `-Action CaptureDesert -Track track_3e26605a8a90165e`: 50 checks, zero failures, including deterministic five-car behavior and dust checks.
- `-Action TestSurfaces`: 50 checks, zero failures.

Capture/test logs are saved beside the screenshot. Owner visual approval and phone motion/performance acceptance remain outstanding.

`-Action ExportAndroid -QuickValidation` passed import/startup, 74 driving, 18 catalog and 22 menu checks and exported successfully. SDK `adb install -r build/android/circuit01-debug.apk` succeeded on the attached phone. No device rendering/performance test was performed. Existing build-tools 35.0.1 fallback and two ObjectDB shutdown leaks in driving tests remain.
