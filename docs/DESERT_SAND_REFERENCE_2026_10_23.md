# Desert windblown sand: reference correction, 2026-10-23

The owner rejects the enlarged yellow flecks and supplies a photograph of fine, muted sand blowing off a dune crest. This revision replaces the grain pool with soft beige-grey powder emitted in irregular local bursts from prepared sand-bank crests. The new reference supersedes the grain-only appearance in SGR/SVI; it does not restore the original regularly distributed branching sheets. Existing terrain artwork, lighting, road/bank geometry, vehicle dust, camera and driving remain unchanged by this slice.

## Requirements and implementation

- **RSP01 — colour:** use a low-saturation `b8b1a7` material tint, diffuse light and matte response, with no bright grain cores or emission. The shader exposes a `source_color` uniform; the noise texture contains scalar data. Godot documents the colour-space distinction between colour uniforms/textures and data in its [shader language reference](https://docs.godotengine.org/en/4.4/tutorials/shaders/shader_reference/shading_language.html#uniforms).
- **RSP02 — fine airborne powder:** 48 camera-facing quads, eight per possible source, share one MultiMesh and material: **96 triangles** instead of 9,216. Advected multiscale density, soft warped edges and unequal lifetimes replace individually visible flakes. Powder rises approximately 0.3–0.85 m above its source and drifts with wind; source bursts have different 6–11-second periods, skipped cycles and quiet intervals. Final opacity multiplier is 0.28, with existing ordinary/gust strengths 0.30/0.95. Rendered transparency is checked in both desktop renderers.
- **RSP03 — grounded, irregular emission:** read prepared gravel-role bank vertices once during configuration, inspect at most 8,192 vertices and retain at most 512 crest anchors. UV-marked banks must be above their ground support, in loose sand and outside bridge cover. Up to six separated sites are active near the camera, with at least 8 m between them. Sites remain fixed until their entire drift/billboard envelope has left the visible region. Flat native tracks retain the irregular world-site fallback. There is no per-frame mesh scan or runtime texture generation.
- **G01/R01/Q01 — preserved contracts:** retain finite-input, pause/background/hidden, finish/retry, biome teardown and exact canonical/driving guards. Renderer-specific depth reconstruction, soft ground intersection and a roof-height guard keep low powder off opaque roofs. Existing wind audio drives intensity.

Runtime changes are `game/track/desert_sand_wind.gd`, its shader and one new mipmapped 256×256 numerical density texture. The texture has a reproducible offline Godot recipe in `game/tests/bake_desert_wind_density.gd`; provenance is in `licenses/ASSETS.md`. It is 157,626 PNG bytes and approximately 0.34 MiB decoded RGBA with mipmaps. Fewer triangles do not establish a performance win: transparent fragment work and physical-device cost remain unmeasured.

## Native evidence and checks

- [Compatibility motion at normal driving zoom](evidence/desert-sand-reference-2026-10-23/gl_compatibility/motion.html).
- [Desktop Mobile motion at normal driving zoom](evidence/desert-sand-reference-2026-10-23/mobile/motion.html).
- Each renderer folder contains `before.png`, `gust.png`, `calm.png`, `detail.png`, `palette.png`, `occlusion.png`, `timeline.json` and `palette.json`. Detail/palette views are explicitly fixture views. Motion contains 90 actual Godot frames at normal driving zoom, gust then ordinary wind, encoded losslessly from the captured JPEG frames. Timing and encoded frame counts are in `preview-encoding.json`.

The neutral-ground colour fixture retains the actual Desert light but hides the warm fullscreen sun veil only for this disposable colour-isolation view. Its original visibility is restored afterward. Production lighting is untouched. The fixture checks mean saturation below 0.16, zero bright saturated specks and 99th-percentile per-channel contrast below 0.20. The ordinary driving views include the original warm scenery and sun veil.

Soft powder necessarily affects more low-contrast pixels than tiny isolated grains. The latest reference therefore replaces SVI's less-than-1% grain-coverage ceiling with a less-than-8% local-powder ceiling, retaining the 2,000-pixel visibility floor, calm floor of 600, quiet-interval ratio and strict zero changed roof pixels. This is an explicit appearance-contract change for the new owner reference; source continuity, lifecycle, canonical data and roof/depth assertions remain. Pixel coverage is not visual-quality or performance certification.

Focused tests pass **55 headless / 68 Compatibility / 68 desktop Mobile** assertions. Existing Desert **87**, ambience **111**, biomes **108**, parser **987 scripts** and import pass. The final native results, actual commands, hashes and task-only Git checkpoint are in [report.json](evidence/desert-sand-reference-2026-10-23/report.json). Native hardware is an RTX 3090; desktop Mobile uses Vulkan and is not a phone test. Capture readbacks and deliberately controlled stepping can emit `RACE_HITCH`; these logs are not gameplay frame-time measurements.

Representative actual commands, using pinned `4.7.2.stable.official.ed1daf0bf`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_desert_wind_density.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 300
.tools/review/Scripts/python.exe docs/evidence/desert-sand-reference-2026-10-23/encode_preview.py
```

## Retained corrections and acceptance

The first soft-powder pass was too subtle and its neutral-floor probe included the warm sun veil, failing the colour-isolation check. The initial images/log remain. Increasing opacity to 0.42 improved readability, but desktop Mobile failed the unchanged 0.20 contrast limit; 0.30 still measured 0.204. Final 0.28 passes. A stray focus-loss pause caption was also hidden in the capture fixture, preserving production pause behaviour and preventing UI changes from entering the sand pixel comparison. These attempts are retained in this receipt, with earlier DSW/SGR/SVI evidence untouched.

The scoped patch compares runtime/test files with their saved preceding versions, adds the new texture/recipe and documentation, and preserves concurrent work. It includes a binary patch for the texture and additive status updates. The checkpoint is checked with `git apply --reverse --check`; it is not a repository-wide commit.

Reload the local client to try it. Owner acceptance of colour, movement and natural appearance remains, as does sustained physical-device performance/appearance acceptance. No phone attachment check or device test was performed. No APK/export/install, live account/backend mutation or deployment was performed.
