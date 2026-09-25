# Winter phone performance ? 2026-09-25

Requirements: V02/V04/V05/Q01. Owner requested physical-phone testing and optimisation if needed after accepting directional winter snow fragments.

Device: attached OnePlus Nord 2 / DN2103, Mali-G77 MC9, Android 13. Debug APK from pinned Godot 4.7.2, production 0.667 render scale, shadows and normal HUD. Runs are unscored local diagnostics. Particle counts, textures, camera and handling remain unchanged.

## Method

The existing mobile probe now records frames with snow chips/powder emitting and bank burst count. The phone runner supports winter selection and an explicit winter-stress option. Ordinary tests drive the owner's existing winter track (`track_b5d3f29314a7ae53`) using AI with touch-HUD stress. The stress test uses real vehicle physics, starts a 22 m/s slide near successive route samples every six seconds, and accelerates across banks/off-track. Teleports are excluded from driven distance, but their rendering/reset cost remains in frame timing. This is a deliberately artificial workload, not a lap record or player-driving acceptance. Its teleports can leave long diagnostic trail segments; its missed-checkpoint/crack overlays are expected.

Each stage warms for five seconds. Initial ordinary A/B/A sampled 30 seconds per stage with particles enabled/disabled/enabled. Bank stress samples 60 seconds before and after the optimisation. SurfaceFlinger actual-present timestamps were also collected during both stress runs; these overlap a different window from the engine's frame timer and must not be compared as identical samples. The final uninterrupted run samples 120 seconds.

## Change

The measured stress workload exposed particle CPU spikes. Snowbank effect sampling now computes body-envelope dimensions, axes and perimeter offsets once per simulation sample, reuses them across swept positions, and stops searching a position after its first bank hit. It preserves the first impact location and final touching state. This only changes presentation queries, not canonical snowbank physics, effect count or appearance. The phone profiling scripts and debug-only probe are the other code changes.

## Results

| Measurement | Before | Optimised |
|---|---:|---:|
| Stress particle CPU mean | 1.768 ms | 1.392 ms |
| Stress particle CPU p99 | 7.063 ms | 4.962 ms |
| Stress frame median / p95 | 16.865 / 20.477 ms | 16.801 / 20.270 ms |
| Stress frame p99 / maximum | 23.307 / 48.970 ms | 22.915 / 36.695 ms |
| Stress frames above 33.34 ms | 3 / 3543 | 2 / 3559 |
| Bank bursts | 25 | 25 |
| Frames with chip / powder emission | 2991 / 2767 | 3007 / 2784 |
| Distance, excluding teleports | 764.5 m | 766.2 m |

Particle CPU mean decreased 21.3%, p99 29.7%. This is a CPU-section saving, not a 21% FPS gain: median frame time was already near the refresh limit. Initial ordinary A/B/A medians were 16.841 / 16.852 / 16.883 ms with particles on/off/on, showing no material median frame-rate gain from removing the effects.

Stress actual presentation (SurfaceFlinger): median 16.837 ? 16.842 ms; p95 16.999 ? 16.996 ms; p99 17.362 ? 17.171 ms; maximum 67.381 ? 33.771 ms. Frames above 33.34 ms fell from 22/2430 to 4/2443 in these overlapping ~41-second windows. Sequential runs and reset timing limit causal attribution of individual outliers.

Final ordinary driving actual presentation: 3,661 frame intervals over 61.65 seconds, median **16.838 ms**, p95 **16.980 ms**, p99 **17.057 ms**, maximum **17.449 ms**, and **zero frames above 25 ms** in this sampled window. This supports smooth near-60-FPS delivery on the tested phone, without claiming a universal sustained guarantee.

The full 120-second ordinary sample covered 1,164 m and three completed laps: 7,128 engine frame samples, median 16.812 ms, p95 20.508 ms, p99 21.994 ms, maximum 37.716 ms; five frames above 25 ms and two above 33.34 ms. This AI line did not emit snow chips or hit banks (all three snow counters zero), so it is a steady-driving check, not the snow-load test. The separate stress run supplies that coverage. Battery temperature rose from 31.7 to 32.8 ?C during the final run; vendor phone temperature rose from 33 to 35 ?C.

The final APK is installed. Both stress and final [phone screenshots](evidence/winter-performance-final-2026-09-25/winter-phone.png) were inspected. Diagnostic configuration/results files were removed and the app relaunched in normal play; `run-as ... ls files` confirmed no probe markers remain. User track/record files were preserved. `git diff --cached --check` passed.

Changed files: `game/vehicle/sand_dust.gd`, `game/diagnostics/mobile_race_probe.gd`, `scripts/profile-features-phone.ps1`, this report, development status/plan, and the four winter-performance evidence folders.

## Actual commands

All engine commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `-Action Doctor`: pinned engine/templates and one authorised DN2103 found.
- `-Action ExportAndroid -QuickValidation`: import/startup passed; driving 74, catalog 18 and menus 22 checks passed; debug APK exported. Repeated after diagnostic additions and after optimisation.
- `-Action CheckScript -ScriptPath res://diagnostics/mobile_race_probe.gd`: passed.
- `-Action CaptureWinter`: 156 checks, zero failures after optimisation.

Phone commands (with `powershell -NoProfile -ExecutionPolicy Bypass -File`):

```text
scripts/profile-features-phone.ps1 -WinterProfile -Seconds 30 -ReportName winter-performance-before-2026-09-25
scripts/profile-features-phone.ps1 -WinterProfile -WinterStress -Baseline -Seconds 60 -ReportName winter-performance-impact-2026-09-25
scripts/profile-features-phone.ps1 -WinterProfile -WinterStress -Baseline -Seconds 60 -ReportName winter-performance-optimized-2026-09-25
scripts/profile_android_frames.ps1 -Seconds 40 -Output docs/evidence/winter-performance-impact-2026-09-25/present
scripts/profile_android_frames.ps1 -Seconds 40 -Output docs/evidence/winter-performance-optimized-2026-09-25/present
scripts/profile-features-phone.ps1 -WinterProfile -Baseline -SkipInstall -Seconds 120 -ReportName winter-performance-final-2026-09-25
scripts/profile_android_frames.ps1 -Seconds 60 -Output docs/evidence/winter-performance-final-2026-09-25/present
```

Raw JSON, configurations, APK hashes, temperatures and phone screenshots are retained in the matching `docs/evidence/` directories. Phone timestamps differ from the workstation date; folder dates use the workstation session date.

## Limits

One USB-powered phone and a finite test duration; not a device fleet or long thermal soak. CPU section timings are per rendered frame and can contain multiple simulation ticks. These overlap GPU work and are not additive frame-time savings. Near-60-FPS median does not mean every frame meets 16.67 ms. Visual acceptance while a person drives remains separate.
