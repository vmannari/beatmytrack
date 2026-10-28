# Electric hood redesign — 2026-10-25

The owner's correction selects **Lucid**, replacing the initial Rivian reference. The original fictional electric sportback now has a broad, lower hood centre, softly raised front-wing shoulders and a rounded clamshell perimeter. The reference is the official [Lucid Air exterior photograph](https://lucidmotors.com/air); the photograph remains outside the game export. No Lucid logo or reference bitmap is included in the vehicle.

| Requirement | Result |
| --- | --- |
| EHD01: redesign the hood using Lucid as the reference | Lower central surface between restrained, flowing shoulders; the previous two heavy black longitudinal strips are removed. Actual prepared-mesh samples put the shoulders about 31–46 mm above the centre across three longitudinal stations. |
| EHD02: proper panel construction | A rounded lid, painted surround, both painted edge returns and a recessed dark reveal replace trim laid over an intact surface. Eight ray samples across both detail levels measure about 4.97–5.04 mm of reveal depth. Every tested lid return joins its panel within 0.001 mm. |
| V01: continuous fitted surfaces | The upper nose and hood share transverse stations, including the rounded tips. All 81 full / 41 simple boundary samples agree within 0.00025 mm after mesh serialization. Mirrored lid triangulation preserves symmetric actual surface profiles between stations. Native before/after close-ups, front and overhead views are retained for both detail levels. |
| R01: preserve the accepted car | Task-start SHA-256 checks retain `electric_car_model.gd`, `car_visual.gd`, `vehicle_simulation.gd`, `electric.tres` and the original model regression suite exactly. No production camera or input code is edited. One-pedal operation and the accepted 72 km/h release stop of 0.767 seconds / 7.563 metres pass. |
| G01: refresh native artwork | Catalogue artwork, 49 appearance photographs and the electric news photograph are rendered from the production mesh and imported. |
| Q01: reviewable checkpoint | [Report](evidence/electric-lucid-hood-2026-10-25/report.json), actual command logs, exact task-start sources/assets, matched captures and a task-only binary Git patch accompany the change. The shared index is untouched. |

`game/vehicle/electric_coachwork.gd` owns the model change. Prepared v5 assets contain **533** meshes. Of the previous 519 resources, **497 remain byte-identical** under the new directory; the two old hood resources and twenty old upper-nose cells retire into the exact baseline backup. The rebake changed only Godot's random local resource IDs in those 497 meshes; serialized-byte comparison verifies that fact before restoring their exact originals, as recorded in `resource-reuse.json`. The retained model suite passes again afterward. Thirty-six new resources implement the hood and shared nose surface. Full/simple model counts are **169,576 / 65,996 triangles**, within the original 170,000 limit. These are geometry counts, not device performance measurements. The electric model uses its ordinary shadow casters; it has no baked stock racing shadow proxy to refresh.

The new `test_electric_hood.gd` checks actual prepared geometry and captures review views. `test_electric_surface_finish.gd` gains an optional evidence destination, retaining every existing assertion. `capture_electric_hood_before.gd` reloads the exact backed-up source and meshes only inside its disposable process to produce matching baseline views.

Actual validation uses pinned Godot 4.7.2 through `scripts/dev.ps1`. [run_validation.ps1](evidence/electric-lucid-hood-2026-10-25/run_validation.ps1) records the full argument list and exit status for every final batch command.

| Check | Outcome |
| --- | --- |
| Hood geometry and close-ups, Compatibility / desktop Mobile | 34 / 34 checks; zero failures. |
| Retained model/material/light-bar suite, Compatibility / desktop Mobile | 34 / 34 checks; zero failures; all 49 light samples visible in day and night. |
| Retained body joins, door seams and rear recesses | 34 checks; zero failures; original 138/138 end/side matches per detail level retained. |
| Actual App Garage, controls and race, Compatibility / desktop Mobile | 60 / 60 checks; zero failures. |
| Electric behavior / strict one pedal | 60 / 63 checks; zero failures. |
| Native art / appearance / news bake | Catalogue image, 49 appearance photos and one fitted news photo; zero failures. |
| Import and complete GDScript parser | Import passes; 1,179 scripts parse with zero failures. |

The first diagnostic reported real between-triangle asymmetry and fixture errors in the return-vertex lookup. Mirroring the lid diagonals fixes actual symmetry; direct distance checks avoid quantization-bin errors and account for the retained intermediate return row. Initial close-ups also exposed fine nose cracks. Shared boundary stations and exact top-point reuse correct those without relaxing any assertion. The first restricted native launch could not open its ordinary user diagnostic log; native checks then ran with normal local process permissions. The initial baseline capture used an unsupported script path and then needed an explicitly typed GDScript reference for its isolated reload. Initial logs and views remain in the evidence. The historical news framing report is restored after saving the new electric-only result in this task's evidence folder.

See the [native before/after gallery](evidence/electric-lucid-hood-2026-10-25/gallery.html). Desktop Mobile is a Vulkan renderer check on the PC. Manual-stepping App tests emit race-hitch diagnostics, so they do not establish frame pacing. Client reload and owner/device appearance, motion and rendering-cost acceptance remain. No device attachment check or device test, APK, purchase, live mutation, deployment or owner-process restart was performed. Concurrent work is preserved.
