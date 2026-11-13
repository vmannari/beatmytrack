# Electric whole-car design pass - 2026-10-26

The owner authorizes DR01-DR07 from the [whole-model review](ELECTRIC_DESIGN_REVIEW_2026_10_26.md). Lucid Air remains the main form reference; Taycan canopy/shoulder and IONIQ 6 rear continuity inform the refinement. The fictional Volt retains the game's established illustrated style.

[Open the before/after comparison](evidence/electric-design-pass-2026-10-26/before-after.html). The slider offers matched full/simple views in Compatibility and desktop Mobile. Actual App captures are separate. [report.json](evidence/electric-design-pass-2026-10-26/report.json) records commands, source/asset hashes and outcomes. The scoped binary Git patch and its isolated apply/byte checks are recorded in `checkpoint.json` in the same directory.

## Requirements and implementation

| ID | Review finding | Result |
|---|---|---|
| EDP01 / DR01 | Angular cabin, separate roof | Crowned roof, curved screens, rolled side canopy and rear roof taper share endpoint positions and tangent planes. |
| EDP02 / DR02 | Heavy hood surround, raised outer trough | Broader inward-tapering lid; restrained 15 mm transverse nose crown replaces 100 mm outer rise. Continuous front-quarter correction and shared denser hood stations preserve original no-S-bend bounds. |
| EDP03 / DR03 | Flat glass/reflections | Fitted side-window openings, rounded borders, stable glass normal frame, dark frit and separate mirror finish. EV paint roughness 0.34/metallic 0.16 retain shared clearcoat. |
| EDP04 / DR04 | Stacked rear parts | Formed deck follows quarters and tail; restrained crown/lip, shallow bumper waist, rounded plate recess and layered slim optics share one rear envelope. |
| EDP05 / DR05 | Soft wheels/poor geometry allocation | Taut split spokes, shallow dish, narrow machined rim, fitted barrel, rotor bell and slots. Wheel centres, tyre diameter, steering and fixed calipers remain. |
| EDP06 / DR06 | Generic panels/sill/mirrors | Rounded recessed door/charge cuts, fitted sill, flatter mirror shells/bezel/glass, and twelve projector modules within the continuous front signature. |
| EDP07 / DR07 | Slivers/unfinished joins | Shared deck/quarter positions and normals, matched opening stations, stable float32 edge poles, fitted undertrays and triangle-seated door reveals. |
| R01 | Preserve driving/unrelated work | Only three EV runtime sources change. Simulation/configuration, collision, inputs, camera, economy and saves are outside this implementation. Concurrent edits remain excluded. |
| G01 / Q01 | Current prepared/runtime assets and evidence | Versioned v11 geometry, five shadows, electric Garage template, 53 native pictures, focused tests, source-matched views and a scoped checkpoint. |

## Construction and renderer details

The canopy uses a common crowned roof and analytic endpoint derivatives. Side panes occupy fitted openings instead of an intact painted sheet. The bonnet remains an independent panel with recessed returns and an inward-tapering plan outline. Forty longitudinal stations in both detail levels preserve the original actual-mesh curvature limits.

