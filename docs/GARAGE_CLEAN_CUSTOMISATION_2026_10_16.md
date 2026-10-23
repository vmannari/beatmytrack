# Clean-car requirement for Garage customisation — 2026-10-16

The owner requires a clean car before changing liveries or cosmetic kits, with a clear washing indication when a dirty car's customisation is attempted.

The later owner request accepts small leftover dirt to avoid hunting hidden specks. The strict epsilon/light-dirt rules below describe the initial implementation; current acceptance thresholds and follow-up evidence are in `GARAGE_CLEAN_TOLERANCE_2026_10_16.md`.

| ID | Implemented requirement |
| --- | --- |
| GCC01 | Dirty cars show **WASH REQUIRED** in Customise and Tuning. The message explicitly names liveries, colours, stickers and kits. **Wash car** opens Care with the original manual washing active. |
| GCC02 | Guard pattern selection, colour previews, sticker selection/placement/properties/centring, livery reset/save, kit selection/save and kit reset. A blocked attempt retains saved appearance and dirt. |
| GCC03 | Recognise the actual washed exterior, including both dirt layers and snow; partially washed and lightly dirty cars remain locked. Clean wet cars may customise. |
| GCC04 | Retained controls read newer local race condition before applying a change; an incoming condition also rebuilds the visible requirement/workbench. Preserve local condition, original car/camera, canonical contracts and existing render/cache behavior. |

`game/ui/garage_cleanliness.gd` reuses the showroom's prepared native triangle acceleration. The first partially washed inspection samples at most 1,280 rays across the top and four sides, keeping only nearest washable exterior hits. Hidden underside/interior voxels are excluded. It evaluates the same trilinear 16-cube wash mapping as the existing finish, for both masks. The clean threshold is the existing native finish epsilon, 0.00001; light dirt of 0.005 still blocks. This is a bounded exterior sampling rule, not a claim to integrate every mesh fragment.

Exterior points are reused until the car/parts/bounds change; the result is reused until those inputs, contamination amounts or mask bytes change. Clean and completely unwashed cars need no ray inspection. No new meshes, render targets, shaders, audio, condition schema, physics or backend contracts were added for this requirement. Existing wash data is retained; the gate does not automatically wash a car or clear its dirt history.

Changed implementation: `game/ui/garage_page.gd`, new `game/ui/garage_cleanliness.gd` and UID. Focused coverage: new `game/tests/test_garage_clean_customisation.gd` and UID. Existing tests: `test_garage_carousel.gd` now washes the real exterior before the original editing assertions and retains explicit dirty-block/partial-wash assertions; `test_car_wash.gd` waits for the existing slide before projecting its pixel probe. Shared workspace economy, editor, backend, scenery and generated build-identity work is outside this task.

Actual verification uses the pinned Godot 4.7.2 build through `scripts/dev.ps1`, with isolated local record directories and `BMT_API_URL` cleared:

| Check | Actual outcome |
| --- | --- |
| Focused headless | 78 checks, zero failures |
| Focused native Compatibility/OpenGL | 83 checks, zero failures |
| Focused native Mobile/Vulkan | 83 checks, zero failures |
| Existing Garage carousel/navigation, headless | 152 checks, zero failures |
| Original washing, native Compatibility | 1,402 checks, zero failures after correct slide settling |
| Whole-project script compilation | 810 scripts, zero failures; includes concurrent workspace scripts |

Focused checks cover all five cars, partial/exterior washing, light dirt, snow, clean wetness, guarded mutations/resets, real clean-car edits/kits, saved mask continuity, restart appearance and newer race wear before the next frame. Native requirement captures cover 960×540, 1280×720 and 1600×720, plus dirty Tuning and unlocked clean kits. Captures are in `docs/evidence/garage-clean-customisation-2026-10-16/{gl_compatibility,mobile}/`.

Actual commands (PowerShell invoked with `-NoProfile -ExecutionPolicy Bypass -File`):

```powershell
scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 120
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_clean_customisation.gd -CommandTimeoutSeconds 120
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_clean_customisation.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3 -CommandTimeoutSeconds 120
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_clean_customisation.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -CommandTimeoutSeconds 120
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_carousel.gd -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_car_wash.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3 -TestArgument '--evidence-root=res://../docs/evidence/garage-clean-customisation-2026-10-16/regressions-final' -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 120
git diff --check -- game/ui/garage_page.gd game/tests/test_garage_carousel.gd game/tests/test_car_wash.gd
```

Retained diagnostic outcomes:

- Initial sandboxed import exited 1 on certificate-store/native access; the same pinned import passed with native access available.
- Initial focused restart assertions failed twice per run because they compared arbitrary floating-point snapshots exactly after JSON round-tripping. Final checks retain exact appearance IDs/colours/kits and wash bytes, with approximate floating-point fields as in the existing washing tests.
- The first native original-wash run had 1/1,402 failures in its brightness assertion: it projected the hit during the live 0.32-second slide. The initial pixel was `(686,340)` and changed blue from 0.2549 to 0.2627. An isolated diagnostic with the exact old `_show_section` method passed 1,402; after explicitly settling the slide, the final real implementation passed 1,402 and the settled `(688,414)` pixel changed blue from 0.0392 to 0.2471. The original brightness assertion remains unchanged. Diagnostic fixture source is retained as text under `before/`; temporary runtime fixtures were removed.
- Early focused renderer folder selection incorrectly read the project default, so Mobile initially overwrote the Compatibility folder. The final harness reads the actual renderer; both renderer folders were regenerated separately.

`report.json`, copied logs, source hashes and a task-only patch provide the review record. No phone attachment check, physical-phone test, APK build/install, deployment, backend test/change or measured FPS claim was made for this task. Owner/phone acceptance remains for the washing effort, wording and touch presentation.
