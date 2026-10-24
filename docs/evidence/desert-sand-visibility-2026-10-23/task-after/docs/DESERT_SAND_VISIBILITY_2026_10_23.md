# More visible Desert sand — 2026-10-23

The owner reports that the sparse granular revision is barely visible. Increase its presence at the normal driving camera while retaining the irregular patches and quiet gaps from the previous revision.

## Requirements and changes

- **SVI01:** Make calm wind and gusts readable at ordinary driving zoom. Calm strength rises from 0.07 to 0.30; the gust target rises from 0.88 to 0.95. Square-root opacity keeps the ordinary-wind grains legible. Rounded, matte flecks have a wider range of light/dark warm pigments, with no emission or specular shine.
- **SVI02:** Give each localized burst more substance. Each existing site has 768 optical grain flecks rather than 192. Optical streak sizes change from 6.5–16 by 3–5 cm to 10–22 by 5–9.5 cm; these represent visible grain clusters at overhead scale, not literal particle size. Source width changes from 0.65–1.8 to 1.2–3.6 m, separating the flecks so they cover more ground within a burst.
- **SVI03:** Keep the six irregular world sites, eight-metre minimum separation, independent phases, skipped events, 28 cm maximum hop and exact source retention across collection cells. Event periods become 6–11 s, with 1.8–4.2 s emission windows and 12% skipped cycles. The effect still has empty ground and quiet intervals. No density sheet or curled veil is added.
- **G01/R01/Q01:** Preserve actual camera settings, canonical track/driving data, depth intersections, pause/background/hidden behavior, finish/retry, biome teardown, existing audio and vehicle dust. Verify both renderers at normal driving zoom, including calm wind.

Runtime changes are limited to `game/track/desert_sand_wind.gd` and its shader. The existing focused fixture, `game/tests/test_desert_sand_wind.gd`, adds a calm-wind image/check and a stronger visibility floor; its movie now uses the actual driving camera at 1280×720. A separate close detail image remains explicitly labelled as a fixture view.

The increased pool is bounded at **4,608 two-triangle instances / 9,216 triangles**, sharing the same mesh/material in one MultiMesh. This is four times the preceding grain pool. There are no new textures, shaders, nodes, draw batches, persistent caches, accounts or simulation work. CPU instance preparation and GPU vertex work increase with the pool; physical-device cost is unmeasured. Existing sources and the prepared visual relief remain shared, and preparation stays at collection-cell changes.

## Native evidence and verification

- [Compatibility motion at normal driving zoom](evidence/desert-sand-visibility-2026-10-23/gl_compatibility/motion.html).
- [Desktop Mobile motion at normal driving zoom](evidence/desert-sand-visibility-2026-10-23/mobile/motion.html).
- Each folder retains `before.png`, `gust.png`, `calm.png`, `detail.png`, `occlusion.png` and `timeline.json`. The six-second movie contains 90 native frames at 15 presentation steps per second, starting with a gust and then ordinary wind. The player uses lossless WebP encoding of those captured JPEG frames, preserving fine moving grains and quiet holds.

The same 12-second strong-wind fixture previously peaked at **303 Compatibility / 277 desktop Mobile pixels**. The revised peaks are **2,190 / 2,130**, about seven times the prior changed-pixel coverage at the same 1280×720 driving view. This is a visibility observation, not a visual-quality or performance certification. Calm snapshots change **1,901 / 1,891 pixels**; both strong-wind timelines also have fully quiet samples. All **783** projected interior pixels on the opaque roof remain exact in both renderers.

The focused checks require a peak of at least **2,000** changed pixels while retaining the original less-than-1% image-coverage ceiling, calm visibility of at least **600** pixels, quiet intervals below 35% of peak, and strict roof equality. Existing lifecycle, source continuity, finite-input and canonical data assertions remain. Final focused results: **52 headless / 62 Compatibility / 62 desktop Mobile**, all passing. Existing Desert **87**, ambience **111**, biomes **108**, parser **934 scripts** and scoped whitespace also pass; actual logs are retained in the receipt.

Native views use NVIDIA GeForce RTX 3090 desktop hardware. Mobile means the desktop Vulkan Mobile renderer. No physical-phone or frame-pacing claim is made. Fixture screenshot readbacks and deliberately controlled stepping can emit `RACE_HITCH` diagnostics; these are not gameplay measurements.

Pinned engine: `4.7.2.stable.official.ed1daf0bf`, via `scripts/dev.ps1`. Engine startup uses the approved normal local execution context for Windows certificate-store access. Actual commands and outcomes are in `evidence/desert-sand-visibility-2026-10-23/report.json`; representative commands are:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_sand_wind.gd -CommandTimeoutSeconds 180
.tools/review/Scripts/python.exe docs/evidence/desert-sand-visibility-2026-10-23/encode_preview.py
git diff --check -- game/track/desert_sand_wind.gd game/track/desert_sand_wind.gdshader game/tests/test_desert_sand_wind.gd
```

## Retained corrections and delivery

The first visibility attempt peaked at 1,221 pixels and used bright rectangular flecks; the strict new 2,000-pixel check failed. Its native images remain in `before/initial-bright-grains.png` and `before/initial-bright-detail.png`, with the original log. Rounding/muting the flecks and increasing density reached 1,659 pixels; that failed check also remains. Widening the individual local burst improved separation/readability and met the same unchanged thresholds in both final renderers.

The source checkpoint compares only this revision's three code/test files against their saved preceding versions, with additive documentation/status changes. Concurrent client/backend work is preserved. The prior sand-trial evidence remains untouched.

Reload the local client to try the revision. Owner acceptance of readability and natural appearance remains. The larger pool needs physical-device performance/appearance acceptance. No phone attachment check/device test, APK/export/install, backend/account mutation or deployment was performed.
