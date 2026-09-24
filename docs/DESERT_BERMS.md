# Reference-directed sand berms

2026-09-24, V02/V04/V05/Q01, kit 61. Owner supplied a desert board specifying low natural sand berms instead of striped kerbs, compacted shoulders and soft straight edges. This supersedes the previous stone-coloured kerb presentation.

Creator desert bends now use a three-band shoulder mesh with uneven sand crowns (approximately 6-26 cm above its base), actual facet normals and shaded slopes. The separate kerb render mesh is omitted for these tracks. Straights retain flat shoulders with a wider smooth blend into dunes. Legacy grid tracks retain their existing footprint but use irregular sand crowns and unstriped grain shading. Canonical kerb contacts remain unchanged; these banks are visual geometry, not new obstacle physics.

Road gravel contrast is reduced from the previous coarse stipple, with three filtered baked samples along the local road axis for subtle directional wear. It does not create permanent tyre tracks; live vehicle trails remain. Shoulders use warmer packed earth rather than grey gravel. Existing rocks and scrub remain; the reference's optional additional boulders/markers are not added as new collisions.

Changes: `game/track/native_track_visual.gd`, `creator_road.gdshader`, `surface_detail.gdshaderinc`, `kerb.gdshader`, status/plan and evidence. No new bitmap assets. Curved shoulder sections have 18 rather than 6 vertices per section, still in the existing shoulder batch; their separate kerb draw is removed. Road-axis wear adds three texture samples. These costs require phone measurement, not a claim of free performance.

[Inspected gameplay capture](evidence/desert-berms/sand-berms.png). Reference composition and dense detailed scenery are not claimed as reproduced exactly.

Actual pinned Godot 4.7.2 commands via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `-Action CaptureDesert -Track track_3e26605a8a90165e`: 50 checks, zero failures after final geometry/normal change, including five-car deterministic behavior and dust.
- `-Action TestSurfaces`: 50 checks, zero failures during material pass.

Remaining acceptance: owner appearance review, road readability through a full lap, physical-device frame pacing/thermal cost, and alignment of cosmetic bank shape with retained kerb contact behavior. Full physics regressions were not rerun because canonical physics did not change.

Final `-Action ExportAndroid -QuickValidation` passed import/startup, 74 driving, 18 catalog and 22 menu checks and exported successfully. SDK `adb install -r build/android/circuit01-debug.apk` succeeded on the attached phone. No device rendering/performance test was performed. Existing build-tools 35.0.1 fallback and two ObjectDB shutdown leaks in driving tests remain.
