# Storm wet material, 2026-09-30

Requirements: V02/V04/V05/Q01; owner authorizes implementing the supplied wet-asphalt material proposal. Visual kit 96 supersedes kit 94. Kit 95 was an intermediate local capture/cache revision.

The baseline is wet asphalt: albedo multiplier 0.76 and roughness around 0.38, with separate metre-scale basin coverage approaching albedo 0.65 / roughness 0.12. Puddles flatten aggregate relief and suppress grain. Their mask uses the upper tail of two continuous world-space noise scales, independently of the fine baked aggregate. This is cosmetic coverage, not a drainage/depression simulation; the proposed 5?15% coverage is not a measured track-wide guarantee.

A critical cause of the earlier invisible sheen was found during an actual reflection-on/off capture: Compatibility toon diffuse multiplies environment specular by metallic, suppressing it on non-metal asphalt. Storm creator/terrain/bridge surfaces now use Burley diffuse and GGX specular with a shared static overcast sky (64-pixel radiance faces, quality filtering). No SSR, new lights, transparent road layer, animated reflection strokes or emission overlay. Markings, kerbs and start-line paint receive lower roughness; the start-line material explicitly enables GGX, previously disabled by VisualGeometry.material. Sky resources are shared and switching to another biome clears the Storm environment.

Dry shader wrappers retain their prior rendering modes and share the same extracted shader bodies with the Storm wrappers. Existing grass edge/fringe geometry, chips, joins and kerb tapers remain. Camera, collision, handling, tire spray and softened screen droplets are unchanged. Native and creator bridges select the Storm wrapper. Painted Storm terrain uses Burley across its blended surface, so its diffuse shading also changes slightly.

Changed files: shared surface_detail.gdshaderinc; creator_road/terrain/bridge_road shader wrappers and extracted includes; three storm_* road wrappers; storm_sky shader/resource; native_track_visual.gd, creator_bridge_visual.gd, bridge_presentation.gd, track_theme.gd; diagnostic surface_material_probe.gd, test_storm.gd; this document and status/phase notes. Existing unrelated bridge/headlight and backend/UI work is retained outside this checkpoint.

Actual validation through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `CaptureStorm -Track track_acf29166cceaaa42`: 90 checks, zero failures, no shader/engine errors. Includes wet handling/replays, weather/pause/spray, wet paint/start line, environment cleanup, and an image comparison with reflections disabled. The sampled view has a summed red-channel difference of 196.133 (8500 sampled pixels); the original toon road comparison was zero. This verifies a visible reflected-light contribution, not owner acceptance.
- `CaptureStorm -Track fixture:knit_bridge_regression`: 90 checks, zero failures; Storm bridge fixture loads/renders without shader errors. Start-area capture inspected; a close bridge-deck review remains outstanding.
- `TestSurfaceProfile`: 928 checks, zero failures and no shader errors. The first run failed because the diagnostic probe assumed inline shader bodies; it now expands shared includes and retains all original invariant checks.
- An intermediate dynamically-created-sky experiment emitted two GL texture-leak errors at exit despite its assertions passing. It was replaced with a shared preloaded Sky resource; subsequent final captures exit cleanly.
- Normal rain and lightning desktop screenshots were inspected. No Android export or physical-phone test; device attachment was not checked. Mobile GPU cost/frame pacing and owner visual acceptance remain outstanding. The sky adds environment sampling; no mobile performance claim is made.

Evidence: [rain](evidence/storm-material-2026-09-30/rain.png), [lightning](evidence/storm-material-2026-09-30/lightning.png), [same frozen view with sky reflections disabled](evidence/storm-material-2026-09-30/reflection-disabled.png).

