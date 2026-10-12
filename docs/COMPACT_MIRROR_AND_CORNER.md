# Compact mirror proportions and nose corner - 2026-10-10

Requirements: CG06 (thinner,50% taller mirrors), CG07 (marked hood/fender corner rounded), CG01-CG05/G01/V06/R01/Q01. The owner supplies close-up references and requests these two specific corrections.

Both mirror housings change from0.110m to0.165m tall, exactly50% taller, and from0.128m to0.064m deep,50% thinner. Their0.206m width and mounting positions stay fixed. Glass inserts gain the same50% height and follow the thinner rear face. The capsule mounts are retained. Cosmetic Compact rollover support increases to1.150m to cover the taller housing; canonical handling/collision/camera/records are untouched.

The marked upper-front blue cap was a flat extrusion with square end/top faces. It is replaced by six closed rounded-nose surface patches with35mm edge radii, curvature-following front depth and extra sampling near the fillets. They use the actual body paint. The lamps, grille and hood remain the existing components.

The offline bake now contains52resources/687896bytes:48coachwork/mirror/bumper/nose surfaces and4glazing/seal surfaces. Exactly14existing mirror resources change; all32other previous assets retain their SHA-256 hashes. Six new rounded-nose resources are added. Source provenance and hashes are updated in the existing manifest/PROVENANCE.md and licenses/ASSETS.md. No external media or service was used.

Changed files: `game/vehicle/compact_coachwork.gd`, `compact_detail.gd`, `car_visual.gd`; the14mirror and6new nose native resources, manifest/provenance; expected source-resource count in `game/tests/test_garage_studio.gd`; new isolated native inspection `game/tests/capture_compact_mirror_corner.gd`; this documentation, prior correction follow-up, status/plan/license entry. [Task-only text/binary checkpoint](evidence/compact-mirrors-2026-10-10/scoped-change.patch) excludes unrelated workspace changes.

Actual commands use pinned Godot4.7.2 stable ed1daf0bf through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with normal engine log/certificate access. The native inspection disables API requests and uses isolated record/library/cloud paths.

| Actual command | Actual outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/bake_compact_coachwork.gd` | Final52native meshes,687896bytes, exit0 |
| `-Action TestScript -ScriptPath res://tests/test_garage_studio.gd -Graphical` |77checks, zero failures, exact source/bake arrays for all52resources, materials/liveries/isolated glass/wheels/batching/captures retained |
| `-Action TestSuspension` |59checks, zero failures; cosmetic roll/suspension/ramp behavior retained |
| `-Action TestScript -ScriptPath res://tests/capture_compact_mirror_corner.gd -Graphical` | Actual mesh AABB `(0.206,0.165,0.064)`m; height ratio1.499999653/depth ratio0.500000082 (float precision); three native actual-app closeups saved |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` |468scripts, zero failures |
| Native manifest hash comparison |14existing mirror files changed;32earlier nonmirror files exact |
| `adb devices -l` | OnePlus Pad2 OPD2403/f0ba474a attached; no phone attached |
| Scoped whitespace/reverse checkpoint checks | Pass |

Inspected [mirror side](evidence/compact-mirrors-2026-10-10/mirror-side-1280.png), [mirror top](evidence/compact-mirrors-2026-10-10/mirror-top-1280.png), and [rounded front corner](evidence/compact-mirrors-2026-10-10/front-corner-1280.png). These feature-inspection captures use the real car and app, with a local inspection-camera target/FOV; shipping camera controls are unchanged. No user-provided screenshot pixels are shipping assets.

Final studio model:97436triangles/47batched meshes. Desktop studio build observed213.922ms; RTX3090 Compatibility SubViewport CPUmedian0.640ms/GPUmedian0.183ms. These are individual desktop observations, not phone performance or a whole-app speed claim. No physical-device test, Android export/install, full Validate, backend deployment or production action was performed for this task. Remaining acceptance: owner close-up shape review and device pacing. Restart/rebuild the client to use the revised baked resources.
