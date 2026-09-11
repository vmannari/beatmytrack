# Visual acceptance / v2.0

The style and camera direction are selected; a production Godot implementation is not yet accepted. Reference images do not constitute phone testing.

| ID | Gate | Required evidence | Rejection condition |
|---|---|---|---|
| V01 | P0 | Side-by-side engine shot and `gameplay_camera_115.png` at matched viewport; measured projected car bounds; world/car proportions unchanged | Chase view, horizon, full-track camera or car-only scaling |
| V02 | P0-V | One authored car and corner using stepped shading, selective contours, restrained palette and matching prop scale | Glossy photorealism, toy proportions, cubic placeholders or inconsistent linework |
| V03 | P0 | Full lap video showing every travel direction and steering/brake simultaneous input | Look-ahead lost on reverse heading; camera rotates with the car; hidden turn apex |
| V04 | P0-V | Same scene at 16:9 and wider landscape device ratios with safe-area overlay | Stretched scene, obscured pedals, smaller car merely to fit whole track |
| V05 | P0-V | 20-minute device capture on an agreed mid-range phone with frame-time trace and thermal state | Claimed 60 fps based on desktop screenshot or average fps only |
| V06 | P1/P2 | Play→Race→Results→Retry and Garage→Upgrade→Tune→Test flows; screenshot/state matrix | New premium currencies, loss of histogram/neighbourhood or paid performance progression |
| V07 | P3 | Same track geometry in editor and Test drive; occlusion test under large decorations | Editor preview differs from collisions; imported user scripts/resources |
| V08 | P6 | Asset provenance list and fictional/cleared vehicle identities | Reference-board logos/models shipped as licensed production assets without rights review |

Suggested acceptance targets, not measured facts: 1.15x baseline projected car size within ±0.03x in the calibrated shot; 60 fps on the nominated target device with p95 render-frame time within 16.7 ms after warm-up, assessed together with worst stutters and thermal trend; optional low-tier 30 fps mode without changing simulation. Reject temporal contour shimmer even when a still frame looks good. Quality mode may reduce prop detail or shadow reach, but not change grip, track collisions, timing or the camera contract.

Before expanding the asset count, the owner approves one car, one corner, a full-lap video, the race HUD and a garage view on a physical phone. The test result must name the actual device, build, renderer and conditions. No such device test was performed while producing this package.
