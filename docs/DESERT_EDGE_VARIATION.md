# Broad desert road-edge variation

2026-09-24, V02/V04/V05/Q01, kit 67. Owner requests a more uneven edge with relatively low-frequency variation.

`game/track/creator_road.gdshader` samples the existing edge field at 0.18 cycles/m for packed sand instead of 5.5. Stronger blend displacement is weighted by 4u(1-u), keeping both strip endpoints exact and avoiding hard joins. The field has approximately 5.6 m cells rather than fine serrations. Geometry, canonical road boundary, colour and berms are unchanged. `native_track_visual.gd` increments the presentation version. No new texture samples, draw calls or vertices.

[Inspected gameplay screenshot](evidence/desert-edge-variation/road-edge.png).

Pinned Godot 4.7.2 commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`: `-Action CaptureDesert -Track track_3e26605a8a90165e` passes 53 checks; `-Action ExportAndroid -QuickValidation` passes import/startup plus 74 driving, 18 catalog and 22 menu checks and exports successfully. Existing build-tools fallback and driving-test shutdown leaks remain. Logs saved beside screenshot. Owner visual acceptance and device motion/performance acceptance remain; this small material adjustment was not reprofiled.
`adb install -r build/android/circuit01-debug.apk`: Success on attached DN2103. No device rendering/performance test performed for this revision.