Implementation references: [Godot environment reflection sources](https://docs.godotengine.org/en/stable/classes/class_environment.html), [Sky filtering and radiance size](https://docs.godotengine.org/en/stable/classes/class_sky.html), [Compatibility toon environment-specular branch](https://github.com/godotengine/godot/blob/master/drivers/gles3/shaders/scene.glsl). Local pinned Godot 4.7.2 capture comparison is the runtime evidence; upstream source is explanatory.

## Kit 97: readable reflection, owner follow-up

The owner still could not see the kit 96 sky reflection. Its low-contrast environment added mostly a weak overall gray tint. Kit 97 replaces that sky with dark cloud cover and brighter, irregular openings, filtered as a static 128-pixel radiance cubemap. The lighting remains engine sky specular, not painted albedo or emission. Smooth water retains a stronger reflection (specular 0.60) while rough binder/aggregate uses 0.28, keeping the surrounding asphalt dark. The shared puddle field has a narrower derivative-filtered transition and a small additional contour detail scale to prevent the bright regions reading as blurred smudges. No camera, lightning, screen droplet, spray or simulation changes.

Changed files: storm_sky.gdshader/tres; shared surface_detail.gdshaderinc and creator/terrain/bridge shader includes; native_track_visual.gd (cache revision); diagnostic surface_material_probe.gd (legacy interface adapter); this document, status/phase notes and new evidence.

Actual commands using the pinned scripts/dev.ps1 entry point:

- `CaptureStorm -Track track_acf29166cceaaa42`: final 94 checks, zero failures, no engine/shader errors. The reflection-on/off comparison sums 415.259 red-channel difference over 8500 samples, versus 196.133 for kit 96. This metric verifies a larger rendered contribution; it does not establish aesthetic acceptance. Final normal-rain image inspected at gameplay scale; distinct pale pools are visible near the start line.
- `TestSurfaceProfile`: 928 checks, zero failures, no shader errors.
- `git diff --check`: passes (line-ending notices only).

Evidence: [normal rain](evidence/storm-reflection-2026-09-30/rain.png), [reflections disabled](evidence/storm-reflection-2026-09-30/reflection-disabled.png), [later car/camera position](evidence/storm-reflection-2026-09-30/moving-car.png). The latter uses the existing presentation-only moving-car capture fixture, not a completed driving lap. The cubemap represents the overcast sky only; cars and scenery are not reflected. Environment highlights vary with viewing angle and surface roughness, so not every puddle is bright. Close bridge-deck review and owner visual acceptance remain outstanding. No Android export or phone test; device attachment not checked. Increased radiance resolution and puddle contour shader cost have not been measured on a phone.

## Reflection performance check

Owner additionally requests checking for a significant performance drop. Added `ProfileStormReflections` to scripts/dev.ps1 and the typed diagnostic game/tests/profile_storm_reflections.gd.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ProfileStormReflections -Track track_acf29166cceaaa42`. Clean exit with valid nonzero GPU timer readings on NVIDIA GeForce RTX 3090 / OpenGL Compatibility / pinned Godot 4.7.2. VSync and Engine FPS limiting are disabled. The same paused gameplay scene, camera, materials and weather overlay are rendered in alternating off/on/on/off/off/on order at each resolution; each window has 90 warm-up frames plus 300 measured frames. Off disables sky reflection and removes the active sky/background; on restores the shipping sky. The shared Sky resource remains retained during off windows, so allocation totals are not an incremental-memory measurement. Total measured frames: 3600. Wall-clock frame intervals and RenderingServer viewport CPU/GPU timers are recorded separately.

Median of the three window medians per condition:

| Resolution | GPU off / on | Frame interval off / on | Render CPU off / on |
| --- | --- | --- | --- |
| 1280x720 | 1.120 / 1.104 ms | 2.608 / 2.556 ms | 1.542 / 1.526 ms |
| 1920x1080 | 1.114 / 1.134 ms | 2.571 / 2.608 ms | 1.535 / 1.563 ms |

At 1080p this is +0.020 ms GPU (about 1.8%) and +0.037 ms wall interval (about 1.4%). The 720p difference changes sign within run noise; no speedup is claimed. Draw calls remain 373 and primitives 252218 in every window. Median of window GPU p95 is 1.673 / 1.635 ms at 720p and 1.720 / 1.745 ms at 1080p. No significant steady-state desktop rendering drop was observed.

[Raw timing windows](evidence/storm-reflection-2026-09-30/performance.json). These are controlled stationary-scene rendering measurements, not race FPS, a phone benchmark, an isolated first-use cubemap bake measurement, or a comparison against old pre-wet-material code. The off condition still evaluates the same wet-material roughness/normal helpers, isolating the sky-reflection rendering contribution. The static cloud shader runs when the sky is filtered, not per road fragment every frame. Actual Android GPU cost, startup spike and thermal/frame-pacing acceptance remain unverified. No phone attached-state check, device test or export was performed.


## Kit 98: textured, quieter puddles (2026-10-01)

Owner requests less smooth puddles and slightly dimmer reflections. Requirements V02/V04/V05/Q01. Shared surface_detail.gdshaderinc now retains pooled normal relief at 0.045 (previously 0.006), pooled roughness at 0.18 with existing grain variation (previously flat 0.12), and pooled albedo grain at 0.14 (previously 0.06). Pooled specular decreases from 0.60 to 0.52. native_track_visual.gd advances the material cache to kit 98. Coverage, road edges, sky, lightning and physics remain unchanged. No additional texture samples or rendering passes; the previous desktop performance measurement is not a fresh benchmark of this revision.

Actual commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- Initial CaptureStorm and TestSurfaceProfile encountered an unresolved rewind_button class from other workspace work; the capture was stopped. `Import` successfully registered RewindHUDButton without source changes.
- `CaptureStorm -Track track_acf29166cceaaa42` after import: 95 checks, zero failures, clean exit. Reflection comparison delta 376.337 across 8500 samples; verifies reflection contribution, not aesthetic acceptance.
- `TestSurfaceProfile` after import: 928 checks, zero failures, clean exit.
- Rendered [normal rain preview](evidence/storm-puddle-texture-2026-10-01/rain.png) inspected: pools retain highlights with fine texture and reduced brightness. Screenshot includes unrelated current HUD work.

Changed files: the two material/cache sources, this document, status/phase notes and the preview. Owner visual acceptance remains pending. No Android export or phone test; attached-device state not checked. Mobile performance remains unverified.


## Kit 99: wider reflection visibility and brighter lightning (2026-10-01)

Requirements V02/V04/V05/Q01. Owner requests reflections farther from the car and brighter lightning. There is no car-distance reflection mask: narrow sky openings made their angular highlights cluster around the camera. storm_sky.gdshader broadens the two opening lobes (powers 64/110 to 18/36), retaining cloud breakup and peak radiance. This makes off-axis puddles reflect more of the bright sky; it is not a world-space radius. Kit 98 puddle grain, roughness and specular remain. native_track_visual.gd advances cache revision to 99. storm_weather.gd raises directional lightning gain from 6 to 8.5 (42% increase in added light; maximum 2.72 above baseline). Strike timing, shallow random swells and screen overlay are unchanged.

Actual commands via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`: `CaptureStorm -Track track_acf29166cceaaa42` passed 95 checks, reflection-on/off delta 598.561; `TestSurfaceProfile` passed 928 checks. Both exited cleanly without engine/shader errors. Rain and peak-lightning captures inspected: reflections extend to the left bend, right road and upper road; lightning increases scene illumination. The summed delta verifies contribution, not distance coverage or owner acceptance.

Evidence: [rain](evidence/storm-wide-reflection-2026-10-01/rain.png), [lightning](evidence/storm-wide-reflection-2026-10-01/lightning.png), [later view](evidence/storm-wide-reflection-2026-10-01/later-view.png). No extra texture samples, rendering passes, dynamic sky updates or lights. Performance benchmark not rerun; prior desktop result does not establish phone performance. No phone test/export; device attachment not checked. Owner visual acceptance remains pending. Changed files: storm_sky.gdshader, storm_weather.gd, native_track_visual.gd, this document, STORM_LIGHTNING.md, status/phase notes and new evidence.


## Kit 100: rain impacts in puddles (2026-10-01)

Owner authorizes trying the shader-only ripple proposal. Requirements V02/V04/V05/Q01. surface_detail.gdshaderinc adds one contained, staggered expanding impact per 2m world-space cell, with a 1.7s cycle and an approximately 0.8s visible lifetime. Rings perturb normals only under the existing puddle mask; no painted/emissive circles, new meshes, particles, texture samples or render passes. Existing reflection lighting provides their contrast. Subpixel rings fade by screen derivatives. The pattern is a bounded visual approximation, not individual rain collisions or a fluid simulation. Impact phases and centers vary across cells but repeat each cycle.

project.godot registers a ripple clock and enable switch. storm_weather.gd initializes and updates the clock only when weather advances, preserving pause. NativeTrackVisual cache revision is 100. test_storm.gd isolates ripple clock changes while other weather is frozen and checks rendered pixel differences. profile_storm_reflections.gd gains `-Screen ripples` to keep the sky active and compare only the ripple branch, with the same animated clock updates in both conditions.

Actual commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- Initial `CaptureStorm -Track track_acf29166cceaaa42` failed the new motion check (zero image difference): the first distance fade suppressed the rings at gameplay scale. Widened the rings and adjusted derivative fading; retained the assertion.
- Final `CaptureStorm -Track track_acf29166cceaaa42`: 96 checks, zero failures, no shader errors. Isolated ripple delta 1.8667 across 34000 sampled pixels. Normal gameplay capture inspected; small rings are visible in reflected pools, deliberately subtle.
- Final `TestSurfaceProfile`: 928 checks, zero failures, clean exit.
- `ProfileStormReflections -Track track_acf29166cceaaa42 -Screen ripples`: clean exit, RTX 3090 / Compatibility, 3600 samples with alternating off/on windows, 90 warm-up and 300 measured frames each. Median of three window GPU medians off/on: 720p 0.965/1.110ms (+0.145ms), 1080p 1.384/1.398ms (+0.014ms). Wall medians 2.779/2.834ms and 2.694/2.593ms respectively. Timings show drift and noise (GPU p95 varies substantially), so these are approximate desktop observations, not a precise isolated shader cost or a phone estimate. Draw calls stay 374, primitives 252137, texture allocation unchanged in each resolution.

Evidence: [first phase](evidence/storm-ripples-2026-10-01/rain.png), [0.27 seconds later with only ripple time changed](evidence/storm-ripples-2026-10-01/ripples-later.png), [raw timings](evidence/storm-ripples-2026-10-01/performance.json). Static screenshots do not establish animation quality. Owner in-motion acceptance, phone GPU/frame pacing and small-screen readability remain outstanding. No phone test/export; device attachment not checked. Current implementation assumes one active gameplay weather clock; editor previews inherit its last value. Changed files: six runtime/test/config sources named above, this document, status/phase notes and evidence.


## Kit 101: dense scattered impacts and cost audit (2026-10-01)

Owner follow-ups prioritize many smaller impacts, less grid alignment and checking fan/GPU load. Requirements V02/V04/V05/Q01. Impact cells shrink to 0.42m, with a new hashed position every event, staggered 0.38s periods and 0.26s lifetimes. Maximum ring-center radius is 0.078m before fade-out. Centers vary over 0.18m within each cell; cell containment remains a bounded approximation, not a full Poisson distribution. Wet-only normal perturbation and pause behavior remain. There are no individual particles or draw calls per impact: more spatial impacts do not increase evaluations per pixel.

The cost audit replaces sine-based hashes with arithmetic hashes, replaces the sine/exponential ring with a bounded polynomial, reuses the puddle-mask result and skips ring evaluation outside visible puddles. Cache revision advances to 101. The screenshot motion check is strengthened from delta >0.1 to >10; it remains a render regression, not a substitute for owner motion acceptance.

The profiler now accepts `-Screen ripples-60`, using an explicit 60 FPS cap for the same alternating off/on GPU measurements. Its earlier uncapped mode itself produces high GPU load. At the time of the fan report several other game instances were running; nvidia-smi reported RTX 3090 at 303.75W, 80C and 62% fan. These readings are whole-GPU load, not attribution to this feature. Other game instances were not terminated. Concurrent activity limits benchmark isolation; no mobile or thermal acceptance is claimed.


Actual checks via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `CaptureStorm -Track track_acf29166cceaaa42` after final tuning: 96 checks, zero failures; isolated motion delta 12.2784. An intermediate polynomial version failed the strengthened motion check (6.502); amplitude was corrected rather than weakening the check. Final screenshot inspected: many small impacts in pools instead of sparse large rings. User motion acceptance is still required.
- Final `TestSurfaceProfile`: 928 checks, zero failures.
- `ProfileStormReflections -Track track_acf29166cceaaa42 -Screen ripples`: completed uncapped while other game copies were running. This can contribute to fan load; not used as thermal acceptance.
- `ProfileStormReflections -Track track_acf29166cceaaa42 -Screen ripples-60`: completed before and after arithmetic simplification. Each run measures 3600 frames across alternating off/on windows. At 720p GPU window medians off/on were 1.486/1.478ms before and 1.458/1.443ms after. At 1080p: 2.071/2.589ms before (+0.518ms), 2.575/2.599ms after (+0.024ms). Rendered frame intervals stayed approximately 16.66ms. Background workload drift is apparent from the changed off baseline: this is not proof of a 0.494ms optimization gain. Optimized draw calls remain 374, primitives 252137; texture allocations unchanged. The post-optimization profile used polynomial amplitude 2.5; final visual tuning changes that multiplication constant to 4.0, without changing operations. Performance was not rerun for that constant-only adjustment.
- `nvidia-smi --query-gpu=name,utilization.gpu,power.draw,temperature.gpu,fan.speed --format=csv` and process inspection established concurrent GPU load. No game instances owned by the user were stopped. No physical-phone test or Android export; device attachment not checked.

Evidence: [small scattered impacts](evidence/storm-dense-ripples-2026-10-01/rain.png), [later phase](evidence/storm-dense-ripples-2026-10-01/ripples-later.png), [before capped timings](evidence/storm-dense-ripples-2026-10-01/before-60.json), [optimized capped timings](evidence/storm-dense-ripples-2026-10-01/optimized-60.json), [uncapped timings](evidence/storm-dense-ripples-2026-10-01/uncapped.json). A single-instance phone/desktop thermal check and in-motion visual approval remain outstanding. Changed files: surface_detail.gdshaderinc, native_track_visual.gd, test_storm.gd, profile_storm_reflections.gd, this document, status/phase notes and evidence. No physics, camera or lighting changes.


## Kit 102: physical-phone optimization

2026-10-01: offline-baked lens data replaces full-screen procedural droplet/rivulet math, wet-road relief skips non-road terrain and mobile lens trails use fewer segments. Physical DN2103 matched-duration median/p95 improve from 23.526/35.265ms to 16.457/24.493ms. Sustained actual-present median/p95 are 16.839/17.013ms with 2% missed refreshes. The optimized APK is installed; details, commands, tradeoffs and evidence are in [STORM_MOBILE_OPTIMIZATION.md](STORM_MOBILE_OPTIMIZATION.md).
