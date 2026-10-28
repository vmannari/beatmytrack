# Forklift side cleanup - 2026-10-25

FSP01/R01/G01/Q01 implements the owner's correction that the side panels do not fit and serve little purpose. Remove both raised rectangular access-panel assemblies: the paint plates, black backing frames, handles and four small decorative fasteners. Their tops rose above the formed side edge and their flat backs did not follow the curved skin. The existing formed bodywork now supplies the continuous side surface; no replacement decoration is added.

[Native before/after and both-side close-ups](evidence/forklift-side-cleanup-2026-10-25/report.html) · [Commands, outcomes and hashes](evidence/forklift-side-cleanup-2026-10-25/report.json)

The two solid side skins, wheel arches, entry steps/grips, top engine-access lid and functional guard/mast fittings remain. Fork height, outward fork winding, closed steering grip, connected lift chains, hollow upper exhaust and the single rear sticker are retained. The `forklift-3` resource, simulation, CarVisual, model dispatch and livery sources match their task-start hashes. Actual powered speed remains 79.9999969482422 km/h, within floating-point tolerance of 80.

The only production source edit is removal of the panel construction in `game/vehicle/forklift_model.gd`. `test_forklift_model_finish.gd` gains an evidence-directory argument and two close-up poses so it can be reused without overwriting historical evidence. No assertions or thresholds are changed and no new test mirrors the cosmetic removal. Catalogue artwork and all 49 native appearance photos are refreshed with their existing filtering configuration.

| Actual native command/check | Result |
|---|---|
| `TestScript -ScriptPath res://tests/test_forklift_model_finish.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-dir=res://../docs/evidence/forklift-side-cleanup-2026-10-25'` | 97 checks, zero failures; 15 captures including both sides and production batching |
| Same command with `-RenderingMethod mobile` | 97 checks, zero failures; desktop Mobile renderer |
| `TestScript -ScriptPath res://tests/test_forklift.gd -Graphical -RenderingMethod gl_compatibility` with array arguments for `--evidence-dir=res://../docs/evidence/forklift-side-cleanup-2026-10-25/integration` and `--bake-art` | 111 checks, zero failures; actual Garage/driving, both detail levels, articulation, replay, weathering, 80 km/h and catalogue capture |
| `TestScript -ScriptPath res://tests/bake_livery_previews.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--vehicle=forklift'` | 49 captures complete |
| Pinned `Import` and full script parser | Import passes; 1,162 scripts, zero failures |

All engine work uses `scripts/dev.ps1` and pinned Godot `4.7.2.stable.official.ed1daf0bf`. Native model counts are 145,512 detailed / 50,744 racing triangles, with 42 prepared mesh instances. These are inventory measurements, not a device performance claim. All earlier solid-body and mechanical-geometry assertions remain enabled. The task does not rerun the bridge suite or change its handling/clearance sources.

Changed files: model, reusable capture arguments/poses, native PNGs, this guide, evidence and scoped status entries. A Git-checkable task-only text patch and native-asset archive preserve the task-start source base without touching the owner's index or HEAD. Prior Forklift evidence and concurrent Electric, Kart, translation, Desert, website and account work are preserved.

No device attachment check or physical-device test, APK, real purchase, live mutation, deployment or owner-process restart was performed. Reload the client for the model/photos. Owner/device visual and frame-pacing acceptance remain.
