# Winter snow wind experiment — 2026-10-11

Requirements WW01–WW04 (this owner request), V04/V05 (readable mobile presentation), G01/R01 (canonical separation), Q01 (actual evidence).

WW01 adds light ground-hugging snow ribbons and localized powder blowing from exposed upwind snowbanks. WW02 shares one fixed world-space direction and the existing WinterWind audio's smoothed intensity. WW03 bounds computation, geometry and transparency. WW04 covers pause/background, retry, finish, biome change and race exit. Ordinary racing remains five laps with identical driving, contracts, clocks and scores.

The experiment is enabled automatically in Winter races and untimed practice on the next local run. No settings labels or gameplay overlay were added. Start the pinned local client with `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Run` and select a Winter track.

## Implementation and cost

- `game/track/winter_snow_wind.gd` and `.uid`: two MultiMesh batches, 81 road/terrain ribbons plus at most 12 nearby bank sources with three wisps each. Prepared snowbank crest geometry is read once into spatial buckets. Local source selection examines at most 81 buckets every 0.25 seconds; ground transforms change only when crossing a six-metre grid boundary. Shader motion handles individual wisps; there are no per-particle CPU updates or extra physics.
- `game/track/winter_snow_wind.gdshader` and `.uid`: wind-aligned world geometry, shared travel/strength, low alpha, soft edges, existing dust texture's alpha, short lifetimes, range fading and opaque-intersection depth fading for Compatibility and Mobile. World-space bank cards have a shallow tilt; camera rotation changes their projection, never their travel direction. No shadows, lights, collisions, full-screen snow or additional depth pass.
- `game/core/game.gd`: Winter-only world node creation, presentation updates, retry reset and cleanup when changing biome. Race exit owns/frees the node normally. Existing recorded wind, frost, tire spray and handling remain intact.
- `game/tests/test_winter_snow_wind.gd` and `.uid`: real race lifecycle, geometry/canonical isolation, fixed budgets, source contacts, pause/background, retry/finish, actual captures, opaque car-roof comparison and four alternating render measurements.
- `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`: actual outcome and remaining acceptance.

One extra texture lookup reuses the existing `dust_puff_v1.png` alpha; RGB is not used, so no sandy colour is added. New scripts/shader are original project code. No new art assets, recordings, dependencies or runtime downloads. References supplied by the owner are visual guidance, not shipping assets.

The measured full pool adds **two draw calls and 234 triangles** (117 quads), independent of total track size. Desktop presentation updates measured roughly 14–22 microseconds on this machine across the recorded runs. On the RTX 3090, final four 120-frame GPU medians were 1.609/1.585/1.316/1.293 ms (off/on/on/off); CPU rendering medians 2.978/2.878/2.641/2.218 ms. GPU/process activity varied, including a desktop Mobile smoke run around capture startup; these measurements are not an isolated precise speedup/overhead or phone benchmark. Raw values are in [profile.json](evidence/winter-snow-wind-2026-10-11/profile.json). The stable geometric budget and source-query bounds are the useful performance evidence here. Godot documents [MultiMesh instancing and custom bounds](https://docs.godotengine.org/en/stable/classes/class_multimesh.html); the implementation provides bounds expanded for shader motion.

## Actual commands and outcomes

All engine commands use `scripts/dev.ps1` and pinned `4.7.2.stable.official.ed1daf0bf`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -TestArgument @('--capture','--video')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_wind.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestIce
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
& 'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe' devices -l
python build/checkpoint_winter_snow.py
```

Final results: Import exit 0; visual lifecycle 29 checks/0 failures headless and desktop Mobile/Vulkan; Compatibility capture 35/0; existing winter audio 87/0; ice/snowbank handling 69/0; app lifecycle 99/0. Actual simulation snapshots, road cells and bank contacts remained exact. The frozen before/after capture samples 741 warm-coloured opaque car-roof pixels with **zero changed pixels**. The broader rectangle contains road/edges and has 68 changed pixels; that is not a car-surface failure.

Initial sandboxed import could not read the Windows certificate store; local execution with the needed OS access succeeded. First script constant used a nonconstant normalization expression and was corrected to its already normalized numeric vector. Initial fixture called a nonexistent `_reset_race`; it was corrected to the actual `restart()` method. Assertions were retained. Optional Python image analysis was unavailable because Pillow was not installed; the final pixel check uses native Godot Image directly. No package installation was needed.

Evidence: [driving gust](evidence/winter-snow-wind-2026-10-11/gust.png), [same view without wind](evidence/winter-snow-wind-2026-10-11/before.png), [curve](evidence/winter-snow-wind-2026-10-11/bend.png), [rotated camera](evidence/winter-snow-wind-2026-10-11/rotated.png), [960×540](evidence/winter-snow-wind-2026-10-11/compact.png), and [four-second motion preview](evidence/winter-snow-wind-2026-10-11/motion.html). Preview embeds actual 640×360 Godot frames at 12 fps; the race is frozen for visual inspection while the presentation advances. This is not a completed player race or device recording. Captures were inspected for readable road edges, car, controls and curve.

The task-only checkpoint/patch and actual logs are saved beside this evidence. It uses an isolated Git repository under `build/winter_snow_wind/checkpoint-repo`, preserving the main index/branch and unrelated working changes.

## Remaining acceptance

DN2103 phone is attached according to ADB. **No physical-device test, Android export/install, full Validate, backend work or deployment was performed.** Phone frame pacing, thermal cost, depth fading on Mali/Adreno/MSAA, moving-car visibility under sustained gusts, steep/overlapping bridge scenes and owner preference for strength remain unaccepted. Bank sources exclude bridge footprints; standard opaque depth handles the low drift layer, but desktop captures do not prove every mobile depth configuration.

This deliberately implements the two recommended initial effects. Sparse high airborne snow is deferred. Visuals follow the existing recorded wind's longer 2.5–5-second smooth swells and calm/high holds; the suggested 1–3-second gusts and occasional short strong bursts are not a separate new scheduler. Keeping the existing sound and visuals coherent avoids another wind controller or audio behavior change. Source allocation is camera-near and bounded, not a track-wide weather simulation.
