# Storm mobile optimization - 2026-10-01

Requirements V02/V04/V05/Q01. Owner reports uneven Storm gameplay on the physical phone; desktop timings were not sufficient mobile acceptance.

## Changes

- Replaced the full-screen procedural wet-glass shader (two bead fields and six winding-rivulet calculations per pixel) with original offline-baked linear data. Runtime does one data lookup and a single refraction lookup only under water coverage. The 1536x768 RGBA texture costs approximately 4.5 MiB uncompressed, 561 KB PNG; there is no runtime bake or new screen copy. Large moving lens drops, rain streaks, lightning and puddle ripples stay animated. Small adhered beads and rivulets are now static shapes; lightning still lights them. Baked shapes scale with viewport aspect rather than regenerating their layout. Owner visual acceptance of this tradeoff remains.
- Wet-road relief now exits for zero road coverage, avoiding noise/normal calculations on the surrounding grass/sand terrain.
- Mobile lens trails join every third retained history sample, reducing decorative line submissions while retaining their duration and movement. Desktop trail geometry is unchanged.
- Cache revision 102. No camera, track geometry, canonical handling or race-rule changes in this task.

Asset provenance: `game/assets/textures/storm_glass_data.png` is generated solely from this project's original storm shader. `game/tests/bake_storm_glass.gdshader` retains the procedural source; `game/tests/bake_storm_glass.gd` renders the packed normal/coverage/rim data. No external images or service used. Import preserves raw channels (no sRGB sampler, alpha-border repair or premultiplication). Regenerate through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 BakeStormGlass`, then Import. The bake validates nonconstant alpha; an intermediate opaque-viewport bake lost rim alpha and was corrected to transparent output before the final deployment.

## Validation

Actual pinned-engine commands through scripts/dev.ps1: BakeStormGlass succeeds with valid 1536x768 data; Import succeeds; CaptureStorm -Track track_acf29166cceaaa42 passes 96 checks including isolated ripple motion; TestSurfaceProfile passes 928. Final ExportAndroid -QuickValidation passes import/startup, driving 72, catalog 18, menus 48 and exports the debug APK. Build-tools 35.0.1 fallback and existing driving ObjectDB cleanup warnings remain. No full all-project/physics regression run is claimed. One initial BakeStormGlass invocation was rejected before execution because the new action was not yet in ValidateSet; corrected.

Device DN2103 / Android 13 / Mali-G77 MC9 was attached. `scripts/profile-features-phone.ps1 -StormOnly -Baseline` installs with `adb install -r` (unless -SkipInstall), runs unscored AI with touch stress at existing 0.667 scale, removes its debug marker and restores the normal app. Existing player data is retained. No manual driving skill/handling acceptance claimed. Current workspace APK includes unrelated concurrently authorized UI/handbrake changes, so measurements compare complete builds, not perfectly isolated shader variants.

| Run | Sample | Internal median | Internal p95 |
| --- | --- | --- | --- |
| Installed baseline, -SkipInstall | 30 s | 23.526 ms | 35.265 ms |
| Intermediate baked overlay | 30 s | 19.479 ms | 31.557 ms |
| Final combined optimizations | 45 s | 16.373 ms | 23.922 ms |
| Final repeat, matching baseline duration | 30 s | 16.457 ms | 24.493 ms |

The matched-duration result is about 30% lower median and p95 frame time. Sequential runs have different thermal/load conditions; this is not proof of exact individual savings. Some frames still miss 60 FPS. Baseline battery temperature was 37.4 C; temperatures and APK hashes are retained per run. The intermediate baked result predates the alpha correction and is not final visual acceptance.

Commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-features-phone.ps1 -StormOnly -Baseline [-SkipInstall] -Seconds 30|45|60 -ReportName <folder-name>` with the actual durations shown above. Evidence folders are `storm-mobile-before-2026-10-01`, `storm-mobile-baked-2026-10-01`, `storm-mobile-final-2026-10-01`, `storm-mobile-repeat-2026-10-01`, and `storm-mobile-sustained-2026-10-01` under docs/evidence. Raw config files preserve exact settings.

An initial SurfaceFlinger capture overlapped debug-stage completion/relaunch (4-second gap), and a second captured only the tail before the layer disappeared. Neither establishes steady driving frame pacing. Their raw outputs are retained with those limits. The sustained run collects display timestamps during the driving window separately.

Changed files: storm_wet_glass.gdshader, storm_weather.gd, surface_detail.gdshaderinc, native_track_visual.gd, the generated texture/import, bake script/shader, scripts/dev.ps1 action, this document, STORM_WET_MATERIAL.md, status/phase notes and evidence. Long thermal soak, other phone GPUs and owner visual/driving acceptance remain outstanding.


Final sustained phone result (60 seconds): internal median 16.460ms, p95 24.296ms. Separate SurfaceFlinger sample wholly during driving collected 1551 intervals across 26.64s: median 16.839ms, p95 17.013ms, p99 33.680ms, maximum 33.902ms; 31 intervals exceeded 25ms (2.0%). This confirms considerably steadier displayed frames, not a locked-60 guarantee or a long thermal soak. [Phone gameplay screenshot](evidence/storm-mobile-sustained-2026-10-01/phone.png) inspected with active rain, road reflections and small impacts. [Display timing report](evidence/storm-mobile-sustained-2026-10-01/present.json), [internal report](evidence/storm-mobile-sustained-2026-10-01/storm.json), [desktop preview](evidence/storm-mobile-optimization-2026-10-01/desktop.png). Earlier phone captures landed after completion (pause drawer/sign-in); they are not driving evidence.

The profiler restored normal app launch and removed mobile_probe markers after all runs. USB reverse tcp:18181 was restored and verified for the local backend. Final optimized APK remains installed. No production deployment. User approval of mobile smoothness and the now-static small lens beads remains pending.
