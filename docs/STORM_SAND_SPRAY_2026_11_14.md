# Storm sand tire effects (2026-11-14)

The owner requests no dust clouds on Storm sand, with only a small dirt spray from the tires.

- **SSS01:** suppress both ground and elevated sand clouds in Storm, including during braking/sliding. Clear lingering dry-biome clouds when an effect changes to Storm.
- **SSS02:** use the existing rear-tire solid-grain emitters for a low, short dirt spray. Normal rolling has a small speed-dependent contribution; sliding/braking increases it up to 32% of the existing particle budget. Grains have a 25 mm base radius, 70 mm height, 0.32-second lifetime, downward gravity and 1.2–2.8 m/s launch speed.
- **SSS03:** preserve independent wheel surface gating, wet-asphalt droplets, dry/Desert effects and canonical simulation state.

`game/vehicle/sand_dust.gd` now selects sand presentation by biome. `game/tests/test_storm_sand_spray.gd` exercises driving, sliding, braking, reverse, mixed sand/asphalt contacts, elevated sand, stops, airborne/rolled states, biome transitions and clear/restart. Its optional capture uses the real Quarry race and the production follow camera. `game/tests/test_prepared_race_resources.gd` updates the renamed private profile helper without changing assertions.

Actual validation uses the pinned `4.7.2.stable.official.ed1daf0bf` console executable through `scripts/dev.ps1`. Later race tests use a disposable `build/storm-sand-spray-test-profile` APPDATA; no owner save or running owner process was changed. The initial effect-only test constructs no race or account controller.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_storm_sand_spray.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_soil.gd

# In a process with script execution enabled, for each desktop renderer:
$env:APPDATA = Join-Path $PWD 'build/storm-sand-spray-test-profile'
$env:BMT_API_URL = ''
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_storm_sand_spray.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3 -TestArgument @('--capture') -CommandTimeoutSeconds 180
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_storm_sand_spray.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--capture') -CommandTimeoutSeconds 180
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert.gd -CommandTimeoutSeconds 180
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_storm.gd -CommandTimeoutSeconds 180
# Temporary original-emitter test copies, removed after use:
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/control_storm_sand_before_storm.gd -CommandTimeoutSeconds 180
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/control_storm_sand_before_desert.gd -CommandTimeoutSeconds 180
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/check_model_refinement_parse.gd -CommandTimeoutSeconds 180
```

The first attempted graphical `powershell -File` invocation rejected `--capture` as a missing array argument before running Godot. Passing an actual PowerShell array through `& ./scripts/dev.ps1` corrected the invocation.

| Check | Actual result |
| --- | --- |
| Focused headless effect behavior | 21 checks, 0 failures |
| Focused real Quarry race, Compatibility/OpenGL | 23 checks, 0 failures; 4 spray-contributing pixels |
| Focused real Quarry race, desktop Mobile/Vulkan | 23 checks, 0 failures; 11 spray-contributing pixels |
| Existing soil regression | 164 checks, 0 failures |
| Production parser | 566 scripts, 0 failures |
| Storm suite with original emitter source | 100 checks, the same 3 failures |
| Existing Desert suite | Stops at Hover packed-road versus loose-sand acceleration assertion, before creating its SandDust effect |
| Existing Storm suite | 100 checks, 3 failures: front/rear droplet intensity, speed-dependent droplet launch and Hover wet/ice slide comparison |

The focused transition checks retain Desert's nine-second billowing clouds and restore original dry-sand spray. The original-emitter Storm control reproduces all three broader Storm failures. The attempted original-emitter Desert control encountered a concurrently missing `res://track/track_visual_identity.gd` preload before running. That dependency was present again for the final production parser, which passes 566/0. No existing assertion was removed or weakened. The temporary controls used the exact original emitter source from `c3ccefd87^` without its global class name; the original test assertions were unchanged.

Native capture pairs: [Compatibility driving](evidence/storm-sand-spray-2026-11-14/gl_compatibility/driving.png), [without dirt](evidence/storm-sand-spray-2026-11-14/gl_compatibility/without-spray.png); [Mobile driving](evidence/storm-sand-spray-2026-11-14/mobile/driving.png), [without dirt](evidence/storm-sand-spray-2026-11-14/mobile/without-spray.png). Both views were inspected. The small pixel counts demonstrate restrained visible dirt in these desktop samples; they are not device or performance measurements. Actual race-entry hitch diagnostics remain in the capture logs.

The [validation receipt](evidence/storm-sand-spray-2026-11-14/validation.json), concise logs and [source patch](evidence/storm-sand-spray-2026-11-14/source.patch) are retained; the patch passes `git apply --reverse --check`. Evidence lives under `docs/evidence/storm-sand-spray-2026-11-14/`. Concurrent repository checkpoints included the source changes during verification; this task did not stage or commit the main index. No vehicle model, handling, track data, camera or production prepared assets were authored. No device query/test, export/APK, backend request or deployment was performed. Reload and owner appearance acceptance remain.

Completion cleanup: the compound PowerShell removal command was blocked by automatic review. Explicit `apply_patch` deletions safely removed the three task-owned temporary text files. The prescribed `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply` then completed: 22.96 to 22.96 GiB, zero eligible entries; recent/protected/locked output remains above the 20 GiB target. No new pin or complete project copy was retained.
