# Gradual desert berm ends

2026-09-24; V02/V04/V05/Q01; kit 64. Owner accepted directional road texture but requested gradual berm starts/ends, more natural sand styling and outer blending.

Berm height now uses a smooth three-metre envelope at both ends of each contiguous curved centreline run. Finding the actual curved run matters: a piece may contain both straight and curved samples, so tapering only at piece endpoints did not remove the observed step. The envelope is evaluated at shared shoulder endpoints, retaining matching adjacent vertices. Cross-section footprint and canonical contacts are unchanged. Height roughness is reduced and spaced farther apart to soften the ribbed appearance; baked sand clod highlights are warmer/lighter and facet darkening is reduced. The outer shoulder uses a wider, irregular dune blend. The approved road texture/UVs are unchanged.

Changed `game/track/native_track_visual.gd` and `creator_road.gdshader`, status/plan and evidence. No new meshes, triangle count, material draws, texture assets or fragment texture lookups relative to kit 63. Curve-run lookup adds construction-time CPU work; phone cost has not been measured.

[Inspected final gameplay capture](evidence/desert-taper/tapered-berms.png).

Actual pinned Godot 4.7.2 command through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureDesert -Track track_3e26605a8a90165e`: 50 checks, zero failures after final curve-run correction. Five-car deterministic behavior, dust and surface invariants are included.

Remaining: owner style acceptance, a moving-camera review of all bend transitions and device performance/track-load cost. The capture verifies one saved desert track; no claim of exact photographic reference reproduction or new berm physics.

`-Action TestSurfaces`: 50 checks pass. Final `-Action ExportAndroid -QuickValidation`: successful import/startup, 74 driving, 18 catalog and 22 menu checks; APK exported. SDK `adb install -r build/android/circuit01-debug.apk`: Success on attached phone. No device rendering/performance test performed. Existing build-tools 35.0.1 fallback and driving-test shutdown leaks remain.
