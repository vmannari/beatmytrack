# Matching Winter snow and softened bridge-bank endings — 2026-10-12

The owner accepts the improving connected bank and requests matching terrain style plus removal of the abrupt bank cuts at bridge approaches. Kit157 keeps the accepted bank shape and changes its material sharing and bridge-end falloff.

| Requirement | Implemented behavior |
| --- | --- |
| WE31 / V04 | Terrain, bank and deposited snow use the same neutral-white treatment of the original texture. Preserve its value detail, world scale and rotation; cool lighting and shadows supply blue. |
| WE32 / V04 / V05 | At ground-road endpoints connected to bridges, banks settle into the terrain over up to 4 m with a smooth profile and matching normals. Ordinary ground continuations and unrelated underpasses retain their banks. |
| G01 / R01 / Q01 | Reuse prepared topology and cached rows/UVs; retain mesh indexing, particle limits, camera, road material, collision cells and canonical contracts. Actual renderer/cache/mesh checks and desktop performance evidence. |

## Changed files

- `game/track/surface_detail.gdshaderinc`: `snow_detail()` now returns the bank's previously accepted neutral-white formula (`clamp(original_luminance*1.06+0.09,0,0.82)`). Its two original texture samples and value detail remain. Winter terrain and bank therefore share a material treatment rather than applying it only to raised banks.
- `game/track/winter_bank.gdshader`: remove the bank-only second colour transform. The existing small crest lift follows actual elevation, so a flattened bridge ending matches the ground instead of leaving a brighter rectangular patch.
- `game/track/native_track_visual.gd`: prepared endpoint partners identify bridge mouths. Ground continuations prevent fading; a crossing through a bridge's middle is not an endpoint match. Cache the start/end flags and length per road piece. Smooth falloff lowers banks to the existing -0.065 m buried foot over `min(4 m,45% of piece length)` and applies the same profile to normals. Additional UV queries occur only inside the local falloff. Clump footprints/jitter receive 1.5 m clearance from the falling section to preserve surface contact. Cache version advances from the captured concurrent baseline154 to157; all unrelated Desert/Night work is retained.
- `game/tests/capture_winter_bridge.gd`: selectable output folder, optional fresh meshes/entry-exit views and six checks against actual mesh data. Existing collision-cell assertion remains.
- `game/tests/test_winter_environment.gd`: current evidence path only; assertions and gameplay camera behavior remain.
- `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and this report record commands, outcomes and acceptance.

The existing `SurfaceShaderVariants` already selects Burley diffuse lighting for Winter. It remains unchanged; no new shader assets, lights, texture lookups, draw calls, particle systems, collision objects or physics/compiler/backend contracts are introduced. Snowbank shape, directional road detail, stakes and original asset provenance remain.

## Actual commands and results

Commands used `scripts/dev.ps1`, process-local execution-policy bypass and pinned Godot `4.7.2.stable.official.ed1daf0bf`. [Actual logs](evidence/winter-unified-snow-2026-10-12/logs/).

| Arguments to `scripts/dev.ps1` | Result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_winter_environment.gd -Graphical -TestArgument @('--capture','--fresh-roads','--bank-detail','--video')` | 101 checks, zero failures. Final shared snow formula, actual taper/bridge width attributes, poles, terrain join, scenery and canonical separation. |
| Same environment script with `-Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--capture','--fresh-roads','--bank-detail')` | 100 checks, zero failures. Desktop Mobile Vulkan captures inspected. |
| `-Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -TestArgument @('--capture','--video','--output-dir=res://../docs/evidence/winter-unified-snow-2026-10-12/wind-validation')` | 47 checks, zero failures. 723 static and 761/751/750 moving opaque roof samples unchanged; interior AA samples unchanged; dark-light delta zero. Short concurrent wind timings are not used for performance claims. |
| `-Action TestScript -ScriptPath res://tests/capture_winter_bridge.gd -Graphical -TestArgument @('--fresh-roads','--approaches','--check-joins','--output-dir=res://../docs/evidence/winter-unified-snow-2026-10-12/bridges')` | Final157: six checks, zero failures; four actual views. 66 mouth samples, highest -0.027615 m; distant bank max1.272811 m and unrelated underpass bank max1.244847 m. Finite geometry and exact collision cells preserved. |
| Same bridge script with `-RenderingMethod mobile -RenderingDriver vulkan` and output `.../bridges-mobile` | Final157: six checks, zero failures; identical mesh metrics and four Mobile views. |
| `-Action TestScript -ScriptPath res://tests/test_road_cache.gd -Graphical` | Final157: 66 checks, zero failures, including cache restoration across existing biome fixtures. |
| `-Action Doctor` | Correct engine/templates/tools; ADB device list empty. |

Environment/wind checks were recorded with kit156. Final157 adds only the clump-clearance buffer at bridge mouths; their bridge-free fixture has exactly the same material and geometry. Bridge and cache checks run after that adjustment. Combined checks: **326 passed, zero failures**. A pre-change bridge capture is retained under `before-bridges`.

The independent final driving command was `-Action TestScript -ScriptPath res://tests/profile_winter_desktop.gd -Graphical -TestArgument @('--document=C:/Users/ville/AppData/Roaming/Circuit01Lab/cloud/fe772d2e756f39f351786a6c81dcb401f381848c01d5ea2cfdc05969d0cf0aed/cd0b5ca436fd1dd3e15256ba506fa528792e351bd6df13dbbaa49681d8e75262.json','--tag=unified-snow-final','--profile-dir=res://../docs/evidence/winter-unified-snow-2026-10-12/performance','--4k','--seconds=20','--modes=full')`.

RTX3090 Compatibility, 3840×2160, scale1, 2× MSAA, diagnostic VSync off: **6,793 samples / 2,401 actual ticks / 78.963 m** in the unscored 20 s sample. Frame median **2.880 ms**, p95 **3.872 ms**, p99 **4.673 ms**, worst **6.213 ms**, zero frames over16.667 ms. GPU median **2.433 ms**, p95 **3.022 ms**. 375 draws, about591,748 submitted primitives including current scene assets/shadows. Slippery's indexed bank has55,932 vertices/257,562 indices. [Final raw measurements](evidence/winter-unified-snow-2026-10-12/performance/desktop-unified-snow-final-gl_compatibility.json). No numerical speedup or all-PC/phone performance claim is made. Cold construction was not reprofiled.

## Evidence and remaining acceptance

[Matched terrain and banks while driving](evidence/winter-unified-snow-2026-10-12/driving.png), [driving motion](evidence/winter-unified-snow-2026-10-12/driving-motion.html), [bank/terrain close-up](evidence/winter-unified-snow-2026-10-12/bank-detail.png), [bridge entry](evidence/winter-unified-snow-2026-10-12/bridges/entry-bank.png), [angled bridge exit](evidence/winter-unified-snow-2026-10-12/bridges/exit-bank.png), [exit before change](evidence/winter-unified-snow-2026-10-12/before-bridges/exit-bank.png), [Mobile exit](evidence/winter-unified-snow-2026-10-12/bridges-mobile/exit-bank.png).

Restart the client to replace existing prepared worlds. Owner visual review on the supplied track, full laps and complex narrow/overlapping creator junctions remains. Fading is topology-based: unconnected/overlaid spans are not treated as joined mouths, and ground continuations deliberately retain banks. No phone is attached; no physical-device visual/performance/thermal/touch test, Android export/install, full Validate, physics regression, backend test/deployment or live write was performed. Desktop Mobile Vulkan is not a device test.

The task-only checkpoint/source patch are under `build/winter_unified_snow`; unrelated work and the main Git index/branch remain unchanged.
