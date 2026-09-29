# Spiral roadside seams (2026-09-29)

Requirements: V02/V04/V05/Q01; owner-marked Spiral screenshot.

Sand previously stopped abruptly wherever a road-edge sample became a kerb. It now continues beneath the tapered kerb and around the bend, preserving the existing irregular grass blend. Two neighbouring strips previously occupied the same plane with different UV-based colours, causing depth fighting. ShoulderMesh clips overlapping triangles to the lower interpolated edge weight, so the nearer road supplies the sand blend. Spatial bins bound comparisons; convex subtraction avoids filled hole contours. Road widths, canonical surfaces, collisions, handling and camera are unchanged.

Changed files: game/track/native_track_visual.gd (kit 86, continuous shoulders and builder integration); game/track/shoulder_mesh.gd (overlap resolution); game/tests/test_shoulders.gd; scripts/dev.ps1 (TestShoulders); status/plan and this evidence.

Actual commands (PowerShell, pinned 4.7.2 through scripts/dev.ps1):

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://track/shoulder_mesh.gd`: passed initial helper parse; subsequent graphical/test runs parsed the final helper.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestShoulders`: passed; overlapping 20-square-metre strips produce exactly 30 square metres, 10 triangles, correct nearest-road blend, no overlapping interiors.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureStyle -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_c83d54c221644807.json"`: before and final captures passed; native cells unchanged, zero bad road normals, 12 route views saved. Views 3, 8 and 10 inspected. Final shoulder mesh has 56,277 vertices versus 27,720 before; additional continuous bend coverage and clipped triangles increase geometry.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestSurfaceProfile`: 928 checks, zero failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestDesert`: 53 checks, zero failures.
- Android SDK `adb.exe devices`: empty device list. No phone attached; no Android export, installation or device test.
- `git diff --check`: passed.

[Before](evidence/spiral-shoulders/before.png) / [After](evidence/spiral-shoulders/after.png). Captures use the desktop gameplay camera and retain the test harness pause/countdown overlay. Static inspection supports the continuous shoulders; subjective driving/moving-camera and physical-phone acceptance remain. Mobile build-time/frame-time cost of extra geometry has not been measured. Existing unrelated working-tree edits were preserved.
