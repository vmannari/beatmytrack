# Racing car batching and optional simpler models

2026-10-13. Owner requests the first two racing-render audit improvements, with
the simpler model selectable from game Settings. Requirements RCM01 fewer car
submissions, RCM02 reduced racing/shadow geometry, RCM03 locally saved graphics
choice; preserve V04/V05/G01/R01/Q01, actual cosmetics, camera and canonical racing.

## Behavior

Settings → Graphics → **Simpler car models** is off by default. Apply saves the
boolean `simple_car_models` locally; the next race reads it before constructing
the car. It does not rebuild or restart an active attempt. Garage/showroom cards
keep the detailed model. Graphics Reset is staged until Apply, like other settings.

The detailed compact retains every original triangle. Matching untextured parts
now share batches across compatible vertex formats. Original positioned GPU
transform frames, outlined-material formats, source pigments, paint variants,
brake materials, steering, body suspension and wheel rolling remain separate
where needed. The four smaller cars already have small batches and retain their
existing submission count rather than introducing visible edge changes.

Optional simpler cars reuse the original shapes and finishes. Compact coachwork
and glazing use offline meshes with half the original sample count per axis;
small surface fittings and primitives use reduced sampling. The bake exports
five shadow meshes per standard car: one sprung-body mesh and four independently
rolling wheel meshes. Positions-only shadow resources are excluded from ghost
geometry, paint and weathering bindings. Original bounds retain wash-volume
mapping. Fitted body/hood/aero or rim frames keep their actual geometry as casters
instead of an inaccurate stock-only shadow proxy; their costs depend on the kit.

Concurrent livery, fitted-part, loading/warmup and Windows-audio changes were
preserved. Graphics/weathering/clean restoration are tested on the simpler model.
One shader-metadata guard in `vehicle_weathering.gd` makes unrelated shaders,
including shadow-only materials, remain outside its source-paint bindings.

## Actual work reduction

Pinned Godot 4.7.2, RTX 3090. All five models were checked on Compatibility and
desktop Mobile/Vulkan. These are geometry/submission results, not phone FPS.

| Standard car | Detailed visible triangles | Simpler visible triangles | Simpler shadow triangles |
| --- | ---: | ---: | ---: |
| Compact | 104,558 | 39,594 | 2,220 |
| Pickup | 4,306 | 2,578 | 994 |
| Classic | 4,794 | 2,778 | 1,194 |
| Formula | 4,556 | 2,684 | 1,092 |
| Kart | 5,416 | 3,192 | 1,604 |

Compact mesh submissions fall **64 → 50** with detail retained. Standard simpler
cars have five shadow casters. In the isolated compact+ground fixture at
1600×900, the old/detailed-batched/simpler variants submit **130/102/57** draws
and **209,140/209,140/41,838** primitives on both renderers. The simpler compact
therefore has 62.1% fewer visible triangles, 97.9% fewer shadow triangles and
80.0% fewer total submitted primitives in this fixture.

Three alternating timing repetitions are retained. Desktop Mobile/Vulkan
median-of-stage-medians GPU time was 0.102/0.102/0.091 ms and render CPU time
0.155/0.147/0.123 ms. Compatibility was load-sensitive: one simpler stage reached
1.622 ms. No stable Compatibility speedup, combined racing FPS, startup speedup
or phone/thermal gain is claimed. First-instance construction samples have
unequal resource/pipeline cache warmth. Baked resources total about 292 KB.

## Commands and checks

All engine invocations use `powershell -NoProfile -ExecutionPolicy Bypass` and
`scripts/dev.ps1`; normal engine log/cache access was required.

- `TestScript -ScriptPath res://tests/bake_racing_car_models.gd`: completed offline bake; fifty compact resources and twenty-five shadow resources. Existing detailed assets retained.
- `TestScript -ScriptPath res://tests/test_racing_car_models.gd -Graphical`, then `-RenderingMethod mobile -RenderingDriver vulkan`: **85 checks each, zero failures**. Five-car geometry/casters/articulation, pixel proof, cosmetics, graphics/weathering/clean restoration, ghost exclusion and fitted-part safeguards.
- `TestScript -ScriptPath res://tests/test_racing_car_settings.gd -Graphical`, both renderers: **15 checks each, zero failures**. Actual three-size Settings captures, staged/apply/reload preference, detailed garage, both race construction paths, five laps, canonical state and wash bounds.
- `TestDriving`: **72 checks, zero failures**. `TestRewind`: **61**, `TestRecords`: **54**, `TestVehicleBatch`: **35**, all zero failures.
- `TestScript -ScriptPath res://tests/test_compact_model_optimization.gd`: **72 checks, zero failures**, exact five-car triangle attributes/material roles.
- `TestScript -ScriptPath res://tests/test_vehicle_weathering.gd`: **805 checks, zero failures**. `test_car_wash.gd`: **1,383**, zero failures.
- `TestScript -ScriptPath res://tests/test_script_parse.gd`: final **644 scripts, zero failures**.
- `TestScript -ScriptPath res://tests/profile_racing_car_models.gd -Graphical`, both renderers: nine completed stages each; raw timings and construction samples retained.
- `Doctor`: matching engine/templates; OnePlus DN2103 attached. No physical-device render/performance run or APK export/install was performed for this change.
- Scoped `git diff --check`: passed.

Initial aggressive merging changed a few silhouette/outline pixels. The final
implementation preserves original GPU transform frames and keeps outlined
materials in their original format groups. Final paired detailed pixels retain
the original ≤2/255 limit: Compatibility compact at most 1/255, Mobile at most
2/255; other cars exact. The fixture now compares the same car/material instance
before and after batching, avoiding independent-material ordering differences at
existing coplanar seams. Its count check requires compact reduction and no
additional submissions for already-small cars. A diagnostic snapshot type error
was fixed. Concurrent build-identity and audio-library rebuild interruptions are
retained in logs; final model runs passed after those external changes settled.

## Files and review evidence

Runtime changes: `vehicle/{visual_geometry,car_visual,racing_car_models,
compact_coachwork,compact_detail,compact_glazing,compact_rear_design,
personal_ghost,vehicle_weathering}.gd`, `core/game.gd`,
`persistence/local_records.gd`, `ui/settings_page.gd`; owned baked assets and
their provenance under `assets/vehicles/racing_simple_v1`. Four focused
test/bake/profile scripts accompany the implementation.

[Graphics Settings](evidence/racing-car-models-2026-10-13/graphics-960.png),
[detailed compact](evidence/racing-car-models-2026-10-13/compact-detailed.png),
[simpler compact](evidence/racing-car-models-2026-10-13/compact-simple.png),
[work/timing summary](evidence/racing-car-models-2026-10-13/profile-summary.json).
Complete captures/raw profiles/before sources are in
`build/racing-car-models-2026-10-13`; the task-only Git-format checkpoint and
hash manifest live beside the selected evidence. Shared Git branch/index are
preserved; unrelated livery/customisation/audio work is excluded from that patch.

Remaining acceptance: owner review of reduced silhouettes/shadows during driving,
fitted-kit cost and physical-phone frame pacing/thermal behavior. No physics,
rules/compiler contract, backend/score write, full Validate, merge or deployment.
