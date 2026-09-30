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
