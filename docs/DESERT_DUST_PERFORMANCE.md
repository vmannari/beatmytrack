# Desert dust mobile performance — 2026-10-03

Requirements: **V02/V04/V05, R01, Q01**. Owner reports mobile slowdown with many desert clouds. This presentation slice retains deliberately obstructive dust, nine-second lifetime, emission response, colour, expansion, soft road/car intersections and particle capacities: four 64-particle lingering emitters plus four 48-particle contact emitters. Canonical physics, rules, surfaces and camera settings are unchanged.

`desert-dust-10` trims the billowing cards to a circumscribed octagon. The radial shader already has zero opacity outside the inscribed circle; the mesh removes 17.16% of rasterized card area without cutting visible cloud support. UV rotation is affine, so its sine/cosine and matrix multiplication now run at vertices and interpolate across each card. Mipmapped linear sampling replaces unnecessary anisotropic filtering on the camera-facing dust cards. The existing depth intersection shader remains. Generic irregular sand clouds restore their original square meshes when leaving desert. The extra four triangles per cloud trade a small geometry increase for less transparent pixel work.

Shader interpolation and Compatibility depth conventions were checked against the official [shading-language](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html) and [depth reconstruction](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html) documentation; actual pinned-engine desktop and phone rendering were then exercised.

Changed files:

- `game/vehicle/sand_dust.gd`: mesh and shader optimization, presentation version.
- `game/tests/test_desert.gd`: verify triangle area, coverage of the entire circular rim, preserved affine UVs/capacity, restoration outside desert; resume the disabled-physics capture fixture after focus loss so the pause drawer does not hide evidence. Lingering evidence waits three real seconds.
- `game/diagnostics/mobile_race_probe.gd`: launch local benchmarks through the practice path with explicit offline-only startup. Ordinary Race now rejects unpublished local tracks; the old probe therefore attempted to configure a null game. The diagnostic still enables the canonical timed validator and sets the unscored/practice flag; it does not obtain a race ticket or save competitive results/last-track preferences. Existing practice HUD visibility remains, so this is not full ordinary-race HUD acceptance.
- This report, status/phase notes and the evidence directories linked below. Unrelated working-tree edits are retained.

## Physical-device results

DN2103 / Mali-G77 MC9, pinned Godot `4.7.2.stable.official.ed1daf0bf`, Compatibility, 0.667 world rendering scale. Two freshly exported debug APKs compare the prior dust source and optimized dust source; both include the repaired diagnostic. Each run measures production particles / particles hidden / production particles, with five-second warmups and fifteen-second sample windows. Actual physics drives the local desert track `track_3e26605a8a90165e` with touch stress. The first production window includes approximately 146–152 m of warmup plus sampled travel; repeated windows cover approximately 120–121 m.

| Build / window | Frames | Median ms | p95 ms | p99 ms | Frames >33 ms |
|---|---:|---:|---:|---:|---:|
| Before, dust on | 809 | 17.167 | 27.107 | 31.717 | 3 |
| Before, particles hidden | 880 | 17.117 | 20.179 | 22.062 | 0 |
| Before, dust on repeat | 838 | 17.426 | 27.985 | 32.689 | 6 |
| After, dust on | 891 | 16.725 | 20.311 | 22.162 | 1 |
| After, particles hidden | 892 | 16.713 | 20.632 | 23.053 | 0 |
| After, dust on repeat | 892 | 16.769 | 20.112 | 22.318 | 0 |

The two dust-on p95 comparisons improve 25.1% and 28.1%; p99 improves about 30% and 32%. This supports reduced dust-related long frames on this device. It does not establish a guaranteed 60 fps or universal GPU speedup. The first old-build window also contains one 784 ms maximum frame; raw samples retain it. CPU particle sampling stays approximately 0.49 ms, consistent with this being a rendering optimization rather than a canonical/sampling change. Battery temperature rises 35.4→36.1°C before and 36.4→37.1°C after; clocks are not controlled and travel differs slightly.

