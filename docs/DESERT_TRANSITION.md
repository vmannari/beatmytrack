# Desert road-edge transition correction

2026-09-24, V02/V04/V05/Q01, kit 62. Owner rejected the ribbed bank and asked for the original reference's graded transition at the road edge.

Desert shoulders now span 1.8-2.4 m within a 2.6 m ground skirt. A four-band cross section separates the flatter worn contact zone from the deposited sand ridge and outer loose grit. Crown variation changes over broader patches instead of oscillating every few vertices; curve crowns peak around 17 cm above the strip base, while straight crowns stay around 5 cm. The road-side blend is 0.56 m rather than 0.20 m. Baked clod breakup and outer blending keep the transition distinct without the repeated vertical ribs visible in the rejected screenshot.

Changed files: `game/track/native_track_visual.gd` (width, cross section, height variation and kit), `game/track/creator_road.gdshader` (contact/ridge/loose-grit material and wider road blend), status/plan and evidence. No new assets, draw batches or canonical physics changes. Shoulder strips use 24 vertices per segment, previously 18 on bends and 6 on straights; fragment cost adds two baked samples on desert shoulders. This is a measured-acceptance item, not a claim of unchanged frame time.

[Inspected final gameplay screenshot](evidence/desert-transition/road-transition.png). Original reference is visual guidance, not a shipping raster. Dense reference vegetation/boulders are outside this road-edge correction.

Actual commands via pinned Godot 4.7.2 entry `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `-Action CaptureDesert -Track track_3e26605a8a90165e`: 50 checks, no failures, after final blend adjustment; five-car deterministic behavior, dust and surface invariants included.
- `-Action TestSurfaces`: 50 checks, no failures.

Evidence logs are saved with the screenshot. Owner visual review, moving-camera aliasing and physical-device performance remain outstanding. Driving/contact geometry, camera, daylight and dust behavior are unchanged.

Final `-Action ExportAndroid -QuickValidation`: successful import/startup, 74 driving, 18 catalog and 22 menu checks; APK exported. SDK `adb install -r build/android/circuit01-debug.apk`: Success on attached phone. No device rendering/performance test performed. Existing build-tools 35.0.1 fallback and two driving-test ObjectDB shutdown leaks remain.
