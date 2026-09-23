# Grass visual and phone comparison — 2026-09-23

Requirements V02/V04/V05/Q01. The owner clarified that restoring the old texture does not meet the goal: improve vegetation while avoiding significant performance loss.

## Visual change

Kit 57 introduces original narrow-blade meadow artwork with curved fans, root cavities and muted olive/sage tips. It replaces the old round-leaf ground cover for Pine and Storm grass only. The existing three-scale approach now uses actual grass artwork for its medium-scale structure. A rotated, offset companion sample reduces obvious repetition; low-amplitude baked macro colour and mip-filtered fine normals retain variation. Five opaque folded tuft meshes gain wider blades and a dark-root/pale-tip vertex gradient. Triangles, instance counts, shadow settings and physics remain unchanged. Original world/camera dimensions remain unchanged.

The first integration was too bright under the game's lighting; its material tint was corrected before the phone build. No runtime procedural noise was added. New texture import is capped to 1024 with mipmaps. The generated raster is retained unchanged in `game/assets/textures/meadow_grass_v2.png`; [exact prompt and provenance](GRASS_MEADOW_PROMPT.md).

[Interactive same-camera comparison](evidence/grass/comparison.html) covers the default circuit, Ajorata and Storm. [Ajorata current](evidence/grass/track_acf29166cceaaa42/hybrid-driving.png) and [original](evidence/grass/track_acf29166cceaaa42/grass_original-driving.png); [Storm current](evidence/grass/track_f7dc946b49ce9ea8/hybrid-driving.png). Desktop captures were inspected. The generation prompt requested a seamless texture, but exact periodic boundaries are not mathematically guaranteed; broader route and device motion review remain part of visual acceptance.

## Measurement protocol

Physical DN2103 / Android 13, Godot 4.7.2 Compatibility, existing game render scale, normal weather, shadows, HUD, input, timing, trails and particles. Fresh APK exported after quick validation and installed with `adb install -r`, preserving player data. The local debug probe runs unscored AI drives; it does not save records. The runner removes its temporary marker/results and restores normal play on completion.

Three modes share the same scene and canonical track:

- `grass_original`: original painted grass shader, new normals disabled and tuft roots hidden.
- `grass_material`: new meadow material and normals, tufts hidden.
- `baseline`: complete new material plus tufts (the shipping candidate).

The original comparison restores the actual pre-hybrid grass colour function, rather than the unrelated historical asphalt probe. Current stone/prop geometry remains fixed across all modes; it does not recreate the small green low-cover mounds removed in kit 55. This is a conservative material/tuft comparison, not a full historical build rollback.

First pass: original / full / original / material-only / full / original, each five seconds warming plus twenty seconds measured, on Ajorata and Storm. Six stages per track. A later Storm repeat uses the same sequence with ten-second measurement windows to examine the device-wide slowdown observed late in the first pass. Reports are whole-frame wall-clock times, not isolated GPU timestamps. Capped frame pacing can hide GPU headroom differences. Changing weather phases and AI trajectories limit exact reproducibility.

Raw evidence: [first pass](evidence/grass-performance-2026-09-23/), [Storm repeat](evidence/grass-performance-storm-repeat-2026-09-23/). These include stage configuration, APK SHA-256, device identity, battery readings and every stage result. Late in the first Storm run, simulation and telemetry costs nearly doubled as well as frame time; the original material remained slow when restored. This is evidence of a device-wide performance shift, consistent with throttling, not proof that grass caused the slowdown. A thermal-service inspection reported active `cpu_adaptive_0` cooling, while the overall Android thermal status was 0; vendor battery readings reached 44.3 °C. Avoid mixing the earlier fast and later slow stages into one claimed grass cost.

## Measured results

Each reference below is the average of the original-material medians bracketing the corresponding full-grass run. Differences of a few hundredths of a millisecond are noise, not an optimization claim.

