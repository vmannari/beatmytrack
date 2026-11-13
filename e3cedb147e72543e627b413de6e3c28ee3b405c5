# Electric nose light bar — 2026-10-25

The owner requests one long, narrow nose light, with recent Tesla styling as the reference. ELB01 replaces the separate front projectors and short guides with a single uninterrupted pale-white diffuser in a slim recessed housing. Its rounded tips follow the curved fascia. The small original badge sits below the light, leaving the centre uninterrupted. Daytime and night lenses share the same surface; night mode creates one lens and retains the existing single bounded road light.

The reference was checked against the [official Model Y lighting manual](https://www.tesla.com/ownersmanual/modely/en_pr/GUID-1C209641-AA23-47AC-B0D1-3FE3779CF222.html). It informed the continuous-light direction only. Geometry is original native project code; no Tesla image, mesh, badge or other asset is included.

ELB02 refreshes the actual production car, catalogue illustration and all 49 native appearance photos. The v3 mesh cache contains 437 prepared resources and replaces the unused v2 cache after an exact task-start backup. Full/simple triangle counts fall to 154,276 / 55,700. Compact materials, rolling wheels, rear lighting, graphics, physical scale and camera remain.

R01 retains strict one-pedal driving, aggressive complete-stop regeneration, rear-wheel drive and D/R in the saved brake position. The handling resource, simulation, driver, touch controls and Game files are byte-identical to the completed refinement. This visual change requires no physics/config version or online contract change.

## Native validation

The pinned Godot 4.7.2 tests run through `scripts/dev.ps1`. Both native model runs pass **34 checks**. At the close frontal review pose, the light spans 580.636 pixels and is 6.651 pixels thick. All 49 projected samples remain illuminated across its width in both daylight and night mode, on Compatibility and desktop Vulkan Mobile. Finite geometry/normals, batching, Compact finishes and independent calipers also pass. The initial test pose framed the bar below the 500-pixel review threshold; moving the diagnostic camera closer passes the unchanged threshold. No production camera changed, and the initial two failures remain in the evidence logs.

Commands from the repository root, after `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Arguments | Result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/bake_electric_model.gd` | 437 prepared meshes. |
| `-Action TestScript -ScriptPath res://tests/test_electric_model.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence-root=res://../docs/evidence/electric-lightbar-2026-10-25/model` | 34 checks; native day/night continuity and fitted-light captures. |
| Same model test with `-RenderingMethod mobile -RenderingDriver vulkan` and `mobile-model` output | 34 checks on desktop Mobile. |
| `-Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --bake-art` | New catalogue artwork. |
| `-Action TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --vehicle=electric` | 49 final photos. |
| `-Action Import` | Final asset imports. |
| `-Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence-root=res://../docs/evidence/electric-lightbar-2026-10-25/native` | Actual Garage selection, saved cosmetics, D/R touch/mouse, complete stops and restart; final count in report. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | 1,142 scripts, zero failures. |

G01/Q01 evidence: [before/after gallery](evidence/electric-lightbar-2026-10-25/gallery.html), [native front view](evidence/electric-lightbar-2026-10-25/model/electric-front.png) and [report with source hashes](evidence/electric-lightbar-2026-10-25/report.json). The scoped binary-capable checkpoint is a delta against the task-start shared workspace. Concurrent sign-in, localization, Garage, tutorial and backend work is preserved.

Native Mobile means the desktop rendering path, not a physical-device test. Owner visual/device acceptance and a client reload remain; no attachment check, device test, APK, live mutation, purchase, deployment or owner-process restart occurred. Earlier refinement metrics and captures remain historical evidence; their projector/cache descriptions are superseded by this light-bar update.
