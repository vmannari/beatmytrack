# Kart sleeves with defined elbows — 2026-11-12

KAR01/KAR02 address the owner's screenshot and feedback that the arms look rubbery. The preceding full-length curved sleeves are superseded by straighter upper-arm and forearm sections meeting at a short rounded elbow. The shoulder, upper arm, elbow, forearm and wrist now have separate fitted proportions. Oval sections, a narrower wrist/cuff, a small outer elbow volume and local inner compression folds make the silhouette read as a clothed bent arm.

Compare the actual engine views: [before side](evidence/kart-driver-arm-structure-2026-11-12/before-side-right.png), [after side](evidence/kart-driver-arm-structure-2026-11-12/after-side-right.png), [after close-up](evidence/kart-driver-arm-structure-2026-11-12/after-body.png). These are matched native views with the same camera and default paint.

The native driver remains **12,048 triangles / six materials / six steering poses**. The production steering code, grip targets, wheel location and 36-degree wheel rotation are unchanged. The new geometry test independently reads the saved mesh and each authored steering pose. It verifies distinct straight shafts, elbow bend, taper and exact decoded attributes on the supported body and other surfaces. It passes **55/0**; the previous rubbery model fails **28 of the same 55 checks**. Maximum measured shaft bow falls from **19.293 mm to 0.078 mm** across the tested poses. The visible bend between the two shafts is approximately **45.7–62.8 degrees**.

All non-sleeve material surfaces and their six targets, plus the static torso/leg/boot/seam attributes, remain exact. Both hands still follow the rotating wheel. The physical backrest/shell matrix passes **286/0**, pedal/pan/grip checks pass **27/0**, and moving clearance against every hood and side-pod style passes **270/0**. The direct steering/finish suite passes **130/0** in each desktop renderer.

The authoring change is confined to `game/tests/bake_kart_driver_polish.gd`: piecewise straight paths, a short elbow transition, an anatomical radius profile, oval sections, local folds and restrained cuff/seam colouring. It also accepts an evidence destination while retaining the original immutable source fixture. `test_kart_arm_structure.gd`, the matched review helper and a private pinned runner supply the new evidence. Attribution notes record the original sleeve adaptation. No runtime steering, canonical physics, car configuration, player paint or saved appearance is changed.

Representative commands:

```powershell
python scripts/run_kart_arm_structure.py before-review res://tests/review_kart_arm_structure.gd --rendering-method gl_compatibility -- --simple --before
python scripts/run_kart_arm_structure.py arm-native-bake res://tests/bake_kart_driver_polish.gd --headless
python scripts/run_kart_arm_structure.py structure res://tests/test_kart_arm_structure.gd --headless
python scripts/run_kart_arm_structure.py rejected-curve-structure res://tests/test_kart_arm_structure.gd --headless -- --before
python scripts/run_kart_arm_structure.py after-review res://tests/review_kart_arm_structure.gd --rendering-method gl_compatibility -- --simple
python scripts/run_kart_arm_structure.py moving-clearance res://tests/test_kart_steering_clearance.gd --headless
python scripts/rebuild_kart_arm_structure.py
```

The first bake used the preceding task's default numerical receipt destination; the matching new receipt is copied into this task's evidence. Subsequent bakes can explicitly use `--evidence-root=res://../docs/evidence/kart-driver-arm-structure-2026-11-12`. Original source snapshots, native before views, the rejected-model check and new command/exit receipts remain. The driver size, helmet design and supported body from the prior task are retained, without claiming owner acceptance of the corrected arm appearance.

Reload/relaunch and owner visual review remain. No device query/test, APK, owner-save/process change, backend request, deployment or main-index write is performed. Device performance is unmeasured; geometry, material and pose counts are unchanged.

## Final cached and App verification

The refreshed prepared steering suite passes **131/0 each desktop renderer** with an actual prepared-base hit. Actual App Garage/race checks pass **25/0 each**, including wheel/arm updates through the normal Game presentation and matching direct/Garage visible geometry at **33,656 triangles**. All four kart bases, its fitted modules, Garage and all 49 kart livery photographs plus catalogue/news/header pictures are refreshed. The shared rebuild completes under a stable source fence; the final preflight passes **551 resources / 2,267 checks / zero failures**, and the picture audit passes **six native pictures / 157 source hashes**. All **24 unrelated picture controls are byte exact**; fresh unrelated rerenders are retained separately.

The [nine-file source checkpoint](evidence/kart-driver-arm-structure-2026-11-12/source-only.patch) passes byte-exact forward/reverse application in an owned miniature repository, strict reverse checking in the live workspace and whitespace checking. Its [receipt](evidence/kart-driver-arm-structure-2026-11-12/source-checkpoint-receipt.json) verifies the unchanged main index, production steering source and all eight task-start car configurations. Generated binary hashes and final results are recorded in `final-summary.json` in the same evidence directory.