The deck and quarter share boundary stations and the same transported edge normal. An intended rolled-edge coordinate is stabilized within one micrometre of its pole: float32 serialization previously amplified a small Y difference into a roughly 56 micrometre lateral gap. Prepared door ribbons follow actual paint triangles through [Godot's physicsless TriangleMesh intersection API](https://docs.godotengine.org/en/stable/classes/class_trianglemesh.html). Offline query coordinates are temporarily multiplied by 100 to avoid tiny-triangle intersection epsilon misses. Scene, collision and simulation scale stay unchanged; runtime prepared loading builds no query structures.

Glazing remains opaque with bounded analytic studio reflections. The EV shader handles [Godot's output colour spaces](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html): Compatibility reports OUTPUT_IS_SRGB, while Mobile uses linear output. Fixed 5x5 windshield samples reduce the largest inter-renderer channel difference from 49 to 8 levels out of 255. The Compatibility front-quarter image is byte-exact across this correction. This local comparison does not claim whole-image equivalence; shared scene/body lighting remains renderer-dependent.

## Actual verification

| Check | Outcome |
|---|---|
| Form/construction | 54 checks, 0 failures |
| Exact task-start regression | Original 44 checks/21 expected failures; expanded 52/29; both retained |
| Clean bonnet / smooth nose / fairing / hood / surface / roundness | 34 / 22 / 28 / 28 / 34 / 8, all passing |
| Native model/lighting | 34 Compatibility, 34 final desktop Mobile, all passing |
| Native whole-car quality | 60 Compatibility, 60 final desktop Mobile, all passing |
| Actual App Garage/race | 70 Compatibility, 70 desktop Mobile, all passing, including canonical geometry comparison |
| Electric racing representations | 23 headless, 25 Compatibility, all passing |
| Broader all-car representations | 102 checks, 2 retained forklift failures |
| Existing electric simulation / one-pedal | 60 / 63, all passing against concurrent current configuration |
| Prepared/art | 864 v11 meshes, five electric shadows, electric Garage template, 49 livery pictures plus menu/news/header/starting-Garage pictures |
| Parser/import | Final pinned outcomes in report.json |

Maximum roof/screen and roof/side normal differences are 0.138 and 0.198 degrees. Deck/quarter positions agree within 0.24 micrometres, with identical boundary normals. Full/simple visible geometry is **158,270 / 70,716 triangles**, previously 169,821 / 69,761: full detail falls 6.80%, simple rises 1.37%. Both retain the 170,000 ceiling. Full wheel assemblies including brakes fall from 65,280 to 32,256 triangles. The simple car has five shadow casters/6,178 shadow-only triangles; older helpers report 76,894 when counting those proxies. Geometry counts are not physical-device frame-time measurements.

Native inspection caught a bonnet rise/dip, noisy glass and deck-edge gaps after early checks passed. Those drafts and failed regressions are retained. Original no-S-bend limits were corrected through geometry/sampling without relaxing thresholds. Other retained failures include initial GDScript fixture typing/names, tiny-triangle queries, a headless quality-capture timeout, a read started before its bake finished, and the art helper's initial wrong ProfilePreview readiness property. Final commands use completed, source-matched assets.

Four fixtures change for authorized design/existing behavior: exact EV material values replace shared-Compact equality; one lower-door probe moves from Z=0.27 to 0.30 beyond a new rounded corner while retaining depth bounds; racing tests await readiness and exercise regeneration while moving plus its existing idle state; actual-App tests await complete progressive preparation and compare current Garage/canonical mesh arrays. The intermediate App geometry assertion inspected a temporary warm-up facade and failed. Its corrected run waits for full preparation. The first App attempt stopped before captures and remains excluded.

The readiness hypothesis alone did not fix redundant EV shadows: fixed brake assemblies sit outside rolling frames. Their simple-model casters are now disabled while calipers steer independently. The broader suite still fails forklift caster/frame assertions that were present in the initial run; forklift sources/resources remain outside scope.

## Scope, checkpoint and remaining acceptance

Runtime source scope is `electric_coachwork.gd`, `electric_car_model.gd` and `electric_glass.gdshader`. All 623 historical v10 files remain byte-exact. Eight obsolete intermediate v11 resources are archived in the evidence. Derived changes are electric-only shadow proxies/manifest entry, Garage scene and native photos. The Garage baker now awaits model readiness before serializing. Header/starting-Garage art uses the existing native studio recipes, with only electric provenance declarations changed.

Task-start snapshots, current source hashes and concurrent diffs are recorded. Concurrent `car_visual.gd` cache work, physics 0.74 and electric-17 configuration changes are retained and excluded from the task patch; this implementation did not edit those sources. Camera, shared finish/tyre and studio sources remain exact. The checkpoint is checked/applied in an isolated temporary directory; the shared Git index is not staged, committed or reset.

Reload/rebuild is needed for an already-running game/editor. Owner appearance/motion acceptance and physical-device cost acceptance remain. No physical-device attachment check/test, APK, authentication/purchase, owner-save/live database mutation, deployment, merge or owner-process restart was performed. This is a concrete model revision; AAA certification is not claimed.

## Reference provenance

Official [Lucid Air](https://lucidmotors.com/air), [Taycan exterior design](https://newsroom.porsche.com/en_US/products/taycan/exterior-design-18551.html) and [IONIQ 6](https://www.hyundai.com/worldwide/en/newsroom/detail/hyundai-motor-unveils-the-new-ioniq-6-and-ioniq-6-n-line-under-%E2%80%98pure-flow%2C-refined%E2%80%99-concept-0000000928) images from the preceding review remain outside game assets. No manufacturer image/logo/badge or downloaded vehicle model is added to the game.
