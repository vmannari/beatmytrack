# Simple 3D rivalry podium — 14 October 2026

**RPS01 / RPC01–RPC04 / V03–V05 / R01 / Q01.** The owner rejects the initial detailed podium appearance and requests the existing simpler 3D models.

The three top podium cars now select `CarVisual.simple_model` before entering the scene tree. This uses the same reduced geometry path as Settings → Graphics → Simpler car models. Each leader retains their own pinned vehicle, paint colours, wrap, sticker placement and fitted Compact parts. Camera, lighting, card dimensions, static viewport updates and the preceding appearance-sharing implementation remain. This is the existing simplified production geometry; it preserves the original vehicle shapes and finishes.

`game/ui/rivalry_victory_car.gd` exposes the model choice, with its previous detailed default retained for awards. `game/ui/weekly_rivalry_page.gd` opts only the podium into simpler models. `game/tests/test_rivalry_custom_cars.gd` verifies the actual model choice on all fifteen native car instances, the detailed awards default, retained cosmetics/scope/fallback and static draw behavior. Its optional `BMT_RIVALRY_CARS_EVIDENCE_DIR` isolates new captures from the rejected version. There are no backend, catalog/mesh asset, global Graphics setting or canonical changes.

Actual commands used pinned Godot **4.7.2.stable.official.ed1daf0bf** through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with APPDATA in separate `.tools/rivalry-simple-cars*-user` directories:

| Actual command | Outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_rivalry_custom_cars.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3` | **135 checks, zero failures**; native captures at 960×540, 1280×720 and 1600×720, plus all five vehicle types. |
| Same podium test with `-RenderingMethod mobile -RenderingDriver vulkan` | **135 checks, zero failures**; matching native Mobile views. |
| `-Action TestScript -ScriptPath res://tests/test_racing_car_models.gd` | **75 checks, zero failures**; actual lower geometry counts for all five chassis, articulated wheels, local materials, livery/weathering, fitted parts and settings persistence. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | **756 scripts, zero failures** in the current shared workspace. |

Both podium runs measured 141 settled draw calls versus 334 with all three car viewports explicitly forced to update continuously; returning to one-shot updates restored 141. This verifies bounded steady-state render work, not phone performance. The model regression measured 39,756 simple versus 101,660 detailed stock Compact triangles in the current shared workspace; the other four simple chassis also reduced geometry. These counts belong to the existing model path, which this task does not modify.

New native evidence is under [Compatibility](evidence/rivalry-simple-cars-2026-10-14/gl_compatibility) and [Mobile](evidence/rivalry-simple-cars-2026-10-14/mobile): [small hub](evidence/rivalry-simple-cars-2026-10-14/gl_compatibility/hub-960x540.png), [Mobile compact](evidence/rivalry-simple-cars-2026-10-14/mobile/car-compact.png), and five chassis captures in each renderer folder. The preceding rejected captures remain in their original folder. All captures use explicit isolated fixtures rather than live standings.

The scoped checkpoint contains these three runtime/test files, this report and the RPS01 entries in `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`. The [patch](evidence/rivalry-simple-cars-2026-10-14/scoped-change.patch), receipt and task-start files are retained under the evidence directory; the separate Git checkpoint is under `build/rivalry-simple-cars-checkpoint`. The main Git index and concurrent workspace changes are preserved.

No phone test/attachment check, APK export/install, backend change or deployment was performed. Owner acceptance of the simpler appearance and physical-phone readability remain. The previous matching-client/backend rollout requirement for shared remote customisation still applies.
