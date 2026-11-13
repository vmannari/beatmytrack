# Electric rear and whole-car quality pass — 2026-10-25

The owner rejects the basic rear and asks for a much higher overall car quality. This pass replaces the slab-tail presentation and refines the native model as a whole. [Matched before/after gallery](evidence/electric-quality-pass-2026-10-25/gallery.html), [measurements and commands](evidence/electric-quality-pass-2026-10-25/report.json), [Git checkpoint](evidence/electric-quality-pass-2026-10-25/checkpoint.patch).

| Requirement | Result and implementation |
| --- | --- |
| EQP01 | Convex tail wraps into the quarters; actual centre-to-outer bow is 0.08579/0.08652 model metres in full/simple. The small lip is formed in the painted deck rather than a separate bright accent blade. |
| EQP02 | Slim recessed smoked optics have a rounded brake guide, lower guide and end cells. Curved plate lettering/fasteners, camera, subtle parking sensors, swept valance and connected undertray channels replace the blank plate and dangling rectangular fins. |
| EQP03 | Swept mirror shells with recessed curved glass; thinner fitted screen apertures/seals; curved matte demister traces; flush handles; dished forged spokes and shallow hub/fasteners. Closed inner wheel tubs and corrected inward-facing arch-return normals eliminate cross-body views. |
| R01 | All 166 prepared front/hood resources remain exact originals. Existing hood/front/surface invariants and model budget remain. Steering/rolling calipers and one-pedal controls pass their retained tests. Independent electric-11/physics 0.72 work is preserved and excluded. |
| G01 | Native menu artwork, news photo and all 49 electric appearance photos refreshed and imported. |
| Q01 | Isolated binary Git patch checked, applied and byte-compared against its final tree; shared index untouched. |

Runtime scope: `electric_coachwork.gd`, `electric_car_model.gd`, new `electric_glass.gdshader`, and one showroom material-selection condition that recognizes the electric shader. Other cars retain the original glass shader. Opaque analytic glazing adds no scene capture, screen read, transparency pass, light or per-frame script callback. The original Barlow font supplies baked fictional BMT 007 plate lettering; no Lucid name, logo or reference photo ships.

Prepared v8 has 622 resources, including 231 byte-identical originals. The exact v7 directory is archived under evidence before retirement. Full/simple counts fall from 169734/70506 to 168138/65386, below the unchanged 170000 full-model ceiling. Removing buried screen/gasket skins and bulky handle hardware funds the new rear and inner construction.

Validation uses pinned Godot 4.7.2 through `scripts/dev.ps1`. [The executable batch](evidence/electric-quality-pass-2026-10-25/run_validation.ps1) records all 19 successful commands and raw logs. Quality 60/60 and model 34/34 pass in Compatibility/desktop Mobile. Retained smooth nose 32/32, hood 34/34, surface 34 and rounded front 8 pass. Actual Garage/race 60/60, electric 60, one-pedal 63, import and parser 1209 pass. Each renderer/detail level exposes all 49 rear lamp samples; all 24 tested inner-wheel sightlines hit their closed tubs. Shared body/end joins match at 134/134 full and 136/136 simple vertices with a maximum 0.0037-degree normal difference.

The exact task-start model is reloaded only in isolated process memory and fails 38 of the same 60 focused checks. Intermediate native views, the original failure, initial fixture mistakes, mirrored/hidden plate, demister and arch-winding diagnostics are retained. The surface fixture adds only the new optic names to its ray-selection set; every original depth/tolerance remains. No original geometry, symmetry, shading, budget or behavior assertion was weakened.

This is a substantial model quality correction, not an overall AAA certification. Reload is needed to see it in an already-running client. Owner/device appearance, motion and rendering-cost acceptance remain. Desktop Mobile is PC Vulkan, not a device test. No device attachment check/test, APK, real purchase, live mutation, deployment or owner-process restart was performed. Concurrent work is preserved; document snapshots isolate this task's edits.
