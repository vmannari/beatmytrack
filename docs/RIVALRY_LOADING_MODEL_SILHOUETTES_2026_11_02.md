# Rivalry loading silhouettes from production models (2026-11-02)

The owner rejected the generic loading car icons and requested silhouettes from the game's actual car models, with the same colors as the podium.

| Requirement | Implementation |
| --- | --- |
| RLS01 | Offline renders of the current Rally, Kart, Forklift, Volt and Hover meshes replace the mathematical generic car. The bake uses the existing podium's camera position, viewing target and PI car rotation, fitting and centering each silhouette without changing its proportions. The loading view follows the currently selected vehicle immediately; Compact Circuit retains its pinned Rally. |
| RLS02 | Loading and populated cards now share the same panel and footer style helpers, plus the existing medal-lit stage shader. Silhouettes and identity bars use the exact gold, silver-blue and bronze medal pigments. Final populated-card styles retain their previous values. |
| RLS03 | The small packaged atlas is drawn with a soft alpha filter and the previous slight pulse. Standings animation remains. Loading still creates no 3D scene, viewport or CPU animation callback; error/retry, final-board handoff and same-car background refresh remain covered. |

The atlas is `game/assets/menu/rivalry_loading_cars_v1.png`: five 384x256 tiles in a 1920x256 lossless texture (1.875 MiB of uncompressed RGBA pixels before renderer overhead). Its packaged byte count is recorded in `report.json`. It depicts stock geometry only; actual results retain each driver's equipped appearance. No private account data enters the asset.

`game/tests/bake_rivalry_loading_silhouettes.gd` generates the atlas from current production `CarVisual` models with prepared assembly restoration disabled. A uniform unshaded material produces alpha masks, without changing the runtime models. [bake.json](evidence/rivalry-loading-model-silhouettes-2026-11-02/bake.json) records camera transforms, fitting FOVs, mesh counts, mask bounds, source hashes and the final PNG hash. The native bake completed five cars with zero failures.

The atlas was imported successfully with the pinned engine in a minimal isolated project containing only the new PNG. Its import configuration and generated texture cache were copied to the same resource path in the main workspace. This avoids the previously documented native-extension copy problem during broad main-project imports; no owner editor or settings were changed.

| Verification | Actual outcome |
| --- | --- |
| Compatibility/OpenGL, 1280x720, 960x540, 1600x720 | 135 checks, zero failures. |
| Desktop Mobile/Vulkan, same sizes | 135 checks, zero failures. |
| Captures | Eleven per renderer: three loading views, three motion samples and all five model-specific views. |
| Model/palette/lifecycle coverage | Distinct unclipped masks; selected-car and circuit selection; exact loading/final panel and footer colors; soft pulse and table shimmer; no live 3D loading; failure/retry, cleanup and background refresh. |
| Scoped checkpoint | Binary-inclusive task-start patch, source/asset hashes and actual check outcomes in `report.json`. |

An initial test attempt had a byte-array fingerprint conversion parse error. The next attempt caught two faint pulse frames quantizing to nearly identical alpha near a peak. The final fixture can take one additional real-time sample before judging motion; its original lower and upper pixel-change bounds remain unchanged. The direct PNG-read test warning was resolved by validating the actual imported texture. Original attempt logs are recorded in [report.json](evidence/rivalry-loading-model-silhouettes-2026-11-02/report.json).

The source-hash checkpoint detected concurrent Forklift geometry/customisation edits after the first bake. The initial report and patch are retained; a repeat bake against the current sources produced a byte-identical stock silhouette atlas. The imported image and both renderer passes therefore cover the same final pixels. Compatibility was also repeated after the refresh. The concurrent model changes are preserved and excluded from this task's patch.

Final native views include [Rally](evidence/rivalry-loading-model-silhouettes-2026-11-02/gl_compatibility/model-compact.png), [Kart](evidence/rivalry-loading-model-silhouettes-2026-11-02/mobile/model-kart.png), [Forklift](evidence/rivalry-loading-model-silhouettes-2026-11-02/mobile/model-forklift.png), [Volt](evidence/rivalry-loading-model-silhouettes-2026-11-02/mobile/model-electric.png) and [Hover](evidence/rivalry-loading-model-silhouettes-2026-11-02/mobile/model-hovercraft.png).

Actual native command forms, with isolated `APPDATA=build/rivalry-loading-model-silhouettes/profile` and empty `BMT_API_URL`:

```powershell
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_rivalry_loading_silhouettes.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3 -CommandTimeoutSeconds 90
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_loading_visuals.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3 -CommandTimeoutSeconds 120
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_loading_visuals.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -CommandTimeoutSeconds 120
```

The engine is pinned `4.7.2.stable.official.ed1daf0bf`. Normal local access avoids the certificate-store startup issue already established in this session. Native windows were off-screen, and all service data was synthetic. No device query/test, Android export, owner-save/process change, live/backend mutation, deployment or main-index write occurred. Owner appearance and device acceptance remain. Concurrent work and generated identities are preserved. This task corrects loading artwork; no model-loading speedup is claimed.
