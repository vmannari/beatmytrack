# Recent-change performance investigation — 2026-09-21

Requirements: R01/R03/G01/V03/V05/Q01. Scope: presentation CPU work, a collision-overlay hang, and physical-phone measurements. No handling, simulation cadence, collision geometry, race validation, effect density, camera framing or render-quality reduction was made by this task.

## Findings and changes

- `game/camera/impact_cracks.gd`: overflow circulated forever once every glass edge reached full damage. The existing eight checks never saturated all four edges. Overflow now visits at most three other edges and discards excess once they are full. A 100-impact regression terminates with every edge exactly 1.0; reset clears all damage.
- `game/ui/hud_frame.gd`, `game/ui/playground_hud.gd`: the speedometer's approximately 12 Hz updates rebuilt twenty 64-vertex backing polygons and its static arcs. The static draw list is now retained; only a child containing the ticks redraws when the illuminated tick count changes. Resize still invalidates the complete instrument. This preserves the existing drawing, rather than reducing its detail.
- `game/vehicle/sand_dust.gd`: skip transform/orientation uploads for inactive emitters and avoid unchanged emission-property writes. Existing world-space particles finish their normal lives; the next active sample uses the current wheel contact. Counts, opacity, lifetime and smoke's 120 Hz cadence are unchanged.
- `game/vehicle/skid_trails.gd`: reject sub-spacing samples immediately after computing the bridge-adjusted left-wheel position. Previously the other three bridge heights, four surface classifications and four intensity calculations ran even when the sample was discarded. The comparison run preserves every output transform, color and custom-data value exactly.
- `game/core/game.gd`, `game/diagnostics/mobile_race_probe.gd`: separate particle CPU timing and a debug-marker-only particles on/off/on experiment. Hidden diagnostic effects skip sampling. Normal gameplay enables them; the probe restores them at completion.
- `game/tests/test_performance.gd`, `game/tests/test_impact_cracks.gd`, `scripts/dev.ps1`: retained-drawing, saturation, emitter-transition and optional saved-source comparison checks, exposed through `TestPerformance`.

## Desktop verification

Actual commands use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with pinned Godot 4.7.2:

| Action | Result |
|---|---|
| `TestPerformance` | 9 glass checks and 13 performance/equivalence checks passed |
| `TestSoil` | 160 checks passed |
| `TestMobileControls` | 555 checks passed |
| `CaptureBridgeHUD` | 157 graphical checks passed; refreshed `build/bridge-hud-*.png` |
| `CheckScript -ScriptPath res://diagnostics/mobile_race_probe.gd` | Passed |
| `ExportAndroid -QuickValidation` | Import/startup, 74 driving, 18 catalog and 22 menu checks passed; signed debug APK exported |

The final optional before/after microbenchmark (five batches of 2,000 samples, median per sample) measured particles at 28.8875 → 27.362 microseconds and trails at 24.001 → 9.25 microseconds, approximately 2.6× faster for that trail workload. These are desktop CPU measurements, not phone FPS predictions. The benchmark sources are session-local files under `build/performance-2026-09-21/`; the functional tests also run without them.

One intermediate benchmark attempt failed to strip a CRLF class declaration from its saved baseline. It was stopped, the loader corrected, and the complete comparison passed. Export validation retained the existing ObjectDB leak warning in the driving test. No full physics/replay regression was run: this task did not edit canonical physics. Other work was concurrently editing road wear and bridge behavior in this shared workspace; those changes were preserved.

## Physical phone

DN2103, Android 13, Mali-G77 MC9, Compatibility renderer, normal 0.667 3D scale, compact Original+ vehicle, shadows enabled. APKs were actually installed and launched. Local tracks and records were retained. The AI probe exercises actual racing HUD, route validation and tyre effects without saving a personal best. It uses a diagnostic 10,000-lap limit to avoid ending early; ordinary races still use five laps.

Saved APK SHA-256:

- Before: `1BE0E9D04EC84F39A04E540353F4127C8DB9786163A59908D61C00997D4ECC81`
- After: `33A409D9C9B04E21853562D08668CD812D235EFB4173EB87765E2D7E49E6CAB3`

The 45-second Ajorata samples follow five seconds of warm-up:

