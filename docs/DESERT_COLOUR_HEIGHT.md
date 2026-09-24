# Desert road colour, inward blend and taller inner berms

2026-09-24, V02/V04/V05/Q01, kit 66. Owner requested road colour closer to its environment, a longer road-side transition and higher sand berms on inner curves.

Road pigment changes from #96866d to warmer/darker #8e795a. Directional texture and UVs are retained. Desert edge strips start 0.91 m farther inward: blend width grows from 0.56 m to 1.47 m, with the outer endpoint unchanged. Inner-curve clod crown heights increase by 65%; straight deposits retain their previous height. Clod count, footprints, triangle count, shader texture samples, camera, lighting and canonical contacts are unchanged. The wider blend increases overdraw area slightly; no device performance equivalence is claimed.

Changed `game/track/track_theme.gd`, `native_track_visual.gd`, status/plan and evidence. [Inspected bend/straight capture](evidence/desert-colour-height/route-35.png); other route captures are alongside it. Prior apron milestone screenshots are preserved.

Actual pinned Godot 4.7.2 commands via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `-Action CaptureDesert -Track track_3e26605a8a90165e`: 53 checks pass, 809 clods, including exact five-car behavior, dust and route captures.
- `-Action TestSurfaces`: 50 checks pass.
- `-Action ExportAndroid -QuickValidation`: import/startup plus 74 driving, 18 catalog and 22 menu checks pass; APK exported.

Existing build-tools 35.0.1 fallback and driving-test ObjectDB shutdown warnings remain. Owner visual acceptance and phone motion/performance review of this revision remain; previous kit-65 measurements are not repeated or relabelled as this build's results.
`adb install -r build/android/circuit01-debug.apk`: Success on attached DN2103. No device rendering/performance test performed for this revision.
