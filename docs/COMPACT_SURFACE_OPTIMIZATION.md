# Compact fender repair and model optimization - 2026-10-11

Requirements: CG15 (fix the marked front/rear shoulder distortions), CG16 (optimize without changing the corrected appearance), CG01-CG14/GL01-GL06/V06/R01/Q01. This updates the shared fictional Compact in Garage and driving.

The body grid stretched its vertical samples around the wheel cut-outs, causing up to27.901degrees of normal error and uneven interpolation through the waist. Broad arch overlays also carried a9mm raised outer edge through the shoulder highlight. Consistent upper height rows, physical Y/Z steel normals and a lower arch blend remove the apparent dents. Lower rows clip to the wheel openings; collapsed triangles are omitted. Shared lower-body profiles and an inverse height mapping preserve the nose/rear joins and physical bumper height. The original0.405m wheel-opening lips, rubber seals and wheel positions remain. Regional normal error is now below0.004degrees, guarded at0.05degrees.

The corrected model is the reference for optimization. Immutable tire/cylinder meshes are reused; eight cached rear lamp tiles replace400individual panels. Completed material batches deduplicate identical vertices. Materials remain per instance, including paint and brake response. Rear tiles retain their original attribute layout so the final car still uses48draw batches. The diagnostic optimization switch is internal to tests.

| Measured property | Corrected control | Optimized |
| --- | ---: | ---: |
| Mesh instances constructed before batching |985 |593 |
| Final mesh submissions |48 |48 |
| Final vertices |84764 |70022 |
| Final triangles |97376 |97376 |
| Warm model construction, separate desktop run |80.251ms |61.727ms |

This is39.8% fewer construction instances,17.4% fewer vertices and23.1% lower warm construction time in this run. The build values use the upper median of eight warm samples after excluding two initial iterations. They measure CarVisual construction, not whole-menu loading or phone FPS. [Actual samples](evidence/compact-surface-optimization-2026-10-11/build-profile.json) retain the numbers. An earlier concurrent-graphics run showed94.876-to61.499ms; it is not used for the final claim.

Every triangle retains its material role, winding, positions, normals, tangents, UVs and colors for all five cars. The final batched Compact is pixel-identical to its corrected control in all six native inspection views in the same scene/GPU session. The earlier98432-to97376triangle change occurs during surface repair and removal of collapsed rows; optimization itself retains97376triangles.

Changed files: game/vehicle/compact_coachwork.gd, compact_detail.gd, visual_geometry.gd, car_visual.gd;14v3native body/arch resources and manifest/provenance; existing game/tests/test_compact_front_join.gd and test_compact_front_bumper.gd; new test_compact_surface_quality.gd, test_compact_model_optimization.gd and UIDs; this document and scoped status/plan/license entries.36of50native hashes remain exact. Final native assets total709254bytes. No external mesh, texture, generated bitmap, supplied reference pixels, service or dependency is added. [Task-only binary/text checkpoint](evidence/compact-surface-optimization-2026-10-11/scoped-change.patch) preserves prior and unrelated work.

Actual commands use pinned Godot4.7.2 stable ed1daf0bf via powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1, with normal log/certificate access. Studio inspection uses production CarVisual/ShowroomStudio; actual-app fixtures disable API requests and isolate records/library/cloud paths.

| Actual command | Actual result |
| --- | --- |
| -Action TestScript -ScriptPath res://tests/bake_compact_coachwork.gd |Final50meshes/709254bytes, exit0 |
| Surface-quality script with -TestArgument '--phase=before' -Graphical |Original-model inspection and28degree error captured before edits |
| Same script with --phase=fixed / --phase=fixed-batched |Corrected control views/counts saved |
| Same script with --phase=optimized-batched |Final238checks, zero failures: normals, consistent rows, original lips, six exact pixel comparisons |
| -Action TestScript -ScriptPath res://tests/test_compact_model_optimization.gd |60checks, zero failures: exact all-five-car triangle attributes/materials, wheel transforms and per-instance paint; final warm80.251-to61.727ms |
| -Action TestScript -ScriptPath res://tests/test_compact_front_join.gd -Graphical |3033checks, zero failures: shared edges/normals/tangents, unaffected old-v2 arrays and original rear profile points |
| -Action TestScript -ScriptPath res://tests/test_compact_joints.gd -Graphical |368checks, zero failures |
| -Action TestScript -ScriptPath res://tests/test_compact_hood.gd -Graphical |3940checks, zero failures |
| -Action TestScript -ScriptPath res://tests/test_compact_front_bumper.gd -Graphical |2992checks, zero failures |
| -Action TestScript -ScriptPath res://tests/test_garage_studio.gd -Graphical |Final75checks, zero failures: all50source/bake arrays exact, paint/UV/glass isolation, wheels/batching; final48meshes/97376triangles/70022vertices |
| -Action TestScript -ScriptPath res://tests/test_garage_livery.gd -Graphical |115checks, zero failures |
| -Action TestScript -ScriptPath res://tests/test_compact_side_profile.gd -Graphical |252checks, zero failures; actual Garage views saved |
| -Action TestVehicleBatch |35checks, zero failures |
| -Action TestHeadlights / -Action TestSuspension |81 /59checks, zero failures |
| -Action TestScript -ScriptPath res://tests/test_script_parse.gd |497scripts, zero failures |
| -Action Import |Succeeds; new test metadata generated/current caches refreshed |
| Native SHA-256 comparison |14changed body/arch resources;36exact |
| Scoped whitespace/reverse-apply checks |Pass |

Intermediate findings: correcting normals alone did not remove interpolation artifacts; consistent rows and the lower arch blend were also required. Experimental box-mesh sharing changed one edge pixel by up to5/255, so it was discarded. The final pixel-equality assertion remains strict. Pillow was unavailable; native Godot Image comparison avoided adding a dependency. Seven old-v2 array-equality assertions correctly rejected newly sampled rear/arch resources. Their revised contract verifies every original rear profile point within the unchanged0.2mm tolerance, retains exact unaffected arrays and independently checks original wheel lips. No shape/color/joint/appearance tolerance was relaxed.

Evidence: [original front](evidence/compact-surface-optimization-2026-10-11/before/front-shoulder.png), [original rear](evidence/compact-surface-optimization-2026-10-11/before/rear-shoulder.png); [repaired front](evidence/compact-surface-optimization-2026-10-11/optimized-batched/front-shoulder.png), [repaired rear](evidence/compact-surface-optimization-2026-10-11/optimized-batched/rear-shoulder.png), [final side](evidence/compact-surface-optimization-2026-10-11/optimized-batched/side-left.png); actual [Garage side](evidence/compact-surface-optimization-2026-10-11/garage/side-left-1280.png) and [Garage angle](evidence/compact-surface-optimization-2026-10-11/garage/front-quarter-1280.png). Native control/optimized images and snapshots are retained under the task evidence folder.

Final Garage observation:165.349ms desktop construction; RTX3090 Compatibility SubViewport CPUmedian0.203ms/GPUmedian0.836ms during concurrent graphical checks. This is not device/whole-app/AAA performance acceptance. Final normal-access Android SDK adb.exe devices -l shows DN2103phone/PRQKU4U4PREQNRWG attached, replacing the earlier tablet connection. No device test, APK export/install, full Validate, canonical physics regression, backend or production deployment was performed. Remaining acceptance: owner shape review and phone rendering/frame pacing. Restart/rebuild the client to load the revised resources and optimized construction.