| Track/run | Original median | New material + tufts | Difference |
|---|---:|---:|---:|
| Ajorata first full run | 16.792 ms | 16.788 ms | -0.004 ms (-0.02%) |
| Ajorata second full run | 16.828 ms | 16.784 ms | -0.044 ms (-0.26%) |
| Storm repeat first full run | 16.786 ms | 16.985 ms | +0.200 ms (+1.19%) |
| Storm repeat second full run | 16.771 ms | 17.008 ms | +0.238 ms (+1.42%) |

Ajorata p95: original 20.280–20.325 ms, full grass 20.198–20.297 ms. Storm repeat p95: original 19.448–19.921 ms, full grass 19.122–19.132 ms. Material-only medians were 16.815 ms on Ajorata and 16.756 ms on the Storm repeat. Endpoint draw counts rose from about 355 to 370 on Ajorata and 316 to 330 on the Storm repeat; counts depend on camera position. The measured cost in these stable runs is small, with no detected significant frame-time regression. This is not a guarantee for every track, phone or temperature.

The first Storm pass must also be retained: original / full / original / material / full / original medians were **16.763 / 17.043 / 16.759 / 16.989 / 28.001 / 27.340 ms**. The material-only run's p95 jumped to 28.556 ms during the transition; the late full and original p95 were 30.550 and 29.587 ms. Simulation mean rose from about 0.79 to 1.46–1.51 ms in both late modes. These observations motivated the repeat; averaging fast and slow baselines together would misattribute the device-wide change to grass. The late full versus immediately following original difference was +0.661 ms (+2.42%), but that pair is less controlled than the repeat.

Eighteen comparison stages completed (16,789 measured frames). A separate two-stage `-GrassProfile -Baseline -SkipInstall -Seconds 10 -ReportName grass-phone-review-2026-09-23` run captures the restored final material on both tracks after measurement ends. Phone screenshots retain the diagnostic unscored 10,000-lap target; normal races still use five laps. [Storm phone view](evidence/grass-performance-storm-repeat-2026-09-23/storm-phone.png), [Ajorata phone view](evidence/grass-phone-review-2026-09-23/ajorata-phone.png). Both phone views were inspected. Player records and track files were retained; normal play was restored after the probes. A final device file listing confirms that `mobile_probe.json` and `mobile_probe_results.json` are absent. The two final capture runs add 1,177 measured frames; they are visual confirmation, not additional original/new comparisons.

## Commands and checks

All Godot actions below run through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action` with the pinned engine/templates.

| Action | Actual outcome |
|---|---|
| `Import` | Passed; 1024 texture cap and mipmaps configured |
| `CaptureGrass` | 30 checks passed, original/material/full comparison captured |
| `CaptureGrass -Track track_acf29166cceaaa42` | 46 checks passed; Ajorata comparison captured |
| `CaptureGrass -Track track_f7dc946b49ce9ea8` | 46 checks passed; Storm comparison captured |
| `TestGrass` | 15 checks passed |
| `TestSurfaces` | 50 checks passed |
| `TestBiomes` | 92 checks passed |
| `TestSurfaceProfile` | 928 graphical checks passed |
| `ExportAndroid -QuickValidation` | Import/startup, 74 driving, 18 catalog, 22 menu checks passed; fresh APK exported |

Phone runner commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-features-phone.ps1` with `-GrassProfile -Seconds 20 -ReportName grass-performance-2026-09-23`, then `-GrassProfile -StormOnly -SkipInstall -Seconds 10 -ReportName grass-performance-storm-repeat-2026-09-23`. Initial export retains existing build-tools 35.0.1 fallback and the driving test's two ObjectDB shutdown leak warnings. No canonical physics changes; full replay regression was not rerun.

Changed files: new meadow PNG/import and provenance; `native_track_visual.gd`, `surface_detail.gdshaderinc`, `grass_tufts.gd`, `grass_tuft.gdshader`; diagnostic `surface_material_probe.gd`; `test_grass.gd`, `dev.ps1`, `profile-features-phone.ps1`; status/plan and evidence. No new runtime service or dependency.

Owner visual approval, longer thermal runs and other target devices remain outstanding. Passing programmatic checks is not visual acceptance.
