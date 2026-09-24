# Directional desert road and restored curve banks

2026-09-24, V02/V04/V05/Q01, visual kit 63. Owner preferred the kit-61 curve bank and rejected the broad flat transition of kit 62. Restore that curve-bank cross section and roughness; straight shoulders remain flat and are darker compacted earth. Shoulder base width is now 1.75 m plus existing bounded irregular variation.

The road now has explicit distance-along/signed-distance-across UVs projected onto each piece centreline. Two anisotropically sampled existing baked fields create elongated fine wear that follows bends. Isotropic road speckle is reduced. Desert road triangles are subdivided toward 2 m maximum edges (depth capped at 12) to avoid interpolating UVs across large curved polygons. This increases mesh vertices and construction work, but keeps existing material batches and adds no texture assets. Canonical collision/road cells are unchanged. Piece-coordinate seams and large intersections still need motion review; no seamlessness or zero performance cost is claimed.

Changed `game/track/native_track_visual.gd`, `surface_detail.gdshaderinc`, `creator_road.gdshader`, status/plan and evidence. No lighting, camera, dust or physics change. The latest owner instruction supersedes the previous attempt to remove the curve-bank pattern.

[Inspected final gameplay capture](evidence/desert-directional/directional-road.png).

Actual command through pinned Godot 4.7.2 entry `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureDesert -Track track_3e26605a8a90165e`: 50 checks, zero failures after final UV subdivision. Includes five-car deterministic behavior, packed/loose traction, dust and surface invariants. An earlier UV trial visibly warped across large triangles and was corrected before this capture.

Remaining: owner visual approval, moving-camera seam/aliasing review, device frame pacing and track-load cost. Reference scenery density is not part of this correction.

`-Action TestSurfaces`: 50 checks pass. Final `-Action ExportAndroid -QuickValidation`: successful import/startup, 74 driving, 18 catalog and 22 menu checks; APK exported. SDK `adb install -r build/android/circuit01-debug.apk`: Success on attached phone. No device rendering/performance test performed. Existing build-tools 35.0.1 fallback and driving-test shutdown leaks remain.
