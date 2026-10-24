# Desert sand during ordinary driving, 2026-10-23

The owner cannot notice the effect in-game despite liking the earlier HTML direction. The earlier material fixture used a stationary camera and forced gust, then selected its peak frame. That did not establish visibility along a moving route with the actual weather loop.

## Requirements and change

- **SGP01:** make windblown sand readable during ordinary driving. Raise the ordinary visual wind floor from 0.30 to 0.65 while retaining the 0.95 gust level. Replace `0.28 * shape` opacity with `0.20 * sqrt(shape)`: sparse wisps gain coverage while the maximum individual core opacity is lower. The existing terrain hue remains, with sunlit airborne value lifted enough to separate from similar ground. Mobile uses a 1.35 pigment multiplier; Compatibility uses 1.0 after a measured hue shift at 1.35.
- **SGP02:** validate through the real `Game._process` presentation path, actual seeded Desert ambience and ordinary moving camera. The new `game/tests/test_desert_sand_gameplay.gd` presents a legal 100 m straight/35 m radius authored circuit at a scripted 14 m/s. It does not force a gust or select a favourable crest. Physics is disabled in this disposable fixture; this is a route-presentation capture, not an autonomous full-physics lap.
- **SGP03/G01/R01/Q01:** preserve the accepted soft shape, terrain hue, burst timing, lift/drift, six separated sites, 48 quads/96 triangles, density texture and one draw batch. Retain finite-input, pause/background/hidden, finish/retry, biome teardown, canonical state, depth and opaque-roof guards. Terrain, camera implementation, wind audio, vehicle dust and driving code are unchanged.

Runtime changes are only `game/track/desert_sand_wind.gd` and its shader. The existing focused fixture uses the new ordinary-strength constant and a new output folder. The new gameplay fixture/UID and local evidence helpers are added. No artwork, dependency, native library or backend change is introduced.

## Reproduction and evidence

The original effect was created correctly on the tested tracks. Native/default-route coverage had nearby sources at 69 of 80 positions; the legal authored circuit had them at all 80 positions, with 77 prepared crest anchors and no retained-source starvation. Source placement was therefore left unchanged.

In the corrected paired-frame moving-camera reproduction, the original material produced **zero of 18 samples** above 1,000 perceptibly changed pixels, peaking at **170 pixels**. A pixel must change by at least 0.01 in one RGB channel; a mere one-step quantization difference does not count. The regression requires at least nine readable samples and a peak of 3,000 pixels. The first wisp-only adjustment still failed, peaking at 661; both attempts are retained.

<!-- CHECKS -->

Final normal-wind route presentation produces **9/18 readable samples in each renderer**, with peaks **4,548 Mobile / 6,389 Compatibility** perceptibly changed pixels, against the original Mobile peak of170. Gameplay checks pass **4 headless / 6 Mobile / 6 Compatibility**. Existing focused checks pass **55/68/68**; Desert **87**, ambience **111**, biomes **108** and parser **1041 scripts** pass. All784 roof pixels stay exact in each renderer. The unchanged colour/contrast limits pass, with zero bright saturated specks. These are visibility and regression observations, not visual-quality or performance certification.

- [Mobile normal-wind driving preview](evidence/desert-sand-gameplay-2026-10-23/mobile/motion.html).
- [Compatibility normal-wind driving preview](evidence/desert-sand-gameplay-2026-10-23/gl_compatibility/motion.html).
- Main renderer folders contain `driving.png`, `driving.json` and 270 actual native frames over 18 presentation seconds, packaged as quality-90 WebP from the captured JPEG frames. Measurements use the original native PNGs. The camera/real ambience advance together; player vehicle motion follows the explicitly scripted route.
- `focused/` retains the stationary material/depth fixtures and their before/gust/calm/detail/palette/occlusion views. Earlier RSP/STC evidence remains untouched. The palette probe remains a neutral-floor isolation view; the driving previews retain normal scenery/light.

Actual commands, measured values, source hashes and the scoped Git checkpoint are in [report.json](evidence/desert-sand-gameplay-2026-10-23/report.json). Pinned engine is `4.7.2.stable.official.ed1daf0bf`, with RTX 3090 desktop hardware. Mobile means desktop Vulkan, not a phone/tablet test. Screenshot readbacks and scripted stepping emit `RACE_HITCH`; these are not gameplay frame-time measurements. Transparent fragment cost can increase despite unchanged geometry.

Representative actual commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_gameplay.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_gameplay.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 300
.tools/review/Scripts/python.exe docs/evidence/desert-sand-gameplay-2026-10-23/encode_preview.py
```

## Retained corrections and acceptance

The first larger-track fixture exceeded the editor's 120 m straight-length limit; it was corrected to a legal circuit and now checks its compiled biome immediately. Its initial short preparation wait was replaced by a bounded elapsed-time wait. Paired visibility captures require three settled draw frames; the initial one-frame comparison included a viewport-resize artifact. Those fixture attempts remain in this receipt and are not used as before/after evidence. The first Compatibility value treatment passed driving visibility but failed the existing hue limit; renderer-specific value calibration passed that same limit. No visibility, hue, contrast or roof assertion was removed to obtain a pass. A slow task encoder was stopped by its verified process identity; final previews use compact review packaging and owner game/editor processes were left running.

Restart the local game to load the source changes. The testing platform/build was asked asynchronously but not established in this task. Owner appearance/recognition on their actual track and sustained physical-device appearance/performance remain. No phone/tablet attachment check, physical-device test, APK/export/install, live account/backend mutation or deployment was performed. The scoped patch preserves concurrent work and earlier sand evidence.
