# Desert sand: granular and intermittent revision — 2026-10-22

The owner rejects the first wind effect as gas-like and too systematic everywhere. This supersedes the broad curved veils in `DESERT_SAND_WIND_2026_10_22.md`.

## Requirements

- **SGR01:** Remove continuous density sheets, curling flow, pale cloud pigment and metre-high loft. Use small earthy flecks making short ballistic hops, with varying speed, size and pigment. Warm and darker grains share actual directional/ambient light. Maximum cosmetic hop is 28 cm above the seated source, rather than the previous roughly one-metre veil.
- **SGR02:** Leave most ground clear. Empty candidate cells, full-cell random offsets and at least eight metres between selected sites give at most six irregular local patches. Independent brief emission windows, unequal durations, skipped cycles and long gaps replace continuous activity at every grid point. The existing wind audio controls overall intensity; strong wind does not make every patch emit together.
- **SGR03:** Keep visible sites in their original world locations as the camera crosses collection cells. Retire a site only outside the whole visible/hop envelope. Preserve pause/background/hidden, finite input, finish/retry, biome teardown and prepared cosmetic ground support.
- **G01/R01/Q01:** Preserve canonical track and actual driving data, camera, road geometry, vehicle dust, existing wind audio, account flows and concurrent work. Review native moving evidence and retain failures/corrections.

## Implementation and bounds

Only `game/track/desert_sand_wind.gd`, its `.gdshader` and `game/tests/test_desert_sand_wind.gd` change at runtime/test scope. The existing race weather integration in `game/core/game.gd` is retained.

One MultiMesh contains at most **1,152 tiny two-triangle planes / 2,304 triangles**, compared with the original 2,592-triangle veil budget. Each of six sites has 192 optical grain flecks; the shader keeps most inactive during gaps. No separate veil batch, new noise texture, procedural texture generation, runtime image readback, new thread/cache or persistent storage is added. The original flow texture is no longer loaded by this effect. One depth read per visible fragment retains both renderer depth conventions and soft opaque intersections.

Flecks represent visible clusters of fine grains at the overhead scale; their 6.5–16 cm streak geometry is an optical presentation choice, not simulated sand particle size. Source sites remain restricted to loose sand, inside the map and clear of overhead bridges. Source height reuses the existing prepared Desert relief. GPU event phases are cosmetic and can differ between GL/Vulkan implementations; they never enter canonical driving or verification.

## Native evidence

- [Compatibility motion](evidence/desert-sand-grains-2026-10-22/gl_compatibility/motion.html).
- [Desktop Mobile motion](evidence/desert-sand-grains-2026-10-22/mobile/motion.html).
- Both folders retain `before.png`, `gust.png`, `detail.png`, `occlusion.png` and `timeline.json`. Before means the same current scene with the revised wind hidden. The rejected broad-veils captures remain in the earlier task directory, untouched.
- Gameplay images use the original camera. The six-second detail preview uses a closer overhead fixture camera aimed at the patch that actually emitted. It contains 90 actual Godot frames at 15 presentation steps per second under constant strong wind, including quiet intervals. Encoding uses lossless animated WebP from the captured JPEG frames to retain fine flecks. Pause holds a canvas snapshot.
- The fixture samples 12 seconds of stationary strong wind. It requires more than 100 visible changed pixels at the peak, fewer than 1% of the gameplay image changed, and a quiet sample below 35% of the peak. This replaces the old veil's minimum-coverage check because the owner's new requirement explicitly calls for sparse grains and clear ground. Lifecycle, exact canonical data and strict opaque-roof pixel equality remain.

All graphical checks run on a desktop NVIDIA GeForce RTX 3090. Desktop Mobile is Vulkan Mobile rendering, not physical-phone execution. The receipt records actual counts and coverage.

Final results: **52 headless / 60 Compatibility / 60 desktop Mobile**, existing Desert **87**, ambience **111**, biomes **108**, project parser **932 scripts**, and scoped whitespace all pass. Strong-wind peaks are **303 / 277 pixels** in the 1280×720 gameplay frame, with **zero** in the quietest sample. Both renderers retain all **783** projected opaque-roof interior pixels exactly.

## Commands and results

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. All engine invocations use the established `scripts/dev.ps1` entry point and the approved normal local execution context needed for Windows certificate access.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_ambience.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_biomes.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
.tools/review/Scripts/python.exe docs/evidence/desert-sand-grains-2026-10-22/encode_preview.py
git diff --check -- game/track/desert_sand_wind.gd game/track/desert_sand_wind.gdshader game/tests/test_desert_sand_wind.gd
```

Actual terminal outcomes, logs, source hashes, retained attempts and the task-only source patch are in `evidence/desert-sand-grains-2026-10-22/report.json`. This patch compares the three revised source/test files against the saved first-trial files, preserving concurrent work in the shared workspace.

## Retained corrections and limitations

1. The initial patch combined delete/add on one shader path and was rejected without applying. The update was then applied with separate supported edits.
2. Initial grains were too small to read at gameplay scale (42 changed pixels at the strongest sampled frame). Its image is retained as `before/grains-too-small.png`. The revised optical flecks use 192 grains/site and slightly longer/wider, stronger cores while keeping very sparse coverage and low hops.
3. Source collection now retains visible old sites across cell changes; focused checks require their exact positions to survive. The fixture chooses the detail source from the actual changed-pixel centroid, since GL and Vulkan can produce different cosmetic hash phases.
4. A final Mobile rerun initially stopped before engine startup because concurrent audio work referenced a not-yet-built `bmt_windows_audio_v5.dll`. `mobile-refined-final.log` retains that error. No audio source, manifest or binary was altered by this task; the rerun follows the existing build's completion.
5. Deliberate fixture stepping and screenshot readbacks produce `RACE_HITCH` diagnostic messages. These are not ordinary gameplay measurements. No FPS, frame-pacing or phone-performance claim is made.

Reload the local client to inspect the revision. Owner acceptance of grain readability, patch frequency and natural motion remains. No phone attachment check/device test, APK/export/install, backend/account mutation or deployment was performed.
