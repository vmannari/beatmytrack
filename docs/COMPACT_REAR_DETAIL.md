# Compact rear detail ? 2026-10-11

CG17 refines rear lamps; CG18 centres and styles the rear plate. Existing visual, livery, wheel and canonical boundaries remain in force.

Rounded lamp housings follow the physical tail, with embedded backs, thin metal edges/dark gaskets and separated amber indicator, red brake, deeper red reflector and warm clear reverse lenses. Live red material retains braking response. Rounded ends and surface-derived normals replace former flat diagonal panels. Height-dependent surface sampling and cached immutable tile geometry preserve per-instance materials.

The blank hatch-level plate is replaced by a centred bumper fitting at x0/y0.47 model metres. An18mm moulded pocket supports a narrow frame, warm white plate, two fixings and fictional BMT 01 native lettering using the already licensed Barlow Condensed SemiBold font. Frame front2.14m and plate front2.144m sit below bumper outer2.15m; plate height lies entirely within bumper. No external assets or supplied reference pixels are included.

Changed files: game/vehicle/car_visual.gd (remove old plate), compact_detail.gd (lamps/plate), compact_coachwork.gd (pocket); game/assets/vehicles/compact_coachwork_v3/rounded_rear_bumper.res, manifest.json and PROVENANCE.md; game/tests/test_compact_rear_detail.gd/uid; test_compact_front_join.gd (exclude intentionally revised bumper from old-v2 array equality); DEVELOPMENT_STATUS.md, docs/PHASE_0_PLAN.md, licenses/ASSETS.md and this document/evidence. New fixture independently checks emitted pocket/mounting vertices; existing tight body-joint tolerances remain. SHA-256 audit confirms49other native resources unchanged;50compressed resources total709662bytes.

Actual commands used powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 from workspace, pinned Godot4.7.2.stable.official.ed1daf0bf:

| Arguments | Final outcome |
| --- | --- |
| -Action TestScript -ScriptPath res://tests/bake_compact_coachwork.gd |50meshes709662bytes; exit0 |
| -Action TestScript -ScriptPath res://tests/test_compact_rear_detail.gd -Graphical |90checks, zero failures; mounts/pocket/lens separation/symmetry/braking and five actual Garage views |
| -Action TestScript -ScriptPath res://tests/test_compact_model_optimization.gd |62checks, zero failures; exact all-five-car triangle attributes/materials, independent colors/wheel transforms |
| -Action TestScript -ScriptPath res://tests/test_compact_surface_quality.gd -TestArgument '--phase=optimized-batched' -Graphical |238checks, zero failures; shoulders/lips/six pixel-identical control-optimized renders |
| -Action TestScript -ScriptPath res://tests/test_garage_studio.gd -Graphical |75checks, zero failures; all50source-bake arrays/UVs/paint/glass/wheels/batching |
| -Action TestScript -ScriptPath res://tests/test_compact_front_join.gd -Graphical |3032checks, zero failures; body/hood corners and original rear profiles |
| -Action TestHeadlights |81checks, zero failures |
| -Action TestScript -ScriptPath res://tests/test_script_parse.gd |498scripts, zero failures |
| -Action Import |Exit0; fixture metadata generated |
| Python byte/SHA-256 audit |Only rounded_rear_bumper.res changed;49exact |
| Android SDK adb.exe devices -l |DN2103/PRQKU4U4PREQNRWG attached |

Initial fixture parsing failed due to a nonexistent VehicleCatalog.set_selected method; corrected to existing selected property before passing runs. No assertions/fit tolerances were relaxed. Narrow-band lens sampling was reduced before final tests. Final model50batches/102320triangles/78832vertices; added rear detail increases these versus the prior body pass. Desktop warm control138.325ms/optimized69.235ms is a local sample, not phone or whole-app performance acceptance. Final Garage observation189.888ms construction; RTX3090 Compatibility SubViewport CPUmedian0.235ms/GPUmedian0.863ms during concurrent checks.

Actual [rear](evidence/compact-rear-detail-2026-10-11/garage-rear.png), [left corner](evidence/compact-rear-detail-2026-10-11/garage-rear-left.png), [right corner](evidence/compact-rear-detail-2026-10-11/garage-rear-right.png), [higher rear](evidence/compact-rear-detail-2026-10-11/garage-rear-high.png) and [close detail](evidence/compact-rear-detail-2026-10-11/garage-rear-close.png). Baseline, hash audit, build samples and optimization views are in the same evidence directory. Scoped Git-format checkpoint scoped-change.patch is whitespace/reverse-apply checked without changing unrelated work.

Remaining acceptance: owner styling review and phone rendering/frame pacing. DN2103 attached; no device test performed. No APK export/install, full Validate/game reproduction, physics change, backend or production deployment. Restart/rebuild client to load revised geometry.