| Build | Median frame | p95 | p99 | CPU process median | Frames >25 ms |
|---|---:|---:|---:|---:|---:|
| Before | 20.806 ms | 24.592 ms | 33.945 ms | 12.554 ms | 77 / 2,110 |
| HUD/emitter/glass fixes | 20.170 ms | 24.226 ms | 27.826 ms | 10.554 ms | 62 / 2,208 |
| Including trail optimization | 19.943 ms | 24.153 ms | 32.631 ms | 10.086 ms | 61 / 2,209 |

This is a modest observed median improvement (~48 → ~50 FPS), with lower CPU cost, **not steady 60 FPS and not proof that all recent changes are fast**. Cold shader/driver activity, thermal state and concurrent source changes limit attribution between APKs. Ajorata's AI hit obstacles 51 times and completed no lap; this is repeatable driving/load evidence, not successful racing acceptance. The new full-glass hang fix is independently tested; the phone run does not prove the old build reached complete glass saturation.

A within-one-APK particle on/off/on experiment used repeated 20-second samples after five-second warm-ups, resetting the race each stage:

| Particles | Median frame | p95 | Particle CPU median |
|---|---:|---:|---:|
| On A | 19.497 ms | 23.935 ms | 0.275 ms |
| Off | 19.542 ms | 23.183 ms | 0.016 ms |
| On B | 19.404 ms | 23.584 ms | 0.271 ms |

There is no material median-frame benefit from disabling particles in this Ajorata workload, so particle quality was retained. This does not cover sustained maximum sand clouds or drift smoke.

Stormy slalom also ran 45-second warmed samples with held touch-input events, using the saved before APK after the optimized run (reverse order):

| Build | Median frame | p95 | p99 | Frames >25 ms |
|---|---:|---:|---:|---:|
| Before | 25.999 ms | 30.659 ms | 32.856 ms | 1,189 / 1,711 |
| After | 24.841 ms | 28.524 ms | 30.777 ms | 831 / 1,801 |

The observed median improved from about 38.5 to 40.3 FPS, still well below the 60 FPS target. Zero collisions occurred; this run does not test maximum broken-glass cost. Existing historical Storm measurements used other builds/conditions and are not a matched baseline for this run.

The optimized saved APK was reinstalled after baseline comparisons. Diagnostic marker/results and temporary device capture/config files were removed, their absence checked, and the normal app was cold-launched. Player files were retained.

Raw reports, test logs and screenshots are in [the evidence directory](evidence/performance-2026-09-21/). [Ajorata phone capture](evidence/performance-2026-09-21/phone-ajorata.png) and [Storm phone capture](evidence/performance-2026-09-21/phone-storm.png) show the retained presentation. Captures are taken after the diagnostic pauses the race.

The SurfaceFlinger helper was also run before/after, but its first latency buffer included startup/old presentation timestamps (5–8 second maximum gaps). Those mixed-window aggregate reports are retained under `build/performance-2026-09-21/` and are not used to claim a steady-state improvement. The table uses the probe's bounded, warmed measurement windows.

## Reproduction and remaining acceptance

Build with `ExportAndroid -QuickValidation`, install with `InstallAndroid`. For the existing debug-only probe, push a JSON file to `/data/local/tmp/performance-probe.json`, then copy it with `adb shell run-as org.circuit01.handlinglab cp /data/local/tmp/performance-probe.json files/mobile_probe.json`. Force-stop the app before `LaunchAndroid`; launching an already-running activity does not reload the marker. Pull `files/mobile_probe_results.json` using `run-as` after completion.

Configuration for the measured normal run: `{"track_id":"track_acf29166cceaaa42","sustained":true,"seconds":45,"use_game_scale":true}`. For the particle experiment use `compare_particles:true`, omit `sustained`, and use `seconds:20`. Storm uses track `track_f7dc946b49ce9ea8`, with `touch_stress:true` to exercise held input events.

Remaining acceptance: longer thermal sessions, worst-case sand/smoke, additional devices, full races driven by the owner, and sustained 60 FPS on heavy tracks. Existing and concurrent edits remain uncommitted; this task does not bundle them into a misleading whole-workspace commit.
