# Electric whole-front rounding — 2026-10-25

The owner rejects the preceding hood-only result as too similar to the old car and supplies a frontal Lucid photograph. **This task changes the complete front silhouette**, using the attachment as its primary reference: a bowed nose, convex bumper, large rolled shoulders, swept corners, curved continuous light, tall side curtains and a wide tapered lower intake. The vehicle remains an original fictional design.

| Requirement | Implementation and evidence |
| --- | --- |
| ERF01: round the whole front | Elliptical transverse sections replace the flat center and small corner radii. The bumper now bows across the full face and tucks inward toward its lower edge. At Y=0.60 m, actual mesh rays measure 64 mm of bow at X=0.45 m and 206 mm at X=0.75 m; the previous model measured 0 and about 3 mm respectively. Center-to-lower-edge tuck increases from 116 to 164 mm. Both detail levels pass the same strict bounds. |
| ERF02: integrate the hood and wings | The front-wing join moves from Z=-2.13 to -1.94 model metres, allowing the entire corner to sweep back. The shoulder roll grows from 55 to 125 mm at the leading end and fades to the retained profile before the front doors. The lowered center edge, fitted hood and curved light pocket follow the new surface. |
| ERF03: reshape the lower fascia | A wide swept intake with tapered ends, inset back, real returns and two recessed slats replaces the narrow rectangular opening. Tall inset curtains and a thin curved lower lip follow the rounded bumper. |
| V01: inspect the actual shape | Matching head-on, three-quarter and overhead captures cover full/simple models before and after. The new shape test deliberately fails six bounds on the exact previous model, then passes on the new model. See the [native gallery](evidence/electric-rounded-front-2026-10-25/gallery.html). |
| R01: preserve accepted behavior | Exact task-start hashes retain `electric_car_model.gd`, `car_visual.gd`, `vehicle_simulation.gd`, `electric.tres`, `test_electric_model.gd` and `test_electric_hood.gd`. No production camera, input or canonical physics source is edited. All existing model and hood assertions remain. |
| G01 / Q01: native assets and reviewable delivery | Catalogue art, 49 appearance photos and the electric news image are refreshed and imported. Commands, outcomes, hashes, original sources/assets and a task-only binary Git checkpoint accompany the [report](evidence/electric-rounded-front-2026-10-25/report.json). |

The runtime change is confined to `game/vehicle/electric_coachwork.gd`. `test_electric_surface_finish.gd` replaces the old hard-coded front plane with the authored new join plane; every existing assertion and tolerance remains. It checks every actual end/side boundary vertex: 134/134 full and 136/136 simple matches, maximum normal difference 0.00296°. Rear recess and closed-door depth measurements remain exact. Existing hood checks retain their strict gap, seam, symmetry and nose-join bounds.

Prepared v6 contains **537 meshes**: **362 exact original resources**, 155 changed shared parts and 20 new parts; 16 former parts retire. The unchanged originals are restored only after serialized-byte comparison proves that the rebake changed nothing except random local ArrayMesh IDs. Full/simple geometry is **169,109 / 66,166 triangles**, inside the unchanged 170,000 limit. Old v5 resources are verified against their exact backup before retiring from the game export. These counts do not establish physical-device performance.

Actual validation uses pinned Godot 4.7.2 through `scripts/dev.ps1`; [run_validation.ps1](evidence/electric-rounded-front-2026-10-25/run_validation.ps1) records every final command and exit code.

| Check | Outcome |
| --- | --- |
| New actual-shape test and reference-angle captures | 14 Compatibility / 14 desktop Mobile checks, zero failures. The old model produces 14 checks / 6 expected failures with the same bounds. |
| Retained model, finite normals, budget and continuous day/night light | 34 Compatibility / 34 desktop Mobile checks, zero failures; all 49 light samples remain visible. |
| Retained actual hood, reveal, symmetry and nose join | 34 Compatibility / 34 desktop Mobile checks, zero failures. |
| Retained body joins, door gaps and rear recesses | 34 checks, zero failures. |
| Native catalogue, appearance and news renders | One catalogue image, 49 appearance photos and one fitted news image. |
| Actual App Garage/race, Compatibility / desktop Mobile | 60 / 60 checks, zero failures. |
| Electric driving / strict one pedal | 60 / 63 checks, zero failures; retained 72 km/h release stop is 0.767 seconds / 7.563 metres. |
| Import / complete parser | Import passes; 1,183 scripts, zero parser failures. |

Initial checks retain two corrected failures. The first new full model exceeded the budget by 259 triangles; reducing redundant sampling across the narrow hood surround brings the final full model below both the limit and the preceding full model. The first front/side check found mismatched new row endpoints; using the existing shared vertical stations closes every boundary without weakening the test. The initial renders and logs remain. The previous model's six shape failures are expected regression evidence, not a claimed passing baseline.

The supplied photograph is a design reference only; no reference bitmap or Lucid branding is added to the game. Desktop Mobile uses PC Vulkan. Manual-stepping race tests can emit hitch diagnostics and are not frame-pacing measurements. Reloading the client and owner/device appearance, motion and rendering-cost acceptance remain. No device attachment check or device test, APK, purchase, live mutation, deployment or owner-process restart was performed. Concurrent work is preserved.