Raw reports, configs, battery readings, hashes and paused end-of-run phone captures: [before](evidence/desert-dust-before-fixed-probe-2026-10-03/desert.json), [after](evidence/desert-dust-after-2026-10-03/desert.json). The profiler intentionally pauses after completing all timing windows; its phone image therefore contains the pause drawer, and is not an unobscured visual acceptance capture. Both runs cleaned their diagnostic markers and relaunched normal play. The optimized APK remains installed.

APK SHA-256:

```text
Before: 7181AEC1B7B423263B49D879AA687DC8EC8260764B1C3280A47C483D4D4C3121
After:  C28408E116633BF0EA436AFF008CF39D45133AFD3D57D737F9B2DC316C638F0F
```

## Actual commands and outcomes

Commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and matching installed templates; the older PATH Godot alias was not used.

| Arguments / command | Outcome |
|---|---|
| `-Action Doctor` | First attempt fails with an adb connection reset; direct SDK adb retry finds the authorized DN2103. |
| `-Action TestDesert` | 87 checks pass, including five-car exact desert replay and cloud footprint checks. |
| `-Action TestSoil` | 163 checks pass. |
| `-Action CaptureDesert -Track track_3e26605a8a90165e` | Original baseline: 79 checks pass on retry after a WASAPI GetBufferSize failure. Optimized final: 113 checks pass. An earlier optimized image had the focus-loss pause drawer; the capture fixture was corrected and rerun. One unintended capture while the old source was temporarily restored for its APK fails the new mesh assertion; restored optimized source passes without weakening assertions. |
| `-Action TestPerformance` | Impact 9 and presentation 16 checks pass. Its optional historical CPU comparisons use older September fixtures and are not dust-10 GPU measurements. |
| `-Action TestStorm`, `-Action TestIce` | 91 and 69 checks pass. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | 262 scripts parse, zero failures. |
| `-Action ExportAndroid -QuickValidation` (before and after) | Both pass import/startup, driving 72, catalog 21, menus 48 and debug APK export. Three shutdown instance-leak warnings occur in driving; exporter falls back to installed SDK build-tools 35.0.1. Full Validate is not run. |
| `scripts/profile-features-phone.ps1 -DesertCostProfile -SkipInstall -Seconds 15 -ReportName desert-dust-before-2026-10-03` | Initial installed-build run fails 0/3 stages because the local Race launch is rejected; null-game error isolated in logcat. Markers cleaned and normal play restored. |
| `scripts/profile-features-phone.ps1 -DesertCostProfile -Seconds 15 -ReportName desert-dust-before-fixed-probe-2026-10-03` | Baseline APK installs; all three phone stages complete. |
| Same profiler with `-ReportName desert-dust-after-2026-10-03` | Optimized APK installs; all three phone stages complete. No shader/script errors seen in the inspected optimized logcat tail. |
| `git diff --check` on the three changed GDScripts | Pass. |

Desktop evidence inspected: [before dense](evidence/desert-dust-performance-2026-10-03/before-dense.png), [after dense](evidence/desert-dust-performance-2026-10-03/after-dense.png), [three-second lingering](evidence/desert-dust-performance-2026-10-03/after-lingering.png), [off-track](evidence/desert-dust-performance-2026-10-03/after-off-track.png). Captures use the real race renderer with a scripted presentation path; they are not manually driven races. Existing historical desert screenshots were restored after copying this task's evidence.

## Remaining acceptance

Owner driving/appearance review, sustained hot-device racing, dense repeated-lap overlap at higher speeds, all vehicles/camera options and lower-end phones remain. No manually driven phone race or cross-device replay test was performed. No canonical change, full physics regression, production/backend deployment or mixed-workspace commit. A scoped patch checkpoint is retained at `build/desert-dust-performance-2026-10-03.patch`; raw command logs remain in `build/logs/` and selected focused logs are copied beside the desktop evidence.
