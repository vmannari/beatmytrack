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
