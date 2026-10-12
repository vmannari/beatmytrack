# Winter wind grounding — 2026-10-11

The owner found this version fog-like and its motion too gentle for harsh wind. It is superseded by [fine powder and faster gusts](WINTER_SNOW_POWDER.md); the world lighting and bank contact are retained, while the broad sheets are removed.

The owner accepted the direction as much better and asked for the wind to feel connected to the world. Revision 3 retains the soft, broken density while replacing bright camera-facing puffs with low continuous flow from the bank crests onto the road. Current owner visual acceptance remains pending.

Requirements WW09 (connected source-to-surface flow), WW10 (snow palette and scene lighting), WW11 (one continuous camera-independent world field), WW12 (bounded modest computation), plus WW01–WW08, V04/V05, G01/R01 and Q01. Canonical handling, five laps, race clocks, scores, ghosts, upload eligibility, audio, car meshes and the camera contract are unchanged by this task.

## Behavior and changed files

- `game/track/winter_snow_wind.gd`: presentation version `winter-wind-3`. Each bank source uses a reusable world-facing PlaneMesh with six spans. Its source edge stays on the prepared visible crest; the geometry descends to a 6.5 cm road layer within the first two metres. Three existing source slots retain low sheets/curls/grains. The ground layer also sits at 6.5 cm. Source lookup, prepared geometry, spatial buckets and the 4 Hz local selection remain unchanged. No camera-facing basis, new emitters or per-frame terrain sampling.
- `game/track/winter_snow_wind.gdshader`: one advected world-space density/warp/grain field drives both layers, so density crosses sheet boundaries without restarting local UV patterns or teleporting a puff. Source geometry stays anchored while the density moves downwind. The material samples the same existing winter snow albedo and uses Lambert lighting with roughness 1/specular 0. It receives the scene's ambient, directional light and existing shadows; the nodes still cast no new shadows. Geometry/depth fading replaces the previous billboard height proxy. Lower opacity and a smooth source-to-road tail reduce detached blob shapes.
- `game/tests/test_winter_snow_wind.gd`: keeps canonical/lifecycle/readability checks; updates the geometry contract from bank quads to six-span sheets and verifies their world-facing basis. Adds an actual paired render comparison with directional/ambient/reflected light disabled to ensure the effect cannot glow independently of the scene. Keeps normal-camera canonical driving, static/moving roof comparisons and alternating render measurements. Evidence goes into a new folder, preserving both earlier revisions.
- `docs/WINTER_SNOW_WIND_REFINEMENT.md`, this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`: latest feedback, implementation, actual checks and pending acceptance.

No `game/core/game.gd` change is needed for this revision. Concurrent vehicle-weathering and other work remain intact. No new bitmap/audio assets or dependencies. Original density PNG remains SHA256 `4f8b0ee626af36a174cd23e8a9275bac144ff2d91fb9126aeefa59627583f0e9`; the existing cleared winter snow texture is reused. Godot documents [lit/unshaded spatial render modes and shadow reception](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html); these are the existing renderer's lighting features, not a new light/shadow pass.

## Cost and actual verification

The allocation remains **81 ground instances and at most 36 bank instances, in two draw calls**. Subdivision increases the maximum from 234 to **594 triangles**: 162 ground triangles plus 36×12 bank triangles. The actual captured pool uses 10 banks/30 sheets and **522 additional triangles** (362,431 off versus 362,953 on). Bank texture lookups share the new world field and lighting; snow albedo adds one existing-texture sample. Receiving shadows and wider connected source sheets have fill/shading costs; equal draw counts do not prove equal GPU cost.

Final desktop measurements: presentation update about 11–13 µs across the recorded runs. Four 120-frame off/on/on/off GPU medians were 0.891/0.901/1.189/1.241 ms; render-CPU medians 1.463/1.516/1.512/1.456 ms on RTX 3090 Compatibility. Shared-machine timing varies, so this is a bounded desktop observation, not a precise incremental-cost or phone benchmark. Raw [profile.json](evidence/winter-wind-grounding-2026-10-11/profile.json) remains reviewable.

Actual outcomes: headless lifecycle **32/0**, Compatibility capture/driving **43/0**, desktop Mobile/Vulkan actual draw/lifecycle **32/0**, app lifecycle **99/0**. The lit/unlit paired-image difference is **620.447** in the lit world and **0** with illumination/reflections disabled: the wind's colour contribution follows scene lighting. That sum is a diagnostic pixel difference, not an intensity unit. Static roof samples **741/0 changed**; moving samples **708/708/683**, with zero changed in every frame. Road cells, contact-bank geometry and the original simulation snapshot remain exact. Diagnostic driving uses a separate canonical simulation and restores the original race; no score/ticket/upload is produced.

### Actual commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -TestArgument @('--capture','--video')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
git diff --check -- game/track/winter_snow_wind.gd game/track/winter_snow_wind.gdshader game/tests/test_winter_snow_wind.gd
Get-FileHash -LiteralPath game/assets/textures/winter_wind_flow_v1.png -Algorithm SHA256
& 'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe' devices -l
python build/checkpoint_winter_grounding.py
```

All engine commands use pinned `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`. No focused test failure occurred. An initial unapplied patch attempted delete/add operations on the same shader path and was rejected by the patch tool; it was corrected to a single update before testing. Geometry-budget expectations change to reflect the explicit six-span implementation; canonical, roof and lifecycle assertions are retained. First capture 42/0 preceded the added lighting comparison; final 43/0 includes it. No full Validate, APK export/install or physics-regression suite is claimed.

## Evidence and remaining acceptance

[Five-second normal-camera driving preview](evidence/winter-wind-grounding-2026-10-11/driving-motion.html), [driving still](evidence/winter-wind-grounding-2026-10-11/driving.png), [strong-gust still](evidence/winter-wind-grounding-2026-10-11/gust.png), [same scene without wind](evidence/winter-wind-grounding-2026-10-11/before.png), [curve](evidence/winter-wind-grounding-2026-10-11/bend.png), [curve motion](evidence/winter-wind-grounding-2026-10-11/motion.html), [rotated camera](evidence/winter-wind-grounding-2026-10-11/rotated.png), [compact viewport](evidence/winter-wind-grounding-2026-10-11/compact.png), and [unlit comparison](evidence/winter-wind-grounding-2026-10-11/unlit-lighting-check.png) are actual Godot captures. The five-second preview contains 60 unique 960×540 frames with canonical car motion and a controlled strong/calm visual gust; it is a diagnostic fixture, not a full player race. The curve capture freezes driving while advancing wind presentation. Captures were inspected for source contact, softer flow, readable road/controls and coherent colour.

Task-only patch, checkpoint manifest and actual logs are saved alongside the evidence. The checkpoint uses an isolated repository under `build/winter_grounding/checkpoint-repo`; main branch/index and concurrent work are untouched.

ADB lists the attached DN2103 phone. **No physical-device test, Android export/install, backend work or deployment was performed.** Owner preference for the restrained density and connected flow, phone fill/shadow cost, frame pacing/thermal behavior, Mali/Adreno depth/MSAA and every bridge/terrain combination remain unaccepted. Bank-to-road profiles target the game's flat road plane and use depth fading at intersections, not runtime terrain simulation. Higher terrain can clip the sheet; graded terrain/bridge flow requires device/scene acceptance. This revision changes visual integration, not wind-driven vehicle forces or a general fluid simulation.
