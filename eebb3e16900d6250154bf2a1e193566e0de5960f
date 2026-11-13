# Electric car model and strict one-pedal correction — 2026-10-25

The owner rejected the previous electric model and requested a substantial visual improvement, one accelerator, no handbrake, immediate aggressive regeneration and a complete stop. The follow-up places D/R where the brake pedal was. These instructions supersede the electric car's earlier explicit brake/reverse and handbrake behavior in `ELECTRIC_CAR_2026_10_25.md`.

| Requirement | Delivered behavior | Evidence |
| --- | --- | --- |
| ER01 | Reworked sportback surfaces, curved fitted glazing, three side panes with a dark B pillar, lower sculpted nose, real recessed projector pockets and air curtains, daytime light guides, formed split spokes and independent calipers. Compact automotive finishes and tyre/glass systems remain. | Matched Compact/electric front, rear, side, roof, optics and wheel views in both renderers. |
| ER02 | One accelerator operates Drive and Reverse. D/R replaces the former brake-pedal location, follows saved placement/opacity and handedness, and switches only below the stopped threshold of 0.15 m/s. Brake and handbrake actions have no driving effect. | Actual App touch/mouse checks, all three steering methods and both handedness settings. |
| ER03 | Full lift immediately requests 11 m/s² regeneration, reaches exact zero and holds without creep in either direction. Pedal travel below the 24% neutral point modulates regeneration. | First-tick, reverse, full-stop and 600-tick idle checks; measured flat-road stop below. |
| R01 | Physics `arcade-planar-0.68` and tune `electric-2` pin the new semantics; exact replay/rewind and every other car's task-start state remain. | 60 focused checks, six-car tick comparisons, 143 all-car checks, 61 rewind checks and real standalone verifier staging. |
| G01/Q01 | Native production geometry and actual Garage/race controls are reviewable; prior failures and shared work are retained. | [Gallery](evidence/electric-refinement-2026-10-25/gallery.html), [report](evidence/electric-refinement-2026-10-25/report.json), scoped checkpoint and command logs. |

## Driving result

From 72 km/h on the clean flat-road fixture, full release now stops in **1.8 seconds / 17.842 metres**. The first 120 Hz tick measures **11.219 m/s²**, including ordinary resistance. The prior electric-1 tune took 4.617 seconds / 45.820 metres. The intermediate 7.6 m/s² revision took 2.592 seconds / 25.699 metres; the owner's stronger-braking instruction replaced it with the final 11 m/s² setting.

Regeneration remains inside the existing rear-axle, cornering and surface traction budgets. A direction command opposing current momentum first dissipates it; the ordinary UI additionally rejects a moving direction change. Reverse uses the same accelerator and its existing 7 m/s cap. Restart immediately restores D and an available stopped selector; pause/focus clearing releases the accelerator while retaining the selected direction.

The existing third quantized replay channel carries D/R for this car only (`0 = D`, `255 = R`); it is not a friction-brake input. The fourth channel has zero canonical effect. No replay array or state schema was widened. Client/verifier/ticket versions must match for online use. Tire marks and particles receive a separate presentation input without the direction channel, preventing false locked-wheel effects in R. Motor and surface load use the accelerator in both directions.

## Model and assets

The v2 cache contains 470 authored mesh resources, 3,029,560 bytes, with exact coachwork/model source hashes in its manifest. Production full/simple models contain 160,628 / 57,288 triangles. Those counts describe the implementation and do not certify visual quality or phone performance. Shared boundaries close the earlier roof/glazing gaps; lamps now sit in formed pockets rather than over a solid face. Steering uprights retain calipers while rims and tyres roll independently. Paint, saved graphics, weathering, collision scale and the driving camera retain their existing contracts.

All 49 livery photos and the catalogue illustration were rebuilt from the actual final car and imported. The 321 obsolete v1 cache files and 16 unused intermediate v2 meshes were removed after checking paths and preserving the prior bytes in the isolated checkpoint base. Earlier model captures and the original task checkpoint remain available.

## Validation

Use the pinned Godot 4.7.2 console through `scripts/dev.ps1`, from the repository root. GPU tests ran on Windows / RTX 3090; “Mobile” below means the desktop Vulkan Mobile renderer.

| Command suffix after `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` | Result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_electric_one_pedal.gd` | 63 checks, including immediate 11 m/s² lift, complete forward/reverse stops, no creep, ignored raw brake/handbrake, all touch layouts, predictive-driver mapping and reverse surface sound. |
| `-Action TestScript -ScriptPath res://tests/test_electric_car.gd` | 60 checks; quantized replay and rewind exact; all six other cars retain every task-start tick across 2,400 inputs each. |
| `-Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence-root=res://../docs/evidence/electric-refinement-2026-10-25/native` | Final native UI result in the report; actual touch and mouse selector, accelerator, complete stops, moving lock, restart, all methods/handedness and 960/1280 layouts. |
| Same UI command with `-RenderingMethod mobile -RenderingDriver vulkan` and `mobile-native` output | Same checks through the desktop Mobile renderer. |
| `-Action TestScript -ScriptPath res://tests/test_electric_model.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence-root=res://../docs/evidence/electric-refinement-2026-10-25/model` | 28 checks; finite curved geometry/normals, source/cache match, batching, bounds, fitted lights and caliper articulation. |
| Same model command with `-RenderingMethod mobile -RenderingDriver vulkan` and `mobile-model` output | 28 checks. |
| `-Action TestCars -CommandTimeoutSeconds 600` | 143 checks; seven cars × three circuits × five laps, all without contacts. |
| `-Action TestHandling` / `-Action TestRewind` / `-Action TestApp` / `-Action TestControlLayout` | 88 / 61 / 141 / 407 checks. |
| `-Action TestScript -ScriptPath res://tests/test_handbrake.gd -TestArgument --car=electric` | 3 checks under the superseding no-handbrake contract; ordinary-car handbrake assertions remain. |
| `-Action TestScript -ScriptPath res://tests/test_surface_audio_response.gd` | 36 checks. |
| `-Action Validate -QuickValidation` | Import/startup, driving72, catalogue21 and menu41 pass; this is not the full regression command. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | Final parser total in report. |
| `-Action TestScript -ScriptPath res://tests/bake_electric_model.gd` | 470 prepared resources. |
| `-Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --bake-art` | Catalogue illustration saved. |
| `-Action TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --vehicle=electric` then `-Action Import` | 49 final photos saved/imported. |

From `backend/`, the isolated local command was:

```powershell
..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k "not postgres and not retained_over_and_under_rejection" --tb=short --basetemp ../build/electric-refinement-pytest-final
```

It passes **72 tests**, with two explicit deselections: the unavailable local PostgreSQL parametrization and the previously recorded archived physics-050 ghost-capture defect. The real verifier's electric config hash is `ae59641c3b5acf909296ac4f6719505e9bed1d0731d8a95213831e963e261e6e`. The fixture keeps its historical rules-v22 key; only current physics/electric fields change. No database, account or live service was updated.

## Corrections and limits

Initial runs retained in evidence include a stale equivalence-fixture path, isolated script-class shutdown leaks, a missing third argument in the no-handbrake test, a surface-test filename typo and shared localization class-cache errors. The fixture path was corrected to the actual task-start source; an explicit NativeTrack preload resolves the script dependency cleanup; the other command/fixture errors were corrected without weakening acceptance. The first backend run retained two stale expected-manifest failures and an unavailable PostgreSQL setup error; the final scoped command above passes. Initial practice actions overflowed the viewport; native inspection identified it and the final selector placement removes that extra top action. The first attempted asset checkpoint extraction matched no paths, and a manifest-byte guard prevented cleanup until a correct isolated backup existed.

Native integration runs report first-use desktop hitches, including manual test stepping and concurrent validation work. They are not a phone frame-time benchmark. No physical device or attachment check, APK, deployment, purchase, live mutation or owner-process restart occurred. Client reload, owner model/driving acceptance and device performance remain. The native images support review of the requested quality improvement; this task does not claim owner-approved AAA quality.

The checkpoint is a scoped delta against this task's shared-workspace baseline, not Git HEAD. It excludes concurrent localization, tutorial, Garage, Forklift and backend work. Source hashes and exact included paths are recorded in `report.json`; the generated patch is checked by Git against the isolated before tree.
